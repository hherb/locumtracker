package com.hherb.locumtracker.ui.screens.assignments

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.hherb.locumtracker.data.database.entity.AssignmentEntity
import com.hherb.locumtracker.data.database.entity.LocationEntity
import com.hherb.locumtracker.data.repository.AssignmentRepository
import com.hherb.locumtracker.data.repository.LocationRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject

/**
 * Backs the add-assignment screen: exposes selectable locations and persists new assignments.
 */
@HiltViewModel
class AddAssignmentViewModel @Inject constructor(
    private val assignmentRepository: AssignmentRepository,
    private val locationRepository: LocationRepository
) : ViewModel() {

    private val _locations = MutableStateFlow<List<LocationEntity>>(emptyList())

    /** Locations the user can assign the new assignment to. */
    val locations: StateFlow<List<LocationEntity>> = _locations.asStateFlow()

    /** True while an insert is in progress, used to disable the save button. */
    val isSaving = MutableStateFlow(false)

    init {
        loadLocations()
    }

    private fun loadLocations() {
        viewModelScope.launch {
            locationRepository.getAllLocations().collect { locations ->
                _locations.value = locations
            }
        }
    }

    /**
     * Creates and persists a new assignment with status "planned".
     *
     * @param name optional human-readable assignment name.
     * @param locationId id of the location the assignment is at.
     * @param rateStructure "daily_rate" or "hourly_rate".
     * @param dailyRate daily rate in dollars, or null for hourly assignments.
     * @param hourlyRate base hourly rate in dollars, or null for daily assignments.
     * @param onCallRate optional on-call hourly rate in dollars.
     * @param callOutRate optional call-out hourly rate in dollars.
     * @param startDate assignment start, epoch milliseconds.
     * @param endDate assignment end, epoch milliseconds.
     */
    fun addAssignment(
        name: String?,
        locationId: String,
        rateStructure: String,
        dailyRate: Double?,
        hourlyRate: Double?,
        onCallRate: Double?,
        callOutRate: Double?,
        startDate: Long,
        endDate: Long
    ) {
        viewModelScope.launch {
            isSaving.value = true

            try {
                val assignment = AssignmentEntity(
                    id = UUID.randomUUID().toString(),
                    locationId = locationId,
                    rateStructure = rateStructure,
                    dailyRate = dailyRate,
                    hourlyRate = hourlyRate,
                    onCallRate = onCallRate,
                    callOutRate = callOutRate,
                    startDate = startDate,
                    endDate = endDate,
                    status = "planned",
                    createdAt = System.currentTimeMillis(),
                    updatedAt = System.currentTimeMillis(),
                    name = name,
                    mainProviderNumber = null,
                    defaultSessionTemplatesJSON = null,
                    additionalLocationIdsJSON = null,
                    providerLocationsJSON = null
                )

                assignmentRepository.insertAssignment(assignment)
                isSaving.value = false
            } catch (e: Exception) {
                isSaving.value = false
            }
        }
    }
}
