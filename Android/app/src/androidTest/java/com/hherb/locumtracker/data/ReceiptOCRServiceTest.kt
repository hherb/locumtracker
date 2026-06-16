package com.hherb.locumtracker.data

import android.content.Context
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.hherb.locumtracker.data.ocr.ReceiptOCRService
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
class ReceiptOCRServiceTest {

    @get:Rule
    val hiltRule = HiltAndroidRule(this)

    @Inject
    lateinit var ocrService: ReceiptOCRService

    private lateinit var context: Context

    @Before
    fun setup() {
        hiltRule.inject()
        context = InstrumentationRegistry.getInstrumentation().targetContext
    }

    @Test
    fun testCategorizeReceipt_petrol() {
        val category = ocrService.categorizeReceipt("BP Petrol Station")
        assertEquals("travel", category)
    }

    @Test
    fun testCategorizeReceipt_hotel() {
        val category = ocrService.categorizeReceipt("Grand Hotel Melbourne")
        assertEquals("accommodation", category)
    }

    @Test
    fun testCategorizeReceipt_restaurant() {
        val category = ocrService.categorizeReceipt("McDonald's Restaurant")
        assertEquals("meals", category)
    }

    @Test
    fun testCategorizeReceipt_pharmacy() {
        val category = ocrService.categorizeReceipt("Chemist Warehouse")
        assertEquals("supplies", category)
    }

    @Test
    fun testCategorizeReceipt_training() {
        val category = ocrService.categorizeReceipt("Medical Training Academy")
        assertEquals("training", category)
    }

    @Test
    fun testCategorizeReceipt_unknown() {
        val category = ocrService.categorizeReceipt("Unknown Business")
        assertEquals("other", category)
    }

    @Test
    fun testCategorizeReceipt_null() {
        val category = ocrService.categorizeReceipt(null)
        assertEquals("other", category)
    }
}
