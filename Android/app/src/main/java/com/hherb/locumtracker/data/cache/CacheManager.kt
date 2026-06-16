package com.hherb.locumtracker.data.cache

import android.content.Context
import android.content.SharedPreferences
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Lightweight key-value store for app preferences, feature flags and sync timestamps,
 * backed by [SharedPreferences].
 *
 * Exposes strongly typed mutable properties whose getters/setters read from and write to
 * a single private preferences file. Defaults are applied when a value has not been set.
 */
@Singleton
class CacheManager @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private companion object {
        /** Default MMM classification applied when none has been chosen (mid rural/remote). */
        private const val DEFAULT_MMM_CLASSIFICATION = 5

        /** Default session start hour (24-hour clock) used when scheduling sessions. */
        private const val DEFAULT_START_HOUR = 8

        /** Default session end hour (24-hour clock) used when scheduling sessions. */
        private const val DEFAULT_END_HOUR = 16

        /** Default on-call rate as a fraction of the base rate (25%). */
        private const val DEFAULT_ON_CALL_RATE_PERCENTAGE = 0.25f

        /** Default call-out rate as a fraction of the base rate (50%). */
        private const val DEFAULT_CALL_OUT_RATE_PERCENTAGE = 0.50f

        /** Default age, in milliseconds, after which cached data is considered stale (24 hours). */
        private const val DEFAULT_STALE_AGE_MS = 24L * 60L * 60L * 1000L
    }

    private val prefs: SharedPreferences by lazy {
        context.getSharedPreferences("locum_tracker_cache", Context.MODE_PRIVATE)
    }

    // Last sync timestamps
    /** Epoch-millisecond timestamp of the last successful sync (0 if never synced). */
    var lastSyncTimestamp: Long
        get() = prefs.getLong("last_sync_timestamp", 0)
        set(value) = prefs.edit().putLong("last_sync_timestamp", value).apply()

    /** Epoch-millisecond timestamp of the last successful backup (0 if never backed up). */
    var lastBackupTimestamp: Long
        get() = prefs.getLong("last_backup_timestamp", 0)
        set(value) = prefs.edit().putLong("last_backup_timestamp", value).apply()

    // User preferences
    /** Default currency code used for new monetary values (defaults to AUD). */
    var defaultCurrency: String
        get() = prefs.getString("default_currency", "AUD") ?: "AUD"
        set(value) = prefs.edit().putString("default_currency", value).apply()

    /** Default MMM classification used when creating new sessions/locations. */
    var defaultMmmClassification: Int
        get() = prefs.getInt("default_mmm_classification", DEFAULT_MMM_CLASSIFICATION)
        set(value) = prefs.edit().putInt("default_mmm_classification", value).apply()

    // UI preferences
    /** Whether dark mode is enabled (defaults to off). */
    var isDarkMode: Boolean
        get() = prefs.getBoolean("is_dark_mode", false)
        set(value) = prefs.edit().putBoolean("is_dark_mode", value).apply()

    /** Whether compact UI layout is enabled (defaults to off). */
    var isCompactMode: Boolean
        get() = prefs.getBoolean("is_compact_mode", false)
        set(value) = prefs.edit().putBoolean("is_compact_mode", value).apply()

    // Feature flags
    /** Whether receipt OCR is enabled (defaults to on). */
    var isOcrEnabled: Boolean
        get() = prefs.getBoolean("is_ocr_enabled", true)
        set(value) = prefs.edit().putBoolean("is_ocr_enabled", value).apply()

    /** Whether cloud sync is enabled (defaults to off). */
    var isCloudSyncEnabled: Boolean
        get() = prefs.getBoolean("is_cloud_sync_enabled", false)
        set(value) = prefs.edit().putBoolean("is_cloud_sync_enabled", value).apply()

    // Session defaults
    /** Default session start hour on a 24-hour clock. */
    var defaultStartHour: Int
        get() = prefs.getInt("default_start_hour", DEFAULT_START_HOUR)
        set(value) = prefs.edit().putInt("default_start_hour", value).apply()

    /** Default session end hour on a 24-hour clock. */
    var defaultEndHour: Int
        get() = prefs.getInt("default_end_hour", DEFAULT_END_HOUR)
        set(value) = prefs.edit().putInt("default_end_hour", value).apply()

    /** Default session type applied to new sessions (defaults to "regular"). */
    var defaultSessionType: String
        get() = prefs.getString("default_session_type", "regular") ?: "regular"
        set(value) = prefs.edit().putString("default_session_type", value).apply()

    // Rate defaults
    /** Default on-call rate as a fraction of the base rate. */
    var defaultOnCallRatePercentage: Float
        get() = prefs.getFloat("default_oncall_rate_percentage", DEFAULT_ON_CALL_RATE_PERCENTAGE)
        set(value) = prefs.edit().putFloat("default_oncall_rate_percentage", value).apply()

    /** Default call-out rate as a fraction of the base rate. */
    var defaultCallOutRatePercentage: Float
        get() = prefs.getFloat("default_callout_rate_percentage", DEFAULT_CALL_OUT_RATE_PERCENTAGE)
        set(value) = prefs.edit().putFloat("default_callout_rate_percentage", value).apply()

    /** Clears every cached preference, feature flag and timestamp. */
    fun clearAll() {
        prefs.edit().clear().apply()
    }

    /** Clears only the sync- and backup-related timestamps, leaving other preferences intact. */
    fun clearSyncData() {
        prefs.edit()
            .remove("last_sync_timestamp")
            .remove("last_backup_timestamp")
            .apply()
    }

    /**
     * Returns whether cached data is stale and should be re-synced.
     *
     * @param maxAgeMs Maximum age in milliseconds before data is considered stale;
     *                 defaults to [DEFAULT_STALE_AGE_MS].
     * @return true if data has never been synced or the last sync is older than [maxAgeMs].
     */
    fun isDataStale(maxAgeMs: Long = DEFAULT_STALE_AGE_MS): Boolean {
        val lastSync = lastSyncTimestamp
        return if (lastSync == 0L) {
            true // Never synced
        } else {
            System.currentTimeMillis() - lastSync > maxAgeMs
        }
    }
}
