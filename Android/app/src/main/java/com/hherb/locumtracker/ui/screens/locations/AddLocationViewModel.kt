package com.hherb.locumtracker.ui.screens.locations

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.hherb.locumtracker.data.database.entity.LocationEntity
import com.hherb.locumtracker.data.repository.LocationRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject

/** Backs [AddLocationScreen]: persists a newly entered location and exposes saving state. */
@HiltViewModel
class AddLocationViewModel @Inject constructor(
    private val locationRepository: LocationRepository
) : ViewModel() {

    /** True while a location is being persisted; drives the save button's progress state. */
    val isSaving = MutableStateFlow(false)

    /**
     * Builds and persists a new location with the supplied details, defaulting unset
     * geo and template fields to null, then updates the saving state.
     *
     * @param name location name.
     * @param address postal/street address.
     * @param phoneNumber optional contact phone number, or null.
     * @param providerNumber optional Medicare provider number, or null.
     * @param mmmClassification Modified Monash Model remoteness band (1-7).
     * @param notes optional free-text notes, or null.
     * @param defaultDailyRate optional default daily rate, or null.
     * @param defaultHourlyRate optional default hourly rate, or null.
     * @param defaultOnCallRate optional default on-call rate, or null.
     * @param defaultCallOutRate optional default call-out rate, or null.
     */
    fun addLocation(
        name: String,
        address: String,
        phoneNumber: String?,
        providerNumber: String?,
        mmmClassification: Int,
        notes: String?,
        defaultDailyRate: Double?,
        defaultHourlyRate: Double?,
        defaultOnCallRate: Double?,
        defaultCallOutRate: Double?
    ) {
        viewModelScope.launch {
            isSaving.value = true

            try {
                val location = LocationEntity(
                    id = UUID.randomUUID().toString(),
                    name = name,
                    address = address,
                    mmmClassification = mmmClassification,
                    latitude = null,
                    longitude = null,
                    effectiveFrom = System.currentTimeMillis(),
                    effectiveTo = null,
                    createdAt = System.currentTimeMillis(),
                    updatedAt = System.currentTimeMillis(),
                    providerNumber = providerNumber,
                    phoneNumber = phoneNumber,
                    notes = notes,
                    defaultDailyRate = defaultDailyRate,
                    defaultHourlyRate = defaultHourlyRate,
                    defaultOnCallRate = defaultOnCallRate,
                    defaultCallOutRate = defaultCallOutRate,
                    defaultSessionTemplatesJSON = null
                )

                locationRepository.insertLocation(location)
                isSaving.value = false
            } catch (e: Exception) {
                isSaving.value = false
            }
        }
    }
}
