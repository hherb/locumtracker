package com.hherb.locumtracker.util

import android.os.SystemClock
import android.util.Log
import java.util.concurrent.ConcurrentHashMap

/**
 * Lightweight in-memory performance profiler that records named timers and aggregates
 * their durations. Operations exceeding [SLOW_OPERATION_THRESHOLD_MS] are logged as warnings.
 *
 * Backed by thread-safe maps, so timers may be started and stopped from multiple threads.
 */
object PerformanceMonitor {
    private const val TAG = "PerformanceMonitor"

    /** Duration (in milliseconds) above which a completed operation is logged as slow. */
    private const val SLOW_OPERATION_THRESHOLD_MS = 1000

    private val timers = ConcurrentHashMap<String, Long>()
    private val metrics = ConcurrentHashMap<String, MutableList<Long>>()

    /**
     * Starts (or restarts) a named timer using the elapsed-realtime clock.
     *
     * @param name The unique name identifying the timer.
     */
    fun startTimer(name: String) {
        timers[name] = SystemClock.elapsedRealtime()
    }

    /**
     * Stops the named timer, records its duration as a metric, and logs a warning if slow.
     *
     * @param name The name of the timer to stop.
     * @return The measured duration in milliseconds, or 0 if no matching timer was running.
     */
    fun stopTimer(name: String): Long {
        val startTime = timers.remove(name) ?: return 0
        val duration = SystemClock.elapsedRealtime() - startTime

        // Store metric
        metrics.getOrPut(name) { mutableListOf() }.add(duration)

        // Log if slow
        if (duration > SLOW_OPERATION_THRESHOLD_MS) {
            Log.w(TAG, "Slow operation '$name' took ${duration}ms")
        }

        return duration
    }

    /**
     * Returns the average recorded duration for the named timer.
     *
     * @param name The name of the timer.
     * @return The average duration in milliseconds, or 0.0 if no metrics exist.
     */
    fun getAverageTime(name: String): Double {
        val times = metrics[name] ?: return 0.0
        return if (times.isNotEmpty()) {
            times.average()
        } else {
            0.0
        }
    }

    /**
     * Returns aggregated statistics for every recorded timer.
     *
     * @return A map from timer name to its statistics: count, average, min, max, and total
     *   (all in milliseconds).
     */
    fun getMetrics(): Map<String, Map<String, Double>> {
        return metrics.mapValues { (_, times) ->
            mapOf(
                "count" to times.size.toDouble(),
                "average" to times.average(),
                "min" to (times.minOrNull()?.toDouble() ?: 0.0),
                "max" to (times.maxOrNull()?.toDouble() ?: 0.0),
                "total" to times.sum().toDouble()
            )
        }
    }

    /** Clears all recorded metrics and any running timers. */
    fun clearMetrics() {
        metrics.clear()
        timers.clear()
    }

    /** Logs a summary (count, average, min, max) of all recorded timers at info level. */
    fun logMetrics() {
        Log.i(TAG, "Performance Metrics:")
        metrics.forEach { (name, times) ->
            Log.i(TAG, "  $name: count=${times.size}, avg=${times.average()}ms, " +
                    "min=${times.minOrNull()}ms, max=${times.maxOrNull()}ms")
        }
    }
}

/**
 * Measures the execution time of [block] under the given timer [name].
 *
 * @param name The timer name to record under.
 * @param block The work to measure.
 * @return The result returned by [block].
 */
inline fun <T> measureTime(name: String, block: () -> T): T {
    PerformanceMonitor.startTimer(name)
    try {
        return block()
    } finally {
        PerformanceMonitor.stopTimer(name)
    }
}

/**
 * Measures the execution time of a suspending [block] under the given timer [name].
 *
 * @param name The timer name to record under.
 * @param block The suspending work to measure.
 * @return The result returned by [block].
 */
suspend inline fun <T> measureTimeSuspend(name: String, block: () -> T): T {
    PerformanceMonitor.startTimer(name)
    try {
        return block()
    } finally {
        PerformanceMonitor.stopTimer(name)
    }
}
