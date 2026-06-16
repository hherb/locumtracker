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
import javax.inject.Inject

/**
 * Pairs an assignment with its resolved location (null when the location is unknown).
 */
data class AssignmentWithLocation(
    val assignment: AssignmentEntity,
    val location: LocationEntity?
)

/**
 * Provides the list of assignments joined with their locations for the assignments list screen.
 */
@HiltViewModel
class AssignmentsViewModel @Inject constructor(
    private val assignmentRepository: AssignmentRepository,
    private val locationRepository: LocationRepository
) : ViewModel() {

    private val _assignments = MutableStateFlow<List<AssignmentEntity>>(emptyList())

    /** All assignments, ordered as returned by the repository. */
    val assignments: StateFlow<List<AssignmentEntity>> = _assignments.asStateFlow()

    private val _locations = MutableStateFlow<Map<String, LocationEntity>>(emptyMap())

    /** All locations keyed by location id, for fast lookup. */
    val locations: StateFlow<Map<String, LocationEntity>> = _locations.asStateFlow()

    /** Assignments combined with their resolved locations, exposed to the UI. */
    val assignmentsWithLocations: StateFlow<List<AssignmentWithLocation>> = combine(
        _assignments,
        _locations
    ) { assignments, locationsMap ->
        assignments.map { assignment ->
            AssignmentWithLocation(
                assignment = assignment,
                location = locationsMap[assignment.locationId]
            )
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    init {
        loadAssignments()
        loadLocations()
    }

    private fun loadAssignments() {
        viewModelScope.launch {
            assignmentRepository.getAllAssignments().collect { assignments ->
                _assignments.value = assignments
            }
        }
    }

    private fun loadLocations() {
        viewModelScope.launch {
            locationRepository.getAllLocations().collect { locations ->
                _locations.value = locations.associateBy { it.id }
            }
        }
    }

    /**
     * Deletes the given assignment from the repository.
     *
     * @param assignment the assignment to delete.
     */
    fun deleteAssignment(assignment: AssignmentEntity) {
        viewModelScope.launch {
            assignmentRepository.deleteAssignment(assignment)
        }
    }
}
