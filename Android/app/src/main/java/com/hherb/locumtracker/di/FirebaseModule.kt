package com.hherb.locumtracker.di

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.storage.FirebaseStorage
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

/**
 * Hilt module providing application-wide Firebase service singletons.
 */
@Module
@InstallIn(SingletonComponent::class)
object FirebaseModule {
    /** Provides the Firebase Cloud Firestore singleton. */
    @Provides
    @Singleton
    fun provideFirestore(): FirebaseFirestore {
        return FirebaseFirestore.getInstance()
    }

    /** Provides the Firebase Authentication singleton. */
    @Provides
    @Singleton
    fun provideAuth(): FirebaseAuth {
        return FirebaseAuth.getInstance()
    }

    /** Provides the Firebase Cloud Storage singleton. */
    @Provides
    @Singleton
    fun provideStorage(): FirebaseStorage {
        return FirebaseStorage.getInstance()
    }
}
