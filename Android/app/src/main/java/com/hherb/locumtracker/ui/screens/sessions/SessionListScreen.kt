package com.hherb.locumtracker.ui.screens.sessions

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Minimum MMM classification (rural/remote) that qualifies for a WIP FPS subsidy badge. */
private const val MIN_RURAL_SUBSIDY_MMM = 3

/**
 * Screen listing all work sessions for an assignment, grouped by daily record, with a
 * summary header of total sessions and hours.
 *
 * @param assignmentId id of the assignment whose sessions are shown.
 * @param onBack invoked when the back navigation icon is tapped.
 * @param onAddSession invoked when the add-session action is tapped.
 * @param viewModel supplies the sessions, daily records and assignment state.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SessionListScreen(
    assignmentId: String,
    onBack: () -> Unit,
    onAddSession: () -> Unit,
    viewModel: SessionListViewModel = hiltViewModel()
) {
    val sessions by viewModel.sessions.collectAsStateWithLifecycle()
    val dailyRecords by viewModel.dailyRecords.collectAsStateWithLifecycle()
    val assignment by viewModel.assignment.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Sessions") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = onAddSession) {
                        Icon(Icons.Default.Add, contentDescription = "Add Session")
                    }
                }
            )
        }
    ) { padding ->
        if (sessions.isEmpty()) {
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
                    Text(
                        text = "No Sessions Yet",
                        style = MaterialTheme.typography.headlineSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "Tap + to add your first session",
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
                // Summary card
                item {
                    SummaryCard(
                        totalSessions = sessions.size,
                        totalHours = sessions.sumOf { it.durationHours }
                    )
                }

                // Sessions grouped by daily record
                val groupedSessions = sessions.groupBy { it.dailyRecordId }
                groupedSessions.forEach { (dailyRecordId, dailySessions) ->
                    item {
                        DailyRecordHeader(
                            date = dailySessions.firstOrNull()?.startTime,
                            sessionCount = dailySessions.size,
                            isOnCall = dailySessions.any { it.sessionType == "on_call" }
                        )
                    }
                    items(dailySessions) { session ->
                        SessionCard(session = session)
                    }
                }
            }
        }
    }
}

/** Card showing the aggregate session count and total hours for the assignment. */
@Composable
fun SummaryCard(totalSessions: Int, totalHours: Double) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.primaryContainer
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = "$totalSessions",
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onPrimaryContainer
                )
                Text(
                    text = "Sessions",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onPrimaryContainer
                )
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = "${String.format("%.1f", totalHours)}",
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onPrimaryContainer
                )
                Text(
                    text = "Hours",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onPrimaryContainer
                )
            }
        }
    }
}

/** Header row for a day's group of sessions: formatted date, on-call tag and session count. */
@Composable
fun DailyRecordHeader(date: Long?, sessionCount: Int, isOnCall: Boolean) {
    val dateFormat = remember { SimpleDateFormat("dd MMM yyyy", Locale.getDefault()) }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            if (date != null) {
                Text(
                    text = dateFormat.format(Date(date)),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
            }
            if (isOnCall) {
                Surface(
                    color = MaterialTheme.colorScheme.tertiaryContainer,
                    shape = MaterialTheme.shapes.small
                ) {
                    Text(
                        text = "On-Call",
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onTertiaryContainer
                    )
                }
            }
        }
        Text(
            text = "$sessionCount sessions",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

/** Card for a single session showing its type, time range, duration and MMM badge. */
@Composable
fun SessionCard(session: com.hherb.locumtracker.data.database.entity.SessionEntity) {
    val timeFormat = remember { SimpleDateFormat("HH:mm", Locale.getDefault()) }

    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Session type badge
            SessionTypeBadge(type = session.sessionType)

            Spacer(modifier = Modifier.width(12.dp))

            // Time and duration
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "${timeFormat.format(Date(session.startTime))} - ${timeFormat.format(Date(session.endTime))}",
                    style = MaterialTheme.typography.bodyMedium
                )
                Text(
                    text = session.durationFormatted,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            // MMM classification
            if (session.mmmClassification >= MIN_RURAL_SUBSIDY_MMM) {
                MMMBadgeSmall(classification = session.mmmClassification)
            }
        }
    }
}

/** Small coloured badge labelling a session type (regular, on-call, call-out). */
@Composable
fun SessionTypeBadge(type: String) {
    val (text, color) = when (type) {
        "regular" -> "Regular" to MaterialTheme.colorScheme.primary
        "on_call" -> "On-Call" to MaterialTheme.colorScheme.tertiary
        "call_out" -> "Call-Out" to MaterialTheme.colorScheme.error
        else -> type to MaterialTheme.colorScheme.onSurface
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

/** Compact MMM classification badge, colour-coded by remoteness level. */
@Composable
fun MMMBadgeSmall(classification: Int) {
    val color = when (classification) {
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
            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
            style = MaterialTheme.typography.labelSmall,
            color = color
        )
    }
}
