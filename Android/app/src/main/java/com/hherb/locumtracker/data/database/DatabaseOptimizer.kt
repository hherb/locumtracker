package com.hherb.locumtracker.data.database

import android.content.Context
import androidx.room.RoomDatabase
import androidx.sqlite.db.SupportSQLiteDatabase
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Applies SQLite performance tuning and maintenance operations to a
 * [LocumTrackerDatabase] (PRAGMA settings, index creation, ANALYZE and VACUUM).
 */
@Singleton
class DatabaseOptimizer @Inject constructor(
    @ApplicationContext private val context: Context
) {
    /**
     * Applies performance-oriented PRAGMA settings to [database]: WAL journaling,
     * an enlarged cache, memory-mapped I/O, NORMAL synchronous mode and in-memory
     * temp storage.
     */
    fun optimizeDatabase(database: LocumTrackerDatabase) {
        // Run optimization queries
        database.openHelper.writableDatabase.apply {
            // Enable WAL mode for better concurrent access
            execSQL("PRAGMA journal_mode=WAL")

            // Set cache size (negative = KB)
            execSQL("PRAGMA cache_size=-8000") // 8MB cache

            // Enable memory-mapped I/O
            execSQL("PRAGMA mmap_size=268435456") // 256MB

            // Optimize for mobile devices
            execSQL("PRAGMA synchronous=NORMAL")
            execSQL("PRAGMA temp_store=MEMORY")
        }
    }

    /** Runs `ANALYZE` on [database] so the query planner has up-to-date statistics. */
    fun analyzeDatabase(database: LocumTrackerDatabase) {
        database.openHelper.writableDatabase.apply {
            execSQL("ANALYZE")
        }
    }

    /** Runs `VACUUM` on [database] to compact the file and reclaim unused space. */
    fun vacuumDatabase(database: LocumTrackerDatabase) {
        database.openHelper.writableDatabase.apply {
            execSQL("VACUUM")
        }
    }

    /** Returns the recommended `CREATE INDEX` statements for frequently queried columns. */
    fun getIndexRecommendations(): List<String> {
        return listOf(
            "CREATE INDEX IF NOT EXISTS idx_assignments_status ON assignments(status)",
            "CREATE INDEX IF NOT EXISTS idx_assignments_location ON assignments(locationId)",
            "CREATE INDEX IF NOT EXISTS idx_assignments_dates ON assignments(startDate, endDate)",
            "CREATE INDEX IF NOT EXISTS idx_sessions_daily_record ON sessions(dailyRecordId)",
            "CREATE INDEX IF NOT EXISTS idx_sessions_time ON sessions(startTime, endTime)",
            "CREATE INDEX IF NOT EXISTS idx_daily_records_assignment ON daily_records(assignmentId)",
            "CREATE INDEX IF NOT EXISTS idx_daily_records_date ON daily_records(date)",
            "CREATE INDEX IF NOT EXISTS idx_receipts_category ON receipts(category)",
            "CREATE INDEX IF NOT EXISTS idx_receipts_date ON receipts(date)",
            "CREATE INDEX IF NOT EXISTS idx_receipts_assignment ON receipts(assignmentId)",
            "CREATE INDEX IF NOT EXISTS idx_attachments_receipt ON attachments(receiptId)",
            "CREATE INDEX IF NOT EXISTS idx_attachments_assignment ON attachments(assignmentId)",
            "CREATE INDEX IF NOT EXISTS idx_locations_mmm ON locations(mmmClassification)"
        )
    }

    /**
     * Creates the recommended indexes from [getIndexRecommendations] on [database],
     * ignoring any individual statement that fails (e.g. an index that already exists).
     */
    fun createIndexes(database: LocumTrackerDatabase) {
        val indexes = getIndexRecommendations()
        database.openHelper.writableDatabase.apply {
            indexes.forEach { sql ->
                try {
                    execSQL(sql)
                } catch (e: Exception) {
                    // Index may already exist
                }
            }
        }
    }
}
