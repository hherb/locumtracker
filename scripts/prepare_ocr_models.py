#!/usr/bin/env python3
"""
PaddleOCR Model Preparation Script

Downloads pre-converted PaddleOCR ONNX models from Hugging Face and validates the output.
Designed for use with the LocumTrackerOCR Swift package.

Usage:
    uv run scripts/prepare_ocr_models.py [--force] [--output-dir PATH]

Requirements:
    - requests

Example:
    uv run scripts/prepare_ocr_models.py --force

Models are sourced from: https://huggingface.co/monkt/paddleocr-onnx
(Apache 2.0 License)
"""

import argparse
import hashlib
import logging
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

import requests

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)


# =============================================================================
# Configuration Constants (mirroring Swift OCRConfiguration)
# =============================================================================

# Hugging Face base URL for raw file downloads
HF_BASE_URL = "https://huggingface.co/monkt/paddleocr-onnx/resolve/main"


@dataclass(frozen=True)
class PreConvertedModel:
    """Configuration for a pre-converted ONNX model download."""

    name: str
    url: str
    output_filename: str
    min_size_bytes: int


@dataclass(frozen=True)
class OCRConfig:
    """Configuration constants for OCR model preparation."""

    # Pre-converted ONNX model configurations from Hugging Face
    # Source: https://huggingface.co/monkt/paddleocr-onnx (Apache 2.0 License)
    DETECTION_MODEL = PreConvertedModel(
        name="detection",
        url=f"{HF_BASE_URL}/detection/v3/det.onnx",
        output_filename="det_v3.onnx",
        min_size_bytes=2_000_000,  # ~2 MB minimum (actual: 2.43 MB)
    )

    RECOGNITION_MODEL = PreConvertedModel(
        name="recognition",
        url=f"{HF_BASE_URL}/languages/english/rec.onnx",
        output_filename="rec_english.onnx",
        min_size_bytes=7_000_000,  # ~7 MB minimum (actual: 7.83 MB)
    )

    # Character dictionary from the same repository
    CHARACTER_DICT = PreConvertedModel(
        name="dictionary",
        url=f"{HF_BASE_URL}/languages/english/dict.txt",
        output_filename="en_dict.txt",
        min_size_bytes=1_000,  # ~1 KB minimum (actual: 1.42 KB)
    )

    # Network settings
    MAX_RETRY_ATTEMPTS = 3
    RETRY_BASE_DELAY_SECONDS = 1.0
    RETRY_MAX_DELAY_SECONDS = 30.0
    RETRY_BACKOFF_MULTIPLIER = 2.0
    REQUEST_TIMEOUT_SECONDS = 60
    DOWNLOAD_TIMEOUT_SECONDS = 300


# =============================================================================
# Utility Functions
# =============================================================================


def calculate_sha256(file_path: Path) -> str:
    """
    Calculate the SHA256 checksum of a file.

    Args:
        file_path: Path to the file to hash.

    Returns:
        The hexadecimal SHA256 checksum string.
    """
    sha256_hash = hashlib.sha256()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            sha256_hash.update(chunk)
    return sha256_hash.hexdigest()


def calculate_exponential_backoff(
    attempt: int,
    base_delay: float,
    max_delay: float,
    multiplier: float,
) -> float:
    """
    Calculate delay for exponential backoff.

    Args:
        attempt: The current attempt number (0-indexed).
        base_delay: The base delay in seconds.
        max_delay: The maximum delay in seconds.
        multiplier: The multiplier for exponential growth.

    Returns:
        The delay in seconds to wait before the next attempt.
    """
    delay = base_delay * (multiplier**attempt)
    return min(delay, max_delay)


def download_file_with_retry(
    url: str,
    destination: Path,
    timeout: int = OCRConfig.DOWNLOAD_TIMEOUT_SECONDS,
    max_retries: int = OCRConfig.MAX_RETRY_ATTEMPTS,
) -> None:
    """
    Download a file from a URL with retry and exponential backoff.

    Args:
        url: The URL to download from.
        destination: The local path to save the file.
        timeout: Request timeout in seconds.
        max_retries: Maximum number of retry attempts.

    Raises:
        requests.RequestException: If download fails after all retries.
        IOError: If file cannot be written.
    """
    last_exception: Optional[Exception] = None

    for attempt in range(max_retries):
        try:
            logger.info(
                f"Downloading {url} (attempt {attempt + 1}/{max_retries})..."
            )

            response = requests.get(url, timeout=timeout, stream=True)
            response.raise_for_status()

            total_size = int(response.headers.get("content-length", 0))
            downloaded_size = 0

            with open(destination, "wb") as f:
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
                        downloaded_size += len(chunk)

                        if total_size > 0:
                            progress = (downloaded_size / total_size) * 100
                            print(
                                f"\rProgress: {progress:.1f}% "
                                f"({downloaded_size:,} / {total_size:,} bytes)",
                                end="",
                                flush=True,
                            )

            print()  # New line after progress
            logger.info(f"Successfully downloaded to {destination}")
            return

        except requests.RequestException as e:
            last_exception = e
            logger.warning(f"Download attempt {attempt + 1} failed: {e}")

            if attempt < max_retries - 1:
                delay = calculate_exponential_backoff(
                    attempt,
                    OCRConfig.RETRY_BASE_DELAY_SECONDS,
                    OCRConfig.RETRY_MAX_DELAY_SECONDS,
                    OCRConfig.RETRY_BACKOFF_MULTIPLIER,
                )
                logger.info(f"Retrying in {delay:.1f} seconds...")
                time.sleep(delay)

    error_msg = f"Failed to download {url} after {max_retries} attempts"
    logger.error(error_msg)
    raise requests.RequestException(error_msg) from last_exception


def validate_file_size(
    file_path: Path,
    min_size: int,
    file_description: str,
) -> None:
    """
    Validate that a file exists and meets minimum size requirements.

    Args:
        file_path: Path to the file to validate.
        min_size: Minimum expected file size in bytes.
        file_description: Human-readable description of the file for error messages.

    Raises:
        FileNotFoundError: If file does not exist.
        ValueError: If file is smaller than expected.
    """
    if not file_path.exists():
        raise FileNotFoundError(f"{file_description} not found at {file_path}")

    actual_size = file_path.stat().st_size

    if actual_size < min_size:
        raise ValueError(
            f"{file_description} is too small: {actual_size:,} bytes "
            f"(expected at least {min_size:,} bytes). "
            "The file may be corrupted or incomplete."
        )

    logger.info(
        f"Validated {file_description}: {actual_size:,} bytes "
        f"(SHA256: {calculate_sha256(file_path)[:16]}...)"
    )


# =============================================================================
# Main Processing Functions
# =============================================================================


def download_model(
    model: PreConvertedModel,
    output_dir: Path,
) -> Path:
    """
    Download a pre-converted ONNX model file.

    Args:
        model: Configuration for the model to download.
        output_dir: Directory to save the model file.

    Returns:
        Path to the downloaded model file.

    Raises:
        requests.RequestException: If download fails.
    """
    logger.info(f"Downloading {model.name} model...")

    output_path = output_dir / model.output_filename
    download_file_with_retry(model.url, output_path)

    return output_path


def prepare_ocr_models(
    output_dir: Path,
    force: bool = False,
) -> None:
    """
    Main function to prepare all OCR models.

    Downloads pre-converted PaddleOCR ONNX models from Hugging Face
    and validates the output files.

    Args:
        output_dir: Directory to save the final model files.
        force: If True, overwrite existing files.

    Raises:
        FileExistsError: If output files exist and force is False.
        Various exceptions if any step fails.
    """
    logger.info("=" * 60)
    logger.info("PaddleOCR ONNX Model Download")
    logger.info("Source: https://huggingface.co/monkt/paddleocr-onnx")
    logger.info("License: Apache 2.0")
    logger.info("=" * 60)

    models = [
        OCRConfig.DETECTION_MODEL,
        OCRConfig.RECOGNITION_MODEL,
        OCRConfig.CHARACTER_DICT,
    ]

    # Check for existing files
    expected_files = [output_dir / m.output_filename for m in models]
    existing_files = [f for f in expected_files if f.exists()]

    if existing_files and not force:
        logger.warning(
            f"Found existing model files: {[f.name for f in existing_files]}"
        )
        logger.warning("Use --force to overwrite existing files.")
        raise FileExistsError(
            "Model files already exist. Use --force to overwrite."
        )

    # Create output directory
    output_dir.mkdir(parents=True, exist_ok=True)

    # Download all models
    downloaded_paths = []
    for model in models:
        logger.info("-" * 40)
        path = download_model(model, output_dir)
        downloaded_paths.append((model, path))

    # Validate all output files
    logger.info("-" * 40)
    logger.info("Validating downloaded files...")

    for model, path in downloaded_paths:
        validate_file_size(
            path,
            model.min_size_bytes,
            f"{model.name.capitalize()} model",
        )

    # Print summary
    logger.info("=" * 60)
    logger.info("Model download complete!")
    logger.info(f"Output directory: {output_dir}")
    logger.info("Files created:")
    for model, path in downloaded_paths:
        if path.exists():
            size_mb = path.stat().st_size / (1024 * 1024)
            checksum = calculate_sha256(path)
            logger.info(f"  - {path.name}: {size_mb:.2f} MB (SHA256: {checksum})")
    logger.info("=" * 60)


def main() -> int:
    """
    Main entry point for the script.

    Returns:
        Exit code (0 for success, 1 for error).
    """
    parser = argparse.ArgumentParser(
        description="Download pre-converted PaddleOCR ONNX models from Hugging Face.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )

    # Determine default output directory relative to script location
    script_dir = Path(__file__).parent.parent
    default_output = (
        script_dir
        / "Packages"
        / "LocumTrackerOCR"
        / "Sources"
        / "LocumTrackerOCR"
        / "Resources"
        / "OCRModels"
    )

    parser.add_argument(
        "--output-dir",
        type=Path,
        default=default_output,
        help=f"Output directory for model files (default: {default_output})",
    )

    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite existing model files",
    )

    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Enable verbose debug logging",
    )

    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    try:
        prepare_ocr_models(
            output_dir=args.output_dir.resolve(),
            force=args.force,
        )
        return 0

    except FileExistsError as e:
        logger.error(str(e))
        return 1

    except requests.RequestException as e:
        logger.error(f"Network error: {e}")
        return 1

    except Exception as e:
        logger.exception(f"Unexpected error: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
