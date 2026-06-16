package com.hherb.locumtracker.core.model

import kotlinx.datetime.Clock
import kotlinx.datetime.plus
import kotlinx.datetime.minus
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class SessionTest {

    private fun createSession(
        startHour: Int = 8,
        endHour: Int = 16,
        mmmClassification: Int = 5,
        sessionType: SessionType = SessionType.REGULAR,
        travelTime: Double? = null
    ): Session {
        val now = Clock.System.now()
        val startTime = now.minus((24 - startHour) * 3600L, kotlinx.datetime.DateTimeUnit.SECOND)
        val endTime = now.minus((24 - endHour) * 3600L, kotlinx.datetime.DateTimeUnit.SECOND)
        return Session(
            id = "test-session",
            dailyRecordId = "test-record",
            startTime = startTime,
            endTime = endTime,
            sessionType = sessionType,
            mmmClassification = mmmClassification,
            travelTime = travelTime
        )
    }

    @Test
    fun testDurationHours() {
        val session = createSession(startHour = 8, endHour = 16) // 8 hours
        assertEquals(8.0, session.durationHours, 0.01)
    }

    @Test
    fun testDurationHours_shortSession() {
        val session = createSession(startHour = 14, endHour = 17) // 3 hours
        assertEquals(3.0, session.durationHours, 0.01)
    }

    @Test
    fun testDurationFormatted() {
        val session = createSession(startHour = 8, endHour = 16) // 8 hours
        // A whole-hour session omits the minutes component by design.
        assertEquals("8h", session.durationFormatted)
    }

    @Test
    fun testDurationFormatted_minutesOnly() {
        val session = createSession(startHour = 14, endHour = 14) // Need to handle this case
        // This would need a more precise test with minutes
    }

    @Test
    fun testEffectiveSubsidyHours_noTravel() {
        val session = createSession(startHour = 8, endHour = 16) // 8 hours
        assertEquals(8.0, session.effectiveSubsidyHours, 0.01)
    }

    @Test
    fun testEffectiveSubsidyHours_withTravel() {
        val session = createSession(
            startHour = 8,
            endHour = 16,
            travelTime = 7200.0 // 2 hours in seconds
        )
        // 8 hours + 2 hours travel = 10 hours
        assertEquals(10.0, session.effectiveSubsidyHours, 0.01)
    }

    @Test
    fun testEffectiveSubsidyHours_travelBelowMinimum() {
        val session = createSession(
            startHour = 8,
            endHour = 16,
            travelTime = 1800.0 // 30 minutes in seconds (< 1 hour minimum)
        )
        // Travel time doesn't count if < 1 hour
        assertEquals(8.0, session.effectiveSubsidyHours, 0.01)
    }

    @Test
    fun testIsSubsidyEligible_mmm3() {
        val session = createSession(mmmClassification = 3)
        assertTrue(session.isSubsidyEligible)
    }

    @Test
    fun testIsSubsidyEligible_mmm7() {
        val session = createSession(mmmClassification = 7)
        assertTrue(session.isSubsidyEligible)
    }

    @Test
    fun testIsSubsidyEligible_mmm1() {
        val session = createSession(mmmClassification = 1)
        assertFalse(session.isSubsidyEligible)
    }

    @Test
    fun testIsSubsidyEligible_mmm2() {
        val session = createSession(mmmClassification = 2)
        assertFalse(session.isSubsidyEligible)
    }

    @Test
    fun testHasSpecificProviderLocation() {
        val session = createSession().copy(providerLocationId = "clinic-1")
        assertTrue(session.hasSpecificProviderLocation)
    }

    @Test
    fun testHasSpecificProviderLocation_false() {
        val session = createSession()
        assertFalse(session.hasSpecificProviderLocation)
    }
}
