package com.hherb.locumtracker.ui.screens.quota

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.hherb.locumtracker.data.database.entity.QuarterlyQuotaEntity
import com.hherb.locumtracker.data.repository.ProfileRepository
import com.hherb.locumtracker.core.service.FPSQuarterService
import com.hherb.locumtracker.core.service.RuralSubsidyService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import javax.inject.Inject

/** Keep upstream flows active for this many milliseconds after the last subscriber stops. */
private const val SUBSCRIPTION_TIMEOUT_MS = 5000L

/** Session count at which the user is considered close to meeting the quarterly quota. */
private const val ALMOST_THERE_SESSIONS = 15

/** Session count at which the user is considered to be making steady progress. */
private const val ON_TRACK_SESSIONS = 7

/**
 * ViewModel backing the FPS quota screen. Loads the current quarterly quota and derives a
 * progress fraction and a human-readable status message from it, and can create a new quota.
 */
@HiltViewModel
class QuotaViewModel @Inject constructor(
    private val profileRepository: ProfileRepository
) : ViewModel() {

    private val _currentQuota = MutableStateFlow<QuarterlyQuotaEntity?>(null)
    /** The quota for the current quarter, or null if none has been created yet. */
    val currentQuota: StateFlow<QuarterlyQuotaEntity?> = _currentQuota.asStateFlow()

    /** All quarterly quotas on record. */
    val quotas: StateFlow<List<QuarterlyQuotaEntity>> = profileRepository.getAllQuotas()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(SUBSCRIPTION_TIMEOUT_MS), emptyList())

    /** Quota completion as a fraction in 0..1 derived from the current quota's session count. */
    val quotaProgress: StateFlow<Float> = _currentQuota.map { quota ->
        if (quota != null) {
            (quota.totalSessions.toFloat() / QuarterlyQuotaEntity::class.java.getField("MINIMUM_SESSIONS").getFloat(null)).coerceIn(0f, 1f)
        } else {
            0f
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(SUBSCRIPTION_TIMEOUT_MS), 0f)

    /** Human-readable status message describing how close the current quota is to being met. */
    val quotaStatus: StateFlow<String> = _currentQuota.map { quota ->
        when {
            quota == null -> "No quota data"
            quota.quotaMet -> "Quota Met!"
            quota.totalSessions >= ALMOST_THERE_SESSIONS -> "Almost there!"
            quota.totalSessions >= ON_TRACK_SESSIONS -> "On track"
            else -> "Keep going!"
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(SUBSCRIPTION_TIMEOUT_MS), "Loading...")

    init {
        loadCurrentQuota()
    }

    private fun loadCurrentQuota() {
        viewModelScope.launch {
            // For demo purposes, use a dummy practitioner ID
            val practitionerId = "default"
            val now = System.currentTimeMillis()
            val quota = profileRepository.getCurrentQuota(practitionerId, now)
            _currentQuota.value = quota
        }
    }

    /** Creates and persists a fresh, zeroed quota for the current FPS quarter. */
    fun createQuota() {
        viewModelScope.launch {
            val practitionerId = "default"
            val now = System.currentTimeMillis()
            val quarterStart = FPSQuarterService.getQuarterStartDate(
                kotlinx.datetime.Instant.fromEpochMilliseconds(now)
            ).toEpochMilliseconds()

            val newQuota = QuarterlyQuotaEntity(
                id = java.util.UUID.randomUUID().toString(),
                practitionerId = practitionerId,
                quarterStartDate = quarterStart,
                mmm3Sessions = 0,
                mmm4Sessions = 0,
                mmm5Sessions = 0,
                mmm6Sessions = 0,
                mmm7Sessions = 0,
                totalSessions = 0,
                quotaMet = false,
                lastUpdated = now
            )
            profileRepository.insertQuota(newQuota)
            _currentQuota.value = newQuota
        }
    }
}
