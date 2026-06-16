package com.hherb.locumtracker.ui.screens.assignments

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.hherb.locumtracker.data.database.entity.AssignmentEntity
import com.hherb.locumtracker.data.database.entity.LocationEntity
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Renders the list of the doctor's assignments, or an empty-state prompt when none exist.
 *
 * @param onAssignmentClick invoked with the tapped assignment's id to open its detail screen.
 * @param onAddAssignment invoked when the user taps the add (+) action.
 * @param viewModel supplies the assignments-with-locations list.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AssignmentsScreen(
    onAssignmentClick: (String) -> Unit,
    onAddAssignment: () -> Unit,
    viewModel: AssignmentsViewModel = hiltViewModel()
) {
    val assignmentsWithLocations by viewModel.assignmentsWithLocations.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Assignments") },
                actions = {
                    IconButton(onClick = onAddAssignment) {
                        Icon(Icons.Default.Add, contentDescription = "Add Assignment")
                    }
                }
            )
        }
    ) { padding ->
        if (assignmentsWithLocations.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    Icon(
                        Icons.Default.CalendarMonth,
                        contentDescription = null,
                        modifier = Modifier.size(64.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        text = "No Assignments Yet",
                        style = MaterialTheme.typography.headlineSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "Tap + to add your first assignment",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(assignmentsWithLocations) { item ->
                    AssignmentCard(
                        assignment = item.assignment,
                        location = item.location,
                        onClick = { onAssignmentClick(item.assignment.id) }
                    )
                }
            }
        }
    }
}

/**
 * Renders a single assignment summary card (location, status, MMM, rate type, date range).
 *
 * @param assignment the assignment to display.
 * @param location the assignment's location, or null if unresolved.
 * @param onClick invoked when the card is tapped.
 */
@Composable
fun AssignmentCard(
    assignment: AssignmentEntity,
    location: LocationEntity?,
    onClick: () -> Unit
) {
    val dateFormat = remember { SimpleDateFormat("dd MMM yyyy", Locale.getDefault()) }

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = location?.name ?: "Unknown Location",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
                StatusBadge(status = assignment.status)
            }

            Spacer(modifier = Modifier.height(8.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                if (location != null) {
                    MMMBadge(classification = location.mmmClassification)
                }
                Text(
                    text = if (assignment.rateStructure == "daily_rate") {
                        "Daily Rate"
                    } else {
                        "Hourly Rate"
                    },
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            Spacer(modifier = Modifier.height(4.dp))

            Text(
                text = "${dateFormat.format(Date(assignment.startDate))} - ${dateFormat.format(Date(assignment.endDate))}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

/**
 * Renders a coloured pill showing the assignment status (planned/active/completed/cancelled).
 *
 * @param status the assignment status key.
 */
@Composable
fun StatusBadge(status: String) {
    val color = when (status) {
        "planned" -> MaterialTheme.colorScheme.primary
        "active" -> Color(0xFF4CAF50)
        "completed" -> Color(0xFF9E9E9E)
        "cancelled" -> Color(0xFFF44336)
        else -> MaterialTheme.colorScheme.onSurface
    }

    val text = when (status) {
        "planned" -> "Planned"
        "active" -> "Active"
        "completed" -> "Completed"
        "cancelled" -> "Cancelled"
        else -> status
    }

    Surface(
        color = color.copy(alpha = 0.1f),
        shape = MaterialTheme.shapes.small
    ) {
        Text(
            text = text,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
            style = MaterialTheme.typography.labelSmall,
            color = color
        )
    }
}

/**
 * Renders a coloured pill showing the Modified Monash Model (MMM) classification.
 *
 * @param classification the MMM category (1-7); MMM3-7 are rural/remote (WIP-eligible).
 */
@Composable
fun MMMBadge(classification: Int) {
    val color = when (classification) {
        1, 2 -> Color(0xFF9E9E9E)
        3 -> MaterialTheme.colorScheme.primary
        4 -> Color(0xFF00BCD4)
        5 -> Color(0xFF009688)
        6 -> Color(0xFFFF9800)
        7 -> Color(0xFFF44336)
        else -> Color(0xFF9E9E9E)
    }

    Surface(
        color = color.copy(alpha = 0.1f),
        shape = MaterialTheme.shapes.small
    ) {
        Text(
            text = "MMM$classification",
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
            style = MaterialTheme.typography.labelSmall,
            color = color
        )
    }
}
