package com.hherb.locumtracker.ui.screens.assignments

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.hherb.locumtracker.data.database.entity.AssignmentEntity
import com.hherb.locumtracker.data.database.entity.LocationEntity
import com.hherb.locumtracker.data.database.entity.SessionEntity
import com.hherb.locumtracker.data.repository.AssignmentRepository
import com.hherb.locumtracker.data.repository.LocationRepository
import com.hherb.locumtracker.data.repository.SessionRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Backs the assignment detail screen: loads the assignment with its location and sessions,
 * and handles deletion.
 */
@HiltViewModel
class AssignmentDetailViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val assignmentRepository: AssignmentRepository,
    private val locationRepository: LocationRepository,
    private val sessionRepository: SessionRepository
) : ViewModel() {

    private val assignmentId: String = savedStateHandle["assignmentId"] ?: ""

    private val _assignment = MutableStateFlow<AssignmentEntity?>(null)

    /** The assignment being shown, or null until loaded. */
    val assignment: StateFlow<AssignmentEntity?> = _assignment.asStateFlow()

    private val _location = MutableStateFlow<LocationEntity?>(null)

    /** The assignment's location, or null until loaded/unresolved. */
    val location: StateFlow<LocationEntity?> = _location.asStateFlow()

    private val _sessions = MutableStateFlow<List<SessionEntity>>(emptyList())

    /** Sessions recorded against this assignment. */
    val sessions: StateFlow<List<SessionEntity>> = _sessions.asStateFlow()

    /** Whether the delete-confirmation dialog is currently shown. */
    val showDeleteDialog = MutableStateFlow(false)

    init {
        loadAssignment()
    }

    private fun loadAssignment() {
        viewModelScope.launch {
            assignmentRepository.getAssignmentByIdFlow(assignmentId).collect { assignment ->
                _assignment.value = assignment
                if (assignment != null) {
                    loadLocation(assignment.locationId)
                    loadSessions()
                }
            }
        }
    }

    private fun loadLocation(locationId: String) {
        viewModelScope.launch {
            locationRepository.getLocationByIdFlow(locationId).collect { location ->
                _location.value = location
            }
        }
    }

    private fun loadSessions() {
        viewModelScope.launch {
            sessionRepository.getSessionsForAssignment(assignmentId).collect { sessions ->
                _sessions.value = sessions
            }
        }
    }

    /** Deletes the currently loaded assignment by its id. */
    fun deleteAssignment() {
        viewModelScope.launch {
            assignmentRepository.deleteAssignmentById(assignmentId)
        }
    }
}
