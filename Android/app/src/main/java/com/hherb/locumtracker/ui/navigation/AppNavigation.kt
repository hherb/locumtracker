package com.hherb.locumtracker.ui.navigation

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import com.hherb.locumtracker.ui.screens.assignments.AddAssignmentScreen
import com.hherb.locumtracker.ui.screens.assignments.AssignmentDetailScreen
import com.hherb.locumtracker.ui.screens.assignments.AssignmentsScreen
import com.hherb.locumtracker.ui.screens.assignments.EditAssignmentScreen
import com.hherb.locumtracker.ui.screens.earnings.EarningsScreen
import com.hherb.locumtracker.ui.screens.locations.AddLocationScreen
import com.hherb.locumtracker.ui.screens.locations.EditLocationScreen
import com.hherb.locumtracker.ui.screens.locations.LocationDetailScreen
import com.hherb.locumtracker.ui.screens.receipts.AddReceiptScreen
import com.hherb.locumtracker.ui.screens.receipts.EditReceiptScreen
import com.hherb.locumtracker.ui.screens.receipts.ReceiptDetailScreen
import com.hherb.locumtracker.ui.screens.receipts.ReceiptsScreen
import com.hherb.locumtracker.ui.screens.quota.QuotaScreen
import com.hherb.locumtracker.ui.screens.sessions.AddSessionScreen
import com.hherb.locumtracker.ui.screens.sessions.SessionListScreen
import com.hherb.locumtracker.ui.screens.settings.SettingsScreen

/**
 * Hosts the app's Navigation-Compose graph, wiring every [Screen] route to its destination
 * composable and handling navigation between them.
 *
 * @param navController controller that drives navigation between destinations
 * @param modifier modifier applied to the underlying NavHost
 */
@Composable
fun AppNavigation(
    navController: NavHostController,
    modifier: Modifier = Modifier
) {
    NavHost(
        navController = navController,
        startDestination = Screen.Assignments.route,
        modifier = modifier
    ) {
        // Main tabs
        composable(Screen.Assignments.route) {
            AssignmentsScreen(
                onAssignmentClick = { assignmentId ->
                    navController.navigate(Screen.assignmentDetail(assignmentId))
                },
                onAddAssignment = {
                    navController.navigate(Screen.AddAssignment.route)
                }
            )
        }

        composable(Screen.Quota.route) {
            QuotaScreen()
        }

        composable(Screen.Earnings.route) {
            EarningsScreen()
        }

        composable(Screen.Receipts.route) {
            ReceiptsScreen(
                onReceiptClick = { receiptId ->
                    navController.navigate(Screen.receiptDetail(receiptId))
                },
                onAddReceipt = {
                    navController.navigate(Screen.AddReceipt.route)
                }
            )
        }

        composable(Screen.Settings.route) {
            SettingsScreen()
        }

        // Add screens
        composable(Screen.AddAssignment.route) {
            AddAssignmentScreen(
                onBack = { navController.popBackStack() },
                onAssignmentAdded = { navController.popBackStack() }
            )
        }

        composable(Screen.AddLocation.route) {
            AddLocationScreen(
                onBack = { navController.popBackStack() },
                onLocationAdded = { navController.popBackStack() }
            )
        }

        composable(Screen.AddReceipt.route) {
            AddReceiptScreen(
                onBack = { navController.popBackStack() },
                onReceiptAdded = { navController.popBackStack() }
            )
        }

        // Detail screens
        composable(
            route = Screen.AssignmentDetail.route,
            arguments = listOf(
                navArgument("assignmentId") { type = NavType.StringType }
            )
        ) { backStackEntry ->
            val assignmentId = backStackEntry.arguments?.getString("assignmentId") ?: return@composable
            AssignmentDetailScreen(
                assignmentId = assignmentId,
                onBack = { navController.popBackStack() },
                onEdit = {
                    navController.navigate(Screen.editAssignment(assignmentId))
                },
                onSessionsClick = { id ->
                    navController.navigate(Screen.sessionList(id))
                }
            )
        }

        composable(
            route = Screen.SessionList.route,
            arguments = listOf(
                navArgument("assignmentId") { type = NavType.StringType }
            )
        ) { backStackEntry ->
            val assignmentId = backStackEntry.arguments?.getString("assignmentId") ?: return@composable
            SessionListScreen(
                assignmentId = assignmentId,
                onBack = { navController.popBackStack() },
                onAddSession = {
                    navController.navigate(Screen.addSession(assignmentId))
                }
            )
        }

        composable(
            route = Screen.AddSession.route,
            arguments = listOf(
                navArgument("assignmentId") { type = NavType.StringType }
            )
        ) { backStackEntry ->
            val assignmentId = backStackEntry.arguments?.getString("assignmentId") ?: return@composable
            AddSessionScreen(
                assignmentId = assignmentId,
                onBack = { navController.popBackStack() },
                onSessionAdded = { navController.popBackStack() }
            )
        }

        composable(
            route = Screen.LocationDetail.route,
            arguments = listOf(
                navArgument("locationId") { type = NavType.StringType }
            )
        ) {
            // TODO: LocationDetailScreen
        }

        composable(
            route = Screen.ReceiptDetail.route,
            arguments = listOf(
                navArgument("receiptId") { type = NavType.StringType }
            )
        ) { backStackEntry ->
            val receiptId = backStackEntry.arguments?.getString("receiptId") ?: return@composable
            ReceiptDetailScreen(
                receiptId = receiptId,
                onBack = { navController.popBackStack() },
                onEdit = {
                    navController.navigate(Screen.editReceipt(receiptId))
                }
            )
        }

        // Edit screens
        composable(
            route = Screen.EditAssignment.route,
            arguments = listOf(
                navArgument("assignmentId") { type = NavType.StringType }
            )
        ) { backStackEntry ->
            val assignmentId = backStackEntry.arguments?.getString("assignmentId") ?: return@composable
            EditAssignmentScreen(
                assignmentId = assignmentId,
                onBack = { navController.popBackStack() },
                onAssignmentUpdated = { navController.popBackStack() }
            )
        }

        composable(
            route = Screen.EditLocation.route,
            arguments = listOf(
                navArgument("locationId") { type = NavType.StringType }
            )
        ) { backStackEntry ->
            val locationId = backStackEntry.arguments?.getString("locationId") ?: return@composable
            EditLocationScreen(
                locationId = locationId,
                onBack = { navController.popBackStack() },
                onLocationUpdated = { navController.popBackStack() }
            )
        }

        composable(
            route = Screen.EditReceipt.route,
            arguments = listOf(
                navArgument("receiptId") { type = NavType.StringType }
            )
        ) { backStackEntry ->
            val receiptId = backStackEntry.arguments?.getString("receiptId") ?: return@composable
            EditReceiptScreen(
                receiptId = receiptId,
                onBack = { navController.popBackStack() },
                onReceiptUpdated = { navController.popBackStack() }
            )
        }

        // Location Detail
        composable(
            route = Screen.LocationDetail.route,
            arguments = listOf(
                navArgument("locationId") { type = NavType.StringType }
            )
        ) { backStackEntry ->
            val locationId = backStackEntry.arguments?.getString("locationId") ?: return@composable
            LocationDetailScreen(
                locationId = locationId,
                onBack = { navController.popBackStack() },
                onEdit = {
                    navController.navigate(Screen.editLocation(locationId))
                }
            )
        }
    }
}
