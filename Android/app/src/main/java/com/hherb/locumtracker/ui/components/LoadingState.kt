package com.hherb.locumtracker.ui.components

import androidx.compose.animation.*
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/** Lifecycle states for an asynchronous operation that UI can react to. */
enum class LoadingState {
    IDLE,
    LOADING,
    SUCCESS,
    ERROR
}

/**
 * Overlay that shows a centered progress card while [state] is LOADING and an inline error
 * card while it is ERROR.
 *
 * @param state current loading lifecycle state driving which overlay (if any) is shown
 * @param loadingMessage message displayed alongside the progress indicator
 * @param errorMessage optional error detail shown in the error card
 * @param onRetry optional callback; when provided a Retry button is rendered in the error card
 */
@Composable
fun LoadingOverlay(
    state: LoadingState,
    modifier: Modifier = Modifier,
    loadingMessage: String = "Loading...",
    errorMessage: String? = null,
    onRetry: (() -> Unit)? = null
) {
    AnimatedVisibility(
        visible = state == LoadingState.LOADING,
        enter = fadeIn(),
        exit = fadeOut(),
        modifier = modifier
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            contentAlignment = Alignment.Center
        ) {
            Card(
                elevation = CardDefaults.cardElevation(defaultElevation = 8.dp)
            ) {
                Column(
                    modifier = Modifier.padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    CircularProgressIndicator()
                    Text(
                        text = loadingMessage,
                        style = MaterialTheme.typography.bodyMedium
                    )
                }
            }
        }
    }

    AnimatedVisibility(
        visible = state == LoadingState.ERROR,
        enter = fadeIn(),
        exit = fadeOut(),
        modifier = modifier
    ) {
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.errorContainer
            )
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    text = "Error",
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onErrorContainer
                )
                if (errorMessage != null) {
                    Text(
                        text = errorMessage,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onErrorContainer
                    )
                }
                if (onRetry != null) {
                    Button(
                        onClick = onRetry,
                        colors = ButtonDefaults.buttonColors(
                            containerColor = MaterialTheme.colorScheme.error
                        )
                    ) {
                        Text("Retry")
                    }
                }
            }
        }
    }
}

/**
 * Snackbar showing a success [message] with an OK action.
 *
 * @param message the success text to display
 * @param onDismiss invoked when the OK action is tapped
 */
@Composable
fun SuccessSnackbar(
    message: String,
    modifier: Modifier = Modifier,
    onDismiss: () -> Unit
) {
    Snackbar(
        modifier = modifier.padding(16.dp),
        action = {
            TextButton(onClick = onDismiss) {
                Text("OK")
            }
        }
    ) {
        Text(message)
    }
}

/**
 * Centered placeholder shown when a list or screen has no content.
 *
 * @param title primary message describing the empty state
 * @param subtitle optional supporting detail
 * @param icon optional leading icon slot rendered above the title
 * @param action optional action slot (e.g. a button) rendered below the text
 */
@Composable
fun EmptyState(
    title: String,
    subtitle: String? = null,
    icon: @Composable (() -> Unit)? = null,
    action: @Composable (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        if (icon != null) {
            icon()
            Spacer(modifier = Modifier.height(16.dp))
        }

        Text(
            text = title,
            style = MaterialTheme.typography.headlineSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        if (subtitle != null) {
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        if (action != null) {
            Spacer(modifier = Modifier.height(16.dp))
            action()
        }
    }
}
