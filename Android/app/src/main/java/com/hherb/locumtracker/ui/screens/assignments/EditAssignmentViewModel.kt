package com.hherb.locumtracker.ui.screens.assignments

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.hherb.locumtracker.data.database.entity.AssignmentEntity
import com.hherb.locumtracker.data.database.entity.LocationEntity
import com.hherb.locumtracker.data.repository.AssignmentRepository
import com.hherb.locumtracker.data.repository.LocationRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Backs the edit-assignment screen: loads the target assignment and locations, and saves updates.
 */
@HiltViewModel
class EditAssignmentViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val assignmentRepository: AssignmentRepository,
    private val locationRepository: LocationRepository
) : ViewModel() {

    private val assignmentId: String = savedStateHandle["assignmentId"] ?: ""

    private val _assignment = MutableStateFlow<AssignmentEntity?>(null)

    /** The assignment being edited, or null until loaded. */
    val assignment: StateFlow<AssignmentEntity?> = _assignment.asStateFlow()

    private val _locations = MutableStateFlow<List<LocationEntity>>(emptyList())

    /** Locations the user can reassign the assignment to. */
    val locations: StateFlow<List<LocationEntity>> = _locations.asStateFlow()

    /** True while an update is in progress, used to disable the save button. */
    val isSaving = MutableStateFlow(false)

    init {
        loadAssignment()
        loadLocations()
    }

    private fun loadAssignment() {
        viewModelScope.launch {
            assignmentRepository.getAssignmentByIdFlow(assignmentId).collect { assignment ->
                _assignment.value = assignment
            }
        }
    }

    private fun loadLocations() {
        viewModelScope.launch {
            locationRepository.getAllLocations().collect { locations ->
                _locations.value = locations
            }
        }
    }

    /**
     * Persists edits to the loaded assignment, refreshing its updatedAt timestamp.
     *
     * @param name optional human-readable assignment name.
     * @param locationId id of the location the assignment is at.
     * @param rateStructure "daily_rate" or "hourly_rate".
     * @param dailyRate daily rate in dollars, or null for hourly assignments.
     * @param hourlyRate base hourly rate in dollars, or null for daily assignments.
     * @param onCallRate optional on-call hourly rate in dollars.
     * @param callOutRate optional call-out hourly rate in dollars.
     * @param status assignment status (planned/active/completed/cancelled).
     * @param startDate assignment start, epoch milliseconds.
     * @param endDate assignment end, epoch milliseconds.
     */
    fun updateAssignment(
        name: String?,
        locationId: String,
        rateStructure: String,
        dailyRate: Double?,
        hourlyRate: Double?,
        onCallRate: Double?,
        callOutRate: Double?,
        status: String,
        startDate: Long,
        endDate: Long
    ) {
        viewModelScope.launch {
            isSaving.value = true

            try {
                val existing = _assignment.value
                if (existing != null) {
                    assignmentRepository.updateAssignment(
                        existing.copy(
                            name = name,
                            locationId = locationId,
                            rateStructure = rateStructure,
                            dailyRate = dailyRate,
                            hourlyRate = hourlyRate,
                            onCallRate = onCallRate,
                            callOutRate = callOutRate,
                            status = status,
                            startDate = startDate,
                            endDate = endDate,
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
