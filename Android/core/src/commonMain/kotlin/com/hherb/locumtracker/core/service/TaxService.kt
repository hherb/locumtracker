package com.hherb.locumtracker.core.service

/**
 * Pure service for Australian tax calculations: GST, ABN validation, and ABN formatting.
 * All functions are side-effect free.
 */
object TaxService {
    /** Australian Goods and Services Tax rate (10%). */
    const val GST_RATE = 0.10

    /** Invoice amount (inclusive) at or above which a customer ABN is required. */
    const val GST_THRESHOLD = 82.50

    /** Number of digits in a valid Australian Business Number (ABN). */
    private const val ABN_DIGIT_COUNT = 11

    /** Divisor for the ABN checksum; a valid ABN's weighted sum is divisible by this. */
    private const val ABN_CHECKSUM_DIVISOR = 89

    /** Positional weights applied to each ABN digit during checksum validation. */
    private val ABN_WEIGHTS = intArrayOf(10, 1, 3, 5, 7, 9, 11, 13, 15, 17, 19)

    /**
     * Validates an ABN using the official 11-digit weighted-checksum algorithm.
     *
     * @param abn The candidate ABN (non-digit characters are ignored).
     * @return `true` when the value has [ABN_DIGIT_COUNT] digits and passes the checksum.
     */
    fun validateAbn(abn: String): Boolean {
        val digits = abn.filter { it.isDigit() }
        if (digits.length != ABN_DIGIT_COUNT) return false

        val weights = ABN_WEIGHTS
        var sum = 0
        for (i in digits.indices) {
            val digit = digits[i].digitToInt()
            val adjusted = if (i == 0) digit - 1 else digit
            sum += adjusted * weights[i]
        }
        return sum % ABN_CHECKSUM_DIVISOR == 0
    }

    /**
     * Calculates the GST to add to a GST-exclusive amount.
     *
     * @param amount The GST-exclusive amount.
     * @param isGstRegistered Whether the practitioner is registered for GST.
     * @return The GST component, or `0.0` when not GST-registered.
     */
    fun calculateGst(amount: Double, isGstRegistered: Boolean): Double {
        return if (isGstRegistered) amount * GST_RATE else 0.0
    }

    /**
     * Extracts the GST component already included within a GST-inclusive amount.
     *
     * @param amount The GST-inclusive amount.
     * @return The embedded GST portion.
     */
    fun extractGst(amount: Double): Double {
        return amount - (amount / (1 + GST_RATE))
    }

    /**
     * Formats an ABN in the standard "XX XXX XXX XXX" grouping when it has exactly
     * [ABN_DIGIT_COUNT] digits.
     *
     * @param abn The ABN to format.
     * @return The grouped ABN, or the original input when it does not have 11 digits.
     */
    fun formatAbn(abn: String): String {
        val digits = abn.filter { it.isDigit() }
        return if (digits.length == ABN_DIGIT_COUNT) {
            "${digits.substring(0, 2)} ${digits.substring(2, 5)} ${digits.substring(5, 8)} ${digits.substring(8)}"
        } else {
            abn
        }
    }

    /**
     * Determines whether an invoice of the given amount requires the customer's ABN.
     *
     * @param amount The invoice amount.
     * @return `true` when [amount] is at or above [GST_THRESHOLD].
     */
    fun requiresCustomerAbn(amount: Double): Boolean {
        return amount >= GST_THRESHOLD
    }
}
