# Phase 1: Model Preparation

Download PaddleOCR models and convert them to ONNX format for use with ONNX Runtime.

## Step 1: Download PaddleOCR Models

```bash
# Create models directory
mkdir -p Resources/OCRModels

# Download PP-OCRv4 mobile models from PaddleOCR releases
# Detection model
wget https://paddleocr.bj.bcebos.com/PP-OCRv4/chinese/ch_PP-OCRv4_det_infer.tar
tar -xf ch_PP-OCRv4_det_infer.tar

# Recognition model
wget https://paddleocr.bj.bcebos.com/PP-OCRv4/chinese/ch_PP-OCRv4_rec_infer.tar
tar -xf ch_PP-OCRv4_rec_infer.tar

# For English-only (smaller):
wget https://paddleocr.bj.bcebos.com/PP-OCRv4/english/en_PP-OCRv4_rec_infer.tar
```

## Step 2: Convert to ONNX Format

```bash
# Install paddle2onnx
pip install paddle2onnx paddlepaddle

# Convert detection model
paddle2onnx --model_dir ch_PP-OCRv4_det_infer \
    --model_filename inference.pdmodel \
    --params_filename inference.pdiparams \
    --save_file pp_ocrv4_det.onnx \
    --opset_version 12 \
    --input_shape_dict="{'x':[-1,3,-1,-1]}"

# Convert recognition model
paddle2onnx --model_dir ch_PP-OCRv4_rec_infer \
    --model_filename inference.pdmodel \
    --params_filename inference.pdiparams \
    --save_file pp_ocrv4_rec.onnx \
    --opset_version 12 \
    --input_shape_dict="{'x':[-1,3,-1,-1]}"
```

## Step 3: Download Character Dictionary

```bash
# Download the recognition dictionary
wget https://raw.githubusercontent.com/PaddlePaddle/PaddleOCR/main/ppocr/utils/ppocr_keys_v1.txt \
    -O ppocr_keys.txt

# For English-only:
wget https://raw.githubusercontent.com/PaddlePaddle/PaddleOCR/main/ppocr/utils/en_dict.txt \
    -O en_dict.txt
```

## Final Model Files

```
Resources/OCRModels/
├── pp_ocrv4_det.onnx      (~3.5 MB)
├── pp_ocrv4_rec.onnx      (~4.5 MB)
└── ppocr_keys.txt         (~200 KB)
```

---

**Previous:** [OVERVIEW.md](OVERVIEW.md)
**Next:** [02_project_setup.md](02_project_setup.md) - Configure SPM/CocoaPods and add models to Xcode
