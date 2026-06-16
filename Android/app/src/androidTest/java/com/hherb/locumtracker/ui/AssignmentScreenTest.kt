package com.hherb.locumtracker.ui

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import com.hherb.locumtracker.ui.screens.assignments.AssignmentsScreen
import com.hherb.locumtracker.ui.theme.LocumTrackerTheme
import dagger.hilt.android.testing.HiltAndroidRule
import dagger.hilt.android.testing.HiltAndroidTest
import org.junit.Before
import org.junit.Rule
import org.junit.Test

@HiltAndroidTest
class AssignmentScreenTest {

    @get:Rule(order = 0)
    val hiltRule = HiltAndroidRule(this)

    @get:Rule(order = 1)
    val composeRule = createComposeRule()

    @Before
    fun setup() {
        hiltRule.inject()
    }

    @Test
    fun testEmptyState_showsMessage() {
        composeRule.setContent {
            LocumTrackerTheme {
                AssignmentsScreen(
                    onAssignmentClick = {},
                    onAddAssignment = {}
                )
            }
        }

        composeRule.onNodeWithText("No Assignments Yet").assertIsDisplayed()
        composeRule.onNodeWithText("Tap + to add your first assignment").assertIsDisplayed()
    }

    @Test
    fun testAppBar_showsTitle() {
        composeRule.setContent {
            LocumTrackerTheme {
                AssignmentsScreen(
                    onAssignmentClick = {},
                    onAddAssignment = {}
                )
            }
        }

        composeRule.onNodeWithText("Assignments").assertIsDisplayed()
    }

    @Test
    fun testAddButton_exists() {
        composeRule.setContent {
            LocumTrackerTheme {
                AssignmentsScreen(
                    onAssignmentClick = {},
                    onAddAssignment = {}
                )
            }
        }

        composeRule.onNodeWithContentDescription("Add Assignment").assertExists()
    }
}
