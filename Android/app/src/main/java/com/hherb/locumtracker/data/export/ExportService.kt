package com.hherb.locumtracker.data.export

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import com.hherb.locumtracker.data.database.entity.*
import dagger.hilt.android.qualifiers.ApplicationContext
import java.io.File
import java.text.SimpleDateFormat
import java.util.*
import javax.inject.Inject
import javax.inject.Singleton

/** Supported export file formats. */
enum class ExportFormat {
    CSV, JSON
}

/**
 * Service that exports earnings, receipts and sessions to shareable files.
 *
 * Writes CSV and JSON files into the app cache directory and exposes them as content
 * URIs via [FileProvider], plus a helper to build a share [Intent].
 */
@Singleton
class ExportService @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private companion object {
        /** Number of milliseconds in one hour, used to convert session durations to hours. */
        private const val MILLIS_PER_HOUR = 3600000.0
    }

    /**
     * Exports receipts and their related assignment/location names to a CSV file.
     *
     * @param receipts Receipts to export.
     * @param assignments Assignments keyed by assignment id, used to resolve names.
     * @param locations Locations keyed by location id, used to resolve names.
     * @return A content URI for the generated file, or null if writing failed.
     */
    fun exportEarningsCSV(
        receipts: List<ReceiptEntity>,
        assignments: Map<String, AssignmentEntity>,
        locations: Map<String, LocationEntity>
    ): Uri? {
        return try {
            val filename = "earnings_${SimpleDateFormat("yyyyMMdd", Locale.getDefault()).format(Date())}.csv"
            val file = File(context.cacheDir, filename)

            file.bufferedWriter().use { writer ->
                // Header
                writer.appendLine("Date,Category,Description,Amount,Assignment,Location")

                // Data
                receipts.forEach { receipt ->
                    val assignment = assignments[receipt.assignmentId]
                    val location = assignment?.let { locations[it.locationId] }

                    writer.appendLine(
                        "${SimpleDateFormat("dd/MM/yyyy", Locale.getDefault()).format(Date(receipt.date))}," +
                        "${receipt.category}," +
                        "\"${receipt.receiptDescription.replace("\"", "\"\"")}\"," +
                        "${receipt.amount}," +
                        "\"${assignment?.name ?: "N/A"}\"," +
                        "\"${location?.name ?: "N/A"}\""
                    )
                }

                // Summary
                writer.appendLine()
                writer.appendLine("Summary")
                writer.appendLine("Total Receipts,${receipts.size}")
                writer.appendLine("Total Amount,${receipts.sumOf { it.amount }}")
            }

            FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                file
            )
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Exports receipts and their related assignment/location names to a JSON file,
     * including a summary block with receipt count and total amount.
     *
     * @param receipts Receipts to export.
     * @param assignments Assignments keyed by assignment id, used to resolve names.
     * @param locations Locations keyed by location id, used to resolve names.
     * @return A content URI for the generated file, or null if writing failed.
     */
    fun exportEarningsJSON(
        receipts: List<ReceiptEntity>,
        assignments: Map<String, AssignmentEntity>,
        locations: Map<String, LocationEntity>
    ): Uri? {
        return try {
            val filename = "earnings_${SimpleDateFormat("yyyyMMdd", Locale.getDefault()).format(Date())}.json"
            val file = File(context.cacheDir, filename)

            file.bufferedWriter().use { writer ->
                val json = buildString {
                    appendLine("{")
                    appendLine("  \"exportDate\": \"${SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(Date())}\",")
                    appendLine("  \"summary\": {")
                    appendLine("    \"totalReceipts\": ${receipts.size},")
                    appendLine("    \"totalAmount\": ${receipts.sumOf { it.amount }}")
                    appendLine("  },")
                    appendLine("  \"receipts\": [")

                    receipts.forEachIndexed { index, receipt ->
                        val assignment = assignments[receipt.assignmentId]
                        val location = assignment?.let { locations[it.locationId] }

                        appendLine("    {")
                        appendLine("      \"id\": \"${receipt.id}\",")
                        appendLine("      \"date\": \"${SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date(receipt.date))}\",")
                        appendLine("      \"category\": \"${receipt.category}\",")
                        appendLine("      \"description\": \"${receipt.receiptDescription}\",")
                        appendLine("      \"amount\": ${receipt.amount},")
                        appendLine("      \"assignment\": \"${assignment?.name ?: "N/A"}\",")
                        appendLine("      \"location\": \"${location?.name ?: "N/A"}\"")
                        appendLine("    }${if (index < receipts.size - 1) "," else ""}")
                    }

                    appendLine("  ]")
                    append("}")
                }

                writer.append(json)
            }

            FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                file
            )
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Exports sessions, with their date/time, duration and assignment name, to a CSV file.
     *
     * Session durations are derived from the start and end times and expressed in hours.
     *
     * @param sessions Sessions to export.
     * @param dailyRecords Daily records used to link a session to its assignment.
     * @param assignments Assignments keyed by assignment id, used to resolve names.
     * @return A content URI for the generated file, or null if writing failed.
     */
    fun exportSessionsCSV(
        sessions: List<SessionEntity>,
        dailyRecords: List<DailyRecordEntity>,
        assignments: Map<String, AssignmentEntity>
    ): Uri? {
        return try {
            val filename = "sessions_${SimpleDateFormat("yyyyMMdd", Locale.getDefault()).format(Date())}.csv"
            val file = File(context.cacheDir, filename)

            file.bufferedWriter().use { writer ->
                // Header
                writer.appendLine("Date,Type,Start Time,End Time,Duration (hours),MMM Classification,Assignment")

                // Data
                sessions.forEach { session ->
                    val dailyRecord = dailyRecords.find { it.id == session.dailyRecordId }
                    val assignment = dailyRecord?.let { assignments[it.assignmentId] }
                    val dateFormat = SimpleDateFormat("dd/MM/yyyy", Locale.getDefault())
                    val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())

                    writer.appendLine(
                        "${dateFormat.format(Date(session.startTime))}," +
                        "${session.sessionType}," +
                        "${timeFormat.format(Date(session.startTime))}," +
                        "${timeFormat.format(Date(session.endTime))}," +
                        "${(session.endTime - session.startTime) / MILLIS_PER_HOUR}," +
                        "${session.mmmClassification}," +
                        "\"${assignment?.name ?: "N/A"}\""
                    )
                }
            }

            FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                file
            )
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Builds an ACTION_SEND intent for sharing a previously exported file.
     *
     * @param uri Content URI of the file to share.
     * @param mimeType MIME type of the file (for example, "text/csv" or "application/json").
     * @return An intent that grants read access and attaches the file for sharing.
     */
    fun shareFile(uri: Uri, mimeType: String): Intent {
        return Intent(Intent.ACTION_SEND).apply {
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
    }
}
