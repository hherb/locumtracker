package com.hherb.locumtracker.ui.screens.settings

import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.hherb.locumtracker.data.database.entity.LocumProfileEntity
import com.hherb.locumtracker.data.export.ExportService
import com.hherb.locumtracker.data.repository.*
import com.hherb.locumtracker.data.sync.SyncManager
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * ViewModel backing the settings screen. Loads and persists the locum profile, exposes
 * cloud-sync status, and orchestrates cloud backup/restore and data export.
 */
@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val profileRepository: ProfileRepository,
    private val syncManager: SyncManager,
    private val exportService: ExportService,
    private val receiptRepository: ReceiptRepository,
    private val assignmentRepository: AssignmentRepository,
    private val locationRepository: LocationRepository
) : ViewModel() {

    private val _profile = MutableStateFlow<LocumProfileEntity?>(null)
    /** The current locum profile, or null if none has been saved yet. */
    val profile: StateFlow<LocumProfileEntity?> = _profile.asStateFlow()

    private val _syncState = MutableStateFlow("Not signed in")
    /** Human-readable description of the latest cloud-sync state. */
    val syncState: StateFlow<String> = _syncState.asStateFlow()

    /** True while a cloud backup or restore is in progress. */
    val isSyncing = MutableStateFlow(false)

    init {
        loadProfile()
        updateSyncState()
    }

    private fun loadProfile() {
        viewModelScope.launch {
            profileRepository.getProfile().collect { profile ->
                _profile.value = profile
            }
        }
    }

    private fun updateSyncState() {
        _syncState.value = if (syncManager.isSignedIn) {
            "Signed in to Firebase"
        } else {
            "Not signed in"
        }
    }

    /**
     * Saves the profile, updating the existing record if present or inserting a new one.
     *
     * @param firstName practitioner's first name
     * @param lastName practitioner's last name
     * @param email optional contact email
     * @param abn optional Australian Business Number
     * @param isGstRegistered whether the practitioner is registered for GST
     */
    fun saveProfile(
        firstName: String,
        lastName: String,
        email: String?,
        abn: String?,
        isGstRegistered: Boolean
    ) {
        viewModelScope.launch {
            val existing = _profile.value
            if (existing != null) {
                profileRepository.updateProfile(
                    existing.copy(
                        firstName = firstName,
                        lastName = lastName,
                        email = email,
                        abn = abn,
                        isGstRegistered = isGstRegistered,
                        updatedAt = System.currentTimeMillis()
                    )
                )
            } else {
                profileRepository.insertProfile(
                    LocumProfileEntity(
                        id = java.util.UUID.randomUUID().toString(),
                        title = null,
                        firstName = firstName,
                        lastName = lastName,
                        email = email,
                        streetAddress = null,
                        suburb = null,
                        state = null,
                        postcode = null,
                        businessStructure = null,
                        abn = abn,
                        isGstRegistered = isGstRegistered,
                        isVocationalRegister = false,
                        providerNumber = null,
                        specialty = null,
                        defaultDailyRate = null,
                        defaultHourlyRate = null,
                        defaultOnCallRate = null,
                        defaultCallOutRate = null,
                        createdAt = System.currentTimeMillis(),
                        updatedAt = System.currentTimeMillis()
                    )
                )
            }
        }
    }

    /** Backs up local data to the cloud and updates [syncState] with the outcome. */
    fun syncToCloud() {
        viewModelScope.launch {
            isSyncing.value = true
            _syncState.value = "Syncing to cloud..."

            val result = syncManager.syncToCloud()

            _syncState.value = if (result.success) {
                "Last backup: ${java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date(result.timestamp))}"
            } else {
                "Backup failed: ${result.message}"
            }

            isSyncing.value = false
        }
    }

    /** Restores data from the cloud and updates [syncState] with the outcome. */
    fun syncFromCloud() {
        viewModelScope.launch {
            isSyncing.value = true
            _syncState.value = "Restoring from cloud..."

            val result = syncManager.syncFromCloud()

            _syncState.value = if (result.success) {
                "Last restore: ${java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date(result.timestamp))}"
            } else {
                "Restore failed: ${result.message}"
            }

            isSyncing.value = false
        }
    }

    /**
     * Exports earnings data to a file and delivers its URI when ready.
     *
     * @param format export format, either "csv" or "json"
     * @param onFileReady invoked with the resulting file's [Uri] on success
     */
    fun exportData(format: String, onFileReady: (Uri) -> Unit) {
        viewModelScope.launch {
            try {
                val receipts = receiptRepository.getAllReceipts().first()
                val assignments = assignmentRepository.getAllAssignments().first().associateBy { it.id }
                val locations = locationRepository.getAllLocations().first().associateBy { it.id }

                val uri = when (format) {
                    "csv" -> exportService.exportEarningsCSV(receipts, assignments, locations)
                    "json" -> exportService.exportEarningsJSON(receipts, assignments, locations)
                    else -> null
                }

                uri?.let { onFileReady(it) }
            } catch (e: Exception) {
                // Handle export error
            }
        }
    }
}
