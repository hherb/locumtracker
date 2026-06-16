package com.hherb.locumtracker.ui

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import com.hherb.locumtracker.ui.screens.settings.SettingsScreen
import com.hherb.locumtracker.ui.theme.LocumTrackerTheme
import dagger.hilt.android.testing.HiltAndroidRule
import dagger.hilt.android.testing.HiltAndroidTest
import org.junit.Before
import org.junit.Rule
import org.junit.Test

@HiltAndroidTest
class SettingsScreenTest {

    @get:Rule(order = 0)
    val hiltRule = HiltAndroidRule(this)

    @get:Rule(order = 1)
    val composeRule = createComposeRule()

    @Before
    fun setup() {
        hiltRule.inject()
    }

    @Test
    fun testAppBar_showsTitle() {
        composeRule.setContent {
            LocumTrackerTheme {
                SettingsScreen()
            }
        }

        composeRule.onNodeWithText("Settings").assertIsDisplayed()
    }

    @Test
    fun testProfileSection_exists() {
        composeRule.setContent {
            LocumTrackerTheme {
                SettingsScreen()
            }
        }

        composeRule.onNodeWithText("Profile").assertIsDisplayed()
    }

    @Test
    fun testBusinessSection_exists() {
        composeRule.setContent {
            LocumTrackerTheme {
                SettingsScreen()
            }
        }

        composeRule.onNodeWithText("Business & Tax").assertIsDisplayed()
    }

    @Test
    fun testCloudSyncSection_exists() {
        composeRule.setContent {
            LocumTrackerTheme {
                SettingsScreen()
            }
        }

        composeRule.onNodeWithText("Cloud Sync").assertIsDisplayed()
    }

    @Test
    fun testExportSection_exists() {
        composeRule.setContent {
            LocumTrackerTheme {
                SettingsScreen()
            }
        }

        composeRule.onNodeWithText("Export Data").assertIsDisplayed()
    }

    @Test
    fun testAbnField_exists() {
        composeRule.setContent {
            LocumTrackerTheme {
                SettingsScreen()
            }
        }

        composeRule.onNodeWithText("ABN").assertIsDisplayed()
    }

    @Test
    fun testGstToggle_exists() {
        composeRule.setContent {
            LocumTrackerTheme {
                SettingsScreen()
            }
        }

        composeRule.onNodeWithText("GST Registered").assertIsDisplayed()
    }
}
