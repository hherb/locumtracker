package com.hherb.locumtracker.core.model

import kotlinx.datetime.Clock
import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class AssignmentTest {

    private fun createAssignment(
        rateStructure: RateStructure = RateStructure.HOURLY_RATE,
        hourlyRate: Double? = 150.0,
        dailyRate: Double? = 1200.0
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
    fun testHasValidRateConfiguration_hourlyRate() {
        val assignment = createAssignment(
            rateStructure = RateStructure.HOURLY_RATE,
            hourlyRate = 150.0
        )
        assertTrue(assignment.hasValidRateConfiguration)
    }

    @Test
    fun testHasValidRateConfiguration_dailyRate() {
        val assignment = createAssignment(
            rateStructure = RateStructure.DAILY_RATE,
            dailyRate = 1200.0
        )
        assertTrue(assignment.hasValidRateConfiguration)
    }

    @Test
    fun testHasValidRateConfiguration_noRate() {
        val assignment = createAssignment(
            rateStructure = RateStructure.HOURLY_RATE,
            hourlyRate = null
        )
        assertFalse(assignment.hasValidRateConfiguration)
    }

    @Test
    fun testHasValidRateConfiguration_zeroRate() {
        val assignment = createAssignment(
            rateStructure = RateStructure.HOURLY_RATE,
            hourlyRate = 0.0
        )
        assertFalse(assignment.hasValidRateConfiguration)
    }

    @Test
    fun testHasValidRateConfiguration_negativeRate() {
        val assignment = createAssignment(
            rateStructure = RateStructure.HOURLY_RATE,
            hourlyRate = -50.0
        )
        assertFalse(assignment.hasValidRateConfiguration)
    }

    @Test
    fun testHasDefaultSessionTemplates_true() {
        val assignment = createAssignment().copy(
            defaultSessionTemplatesJSON = "[{\"id\":\"1\",\"startHour\":8,\"startMinute\":0,\"endHour\":12,\"endMinute\":0}]"
        )
        assertTrue(assignment.hasDefaultSessionTemplates)
    }

    @Test
    fun testHasDefaultSessionTemplates_false() {
        val assignment = createAssignment()
        assertFalse(assignment.hasDefaultSessionTemplates)
    }

    @Test
    fun testHasProviderLocations_true() {
        val assignment = createAssignment().copy(
            providerLocationsJSON = "[{\"id\":\"1\",\"name\":\"Clinic 1\",\"providerNumber\":\"12345\"}]"
        )
        assertTrue(assignment.hasProviderLocations)
    }

    @Test
    fun testHasProviderLocations_false() {
        val assignment = createAssignment()
        assertFalse(assignment.hasProviderLocations)
    }

    @Test
    fun testHasMainProviderNumber_true() {
        val assignment = createAssignment().copy(mainProviderNumber = "12345")
        assertTrue(assignment.hasMainProviderNumber)
    }

    @Test
    fun testHasMainProviderNumber_blank() {
        val assignment = createAssignment().copy(mainProviderNumber = "   ")
        assertFalse(assignment.hasMainProviderNumber)
    }

    @Test
    fun testHasMultipleLocations_true() {
        val assignment = createAssignment().copy(
            additionalLocationIdsJSON = "[\"loc-2\",\"loc-3\"]"
        )
        assertTrue(assignment.hasMultipleLocations)
    }

    @Test
    fun testHasMultipleLocations_false() {
        val assignment = createAssignment()
        assertFalse(assignment.hasMultipleLocations)
    }

    @Test
    fun testAdditionalLocationIdsFromJson_validJson() {
        val ids = Assignment.additionalLocationIdsFromJson("[\"loc-1\",\"loc-2\"]")
        assertTrue(ids.contains("loc-1"))
        assertTrue(ids.contains("loc-2"))
    }

    @Test
    fun testAdditionalLocationIdsFromJson_invalidJson() {
        val ids = Assignment.additionalLocationIdsFromJson("invalid json")
        assertTrue(ids.isEmpty())
    }

    @Test
    fun testAdditionalLocationIdsFromJson_null() {
        val ids = Assignment.additionalLocationIdsFromJson(null)
        assertTrue(ids.isEmpty())
    }
}
