package com.hherb.locumtracker.ui.screens.locations

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.hherb.locumtracker.data.database.entity.LocationEntity
import com.hherb.locumtracker.data.repository.LocationRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Backs [EditLocationScreen]: loads the location identified by the `locationId` argument
 * and persists edits back to the repository.
 */
@HiltViewModel
class EditLocationViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val locationRepository: LocationRepository
) : ViewModel() {

    private val locationId: String = savedStateHandle["locationId"] ?: ""

    private val _location = MutableStateFlow<LocationEntity?>(null)
    /** The location being edited, or null until loaded. */
    val location: StateFlow<LocationEntity?> = _location.asStateFlow()

    /** True while changes are being persisted; drives the save button's progress state. */
    val isSaving = MutableStateFlow(false)

    init {
        loadLocation()
    }

    private fun loadLocation() {
        viewModelScope.launch {
            locationRepository.getLocationByIdFlow(locationId).collect { location ->
                _location.value = location
            }
        }
    }

    /**
     * Applies the supplied edits to the currently loaded location and persists it,
     * doing nothing if no location is loaded, and updates the saving state.
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
    fun updateLocation(
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
                val existing = _location.value
                if (existing != null) {
                    locationRepository.updateLocation(
                        existing.copy(
                            name = name,
                            address = address,
                            phoneNumber = phoneNumber,
                            providerNumber = providerNumber,
                            mmmClassification = mmmClassification,
                            notes = notes,
                            defaultDailyRate = defaultDailyRate,
                            defaultHourlyRate = defaultHourlyRate,
                            defaultOnCallRate = defaultOnCallRate,
                            defaultCallOutRate = defaultCallOutRate,
                            updatedAt = System.currentTimeMillis()
                        )
                    )
                }
                isSaving.value = false
            } catch (e: Exception) {
                isSaving.value = false
            }
        }
    }
}
