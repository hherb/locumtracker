package com.hherb.locumtracker.ui.screens.sessions

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.hherb.locumtracker.data.database.entity.AssignmentEntity
import com.hherb.locumtracker.data.database.entity.DailyRecordEntity
import com.hherb.locumtracker.data.database.entity.SessionEntity
import com.hherb.locumtracker.data.repository.AssignmentRepository
import com.hherb.locumtracker.data.repository.SessionRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Provides the sessions, daily records and parent assignment for [SessionListScreen],
 * keyed by the `assignmentId` saved-state argument.
 */
@HiltViewModel
class SessionListViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val sessionRepository: SessionRepository,
    private val assignmentRepository: AssignmentRepository
) : ViewModel() {

    private val assignmentId: String = savedStateHandle["assignmentId"] ?: ""

    private val _sessions = MutableStateFlow<List<SessionEntity>>(emptyList())
    /** Sessions belonging to the current assignment. */
    val sessions: StateFlow<List<SessionEntity>> = _sessions.asStateFlow()

    private val _dailyRecords = MutableStateFlow<List<DailyRecordEntity>>(emptyList())
    /** Daily records aggregating the assignment's sessions. */
    val dailyRecords: StateFlow<List<DailyRecordEntity>> = _dailyRecords.asStateFlow()

    private val _assignment = MutableStateFlow<AssignmentEntity?>(null)
    /** The assignment these sessions belong to, or null until loaded. */
    val assignment: StateFlow<AssignmentEntity?> = _assignment.asStateFlow()

    init {
        loadSessions()
        loadAssignment()
    }

    private fun loadSessions() {
        viewModelScope.launch {
            sessionRepository.getSessionsForAssignment(assignmentId).collect { sessions ->
                _sessions.value = sessions
            }
        }
    }

    private fun loadAssignment() {
        viewModelScope.launch {
            assignmentRepository.getAssignmentByIdFlow(assignmentId).collect { assignment ->
                _assignment.value = assignment
            }
        }
    }
}
