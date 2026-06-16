package com.hherb.locumtracker.core.model

import kotlinx.datetime.Instant
import kotlinx.serialization.Serializable
import com.hherb.locumtracker.core.util.randomUuidString

/** Number of digits in a valid Australian Business Number (ABN). */
private const val ABN_DIGIT_COUNT = 11

/**
 * The locum practitioner's personal, business, and tax details, plus default rates.
 *
 * @property id Unique identifier for the profile.
 * @property title Optional title (e.g. "Dr").
 * @property firstName Practitioner's first name.
 * @property lastName Practitioner's last name.
 * @property email Optional contact email.
 * @property streetAddress Optional street address.
 * @property suburb Optional suburb.
 * @property state Optional state.
 * @property postcode Optional postcode.
 * @property businessStructure Optional business structure (e.g. sole trader, company).
 * @property abn Optional Australian Business Number.
 * @property isGstRegistered Whether the practitioner is registered for GST.
 * @property isVocationalRegister Whether the practitioner is on the vocational register (VR),
 *   which affects WIP payment rates.
 * @property providerNumber Optional Medicare provider number.
 * @property specialty Optional medical specialty.
 * @property defaultDailyRate Optional default daily rate.
 * @property defaultHourlyRate Optional default hourly rate.
 * @property defaultOnCallRate Optional default on-call rate.
 * @property defaultCallOutRate Optional default call-out rate.
 * @property createdAt Timestamp when the record was created.
 * @property updatedAt Timestamp when the record was last updated.
 */
@Serializable
data class LocumProfile(
    val id: String = randomUuidString(),
    val title: String? = null,
    val firstName: String = "",
    val lastName: String = "",
    val email: String? = null,
    val streetAddress: String? = null,
    val suburb: String? = null,
    val state: String? = null,
    val postcode: String? = null,
    val businessStructure: String? = null,
    val abn: String? = null,
    val isGstRegistered: Boolean = false,
    val isVocationalRegister: Boolean = false,
    val providerNumber: String? = null,
    val specialty: String? = null,
    val defaultDailyRate: Double? = null,
    val defaultHourlyRate: Double? = null,
    val defaultOnCallRate: Double? = null,
    val defaultCallOutRate: Double? = null,
    val createdAt: Instant = Instant.fromEpochMilliseconds(System.currentTimeMillis()),
    val updatedAt: Instant = Instant.fromEpochMilliseconds(System.currentTimeMillis())
) {
    /** The title, first name, and last name joined into a single trimmed string. */
    val fullName: String
        get() = listOfNotNull(title, firstName, lastName).joinToString(" ").trim()

    /** `true` when a non-blank ABN has been set. */
    val hasAbn: Boolean
        get() = !abn.isNullOrBlank()

    /**
     * The ABN formatted in the standard "XX XXX XXX XXX" grouping when it has exactly
     * [ABN_DIGIT_COUNT] digits; otherwise the raw digits (or empty string when no ABN is set).
     */
    val formattedAbn: String
        get() {
            val digits = abn?.filter { it.isDigit() } ?: return ""
            return if (digits.length == ABN_DIGIT_COUNT) {
                "${digits.substring(0, 2)} ${digits.substring(2, 5)} ${digits.substring(5, 8)} ${digits.substring(8)}"
            } else {
                digits
            }
        }
}
