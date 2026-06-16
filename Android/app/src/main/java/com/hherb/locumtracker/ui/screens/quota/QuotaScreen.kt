package com.hherb.locumtracker.ui.screens.quota

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PieChart
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle

/** Minimum sessions required in a quarter for it to count as an active FPS quarter. */
private const val MINIMUM_SESSIONS_PER_QUARTER = 21

/** Session count at which the user is considered close to meeting the quarterly quota. */
private const val ALMOST_THERE_SESSIONS = 15

/** Progress fraction (0..1) at or above which the quota is fully met. */
private const val PROGRESS_COMPLETE = 1f

/** Progress fraction threshold for the "good progress" (primary color) band. */
private const val PROGRESS_GOOD = 0.7f

/** Progress fraction threshold for the "moderate progress" (amber) band. */
private const val PROGRESS_MODERATE = 0.4f

/**
 * FPS quota screen showing quarterly session progress as a ring, a status message, and a
 * per-MMM-tier session breakdown, or a prompt to create a quota when none exists.
 *
 * @param viewModel supplies the current quota, progress fraction and status text, and the create action
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QuotaScreen(
    viewModel: QuotaViewModel = hiltViewModel()
) {
    val currentQuota by viewModel.currentQuota.collectAsStateWithLifecycle()
    val quotaProgress by viewModel.quotaProgress.collectAsStateWithLifecycle()
    val quotaStatus by viewModel.quotaStatus.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(title = { Text("FPS Quota") })
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            if (currentQuota == null) {
                // No quota data
                Spacer(modifier = Modifier.height(32.dp))
                Icon(
                    Icons.Default.PieChart,
                    contentDescription = null,
                    modifier = Modifier.size(64.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = "No Quota Data",
                    style = MaterialTheme.typography.headlineSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = "Create a quarterly quota to start tracking",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.height(16.dp))
                Button(onClick = { viewModel.createQuota() }) {
                    Text("Create Quota")
                }
            } else {
                // Progress ring
                QuotaProgressRing(
                    progress = quotaProgress,
                    sessions = currentQuota!!.totalSessions,
                    required = MINIMUM_SESSIONS_PER_QUARTER,
                    modifier = Modifier.size(200.dp)
                )

                Spacer(modifier = Modifier.height(24.dp))

                // Status text
                Text(
                    text = quotaStatus,
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    color = when {
                        currentQuota!!.quotaMet -> Color(0xFF4CAF50)
                        currentQuota!!.totalSessions >= ALMOST_THERE_SESSIONS -> MaterialTheme.colorScheme.primary
                        else -> MaterialTheme.colorScheme.onSurface
                    }
                )

                Spacer(modifier = Modifier.height(16.dp))

                // Stats cards
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    StatCard(
                        title = "MMM3",
                        value = "${currentQuota!!.mmm3Sessions}",
                        modifier = Modifier.weight(1f)
                    )
                    StatCard(
                        title = "MMM4",
                        value = "${currentQuota!!.mmm4Sessions}",
                        modifier = Modifier.weight(1f)
                    )
                    StatCard(
                        title = "MMM5",
                        value = "${currentQuota!!.mmm5Sessions}",
                        modifier = Modifier.weight(1f)
                    )
                    StatCard(
                        title = "MMM6",
                        value = "${currentQuota!!.mmm6Sessions}",
                        modifier = Modifier.weight(1f)
                    )
                    StatCard(
                        title = "MMM7",
                        value = "${currentQuota!!.mmm7Sessions}",
                        modifier = Modifier.weight(1f)
                    )
                }
            }
        }
    }
}

/**
 * Circular progress ring that visualizes quota completion, color-coded by progress band, with
 * the current and required session counts shown in the center.
 *
 * @param progress completion fraction in 0..1
 * @param sessions current number of counted sessions
 * @param required number of sessions required to meet the quota
 */
@Composable
fun QuotaProgressRing(
    progress: Float,
    sessions: Int,
    required: Int,
    modifier: Modifier = Modifier
) {
    val color = when {
        progress >= PROGRESS_COMPLETE -> Color(0xFF4CAF50)
        progress >= PROGRESS_GOOD -> MaterialTheme.colorScheme.primary
        progress >= PROGRESS_MODERATE -> Color(0xFFFF9800)
        else -> Color(0xFFF44336)
    }

    Box(
        modifier = modifier,
        contentAlignment = Alignment.Center
    ) {
        CircularProgressIndicator(
            progress = progress,
            modifier = Modifier.fillMaxSize(),
            color = color,
            trackColor = MaterialTheme.colorScheme.surfaceVariant,
            strokeWidth = 12.dp,
            strokeCap = StrokeCap.Round
        )

        Column(
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = "$sessions",
                style = MaterialTheme.typography.headlineLarge,
                fontWeight = FontWeight.Bold,
                color = color
            )
            Text(
                text = "of $required sessions",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

/**
 * Compact card showing a labelled statistic (e.g. session count for one MMM tier).
 *
 * @param title the statistic's label
 * @param value the statistic's value, pre-formatted as text
 */
@Composable
fun StatCard(
    title: String,
    value: String,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Column(
            modifier = Modifier.padding(8.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text(
                text = value,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
        }
    }
}
