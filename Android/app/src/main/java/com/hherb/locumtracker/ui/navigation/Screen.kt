package com.hherb.locumtracker.ui.navigation

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.ui.graphics.vector.ImageVector

/**
 * Type-safe definition of every navigable destination in the app.
 *
 * Each subclass exposes its navigation [route], a human-readable [title] and an [icon]
 * used by bottom-navigation / app-bar surfaces. Routes containing `{argument}` placeholders
 * have matching builder helpers in the [companion object] that substitute concrete ids.
 *
 * @property route the Navigation-Compose route pattern for the destination
 * @property title the user-facing title shown for the destination
 * @property icon the icon representing the destination
 */
sealed class Screen(val route: String, val title: String, val icon: ImageVector) {
    data object Assignments : Screen("assignments", "Assignments", Icons.Default.CalendarMonth)
    data object Quota : Screen("quota", "FPS Quota", Icons.Default.PieChart)
    data object Earnings : Screen("earnings", "Earnings", Icons.Default.BarChart)
    data object Receipts : Screen("receipts", "Receipts", Icons.Default.Receipt)
    data object Settings : Screen("settings", "Settings", Icons.Default.Settings)

    // Detail screens
    data object AssignmentDetail : Screen("assignment/{assignmentId}", "Assignment", Icons.Default.Info)
    data object LocationDetail : Screen("location/{locationId}", "Location", Icons.Default.LocationOn)
    data object SessionList : Screen("sessions/{assignmentId}", "Sessions", Icons.Default.Schedule)
    data object AddSession : Screen("add-session/{assignmentId}", "Add Session", Icons.Default.Add)
    data object ReceiptDetail : Screen("receipt/{receiptId}", "Receipt", Icons.Default.Info)

    // Add/Edit screens
    data object AddAssignment : Screen("add-assignment", "Add Assignment", Icons.Default.Add)
    data object AddLocation : Screen("add-location", "Add Location", Icons.Default.Add)
    data object AddReceipt : Screen("add-receipt", "Add Receipt", Icons.Default.Add)
    data object EditAssignment : Screen("edit-assignment/{assignmentId}", "Edit Assignment", Icons.Default.Edit)
    data object EditLocation : Screen("edit-location/{locationId}", "Edit Location", Icons.Default.Edit)
    data object EditReceipt : Screen("edit-receipt/{receiptId}", "Edit Receipt", Icons.Default.Edit)

    /** Helpers that build concrete routes by substituting ids into parameterized route patterns. */
    companion object {
        fun editAssignment(assignmentId: String) = "edit-assignment/$assignmentId"
        fun editLocation(locationId: String) = "edit-location/$locationId"
        fun editReceipt(receiptId: String) = "edit-receipt/$receiptId"
        fun assignmentDetail(assignmentId: String) = "assignment/$assignmentId"
        fun locationDetail(locationId: String) = "location/$locationId"
        fun sessionList(assignmentId: String) = "sessions/$assignmentId"
        fun addSession(assignmentId: String) = "add-session/$assignmentId"
        fun receiptDetail(receiptId: String) = "receipt/$receiptId"
    }
}
