package com.hherb.locumtracker.ui.screens.locations

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle

/** Default MMM classification used when a location has none set. */
private const val DEFAULT_MMM_CLASSIFICATION = 3

/** Lowest selectable MMM classification (metropolitan). */
private const val MIN_MMM = 1

/** Highest selectable MMM classification (most remote). */
private const val MAX_MMM = 7

/**
 * Form screen for editing an existing location, pre-populated from the loaded entity;
 * shows a loading spinner until the location is available.
 *
 * @param locationId id of the location being edited.
 * @param onBack invoked when back navigation is tapped.
 * @param onLocationUpdated invoked after the save action submits the changes.
 * @param viewModel supplies the location and persists updates.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EditLocationScreen(
    locationId: String,
    onBack: () -> Unit,
    onLocationUpdated: () -> Unit,
    viewModel: EditLocationViewModel = hiltViewModel()
) {
    val location by viewModel.location.collectAsStateWithLifecycle()
    val isSaving by viewModel.isSaving.collectAsStateWithLifecycle()

    // Form state
    var name by remember(location) { mutableStateOf(location?.name ?: "") }
    var address by remember(location) { mutableStateOf(location?.address ?: "") }
    var phoneNumber by remember(location) { mutableStateOf(location?.phoneNumber ?: "") }
    var providerNumber by remember(location) { mutableStateOf(location?.providerNumber ?: "") }
    var mmmClassification by remember(location) { mutableStateOf(location?.mmmClassification?.toString() ?: "3") }
    var notes by remember(location) { mutableStateOf(location?.notes ?: "") }

    // Default rates
    var defaultDailyRate by remember(location) { mutableStateOf(location?.defaultDailyRate?.toString() ?: "") }
    var defaultHourlyRate by remember(location) { mutableStateOf(location?.defaultHourlyRate?.toString() ?: "") }
    var defaultOnCallRate by remember(location) { mutableStateOf(location?.defaultOnCallRate?.toString() ?: "") }
    var defaultCallOutRate by remember(location) { mutableStateOf(location?.defaultCallOutRate?.toString() ?: "") }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Edit Location") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { padding ->
        if (location == null) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
                contentAlignment = androidx.compose.ui.Alignment.Center
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
                // Basic info
                Text(
                    text = "Basic Information",
                    style = MaterialTheme.typography.titleMedium
                )

                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("Location Name") },
                    modifier = Modifier.fillMaxWidth()
                )

                OutlinedTextField(
                    value = address,
                    onValueChange = { address = it },
                    label = { Text("Address") },
                    modifier = Modifier.fillMaxWidth()
                )

                OutlinedTextField(
                    value = phoneNumber,
                    onValueChange = { phoneNumber = it },
                    label = { Text("Phone Number (optional)") },
                    modifier = Modifier.fillMaxWidth(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone)
                )

                OutlinedTextField(
                    value = providerNumber,
                    onValueChange = { providerNumber = it },
                    label = { Text("Provider Number (optional)") },
                    modifier = Modifier.fillMaxWidth()
                )

                // MMM Classification
                Text(
                    text = "MMM Classification",
                    style = MaterialTheme.typography.titleMedium
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    for (i in MIN_MMM..MAX_MMM) {
                        FilterChip(
                            selected = mmmClassification == "$i",
                            onClick = { mmmClassification = "$i" },
                            label = { Text("MMM$i") }
                        )
                    }
                }

                // Notes
                OutlinedTextField(
                    value = notes,
                    onValueChange = { notes = it },
                    label = { Text("Notes (optional)") },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 2
                )

                Divider()

                // Default rates
                Text(
                    text = "Default Rates (optional)",
                    style = MaterialTheme.typography.titleMedium
                )

                OutlinedTextField(
                    value = defaultDailyRate,
                    onValueChange = { defaultDailyRate = it.filter { c -> c.isDigit() || c == '.' } },
                    label = { Text("Default Daily Rate ($)") },
                    modifier = Modifier.fillMaxWidth(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal)
                )

                OutlinedTextField(
                    value = defaultHourlyRate,
                    onValueChange = { defaultHourlyRate = it.filter { c -> c.isDigit() || c == '.' } },
                    label = { Text("Default Hourly Rate ($/hr)") },
                    modifier = Modifier.fillMaxWidth(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal)
                )

                OutlinedTextField(
                    value = defaultOnCallRate,
                    onValueChange = { defaultOnCallRate = it.filter { c -> c.isDigit() || c == '.' } },
                    label = { Text("Default On-Call Rate ($/hr)") },
                    modifier = Modifier.fillMaxWidth(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal)
                )

                OutlinedTextField(
                    value = defaultCallOutRate,
                    onValueChange = { defaultCallOutRate = it.filter { c -> c.isDigit() || c == '.' } },
                    label = { Text("Default Call-Out Rate ($/hr)") },
                    modifier = Modifier.fillMaxWidth(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal)
                )

                // Save button
                Button(
                    onClick = {
                        viewModel.updateLocation(
                            name = name,
                            address = address,
                            phoneNumber = phoneNumber.ifBlank { null },
                            providerNumber = providerNumber.ifBlank { null },
                            mmmClassification = mmmClassification.toIntOrNull() ?: DEFAULT_MMM_CLASSIFICATION,
                            notes = notes.ifBlank { null },
                            defaultDailyRate = defaultDailyRate.toDoubleOrNull(),
                            defaultHourlyRate = defaultHourlyRate.toDoubleOrNull(),
                            defaultOnCallRate = defaultOnCallRate.toDoubleOrNull(),
                            defaultCallOutRate = defaultCallOutRate.toDoubleOrNull()
                        )
                        onLocationUpdated()
                    },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = !isSaving && name.isNotBlank() && address.isNotBlank()
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
}
