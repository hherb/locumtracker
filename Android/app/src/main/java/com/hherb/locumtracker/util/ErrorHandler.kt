package com.hherb.locumtracker.util

import android.util.Log
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * Centralised error handling utilities for mapping exceptions to user-friendly messages
 * and safely running blocks that may throw.
 *
 * Cancellation exceptions are always re-thrown so coroutine cancellation is not swallowed.
 */
object ErrorHandler {
    private const val TAG = "LocumTracker"

    /**
     * Maps a thrown exception to a user-friendly message, optionally logging it.
     *
     * [CancellationException] is re-thrown rather than mapped.
     *
     * @param exception The exception to handle.
     * @param userMessage An optional override message used for argument/state errors and unknown errors.
     * @param logError Whether to log the exception; defaults to true.
     * @return A user-friendly error message describing the failure.
     */
    fun handleError(
        exception: Throwable,
        userMessage: String? = null,
        logError: Boolean = true
    ): String {
        if (logError) {
            Log.e(TAG, "Error occurred: ${exception.message}", exception)
        }

        return when (exception) {
            is CancellationException -> throw exception // Re-throw cancellation
            is java.net.UnknownHostException -> "No internet connection"
            is java.net.SocketTimeoutException -> "Connection timed out"
            is java.io.IOException -> "Network error occurred"
            is SecurityException -> "Permission denied"
            is IllegalArgumentException -> userMessage ?: "Invalid input"
            is IllegalStateException -> userMessage ?: "Invalid state"
            else -> userMessage ?: "An unexpected error occurred"
        }
    }

    /**
     * Launches a coroutine on the given scope, catching and reporting non-cancellation
     * exceptions instead of letting them crash the scope.
     *
     * @param scope The coroutine scope to launch on.
     * @param onError Optional callback invoked with any caught exception; if null, the error is logged.
     * @param block The suspending work to execute.
     */
    fun safeLaunch(
        scope: CoroutineScope,
        onError: ((Throwable) -> Unit)? = null,
        block: suspend CoroutineScope.() -> Unit
    ) {
        scope.launch {
            try {
                block()
            } catch (e: CancellationException) {
                throw e // Re-throw cancellation
            } catch (e: Exception) {
                onError?.invoke(e) ?: Log.e(TAG, "Error in coroutine", e)
            }
        }
    }

    /**
     * Runs a block and wraps its outcome in a [Result], re-throwing cancellation.
     *
     * @param block The work to execute.
     * @return [Result.success] with the value, or [Result.failure] with the caught exception.
     */
    fun <T> safeResult(block: () -> T): Result<T> {
        return try {
            Result.success(block())
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Runs a suspending block and wraps its outcome in a [Result], re-throwing cancellation.
     *
     * @param block The suspending work to execute.
     * @return [Result.success] with the value, or [Result.failure] with the caught exception.
     */
    suspend fun <T> safeSuspendResult(block: suspend () -> T): Result<T> {
        return try {
            Result.success(block())
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}

/**
 * Safely retrieves the element at [index], returning null instead of throwing when out of bounds.
 *
 * @param index The index to retrieve.
 * @return The element at the index, or null if the index is out of bounds.
 */
fun <T> List<T>.safeGet(index: Int): T? {
    return try {
        this[index]
    } catch (e: IndexOutOfBoundsException) {
        null
    }
}

/**
 * Returns this string, or [default] when the string is null.
 *
 * @param default The fallback value; defaults to an empty string.
 * @return The string, or the default if null.
 */
fun String?.orDefault(default: String = ""): String {
    return this ?: default
}

/**
 * Parses this string as an [Int], returning [default] when null or unparseable.
 *
 * @param default The fallback value; defaults to 0.
 * @return The parsed integer, or the default.
 */
fun String?.toIntOrNull(default: Int = 0): Int {
    return this?.toIntOrNull() ?: default
}

/**
 * Parses this string as a [Double], returning [default] when null or unparseable.
 *
 * @param default The fallback value; defaults to 0.0.
 * @return The parsed double, or the default.
 */
fun String?.toDoubleOrNull(default: Double = 0.0): Double {
    return this?.toDoubleOrNull() ?: default
}
