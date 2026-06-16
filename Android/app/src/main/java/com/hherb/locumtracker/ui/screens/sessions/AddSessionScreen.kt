package com.hherb.locumtracker.ui.screens.sessions

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/** Default session start hour (08:00) pre-filled in the form. */
private const val DEFAULT_START_HOUR = 8

/** Default session start minute pre-filled in the form. */
private const val DEFAULT_START_MINUTE = 0

/** Default session end hour (16:00) pre-filled in the form. */
private const val DEFAULT_END_HOUR = 16

/** Default session end minute pre-filled in the form. */
private const val DEFAULT_END_MINUTE = 0

/** Default MMM classification (lowest rural/remote band) selected in the form. */
private const val DEFAULT_MMM_CLASSIFICATION = 3

/** Lowest selectable MMM classification for a session (rural/remote bands only). */
private const val MIN_SESSION_MMM = 3

/** Highest selectable MMM classification (most remote band). */
private const val MAX_SESSION_MMM = 7

/** Number of minutes in one hour, used to convert hour/minute pickers to total minutes. */
private const val MINUTES_PER_HOUR = 60

/** Number of seconds in one hour, used to convert travel time to seconds. */
private const val SECONDS_PER_HOUR = 3600

/** Number of seconds in one minute, used to convert travel time to seconds. */
private const val SECONDS_PER_MINUTE = 60

/**
 * Form screen for adding a work session to an assignment: date, start/end times,
 * session type, MMM classification, optional travel time and notes.
 *
 * @param assignmentId id of the assignment the new session is added to.
 * @param onBack invoked when back navigation is tapped.
 * @param onSessionAdded invoked after the save action submits the session.
 * @param viewModel performs persistence and exposes the saving state.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddSessionScreen(
    assignmentId: String,
    onBack: () -> Unit,
    onSessionAdded: () -> Unit,
    viewModel: AddSessionViewModel = hiltViewModel()
) {
    val assignment by viewModel.assignment.collectAsStateWithLifecycle()
    val isSaving by viewModel.isSaving.collectAsStateWithLifecycle()

    // Form state
    var selectedDate by remember { mutableStateOf(System.currentTimeMillis()) }
    var startHour by remember { mutableStateOf("8") }
    var startMinute by remember { mutableStateOf("0") }
    var endHour by remember { mutableStateOf("16") }
    var endMinute by remember { mutableStateOf("0") }
    var sessionType by remember { mutableStateOf("regular") }
    var mmmClassification by remember { mutableStateOf("3") }
    var travelTimeHours by remember { mutableStateOf("") }
    var travelTimeMinutes by remember { mutableStateOf("") }
    var notes by remember { mutableStateOf("") }

    // Date picker state
    var showDatePicker by remember { mutableStateOf(false) }

    val timeFormat = remember { SimpleDateFormat("HH:mm", Locale.getDefault()) }
    val dateFormat = remember { SimpleDateFormat("dd MMM yyyy", Locale.getDefault()) }

    // Calculate duration
    val duration = remember(startHour, startMinute, endHour, endMinute) {
        try {
            val start = (startHour.toIntOrNull() ?: 0) * MINUTES_PER_HOUR + (startMinute.toIntOrNull() ?: 0)
            val end = (endHour.toIntOrNull() ?: 0) * MINUTES_PER_HOUR + (endMinute.toIntOrNull() ?: 0)
            val durationMinutes = if (end > start) end - start else 0
            val hours = durationMinutes / MINUTES_PER_HOUR
            val minutes = durationMinutes % MINUTES_PER_HOUR
            "${hours}h ${minutes}m"
        } catch (e: Exception) {
            "0h 0m"
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Add Session") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Date picker
            OutlinedTextField(
                value = dateFormat.format(Date(selectedDate)),
                onValueChange = {},
                label = { Text("Date") },
                modifier = Modifier.fillMaxWidth(),
                readOnly = true,
                trailingIcon = {
                    IconButton(onClick = { showDatePicker = true }) {
                        Icon(Icons.Default.DateRange, contentDescription = "Select Date")
                    }
                }
            )

            // Time inputs
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                OutlinedTextField(
                    value = startHour,
                    onValueChange = { startHour = it.filter { c -> c.isDigit() }.take(2) },
                    label = { Text("Start Hour") },
                    modifier = Modifier.weight(1f),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number)
                )
                OutlinedTextField(
                    value = startMinute,
                    onValueChange = { startMinute = it.filter { c -> c.isDigit() }.take(2) },
                    label = { Text("Start Minute") },
                    modifier = Modifier.weight(1f),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number)
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                OutlinedTextField(
                    value = endHour,
                    onValueChange = { endHour = it.filter { c -> c.isDigit() }.take(2) },
                    label = { Text("End Hour") },
                    modifier = Modifier.weight(1f),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number)
                )
                OutlinedTextField(
                    value = endMinute,
                    onValueChange = { endMinute = it.filter { c -> c.isDigit() }.take(2) },
                    label = { Text("End Minute") },
                    modifier = Modifier.weight(1f),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number)
                )
            }

            // Duration display
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant
                )
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Duration",
                        style = MaterialTheme.typography.bodyMedium
                    )
                    Text(
                        text = duration,
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.primary
                    )
                }
            }

            // Session type
            Text(
                text = "Session Type",
                style = MaterialTheme.typography.titleMedium
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                FilterChip(
                    selected = sessionType == "regular",
                    onClick = { sessionType = "regular" },
                    label = { Text("Regular") }
                )
                FilterChip(
                    selected = sessionType == "on_call",
                    onClick = { sessionType = "on_call" },
                    label = { Text("On-Call") }
                )
                FilterChip(
                    selected = sessionType == "call_out",
                    onClick = { sessionType = "call_out" },
                    label = { Text("Call-Out") }
                )
            }

            // MMM Classification
            Text(
                text = "MMM Classification",
                style = MaterialTheme.typography.titleMedium
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                for (i in MIN_SESSION_MMM..MAX_SESSION_MMM) {
                    FilterChip(
                        selected = mmmClassification == "$i",
                        onClick = { mmmClassification = "$i" },
                        label = { Text("MMM$i") }
                    )
                }
            }

            // Travel time
            Text(
                text = "Travel Time (optional)",
                style = MaterialTheme.typography.titleMedium
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                OutlinedTextField(
                    value = travelTimeHours,
                    onValueChange = { travelTimeHours = it.filter { c -> c.isDigit() }.take(2) },
                    label = { Text("Hours") },
                    modifier = Modifier.weight(1f),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number)
                )
                OutlinedTextField(
                    value = travelTimeMinutes,
                    onValueChange = { travelTimeMinutes = it.filter { c -> c.isDigit() }.take(2) },
                    label = { Text("Minutes") },
                    modifier = Modifier.weight(1f),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number)
                )
            }

            // Notes
            OutlinedTextField(
                value = notes,
                onValueChange = { notes = it },
                label = { Text("Notes (optional)") },
                modifier = Modifier.fillMaxWidth(),
                minLines = 2
            )

            // Save button
            Button(
                onClick = {
                    val travelTime = try {
                        val hours = travelTimeHours.toDoubleOrNull() ?: 0.0
                        val minutes = travelTimeMinutes.toDoubleOrNull() ?: 0.0
                        (hours * SECONDS_PER_HOUR + minutes * SECONDS_PER_MINUTE).takeIf { it > 0 }
                    } catch (e: Exception) {
                        null
                    }

                    viewModel.addSession(
                        date = selectedDate,
                        startHour = startHour.toIntOrNull() ?: DEFAULT_START_HOUR,
                        startMinute = startMinute.toIntOrNull() ?: DEFAULT_START_MINUTE,
                        endHour = endHour.toIntOrNull() ?: DEFAULT_END_HOUR,
                        endMinute = endMinute.toIntOrNull() ?: DEFAULT_END_MINUTE,
                        sessionType = sessionType,
                        mmmClassification = mmmClassification.toIntOrNull() ?: DEFAULT_MMM_CLASSIFICATION,
                        travelTime = travelTime,
                        notes = notes.ifBlank { null }
                    )
                    onSessionAdded()
                },
                modifier = Modifier.fillMaxWidth(),
                enabled = !isSaving
            ) {
                if (isSaving) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(24.dp),
                        color = MaterialTheme.colorScheme.onPrimary
                    )
                } else {
                    Text("Save Session")
                }
            }
        }
    }

    // Date picker dialog
    if (showDatePicker) {
        val datePickerState = rememberDatePickerState(initialSelectedDateMillis = selectedDate)
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(
                    onClick = {
                        datePickerState.selectedDateMillis?.let { selectedDate = it }
                        showDatePicker = false
                    }
                ) {
                    Text("OK")
                }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) {
                    Text("Cancel")
                }
            }
        ) {
            DatePicker(state = datePickerState)
        }
    }
}
