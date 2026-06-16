package com.hherb.locumtracker.core.service

import com.hherb.locumtracker.core.model.*
import kotlinx.datetime.Clock
import kotlinx.datetime.plus
import kotlinx.datetime.minus
import kotlinx.datetime.Instant
import kotlin.test.Test
import kotlin.test.assertEquals

class EarningsServiceTest {

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

    private fun createAssignment(
        rateStructure: RateStructure = RateStructure.HOURLY_RATE,
        hourlyRate: Double = 150.0,
        dailyRate: Double = 1200.0
    ): Assignment {
        return Assignment(
            id = "test-assignment",
            locationId = "test-location",
            rateStructure = rateStructure,
            hourlyRate = hourlyRate,
            dailyRate = dailyRate
        )
    }

    @Test
    fun testCalculateSessionEarnings_hourlyRate() {
        val session = createSession(startHour = 8, endHour = 16) // 8 hours
        val assignment = createAssignment(
            rateStructure = RateStructure.HOURLY_RATE,
            hourlyRate = 150.0
        )

        val earnings = EarningsService.calculateSessionEarnings(session, assignment)
        assertEquals(1200.0, earnings, 0.01) // 8 hours * $150
    }

    @Test
    fun testCalculateSessionEarnings_dailyRate() {
        val session = createSession(startHour = 8, endHour = 16) // 8 hours
        val assignment = createAssignment(
            rateStructure = RateStructure.DAILY_RATE,
            dailyRate = 1500.0
        )

        val earnings = EarningsService.calculateSessionEarnings(session, assignment)
        assertEquals(1500.0, earnings, 0.01) // Full daily rate regardless of hours
    }

    @Test
    fun testCalculateDailyEarnings_dailyRate() {
        val sessions = listOf(
            createSession(startHour = 8, endHour = 12), // Morning
            createSession(startHour = 13, endHour = 17)  // Afternoon
        )
        val assignment = createAssignment(
            rateStructure = RateStructure.DAILY_RATE,
            dailyRate = 1500.0
        )

        val earnings = EarningsService.calculateDailyEarnings(sessions, assignment)
        assertEquals(1500.0, earnings, 0.01) // Full daily rate for any sessions
    }

    @Test
    fun testCalculateDailyEarnings_hourlyRate() {
        val sessions = listOf(
            createSession(startHour = 8, endHour = 12), // 4 hours
            createSession(startHour = 13, endHour = 17)  // 4 hours
        )
        val assignment = createAssignment(
            rateStructure = RateStructure.HOURLY_RATE,
            hourlyRate = 150.0
        )

        val earnings = EarningsService.calculateDailyEarnings(sessions, assignment)
        assertEquals(1200.0, earnings, 0.01) // 8 hours * $150
    }

    @Test
    fun testCalculateSubsidyAmount_mmm5() {
        val session = createSession(
            startHour = 8,
            endHour = 16, // 8 hours
            mmmClassification = 5
        )

        val subsidy = EarningsService.calculateSubsidyAmount(session, 5)
        assertEquals(1600.0, subsidy, 0.01) // 8 hours * $200/hr for MMM5
    }

    @Test
    fun testCalculateSubsidyAmount_notEligible() {
        val session = createSession(
            startHour = 8,
            endHour = 16,
            mmmClassification = 2
        )

        val subsidy = EarningsService.calculateSubsidyAmount(session, 2)
        assertEquals(0.0, subsidy, 0.01)
    }

    @Test
    fun testCalculateEffectiveHourlyRate() {
        val rate = EarningsService.calculateEffectiveHourlyRate(1200.0, 8.0)
        assertEquals(150.0, rate, 0.01)
    }

    @Test
    fun testCalculateEffectiveHourlyRate_zeroHours() {
        val rate = EarningsService.calculateEffectiveHourlyRate(1200.0, 0.0)
        assertEquals(0.0, rate, 0.01)
    }
}
