package com.hherb.locumtracker

import android.app.Application
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class LocumTrackerApp : Application() {
    override fun onCreate() {
        super.onCreate()
    }
}
