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
import java.util.Calendar
import java.util.UUID
import javax.inject.Inject

/**
 * Backs [AddSessionScreen]: loads the parent assignment and persists a newly entered
 * session (creating its daily record as needed), keyed by the `assignmentId` argument.
 */
@HiltViewModel
class AddSessionViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val sessionRepository: SessionRepository,
    private val assignmentRepository: AssignmentRepository
) : ViewModel() {

    private val assignmentId: String = savedStateHandle["assignmentId"] ?: ""

    private val _assignment = MutableStateFlow<AssignmentEntity?>(null)
    /** The assignment the new session will be attached to, or null until loaded. */
    val assignment: StateFlow<AssignmentEntity?> = _assignment.asStateFlow()

    /** True while a session is being persisted; drives the save button's progress state. */
    val isSaving = MutableStateFlow(false)

    init {
        loadAssignment()
    }

    private fun loadAssignment() {
        viewModelScope.launch {
            assignmentRepository.getAssignmentByIdFlow(assignmentId).collect { assignment ->
                _assignment.value = assignment
            }
        }
    }

    /**
     * Builds and persists a new session for [date], computing absolute start/end times
     * from the supplied hour/minute components, and updates the saving state.
     *
     * @param date day of the session as epoch millis (time component ignored).
     * @param startHour start hour of day (0-23).
     * @param startMinute start minute (0-59).
     * @param endHour end hour of day (0-23).
     * @param endMinute end minute (0-59).
     * @param sessionType session category (regular, on_call, call_out).
     * @param mmmClassification Modified Monash Model remoteness band (1-7).
     * @param travelTime optional travel time in seconds, or null.
     * @param notes optional free-text notes, or null.
     */
    fun addSession(
        date: Long,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        sessionType: String,
        mmmClassification: Int,
        travelTime: Double?,
        notes: String?
    ) {
        viewModelScope.launch {
            isSaving.value = true

            try {
                // Get or create daily record for this date
                val dailyRecord = sessionRepository.getOrCreateDailyRecord(assignmentId, date)

                // Calculate start and end times
                val calendar = Calendar.getInstance().apply {
                    timeInMillis = date
                    set(Calendar.HOUR_OF_DAY, startHour)
                    set(Calendar.MINUTE, startMinute)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }
                val startTime = calendar.timeInMillis

                calendar.set(Calendar.HOUR_OF_DAY, endHour)
                calendar.set(Calendar.MINUTE, endMinute)
                val endTime = calendar.timeInMillis

                // Create session
                val session = SessionEntity(
                    id = UUID.randomUUID().toString(),
                    dailyRecordId = dailyRecord.id,
                    startTime = startTime,
                    endTime = endTime,
                    sessionType = sessionType,
                    mmmClassification = mmmClassification,
                    travelTime = travelTime,
                    subsidyAmount = null,
                    notes = notes,
                    locationId = null,
                    providerLocationId = null,
                    createdAt = System.currentTimeMillis(),
                    updatedAt = System.currentTimeMillis()
                )

                sessionRepository.insertSession(session)

                // Update daily record earnings
                val sessions = sessionRepository.getSessionsForDailyRecord(dailyRecord.id)
                // Note: In production, you'd calculate earnings here

                isSaving.value = false
            } catch (e: Exception) {
                isSaving.value = false
            }
        }
    }
}
