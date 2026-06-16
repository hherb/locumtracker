package com.hherb.locumtracker.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext

private val DarkColorScheme = darkColorScheme(
    primary = Color(0xFF80CBC4),
    secondary = Color(0xFF80CBC4),
    tertiary = Color(0xFF80CBC4)
)

private val LightColorScheme = lightColorScheme(
    primary = Color(0xFF00796B),
    secondary = Color(0xFF00796B),
    tertiary = Color(0xFF00796B)
)

/**
 * Applies the LocumTracker Material3 theme to [content], selecting a color scheme based on
 * dark-mode and dynamic-color preferences.
 *
 * @param darkTheme whether to use dark colors; defaults to the system setting
 * @param dynamicColor whether to use Android 12+ dynamic (wallpaper-based) colors when available
 * @param content the composable subtree to theme
 */
@Composable
fun LocumTrackerTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = true,
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }
        darkTheme -> DarkColorScheme
        else -> LightColorScheme
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography(),
        content = content
    )
}
