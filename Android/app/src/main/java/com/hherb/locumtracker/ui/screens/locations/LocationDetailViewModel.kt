package com.hherb.locumtracker.ui.screens.locations

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
 * Backs [LocationDetailScreen]: loads the location identified by the `locationId` argument
 * along with its linked assignments, and supports deleting the location.
 */
@HiltViewModel
class LocationDetailViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val locationRepository: LocationRepository,
    private val assignmentRepository: AssignmentRepository
) : ViewModel() {

    private val locationId: String = savedStateHandle["locationId"] ?: ""

    private val _location = MutableStateFlow<LocationEntity?>(null)
    /** The location being displayed, or null until loaded. */
    val location: StateFlow<LocationEntity?> = _location.asStateFlow()

    private val _assignments = MutableStateFlow<List<AssignmentEntity>>(emptyList())
    /** Assignments linked to this location. */
    val assignments: StateFlow<List<AssignmentEntity>> = _assignments.asStateFlow()

    /** Whether the delete-confirmation dialog is currently shown. */
    val showDeleteDialog = MutableStateFlow(false)

    init {
        loadLocation()
        loadAssignments()
    }

    private fun loadLocation() {
        viewModelScope.launch {
            locationRepository.getLocationByIdFlow(locationId).collect { location ->
                _location.value = location
            }
        }
    }

    private fun loadAssignments() {
        viewModelScope.launch {
            assignmentRepository.getAssignmentsByLocation(locationId).collect { assignments ->
                _assignments.value = assignments
            }
        }
    }

    /** Deletes the currently displayed location from the repository. */
    fun deleteLocation() {
        viewModelScope.launch {
            locationRepository.deleteLocationById(locationId)
        }
    }
}
