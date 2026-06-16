package com.hherb.locumtracker.di

import android.content.Context
import androidx.room.Room
import com.hherb.locumtracker.data.database.LocumTrackerDatabase
import com.hherb.locumtracker.data.database.dao.AssignmentDao
import com.hherb.locumtracker.data.database.dao.LocationDao
import com.hherb.locumtracker.data.database.dao.ProfileDao
import com.hherb.locumtracker.data.database.dao.ReceiptDao
import com.hherb.locumtracker.data.database.dao.SessionDao
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

/**
 * Hilt module providing the Room database singleton and its DAOs.
 */
@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {
    /** File name of the Room database on disk. */
    private const val DATABASE_NAME = "locum_tracker_database"

    /**
     * Provides the application Room database singleton.
     *
     * Uses destructive migration as a fallback (acceptable during alpha; data loss on
     * schema change is tolerated).
     */
    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): LocumTrackerDatabase {
        return Room.databaseBuilder(
            context,
            LocumTrackerDatabase::class.java,
            DATABASE_NAME
        )
        .fallbackToDestructiveMigration()
        .build()
    }

    /** Provides the [LocationDao] from the database. */
    @Provides
    fun provideLocationDao(database: LocumTrackerDatabase): LocationDao {
        return database.locationDao()
    }

    /** Provides the [AssignmentDao] from the database. */
    @Provides
    fun provideAssignmentDao(database: LocumTrackerDatabase): AssignmentDao {
        return database.assignmentDao()
    }

    /** Provides the [SessionDao] from the database. */
    @Provides
    fun provideSessionDao(database: LocumTrackerDatabase): SessionDao {
        return database.sessionDao()
    }

    /** Provides the [ReceiptDao] from the database. */
    @Provides
    fun provideReceiptDao(database: LocumTrackerDatabase): ReceiptDao {
        return database.receiptDao()
    }

    /** Provides the [ProfileDao] from the database. */
    @Provides
    fun provideProfileDao(database: LocumTrackerDatabase): ProfileDao {
        return database.profileDao()
    }
}
