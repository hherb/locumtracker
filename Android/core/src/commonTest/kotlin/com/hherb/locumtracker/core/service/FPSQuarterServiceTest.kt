package com.hherb.locumtracker.core.service

import com.hherb.locumtracker.core.model.QuotaWarningLevel
import com.hherb.locumtracker.core.model.QuarterlyQuota
import kotlinx.datetime.Clock
import kotlinx.datetime.plus
import kotlinx.datetime.minus
import kotlinx.datetime.Instant
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toLocalDateTime
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class FPSQuarterServiceTest {

    @Test
    fun testGetQuarterStartDate_january() {
        // January 15, 2024 should return January 1, 2024
        val date = Instant.fromEpochMilliseconds(1705276800000L) // Jan 15, 2024
        val quarterStart = FPSQuarterService.getQuarterStartDate(date)
        val startMonth = quarterStart.toLocalDateTime(TimeZone.currentSystemDefault()).monthNumber
        assertEquals(1, startMonth)
    }

    @Test
    fun testGetQuarterStartDate_april() {
        // April 15, 2024 should return April 1, 2024
        val date = Instant.fromEpochMilliseconds(1713139200000L) // Apr 15, 2024
        val quarterStart = FPSQuarterService.getQuarterStartDate(date)
        val startMonth = quarterStart.toLocalDateTime(TimeZone.currentSystemDefault()).monthNumber
        assertEquals(4, startMonth)
    }

    @Test
    fun testCountValidSessions_filtersCorrectly() {
        val now = Clock.System.now()
        val quarterStart = now.minus(30 * 24 * 3600L, kotlinx.datetime.DateTimeUnit.SECOND) // 30 days ago
        val quarterEnd = now.plus(30 * 24 * 3600L, kotlinx.datetime.DateTimeUnit.SECOND) // 30 days from now

        // Valid session (4 hours, MMM5)
        val validSession = com.hherb.locumtracker.core.model.Session(
            id = "valid",
            dailyRecordId = "record",
            startTime = now.minus(10 * 24 * 3600L, kotlinx.datetime.DateTimeUnit.SECOND),
            endTime = now.minus(10 * 24 * 3600L, kotlinx.datetime.DateTimeUnit.SECOND).plus(4 * 3600L, kotlinx.datetime.DateTimeUnit.SECOND),
            sessionType = com.hherb.locumtracker.core.model.SessionType.REGULAR,
            mmmClassification = 5
        )

        // Invalid session (2 hours, too short)
        val invalidSession = com.hherb.locumtracker.core.model.Session(
            id = "invalid",
            dailyRecordId = "record",
            startTime = now.minus(5 * 24 * 3600L, kotlinx.datetime.DateTimeUnit.SECOND),
            endTime = now.minus(5 * 24 * 3600L, kotlinx.datetime.DateTimeUnit.SECOND).plus(2 * 3600L, kotlinx.datetime.DateTimeUnit.SECOND),
            sessionType = com.hherb.locumtracker.core.model.SessionType.REGULAR,
            mmmClassification = 5
        )

        // Session not in quarter
        val outOfQuarterSession = com.hherb.locumtracker.core.model.Session(
            id = "out",
            dailyRecordId = "record",
            startTime = now.minus(60 * 24 * 3600L, kotlinx.datetime.DateTimeUnit.SECOND), // 60 days ago
            endTime = now.minus(60 * 24 * 3600L, kotlinx.datetime.DateTimeUnit.SECOND).plus(4 * 3600L, kotlinx.datetime.DateTimeUnit.SECOND),
            sessionType = com.hherb.locumtracker.core.model.SessionType.REGULAR,
            mmmClassification = 5
        )

        val validSessions = FPSQuarterService.countValidSessions(
            sessions = listOf(validSession, invalidSession, outOfQuarterSession),
            quarterStart = quarterStart,
            quarterEnd = quarterEnd
        )

        assertEquals(1, validSessions.size)
        assertEquals("valid", validSessions[0].id)
    }

    @Test
    fun testCalculateQuotaProgress() {
        val now = Clock.System.now()
        val quarterStart = now.minus(30 * 24 * 3600L, kotlinx.datetime.DateTimeUnit.SECOND)

        val sessions = (1..5).map { i ->
            com.hherb.locumtracker.core.model.Session(
                id = "session-$i",
                dailyRecordId = "record",
                startTime = now.minus(i * 24 * 3600L, kotlinx.datetime.DateTimeUnit.SECOND),
                endTime = now.minus(i * 24 * 3600L, kotlinx.datetime.DateTimeUnit.SECOND).plus(4 * 3600L, kotlinx.datetime.DateTimeUnit.SECOND),
                sessionType = com.hherb.locumtracker.core.model.SessionType.REGULAR,
                mmmClassification = 5
            )
        }

        val quota = FPSQuarterService.calculateQuotaProgress(sessions, quarterStart, now)

        assertEquals(5, quota.totalSessions)
        assertFalse(quota.quotaMet) // 5 < 21 minimum
    }

    @Test
    fun testGetWarningLevel_quotaMet() {
        val quota = QuarterlyQuota(
            practitionerId = "test",
            quarterStartDate = Clock.System.now()
        )
        quota.totalSessions = 25
        quota.quotaMet = true

        assertEquals(QuotaWarningLevel.SUCCESS, FPSQuarterService.getWarningLevel(quota))
    }

    @Test
    fun testGetWarningLevel_critical() {
        val quota = QuarterlyQuota(
            practitionerId = "test",
            quarterStartDate = Clock.System.now()
        )
        quota.totalSessions = 3 // < 50% of 21

        assertEquals(QuotaWarningLevel.CRITICAL, FPSQuarterService.getWarningLevel(quota))
    }

    @Test
    fun testGetWarningLevel_atRisk() {
        val quota = QuarterlyQuota(
            practitionerId = "test",
            quarterStartDate = Clock.System.now()
        )
        quota.totalSessions = 12 // ~57% of 21

        assertEquals(QuotaWarningLevel.AT_RISK, FPSQuarterService.getWarningLevel(quota))
    }

    @Test
    fun testIsEligibleForQuarter_meetsRequirements() {
        assertTrue(FPSQuarterService.isEligibleForQuarter(
            sessionsCount = 25,
            requiredSessions = 21,
            totalQuarters = 4,
            requiredQuarters = 4
        ))
    }

    @Test
    fun testIsEligibleForQuarter_insufficientSessions() {
        assertFalse(FPSQuarterService.isEligibleForQuarter(
            sessionsCount = 15,
            requiredSessions = 21,
            totalQuarters = 4,
            requiredQuarters = 4
        ))
    }

    @Test
    fun testIsEligibleForQuarter_insufficientQuarters() {
        assertFalse(FPSQuarterService.isEligibleForQuarter(
            sessionsCount = 25,
            requiredSessions = 21,
            totalQuarters = 2,
            requiredQuarters = 4
        ))
    }
}
