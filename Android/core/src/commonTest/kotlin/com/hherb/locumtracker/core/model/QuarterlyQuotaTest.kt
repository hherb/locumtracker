package com.hherb.locumtracker.core.model

import kotlinx.datetime.Clock
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class QuarterlyQuotaTest {

    private fun createQuota(
        mmm3Sessions: Int = 0,
        mmm4Sessions: Int = 0,
        mmm5Sessions: Int = 0,
        mmm6Sessions: Int = 0,
        mmm7Sessions: Int = 0
    ): QuarterlyQuota {
        val quota = QuarterlyQuota(
            id = "test-quota",
            practitionerId = "test-practitioner",
            quarterStartDate = Clock.System.now()
        )
        quota.mmm3Sessions = mmm3Sessions
        quota.mmm4Sessions = mmm4Sessions
        quota.mmm5Sessions = mmm5Sessions
        quota.mmm6Sessions = mmm6Sessions
        quota.mmm7Sessions = mmm7Sessions
        quota.recalculateTotals()
        return quota
    }

    @Test
    fun testRawTotalSessions() {
        val quota = createQuota(
            mmm3Sessions = 5,
            mmm4Sessions = 3,
            mmm5Sessions = 2
        )
        assertEquals(10, quota.rawTotalSessions)
    }

    @Test
    fun testTotalSessions_cappedAtMaximum() {
        val quota = createQuota(
            mmm3Sessions = 50,
            mmm4Sessions = 30,
            mmm5Sessions = 30
        )
        // Raw total is 110, but capped at 104
        assertEquals(104, quota.totalSessions)
    }

    @Test
    fun testProgressPercentage() {
        val quota = createQuota(mmm5Sessions = 21)
        assertEquals(100.0, quota.progressPercentage, 0.01) // 21/21 * 100
    }

    @Test
    fun testProgressPercentage_halfComplete() {
        val quota = createQuota(mmm5Sessions = 10)
        val expected = 10.0 / 21.0 * 100.0
        assertEquals(expected, quota.progressPercentage, 0.01)
    }

    @Test
    fun testRemainingSessions() {
        val quota = createQuota(mmm5Sessions = 15)
        assertEquals(6, quota.remainingSessions) // 21 - 15
    }

    @Test
    fun testRemainingSessions_metMinimum() {
        val quota = createQuota(mmm5Sessions = 25)
        assertEquals(0, quota.remainingSessions)
    }

    @Test
    fun testExcessSessions() {
        val quota = createQuota(mmm5Sessions = 60, mmm6Sessions = 50)
        // Raw total: 110, Excess: 110 - 104 = 6
        assertEquals(6, quota.excessSessions)
    }

    @Test
    fun testAddSession_mmm5() {
        val quota = createQuota()
        quota.addSession(5)
        assertEquals(1, quota.mmm5Sessions)
        assertEquals(1, quota.totalSessions)
    }

    @Test
    fun testAddSession_invalidClassification() {
        val quota = createQuota()
        quota.addSession(2) // Not eligible
        assertEquals(0, quota.rawTotalSessions)
    }

    @Test
    fun testRemoveSession_mmm5() {
        val quota = createQuota(mmm5Sessions = 5)
        quota.removeSession(5)
        assertEquals(4, quota.mmm5Sessions)
    }

    @Test
    fun testRemoveSession_cannotGoBelowZero() {
        val quota = createQuota(mmm5Sessions = 0)
        quota.removeSession(5)
        assertEquals(0, quota.mmm5Sessions)
    }

    @Test
    fun testQuotaMet() {
        val quota = createQuota(mmm5Sessions = 21)
        assertTrue(quota.quotaMet)
    }

    @Test
    fun testQuotaNotMet() {
        val quota = createQuota(mmm5Sessions = 20)
        assertFalse(quota.quotaMet)
    }

    @Test
    fun testSessions_forMMM3() {
        val quota = createQuota(mmm3Sessions = 5)
        assertEquals(5, quota.sessions(mmm = 3))
    }

    @Test
    fun testSessions_forMMM5() {
        val quota = createQuota(mmm5Sessions = 10)
        assertEquals(10, quota.sessions(mmm = 5))
    }

    @Test
    fun testSessions_invalidMMM() {
        val quota = createQuota(mmm5Sessions = 10)
        assertEquals(0, quota.sessions(mmm = 2))
    }

    @Test
    fun testConstants() {
        assertEquals(21, QuarterlyQuota.MINIMUM_SESSIONS)
        assertEquals(104, QuarterlyQuota.MAXIMUM_SESSIONS)
        assertEquals(3.0, QuarterlyQuota.MINIMUM_SESSION_DURATION_HOURS, 0.01)
        assertEquals(2, QuarterlyQuota.MAXIMUM_SESSIONS_PER_DAY)
    }
}
