package com.hherb.locumtracker.data

import android.content.Context
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.hherb.locumtracker.data.database.entity.AssignmentEntity
import com.hherb.locumtracker.data.database.entity.LocationEntity
import com.hherb.locumtracker.data.database.entity.ReceiptEntity
import com.hherb.locumtracker.data.export.ExportService
import dagger.hilt.android.testing.HiltAndroidRule
import dagger.hilt.android.testing.HiltAndroidTest
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import javax.inject.Inject

@HiltAndroidTest
@RunWith(AndroidJUnit4::class)
class ExportServiceTest {

    @get:Rule
    val hiltRule = HiltAndroidRule(this)

    @Inject
    lateinit var exportService: ExportService

    private lateinit var context: Context

    @Before
    fun setup() {
        hiltRule.inject()
        context = InstrumentationRegistry.getInstrumentation().targetContext
    }

    @Test
    fun testExportEarningsCSV_returnsUri() {
        val receipts = listOf(
            ReceiptEntity(
                id = "1",
                amount = 100.0,
                category = "travel",
                date = System.currentTimeMillis(),
                receiptDescription = "Fuel",
                createdAt = System.currentTimeMillis(),
                updatedAt = System.currentTimeMillis()
            )
        )

        val assignments = mapOf(
            "assign-1" to AssignmentEntity(
                id = "assign-1",
                locationId = "loc-1",
                rateStructure = "hourly_rate",
                hourlyRate = 150.0,
                startDate = System.currentTimeMillis(),
                endDate = System.currentTimeMillis() + 7 * 24 * 60 * 60 * 1000L,
                status = "active",
                createdAt = System.currentTimeMillis(),
                updatedAt = System.currentTimeMillis()
            )
        )

        val locations = mapOf(
            "loc-1" to LocationEntity(
                id = "loc-1",
                name = "Test Hospital",
                address = "123 Test St",
                mmmClassification = 5,
                createdAt = System.currentTimeMillis(),
                updatedAt = System.currentTimeMillis()
            )
        )

        val uri = exportService.exportEarningsCSV(receipts, assignments, locations)
        assertNotNull(uri)
    }

    @Test
    fun testExportEarningsJSON_returnsUri() {
        val receipts = listOf(
            ReceiptEntity(
                id = "1",
                amount = 250.0,
                category = "accommodation",
                date = System.currentTimeMillis(),
                receiptDescription = "Hotel",
                createdAt = System.currentTimeMillis(),
                updatedAt = System.currentTimeMillis()
            )
        )

        val uri = exportService.exportEarningsJSON(receipts, emptyMap(), emptyMap())
        assertNotNull(uri)
    }

    @Test
    fun testExportSessionsCSV_returnsUri() {
        val uri = exportService.exportSessionsCSV(
            sessions = emptyList(),
            dailyRecords = emptyList(),
            assignments = emptyMap()
        )
        assertNotNull(uri)
    }
}
