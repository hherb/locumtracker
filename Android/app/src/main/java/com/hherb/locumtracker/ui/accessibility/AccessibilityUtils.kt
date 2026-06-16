package com.hherb.locumtracker.ui.accessibility

import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics

/**
 * Central catalogue of screen-reader (TalkBack) content-description strings used across the app,
 * grouped by domain area. Function members build dynamic labels from runtime values; the `val`
 * members are fixed labels for common actions and statuses.
 */
object AccessibilityLabels {
    // Assignment
    fun assignmentName(name: String) = "Assignment: $name"
    fun assignmentStatus(status: String) = "Status: ${status.replaceFirstChar { it.uppercase() }}"
    fun assignmentRate(rate: String) = "Rate: $rate"
    fun assignmentDates(startDate: String, endDate: String) = "From $startDate to $endDate"

    // Location
    fun locationName(name: String) = "Location: $name"
    fun mmmClassification(classification: Int) = "MMM$classification"
    fun mmmClassificationWithDescription(classification: Int, description: String) =
        "MMM$classification - $description"
    fun subsidyEligible(eligible: Boolean) = if (eligible) "Subsidy eligible" else "Not subsidy eligible"

    // Session
    fun sessionType(type: String) = "Session type: ${type.replaceFirstChar { it.uppercase() }}"
    fun sessionTime(startTime: String, endTime: String) = "From $startTime to $endTime"
    fun sessionDuration(duration: String) = "Duration: $duration"

    // Receipt
    fun receiptAmount(amount: String) = "Amount: $amount"
    fun receiptCategory(category: String) = "Category: ${category.replaceFirstChar { it.uppercase() }}"
    fun receiptDate(date: String) = "Date: $date"
    fun attachmentCount(count: Int) = "$count attachments"

    // Quota
    fun quotaProgress(current: Int, required: Int) = "$current of $required sessions"
    fun quotaPercentage(percentage: Float) = "${String.format("%.0f", percentage)}% complete"
    fun quotaStatus(met: Boolean) = if (met) "Quota met" else "Quota not met"

    // Earnings
    fun totalEarnings(amount: String) = "Total earnings: $amount"
    fun totalExpenses(amount: String) = "Total expenses: $amount"
    fun netEarnings(amount: String) = "Net earnings: $amount"
    fun hoursWorked(hours: String) = "Hours worked: $hours"

    // Actions
    val addButton = "Add"
    val editButton = "Edit"
    val deleteButton = "Delete"
    val saveButton = "Save"
    val cancelButton = "Cancel"
    val backButton = "Back"
    val cameraButton = "Take photo"
    val galleryButton = "Choose from gallery"
    val scanButton = "Scan receipt"

    // Form fields
    fun requiredField(fieldName: String) = "$fieldName (required)"
    fun optionalField(fieldName: String) = "$fieldName (optional)"

    // Status messages
    val loading = "Loading"
    val saving = "Saving"
    val syncing = "Syncing"
    val error = "Error occurred"
    val success = "Success"
}

/**
 * Builds a [Modifier] that sets the given [description] as the node's accessibility content description.
 *
 * @param description the content description exposed to assistive technologies
 */
fun semantics(description: String): androidx.compose.ui.Modifier {
    return androidx.compose.ui.Modifier.semantics {
        contentDescription = description
    }
}

/**
 * Builds a [Modifier] that applies arbitrary semantics properties via [block].
 *
 * @param block receiver lambda configuring semantics properties on the node
 */
fun semantics(
    block: androidx.compose.ui.semantics.SemanticsPropertyReceiver.() -> Unit
): androidx.compose.ui.Modifier {
    return androidx.compose.ui.Modifier.semantics(properties = block)
}
