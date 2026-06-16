package com.hherb.locumtracker.ui.screens.receipts

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Receipt
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.hherb.locumtracker.data.database.entity.ReceiptEntity
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Renders the receipts list with a summary header, or an empty-state prompt when there are none.
 *
 * @param onReceiptClick invoked with the receipt id when a receipt row is tapped.
 * @param onAddReceipt invoked when the add (+) action is tapped.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReceiptsScreen(
    onReceiptClick: (String) -> Unit,
    onAddReceipt: () -> Unit,
    viewModel: ReceiptsViewModel = hiltViewModel()
) {
    val receipts by viewModel.receipts.collectAsStateWithLifecycle()
    val totalExpenses by viewModel.totalExpenses.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Receipts") },
                actions = {
                    IconButton(onClick = onAddReceipt) {
                        Icon(Icons.Default.Add, contentDescription = "Add Receipt")
                    }
                }
            )
        }
    ) { padding ->
        if (receipts.isEmpty()) {
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
                        Icons.Default.Receipt,
                        contentDescription = null,
                        modifier = Modifier.size(64.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        text = "No Receipts Yet",
                        style = MaterialTheme.typography.headlineSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "Tap + to add your first receipt",
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
                item {
                    SummaryCard(
                        totalExpenses = totalExpenses,
                        receiptCount = receipts.size
                    )
                }
                items(receipts) { receipt ->
                    ReceiptCard(
                        receipt = receipt,
                        onClick = { onReceiptClick(receipt.id) }
                    )
                }
            }
        }
    }
}

/**
 * Header card showing the total expense amount and the number of receipts.
 *
 * @param totalExpenses summed amount of all receipts.
 * @param receiptCount number of receipts.
 */
@Composable
fun SummaryCard(totalExpenses: Double, receiptCount: Int) {
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
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Column {
                Text(
                    text = "Total Expenses",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onPrimaryContainer
                )
                Text(
                    text = "$${String.format("%.2f", totalExpenses)}",
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onPrimaryContainer
                )
            }
            Column(horizontalAlignment = Alignment.End) {
                Text(
                    text = "Receipts",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onPrimaryContainer
                )
                Text(
                    text = "$receiptCount",
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onPrimaryContainer
                )
            }
        }
    }
}

/**
 * A single receipt row showing category icon, description, category/date, and amount.
 *
 * @param receipt the receipt to display.
 * @param onClick invoked when the card is tapped.
 */
@Composable
fun ReceiptCard(
    receipt: ReceiptEntity,
    onClick: () -> Unit
) {
    val dateFormat = remember { SimpleDateFormat("dd MMM yyyy", Locale.getDefault()) }

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            CategoryIcon(category = receipt.category)

            Spacer(modifier = Modifier.width(12.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = receipt.receiptDescription.ifEmpty { "No description" },
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.Medium
                )
                Text(
                    text = "${receipt.category.replaceFirstChar { it.uppercase() }} • ${dateFormat.format(Date(receipt.date))}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            Text(
                text = "$${String.format("%.2f", receipt.amount)}",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.primary
            )
        }
    }
}

/**
 * Renders an emoji badge representing the receipt [category], falling back to a generic icon.
 */
@Composable
fun CategoryIcon(category: String) {
    val icon = when (category) {
        "travel" -> "🚗"
        "accommodation" -> "🛏️"
        "meals" -> "🍽️"
        "supplies" -> "📦"
        "professional" -> "💼"
        "insurance" -> "🛡️"
        "training" -> "📚"
        else -> "📎"
    }

    Surface(
        color = MaterialTheme.colorScheme.surfaceVariant,
        shape = MaterialTheme.shapes.small
    ) {
        Text(
            text = icon,
            modifier = Modifier.padding(8.dp),
            style = MaterialTheme.typography.titleMedium
        )
    }
}
