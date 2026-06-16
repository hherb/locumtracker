package com.hherb.locumtracker.ui.screens.earnings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.hherb.locumtracker.data.database.entity.AssignmentEntity
import com.hherb.locumtracker.data.database.entity.DailyRecordEntity
import com.hherb.locumtracker.data.database.entity.LocationEntity
import com.hherb.locumtracker.data.repository.AssignmentRepository
import com.hherb.locumtracker.data.repository.LocationRepository
import com.hherb.locumtracker.data.repository.SessionRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import javax.inject.Inject

/** Keep upstream flows active for this many milliseconds after the last subscriber stops. */
private const val SUBSCRIPTION_TIMEOUT_MS = 5000L

/**
 * ViewModel backing the earnings screen. Aggregates daily records into a total earnings figure
 * and a per-location earnings breakdown.
 */
@HiltViewModel
class EarningsViewModel @Inject constructor(
    private val sessionRepository: SessionRepository,
    private val assignmentRepository: AssignmentRepository,
    private val locationRepository: LocationRepository
) : ViewModel() {

    private val _dailyRecords = MutableStateFlow<List<DailyRecordEntity>>(emptyList())
    /** All daily earnings records loaded from storage. */
    val dailyRecords: StateFlow<List<DailyRecordEntity>> = _dailyRecords.asStateFlow()

    private val _assignments = MutableStateFlow<Map<String, AssignmentEntity>>(emptyMap())
    /** Assignments keyed by id, used to resolve a record's location. */
    val assignments: StateFlow<Map<String, AssignmentEntity>> = _assignments.asStateFlow()

    private val _locations = MutableStateFlow<Map<String, LocationEntity>>(emptyMap())
    /** Locations keyed by id, used to label earnings by location. */
    val locations: StateFlow<Map<String, LocationEntity>> = _locations.asStateFlow()

    /** Sum of earnings across all daily records. */
    val totalEarnings: StateFlow<Double> = _dailyRecords.map { records ->
        records.sumOf { it.totalEarnings }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(SUBSCRIPTION_TIMEOUT_MS), 0.0)

    /** Earnings totalled per location name (records without a known location fall under "Unknown"). */
    val earningsByLocation: StateFlow<Map<String, Double>> = combine(
        _dailyRecords,
        _assignments,
        _locations
    ) { records, assignmentsMap, locationsMap ->
        val earningsByLocation = mutableMapOf<String, Double>()
        for (record in records) {
            val assignment = assignmentsMap[record.assignmentId]
            if (assignment != null) {
                val location = locationsMap[assignment.locationId]
                val locationName = location?.name ?: "Unknown"
                earningsByLocation[locationName] = (earningsByLocation[locationName] ?: 0.0) + record.totalEarnings
            }
        }
        earningsByLocation
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(SUBSCRIPTION_TIMEOUT_MS), emptyMap())

    init {
        loadData()
    }

    private fun loadData() {
        viewModelScope.launch {
            sessionRepository.getAllDailyRecords().collect { records ->
                _dailyRecords.value = records
            }
        }
        viewModelScope.launch {
            assignmentRepository.getAllAssignments().collect { assignments ->
                _assignments.value = assignments.associateBy { it.id }
            }
        }
        viewModelScope.launch {
            locationRepository.getAllLocations().collect { locations ->
                _locations.value = locations.associateBy { it.id }
            }
        }
    }
}
