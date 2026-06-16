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

/** Default MMM classification pre-selected for a new location. */
private const val DEFAULT_MMM_CLASSIFICATION = 3

/** Lowest selectable MMM classification (metropolitan). */
private const val MIN_MMM = 1

/** Highest selectable MMM classification (most remote). */
private const val MAX_MMM = 7

/**
 * Form screen for creating a new work location: basic details, MMM classification,
 * notes and optional default rates.
 *
 * @param onBack invoked when back navigation is tapped.
 * @param onLocationAdded invoked after the save action submits the location.
 * @param viewModel performs persistence and exposes the saving state.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddLocationScreen(
    onBack: () -> Unit,
    onLocationAdded: () -> Unit,
    viewModel: AddLocationViewModel = hiltViewModel()
) {
    val isSaving by viewModel.isSaving.collectAsStateWithLifecycle()

    // Form state
    var name by remember { mutableStateOf("") }
    var address by remember { mutableStateOf("") }
    var phoneNumber by remember { mutableStateOf("") }
    var providerNumber by remember { mutableStateOf("") }
    var mmmClassification by remember { mutableStateOf("3") }
    var notes by remember { mutableStateOf("") }

    // Default rates
    var defaultDailyRate by remember { mutableStateOf("") }
    var defaultHourlyRate by remember { mutableStateOf("") }
    var defaultOnCallRate by remember { mutableStateOf("") }
    var defaultCallOutRate by remember { mutableStateOf("") }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Add Location") },
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
                    viewModel.addLocation(
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
                    onLocationAdded()
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
                    Text("Save Location")
                }
            }
        }
    }
}
