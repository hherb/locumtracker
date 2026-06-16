package com.hherb.locumtracker.ui.screens.assignments

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Renders the form for editing an existing assignment, pre-filled from its current values.
 *
 * @param assignmentId id of the assignment being edited.
 * @param onBack invoked when the user navigates back without saving.
 * @param onAssignmentUpdated invoked after the save action is triggered.
 * @param viewModel loads the assignment and locations and persists updates.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EditAssignmentScreen(
    assignmentId: String,
    onBack: () -> Unit,
    onAssignmentUpdated: () -> Unit,
    viewModel: EditAssignmentViewModel = hiltViewModel()
) {
    val assignment by viewModel.assignment.collectAsStateWithLifecycle()
    val locations by viewModel.locations.collectAsStateWithLifecycle()
    val isSaving by viewModel.isSaving.collectAsStateWithLifecycle()

    // Form state
    var name by remember(assignment) { mutableStateOf(assignment?.name ?: "") }
    var selectedLocationId by remember(assignment) { mutableStateOf(assignment?.locationId) }
    var rateStructure by remember(assignment) { mutableStateOf(assignment?.rateStructure ?: "daily_rate") }
    var dailyRate by remember(assignment) { mutableStateOf(assignment?.dailyRate?.toString() ?: "") }
    var hourlyRate by remember(assignment) { mutableStateOf(assignment?.hourlyRate?.toString() ?: "") }
    var onCallRate by remember(assignment) { mutableStateOf(assignment?.onCallRate?.toString() ?: "") }
    var callOutRate by remember(assignment) { mutableStateOf(assignment?.callOutRate?.toString() ?: "") }
    var status by remember(assignment) { mutableStateOf(assignment?.status ?: "planned") }
    var startDate by remember(assignment) { mutableStateOf(assignment?.startDate ?: System.currentTimeMillis()) }
    var endDate by remember(assignment) { mutableStateOf(assignment?.endDate ?: System.currentTimeMillis()) }

    // Date picker state
    var showStartDatePicker by remember { mutableStateOf(false) }
    var showEndDatePicker by remember { mutableStateOf(false) }
    var showLocationPicker by remember { mutableStateOf(false) }

    val dateFormat = remember { SimpleDateFormat("dd MMM yyyy", Locale.getDefault()) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Edit Assignment") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { padding ->
        if (assignment == null) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator()
            }
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // Assignment name
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("Assignment Name (optional)") },
                    modifier = Modifier.fillMaxWidth()
                )

                // Location selector
                OutlinedTextField(
                    value = locations.find { it.id == selectedLocationId }?.name ?: "",
                    onValueChange = {},
                    label = { Text("Location") },
                    modifier = Modifier.fillMaxWidth(),
                    readOnly = true,
                    trailingIcon = {
                        IconButton(onClick = { showLocationPicker = true }) {
                            Icon(Icons.Default.DateRange, contentDescription = "Select Location")
                        }
                    }
                )

                // Status
                Text(
                    text = "Status",
                    style = MaterialTheme.typography.titleMedium
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    listOf("planned", "active", "completed", "cancelled").forEach { s ->
                        FilterChip(
                            selected = status == s,
                            onClick = { status = s },
                            label = { Text(s.replaceFirstChar { it.uppercase() }) }
                        )
                    }
                }

                // Rate structure
                Text(
                    text = "Rate Structure",
                    style = MaterialTheme.typography.titleMedium
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    FilterChip(
                        selected = rateStructure == "daily_rate",
                        onClick = { rateStructure = "daily_rate" },
                        label = { Text("Daily Rate") }
                    )
                    FilterChip(
                        selected = rateStructure == "hourly_rate",
                        onClick = { rateStructure = "hourly_rate" },
                        label = { Text("Hourly Rate") }
                    )
                }

                // Rate inputs
                if (rateStructure == "daily_rate") {
                    OutlinedTextField(
                        value = dailyRate,
                        onValueChange = { dailyRate = it.filter { c -> c.isDigit() || c == '.' } },
                        label = { Text("Daily Rate ($)") },
                        modifier = Modifier.fillMaxWidth(),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal)
                    )
                } else {
                    OutlinedTextField(
                        value = hourlyRate,
                        onValueChange = { hourlyRate = it.filter { c -> c.isDigit() || c == '.' } },
                        label = { Text("Hourly Rate ($/hr)") },
                        modifier = Modifier.fillMaxWidth(),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal)
                    )

                    OutlinedTextField(
                        value = onCallRate,
                        onValueChange = { onCallRate = it.filter { c -> c.isDigit() || c == '.' } },
                        label = { Text("On-Call Rate ($/hr, optional)") },
                        modifier = Modifier.fillMaxWidth(),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal)
                    )

                    OutlinedTextField(
                        value = callOutRate,
                        onValueChange = { callOutRate = it.filter { c -> c.isDigit() || c == '.' } },
                        label = { Text("Call-Out Rate ($/hr, optional)") },
                        modifier = Modifier.fillMaxWidth(),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal)
                    )
                }

                // Date range
                Text(
                    text = "Schedule",
                    style = MaterialTheme.typography.titleMedium
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    OutlinedTextField(
                        value = dateFormat.format(Date(startDate)),
                        onValueChange = {},
                        label = { Text("Start Date") },
                        modifier = Modifier.weight(1f),
                        readOnly = true,
                        trailingIcon = {
                            IconButton(onClick = { showStartDatePicker = true }) {
                                Icon(Icons.Default.DateRange, contentDescription = "Select Start Date")
                            }
                        }
                    )

                    OutlinedTextField(
                        value = dateFormat.format(Date(endDate)),
                        onValueChange = {},
                        label = { Text("End Date") },
                        modifier = Modifier.weight(1f),
                        readOnly = true,
                        trailingIcon = {
                            IconButton(onClick = { showEndDatePicker = true }) {
                                Icon(Icons.Default.DateRange, contentDescription = "Select End Date")
                            }
                        }
                    )
                }

                // Save button
                Button(
                    onClick = {
                        viewModel.updateAssignment(
                            name = name.ifBlank { null },
                            locationId = selectedLocationId ?: "",
                            rateStructure = rateStructure,
                            dailyRate = dailyRate.toDoubleOrNull(),
                            hourlyRate = hourlyRate.toDoubleOrNull(),
                            onCallRate = onCallRate.toDoubleOrNull(),
                            callOutRate = callOutRate.toDoubleOrNull(),
                            status = status,
                            startDate = startDate,
                            endDate = endDate
                        )
                        onAssignmentUpdated()
                    },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = !isSaving && selectedLocationId != null
                ) {
                    if (isSaving) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(24.dp),
                            color = MaterialTheme.colorScheme.onPrimary
                        )
                    } else {
                        Text("Save Changes")
                    }
                }
            }
        }
    }

    // Start date picker
    if (showStartDatePicker) {
        val datePickerState = rememberDatePickerState(initialSelectedDateMillis = startDate)
        DatePickerDialog(
            onDismissRequest = { showStartDatePicker = false },
            confirmButton = {
                TextButton(
                    onClick = {
                        datePickerState.selectedDateMillis?.let { startDate = it }
                        showStartDatePicker = false
                    }
                ) {
                    Text("OK")
                }
            },
            dismissButton = {
                TextButton(onClick = { showStartDatePicker = false }) {
                    Text("Cancel")
                }
            }
        ) {
            DatePicker(state = datePickerState)
        }
    }

    // End date picker
    if (showEndDatePicker) {
        val datePickerState = rememberDatePickerState(initialSelectedDateMillis = endDate)
        DatePickerDialog(
            onDismissRequest = { showEndDatePicker = false },
            confirmButton = {
                TextButton(
                    onClick = {
                        datePickerState.selectedDateMillis?.let { endDate = it }
                        showEndDatePicker = false
                    }
                ) {
                    Text("OK")
                }
            },
            dismissButton = {
                TextButton(onClick = { showEndDatePicker = false }) {
                    Text("Cancel")
                }
            }
        ) {
            DatePicker(state = datePickerState)
        }
    }

    // Location picker dialog
    if (showLocationPicker) {
        AlertDialog(
            onDismissRequest = { showLocationPicker = false },
            title = { Text("Select Location") },
            text = {
                Column {
                    locations.forEach { location ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            RadioButton(
                                selected = selectedLocationId == location.id,
                                onClick = {
                                    selectedLocationId = location.id
                                    showLocationPicker = false
                                }
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Column {
                                Text(
                                    text = location.name,
                                    style = MaterialTheme.typography.bodyLarge
                                )
                                Text(
                                    text = location.mmmClassificationDescription,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { showLocationPicker = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}
