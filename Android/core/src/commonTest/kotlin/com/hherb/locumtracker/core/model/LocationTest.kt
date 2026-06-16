package com.hherb.locumtracker.core.model

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class LocationTest {

    private fun createLocation(
        mmmClassification: Int = 5,
        defaultDailyRate: Double? = null,
        defaultHourlyRate: Double? = null,
        defaultOnCallRate: Double? = null,
        defaultCallOutRate: Double? = null
    ): Location {
        return Location(
            id = "test-location",
            name = "Test Hospital",
            address = "123 Test St",
            mmmClassification = mmmClassification,
            defaultDailyRate = defaultDailyRate,
            defaultHourlyRate = defaultHourlyRate,
            defaultOnCallRate = defaultOnCallRate,
            defaultCallOutRate = defaultCallOutRate
        )
    }

    @Test
    fun testIsRuralSubsidyEligible_mmm3() {
        val location = createLocation(mmmClassification = 3)
        assertTrue(location.isRuralSubsidyEligible)
    }

    @Test
    fun testIsRuralSubsidyEligible_mmm7() {
        val location = createLocation(mmmClassification = 7)
        assertTrue(location.isRuralSubsidyEligible)
    }

    @Test
    fun testIsRuralSubsidyEligible_mmm1() {
        val location = createLocation(mmmClassification = 1)
        assertFalse(location.isRuralSubsidyEligible)
    }

    @Test
    fun testIsRuralSubsidyEligible_mmm2() {
        val location = createLocation(mmmClassification = 2)
        assertFalse(location.isRuralSubsidyEligible)
    }

    @Test
    fun testHasDefaultRates_dailyRate() {
        val location = createLocation(defaultDailyRate = 1200.0)
        assertTrue(location.hasDefaultRates)
    }

    @Test
    fun testHasDefaultRates_hourlyRate() {
        val location = createLocation(defaultHourlyRate = 150.0)
        assertTrue(location.hasDefaultRates)
    }

    @Test
    fun testHasDefaultRates_onCallRate() {
        val location = createLocation(defaultOnCallRate = 37.50)
        assertTrue(location.hasDefaultRates)
    }

    @Test
    fun testHasDefaultRates_callOutRate() {
        val location = createLocation(defaultCallOutRate = 75.0)
        assertTrue(location.hasDefaultRates)
    }

    @Test
    fun testHasDefaultRates_none() {
        val location = createLocation()
        assertFalse(location.hasDefaultRates)
    }

    @Test
    fun testMmmClassificationDescription() {
        assertEquals("MMM1 - Major City", createLocation(mmmClassification = 1).mmmClassificationDescription)
        assertEquals("MMM2 - Regional City", createLocation(mmmClassification = 2).mmmClassificationDescription)
        assertEquals("MMM3 - Large Rural Town", createLocation(mmmClassification = 3).mmmClassificationDescription)
        assertEquals("MMM4 - Medium Rural Town", createLocation(mmmClassification = 4).mmmClassificationDescription)
        assertEquals("MMM5 - Small Rural Town", createLocation(mmmClassification = 5).mmmClassificationDescription)
        assertEquals("MMM6 - Remote Community", createLocation(mmmClassification = 6).mmmClassificationDescription)
        assertEquals("MMM7 - Very Remote Community", createLocation(mmmClassification = 7).mmmClassificationDescription)
    }

    @Test
    fun testMmmClassificationDescription_unknown() {
        assertEquals("Unknown", createLocation(mmmClassification = 8).mmmClassificationDescription)
        assertEquals("Unknown", createLocation(mmmClassification = 0).mmmClassificationDescription)
    }

    @Test
    fun testHasDefaultSessionTemplates_true() {
        val location = createLocation().copy(
            defaultSessionTemplatesJSON = "[{\"id\":\"1\",\"startHour\":8,\"startMinute\":0,\"endHour\":12,\"endMinute\":0}]"
        )
        assertTrue(location.hasDefaultSessionTemplates)
    }

    @Test
    fun testHasDefaultSessionTemplates_false() {
        val location = createLocation()
        assertFalse(location.hasDefaultSessionTemplates)
    }

    @Test
    fun testDefaultSessionTemplate_durationHours() {
        val template = DefaultSessionTemplate(
            id = "test",
            startHour = 8,
            startMinute = 0,
            endHour = 12,
            endMinute = 0
        )
        assertEquals(4.0, template.durationHours, 0.01)
    }

    @Test
    fun testDefaultSessionTemplate_durationHours_withMinutes() {
        val template = DefaultSessionTemplate(
            id = "test",
            startHour = 8,
            startMinute = 30,
            endHour = 12,
            endMinute = 0
        )
        assertEquals(3.5, template.durationHours, 0.01)
    }

    @Test
    fun testDefaultSessionTemplate_durationHours_invalid() {
        val template = DefaultSessionTemplate(
            id = "test",
            startHour = 12,
            startMinute = 0,
            endHour = 8,
            endMinute = 0
        )
        assertEquals(0.0, template.durationHours, 0.01)
    }

    @Test
    fun testDefaultSessionTemplate_timeRangeFormatted() {
        val template = DefaultSessionTemplate(
            id = "test",
            startHour = 8,
            startMinute = 30,
            endHour = 12,
            endMinute = 0
        )
        assertEquals("08:30 - 12:00", template.timeRangeFormatted)
    }
}
