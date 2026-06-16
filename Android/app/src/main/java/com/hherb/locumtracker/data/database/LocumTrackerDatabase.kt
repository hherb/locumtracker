package com.hherb.locumtracker.data.database

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import com.hherb.locumtracker.data.database.dao.AssignmentDao
import com.hherb.locumtracker.data.database.dao.LocationDao
import com.hherb.locumtracker.data.database.dao.ProfileDao
import com.hherb.locumtracker.data.database.dao.ReceiptDao
import com.hherb.locumtracker.data.database.dao.SessionDao
import com.hherb.locumtracker.data.database.entity.AssignmentEntity
import com.hherb.locumtracker.data.database.entity.AttachmentEntity
import com.hherb.locumtracker.data.database.entity.DailyRecordEntity
import com.hherb.locumtracker.data.database.entity.LocationEntity
import com.hherb.locumtracker.data.database.entity.LocumProfileEntity
import com.hherb.locumtracker.data.database.entity.QuarterlyQuotaEntity
import com.hherb.locumtracker.data.database.entity.ReceiptEntity
import com.hherb.locumtracker.data.database.entity.SessionEntity

@Database(
    entities = [
        LocationEntity::class,
        AssignmentEntity::class,
        SessionEntity::class,
        DailyRecordEntity::class,
        ReceiptEntity::class,
        AttachmentEntity::class,
        LocumProfileEntity::class,
        QuarterlyQuotaEntity::class
    ],
    version = 1,
    exportSchema = false
)
/**
 * Room database holding all LocumTracker persistence entities and exposing their DAOs.
 *
 * Use [getDatabase] to obtain the process-wide singleton instance.
 */
abstract class LocumTrackerDatabase : RoomDatabase() {
    /** DAO for location records. */
    abstract fun locationDao(): LocationDao

    /** DAO for assignment records. */
    abstract fun assignmentDao(): AssignmentDao

    /** DAO for session and daily-record rows. */
    abstract fun sessionDao(): SessionDao

    /** DAO for receipt and attachment rows. */
    abstract fun receiptDao(): ReceiptDao

    /** DAO for profile and quarterly-quota rows. */
    abstract fun profileDao(): ProfileDao

    companion object {
        @Volatile
        private var INSTANCE: LocumTrackerDatabase? = null

        /**
         * Returns the process-wide [LocumTrackerDatabase] singleton, creating it on
         * first use from the application context of [context].
         */
        fun getDatabase(context: Context): LocumTrackerDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    LocumTrackerDatabase::class.java,
                    "locum_tracker_database"
                )
                .fallbackToDestructiveMigration()
                .build()
                INSTANCE = instance
                instance
            }
        }
    }
}
