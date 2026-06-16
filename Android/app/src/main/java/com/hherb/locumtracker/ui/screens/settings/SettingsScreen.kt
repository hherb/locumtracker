package com.hherb.locumtracker.ui.screens.settings

import android.content.Intent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CloudDownload
import androidx.compose.material.icons.filled.CloudUpload
import androidx.compose.material.icons.filled.FileDownload
import androidx.compose.material.icons.filled.FileUpload
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.hherb.locumtracker.core.service.TaxService

/** Number of digits in a valid Australian Business Number (ABN). */
private const val ABN_LENGTH = 11

/**
 * Settings screen letting the user edit their profile and tax details, validate their ABN,
 * back up / restore via cloud sync, and export data as CSV or JSON.
 *
 * @param viewModel provides profile state, sync state and save/sync/export actions
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    viewModel: SettingsViewModel = hiltViewModel()
) {
    val context = LocalContext.current
    val profile by viewModel.profile.collectAsStateWithLifecycle()
    val syncState by viewModel.syncState.collectAsStateWithLifecycle()
    val isSyncing by viewModel.isSyncing.collectAsStateWithLifecycle()

    var firstName by remember(profile) { mutableStateOf(profile?.firstName ?: "") }
    var lastName by remember(profile) { mutableStateOf(profile?.lastName ?: "") }
    var email by remember(profile) { mutableStateOf(profile?.email ?: "") }
    var abn by remember(profile) { mutableStateOf(profile?.abn ?: "") }
    var isGstRegistered by remember(profile) { mutableStateOf(profile?.isGstRegistered ?: false) }

    val abnValidation = remember(abn) {
        when {
            abn.isEmpty() -> null
            abn.length < ABN_LENGTH -> "ABN must be 11 digits"
            !TaxService.validateAbn(abn) -> "Invalid ABN"
            else -> "Valid ABN"
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(title = { Text("Settings") })
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
            // Profile section
            Text(
                text = "Profile",
                style = MaterialTheme.typography.titleLarge
            )

            OutlinedTextField(
                value = firstName,
                onValueChange = { firstName = it },
                label = { Text("First Name") },
                modifier = Modifier.fillMaxWidth()
            )

            OutlinedTextField(
                value = lastName,
                onValueChange = { lastName = it },
                label = { Text("Last Name") },
                modifier = Modifier.fillMaxWidth()
            )

            OutlinedTextField(
                value = email,
                onValueChange = { email = it },
                label = { Text("Email") },
                modifier = Modifier.fillMaxWidth(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email)
            )

            Divider()

            // Business section
            Text(
                text = "Business & Tax",
                style = MaterialTheme.typography.titleLarge
            )

            OutlinedTextField(
                value = abn,
                onValueChange = { abn = it.filter { c -> c.isDigit() }.take(ABN_LENGTH) },
                label = { Text("ABN") },
                modifier = Modifier.fillMaxWidth(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                supportingText = abnValidation?.let { validation ->
                    {
                        Text(
                            text = validation,
                            color = when (validation) {
                                "Valid ABN" -> MaterialTheme.colorScheme.primary
                                else -> MaterialTheme.colorScheme.error
                            }
                        )
                    }
                }
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "GST Registered",
                        style = MaterialTheme.typography.bodyLarge
                    )
                    Text(
                        text = "Enable GST calculations",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                Switch(
                    checked = isGstRegistered,
                    onCheckedChange = { isGstRegistered = it }
                )
            }

            Divider()

            // Cloud Sync section
            Text(
                text = "Cloud Sync",
                style = MaterialTheme.typography.titleLarge
            )

            Text(
                text = syncState,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Button(
                    onClick = { viewModel.syncToCloud() },
                    modifier = Modifier.weight(1f),
                    enabled = !isSyncing
                ) {
                    Icon(Icons.Default.CloudUpload, contentDescription = null)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Backup")
                }

                OutlinedButton(
                    onClick = { viewModel.syncFromCloud() },
                    modifier = Modifier.weight(1f),
                    enabled = !isSyncing
                ) {
                    Icon(Icons.Default.CloudDownload, contentDescription = null)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Restore")
                }
            }

            Divider()

            // Export section
            Text(
                text = "Export Data",
                style = MaterialTheme.typography.titleLarge
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Button(
                    onClick = {
                        viewModel.exportData(format = "csv") { uri ->
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = "text/csv"
                                putExtra(Intent.EXTRA_STREAM, uri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            context.startActivity(Intent.createChooser(intent, "Export CSV"))
                        }
                    },
                    modifier = Modifier.weight(1f)
                ) {
                    Icon(Icons.Default.FileUpload, contentDescription = null)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("CSV")
                }

                OutlinedButton(
                    onClick = {
                        viewModel.exportData(format = "json") { uri ->
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = "application/json"
                                putExtra(Intent.EXTRA_STREAM, uri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            context.startActivity(Intent.createChooser(intent, "Export JSON"))
                        }
                    },
                    modifier = Modifier.weight(1f)
                ) {
                    Icon(Icons.Default.FileDownload, contentDescription = null)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("JSON")
                }
            }

            Divider()

            // Save button
            Button(
                onClick = {
                    viewModel.saveProfile(
                        firstName = firstName,
                        lastName = lastName,
                        email = email.ifBlank { null },
                        abn = abn.ifBlank { null },
                        isGstRegistered = isGstRegistered
                    )
                },
                modifier = Modifier.fillMaxWidth(),
                enabled = firstName.isNotBlank() && lastName.isNotBlank()
            ) {
                Text("Save Profile")
            }

            if (isSyncing) {
                LinearProgressIndicator(
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }
    }
}
