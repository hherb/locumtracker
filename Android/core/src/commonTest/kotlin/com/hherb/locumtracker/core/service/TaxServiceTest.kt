package com.hherb.locumtracker.core.service

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class TaxServiceTest {

    @Test
    fun testValidateAbn_validAbn_returnsTrue() {
        // Valid ABN: 51 824 753 556
        assertTrue(TaxService.validateAbn("51824753556"))
    }

    @Test
    fun testValidateAbn_invalidAbn_returnsFalse() {
        assertFalse(TaxService.validateAbn("12345678901"))
    }

    @Test
    fun testValidateAbn_wrongLength_returnsFalse() {
        assertFalse(TaxService.validateAbn("1234567890"))
        assertFalse(TaxService.validateAbn("123456789012"))
    }

    @Test
    fun testCalculateGst_registered_returnsCorrectGst() {
        val gst = TaxService.calculateGst(100.0, isGstRegistered = true)
        assertEquals(10.0, gst, 0.01)
    }

    @Test
    fun testCalculateGst_notRegistered_returnsZero() {
        val gst = TaxService.calculateGst(100.0, isGstRegistered = false)
        assertEquals(0.0, gst, 0.01)
    }

    @Test
    fun testExtractGst_returnsCorrectComponent() {
        // GST inclusive amount: $110, GST component: $10
        val gst = TaxService.extractGst(110.0)
        assertEquals(10.0, gst, 0.01)
    }

    @Test
    fun testFormatAbn_returnsFormattedString() {
        val formatted = TaxService.formatAbn("51824753556")
        assertEquals("51 824 753 556", formatted)
    }

    @Test
    fun testFormatAbn_wrongLength_returnsOriginal() {
        val formatted = TaxService.formatAbn("12345")
        assertEquals("12345", formatted)
    }

    @Test
    fun testRequiresCustomerAbn_aboveThreshold_returnsTrue() {
        assertTrue(TaxService.requiresCustomerAbn(100.0))
    }

    @Test
    fun testRequiresCustomerAbn_belowThreshold_returnsFalse() {
        assertFalse(TaxService.requiresCustomerAbn(50.0))
    }
}
