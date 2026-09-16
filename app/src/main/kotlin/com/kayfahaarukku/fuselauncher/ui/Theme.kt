package com.kayfahaarukku.fuselauncher.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import com.kayfahaarukku.fuselauncher.R

private val Purple = Color(0xFF6750A4)

/**
 * Material Red 500, which is what Flutter's `Colors.red` resolves to. Compose's
 * `Color.Red` is pure #FF0000 and reads as a much louder red beside it.
 */
val BadgeRed = Color(0xFFF44336)

/** Popup and sheet surfaces, matching the Flutter build's hard-coded greys. */
val PopupSurface = Color(0xFF252525)
private val PurpleLight = Color(0xFFD0BCFF)

/**
 * Sheets, dialogs and the settings screen paint real surfaces, so they use an
 * ordinary Material palette. The drawer does not: it floats over whatever
 * wallpaper the user has set.
 */
private val DarkColors = darkColorScheme(
    primary = PurpleLight,
    surface = Color(0xFF252525),
    onSurface = Color.White,
    surfaceContainer = Color(0xFF252525),
    surfaceContainerHigh = Color(0xFF2D2D2D),
    background = Color(0xFF1B1B1B),
    onBackground = Color.White,
)

private val LightColors = lightColorScheme(
    primary = Purple,
    surface = Color.White,
    onSurface = Color.Black,
    surfaceContainer = Color(0xFFF5F5F5),
    surfaceContainerHigh = Color(0xFFEEEEEE),
    background = Color.White,
    onBackground = Color.Black,
)

/**
 * Text drawn straight onto the wallpaper.
 *
 * Wallpaper brightness has nothing to do with the system's dark mode setting -
 * a light wallpaper under a dark theme left white labels almost unreadable - so
 * drawer text does not follow the theme at all. It is white, over a shadow and
 * a scrim, which stays legible on a photo, a solid colour, or anything else.
 */
object Wallpaper {
    val content = Color.White
    val contentMuted = Color.White.copy(alpha = 0.85f)
    val contentFaint = Color.White.copy(alpha = 0.7f)

    /**
     * Heavy on purpose. A light wallpaper is the hard case - a soft shadow
     * disappeared into a pale background and left the labels barely readable -
     * so this is closer to an outline than a drop shadow.
     */
    private val shadow = Shadow(
        color = Color.Black.copy(alpha = 0.9f),
        offset = Offset(0f, 1f),
        blurRadius = 10f,
    )

    /**
     * Sits between the wallpaper and the drawer. Light enough to keep the
     * wallpaper legible, dark enough that white text has something to sit on
     * no matter what the picture is doing behind it.
     */
    val scrim = Brush.verticalGradient(
        0f to Color.Black.copy(alpha = 0.15f),
        0.5f to Color.Black.copy(alpha = 0.28f),
        1f to Color.Black.copy(alpha = 0.45f),
    )

    /** Applies the shadow to any style, keeping the caller's size and weight. */
    fun style(base: TextStyle, color: Color = content): TextStyle =
        base.copy(color = color, shadow = shadow)
}

/**
 * Poppins, the same faces the Flutter build pulled in through google_fonts,
 * bundled here as font resources. Licence in native/licenses.
 */
val Poppins = FontFamily(
    Font(R.font.poppins_regular, FontWeight.Normal),
    Font(R.font.poppins_medium, FontWeight.Medium),
    Font(R.font.poppins_semibold, FontWeight.SemiBold),
    Font(R.font.poppins_bold, FontWeight.Bold),
)

/** Material's own scale, restyled in Poppins so every screen picks it up. */
private val PoppinsTypography = Typography().run {
    copy(
        displayLarge = displayLarge.copy(fontFamily = Poppins),
        displayMedium = displayMedium.copy(fontFamily = Poppins),
        displaySmall = displaySmall.copy(fontFamily = Poppins),
        headlineLarge = headlineLarge.copy(fontFamily = Poppins),
        headlineMedium = headlineMedium.copy(fontFamily = Poppins),
        headlineSmall = headlineSmall.copy(fontFamily = Poppins),
        titleLarge = titleLarge.copy(fontFamily = Poppins),
        titleMedium = titleMedium.copy(fontFamily = Poppins),
        titleSmall = titleSmall.copy(fontFamily = Poppins),
        bodyLarge = bodyLarge.copy(fontFamily = Poppins),
        bodyMedium = bodyMedium.copy(fontFamily = Poppins),
        bodySmall = bodySmall.copy(fontFamily = Poppins),
        labelLarge = labelLarge.copy(fontFamily = Poppins),
        labelMedium = labelMedium.copy(fontFamily = Poppins),
        labelSmall = labelSmall.copy(fontFamily = Poppins),
    )
}

@Composable
fun FuseTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) = MaterialTheme(
    colorScheme = if (darkTheme) DarkColors else LightColors,
    typography = PoppinsTypography,
    content = content,
)
