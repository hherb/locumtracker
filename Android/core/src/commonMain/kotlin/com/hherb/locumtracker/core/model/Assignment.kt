package com.hherb.locumtracker.core.model

import kotlinx.datetime.Instant
import kotlinx.serialization.Serializable
import com.hherb.locumtracker.core.util.randomUuidString

/**
 * A locum work assignment at a given location, defining the rate structure and
 * date range over which sessions are recorded.
 *
 * @property id Unique identifier for the assignment.
 * @property locationId Identifier of the primary [Location] for this assignment.
 * @property rateStructure Whether the assignment is paid per day or per hour.
 * @property dailyRate Fixed amount paid per day (used when [rateStructure] is daily).
 * @property hourlyRate Base amount paid per hour (used when [rateStructure] is hourly).
 * @property onCallRate Rate applied while on call.
 * @property callOutRate Rate applied for call-outs.
 * @property startDate First day of the assignment.
 * @property endDate Last day of the assignment.
 * @property status Lifecycle status of the assignment.
 * @property createdAt Timestamp when the record was created.
 * @property updatedAt Timestamp when the record was last updated.
 * @property name Optional human-readable name for the assignment.
 * @property mainProviderNumber Optional primary Medicare provider number for the assignment.
 * @property defaultSessionTemplatesJSON Serialized default session templates as JSON.
 * @property additionalLocationIdsJSON Serialized list of additional location IDs as JSON.
 * @property providerLocationsJSON Serialized list of provider locations as JSON.
 */
@Serializable
data class Assignment(
    val id: String = randomUuidString(),
    val locationId: String,
    val rateStructure: RateStructure = RateStructure.DAILY_RATE,
    val dailyRate: Double? = null,
    val hourlyRate: Double? = null,
    val onCallRate: Double? = null,
    val callOutRate: Double? = null,
    val startDate: Instant = Instant.fromEpochMilliseconds(System.currentTimeMillis()),
    val endDate: Instant = Instant.fromEpochMilliseconds(System.currentTimeMillis()),
    val status: AssignmentStatus = AssignmentStatus.PLANNED,
    val createdAt: Instant = Instant.fromEpochMilliseconds(System.currentTimeMillis()),
    val updatedAt: Instant = Instant.fromEpochMilliseconds(System.currentTimeMillis()),
    val name: String? = null,
    val mainProviderNumber: String? = null,
    val defaultSessionTemplatesJSON: String? = null,
    val additionalLocationIdsJSON: String? = null,
    val providerLocationsJSON: String? = null
) {
    /**
     * `true` when the rate required by the current [rateStructure] is present and positive.
     */
    val hasValidRateConfiguration: Boolean
        get() = when (rateStructure) {
            RateStructure.DAILY_RATE -> dailyRate != null && dailyRate > 0
            RateStructure.HOURLY_RATE -> hourlyRate != null && hourlyRate > 0
        }

    /** `true` when default session templates have been configured for this assignment. */
    val hasDefaultSessionTemplates: Boolean
        get() = !defaultSessionTemplatesJSON.isNullOrEmpty()

    /** `true` when provider locations have been configured for this assignment. */
    val hasProviderLocations: Boolean
        get() = !providerLocationsJSON.isNullOrEmpty()

    /** `true` when a non-blank main provider number has been set. */
    val hasMainProviderNumber: Boolean
        get() = mainProviderNumber?.trim()?.isNotEmpty() == true

    /** `true` when additional locations beyond the primary one have been configured. */
    val hasMultipleLocations: Boolean
        get() = !additionalLocationIdsJSON.isNullOrEmpty()

    companion object {
        /**
         * Decodes a JSON-encoded list of additional location IDs.
         *
         * @param json JSON string holding a list of location IDs, or `null`/empty.
         * @return The decoded list, or an empty list if [json] is blank or cannot be parsed.
         */
        fun additionalLocationIdsFromJson(json: String?): List<String> {
            if (json.isNullOrEmpty()) return emptyList()
            return try {
                kotlinx.serialization.json.Json.decodeFromString<List<String>>(json)
            } catch (e: Exception) {
                emptyList()
            }
        }
    }
}

/**
 * A specific provider location associated with an assignment, pairing a Medicare
 * provider number with its practice details.
 *
 * @property id Unique identifier for the provider location.
 * @property name Display name of the practice or location.
 * @property providerNumber Medicare provider number used at this location.
 * @property address Optional postal address.
 * @property phoneNumber Optional contact phone number.
 * @property notes Optional free-text notes.
 */
@Serializable
data class ProviderLocation(
    val id: String = randomUuidString(),
    val name: String,
    val providerNumber: String,
    val address: String? = null,
    val phoneNumber: String? = null,
    val notes: String? = null
)
