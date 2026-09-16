package com.kayfahaarukku.fuselauncher.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBackIos
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.ViewList
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material.icons.filled.NotificationsNone
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.PhoneAndroid
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material.icons.filled.Wallpaper
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kayfahaarukku.fuselauncher.data.AppLayoutType

private val Accent = Color(0xFF6750A4)
private val AccentLight = Color(0xFFD0BCFF)
private val CardSurface = Color(0xFF2D2D2D)
private val TitleColor = Color.White
private val SubtitleColor = Color.White.copy(alpha = 0.6f)
private val ChevronColor = Color.White.copy(alpha = 0.5f)

// One accent per row, as in the Flutter build - the colour is how you find the
// row you want without reading every label.
private val BlueSearch = Color(0xFF2196F3)
private val PurpleLayout = Color(0xFF9C27B0)
private val OrangeBadges = Color(0xFFFF5722)
private val BluePreviews = Color(0xFF03A9F4)
private val GreenWallpaper = Color(0xFF4CAF50)
private val GreyAbout = Color(0xFF607D8B)
private val AmberHidden = Color(0xFFFFB300)

/** Everything the settings screen can change, hoisted out of the composable. */
data class SettingsState(
    val searchBarAtTop: Boolean,
    val layout: AppLayoutType,
    val gridColumns: Int,
    val showNotificationBadges: Boolean,
    val showNotificationPreviews: Boolean,
    val hiddenAppCount: Int,
    val notificationAccess: Boolean,
)

private enum class SettingsSheet { SEARCH_BAR, LAYOUT }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    state: SettingsState,
    onSearchBarAtTop: (Boolean) -> Unit,
    onLayout: (AppLayoutType) -> Unit,
    onGridColumns: (Int) -> Unit,
    onBadges: (Boolean) -> Unit,
    onPreviews: (Boolean) -> Unit,
    onRequestNotificationAccess: () -> Unit,
    onManageHidden: () -> Unit,
    onChangeWallpaper: () -> Unit,
    onAbout: () -> Unit,
    onBack: () -> Unit,
) {
    var sheet by remember { mutableStateOf<SettingsSheet?>(null) }
    // Flutter pushed a fresh page each time, so it always opened at the top.
    val scroll = rememberScrollState()
    LaunchedEffect(Unit) { scroll.scrollTo(0) }

    // No background of its own: the Flutter build's settings Scaffold is
    // transparent and the wallpaper carries on behind it, scrim and all.
    Column(Modifier.fillMaxSize()) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 8.dp),
        ) {
            IconButton(onClick = onBack) {
                Box(
                    Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .background(Color.White.copy(alpha = 0.05f))
                        .padding(8.dp),
                ) {
                    Icon(
                        Icons.AutoMirrored.Filled.ArrowBackIos,
                        contentDescription = "Back",
                        tint = TitleColor,
                        modifier = Modifier.size(18.dp),
                    )
                }
            }
            Spacer(Modifier.width(8.dp))
            Text(
                "Settings",
                color = TitleColor,
                fontSize = 24.sp,
                fontWeight = FontWeight.SemiBold,
            )
        }

        Column(
            Modifier
                .verticalScroll(scroll)
                .padding(20.dp),
        ) {
            HeroCard()

            Spacer(Modifier.height(32.dp))
            CategoryHeader("Interface", Icons.Filled.Palette)
            Spacer(Modifier.height(16.dp))

            SettingsCard(Icons.Filled.Search, BlueSearch) {
                NavigationRow(
                    title = "Search Bar Position",
                    subtitle = if (state.searchBarAtTop) "Top of screen" else "Bottom of screen",
                    onClick = { sheet = SettingsSheet.SEARCH_BAR },
                )
            }

            Spacer(Modifier.height(16.dp))

            SettingsCard(
                if (state.layout == AppLayoutType.GRID) Icons.Filled.GridView
                else Icons.AutoMirrored.Filled.ViewList,
                PurpleLayout,
            ) {
                NavigationRow(
                    title = "App Layout",
                    subtitle = if (state.layout == AppLayoutType.GRID) {
                        "Grid • ${state.gridColumns} columns"
                    } else {
                        "List"
                    },
                    onClick = { sheet = SettingsSheet.LAYOUT },
                )
            }

            Spacer(Modifier.height(32.dp))
            CategoryHeader("Notifications", Icons.Filled.NotificationsActive)
            Spacer(Modifier.height(16.dp))

            // Not in the Flutter build, but badges and previews do nothing
            // without it and there was no way to tell from inside the app.
            SettingsCard(Icons.Filled.NotificationsActive, OrangeBadges) {
                NavigationRow(
                    title = "Notification Access",
                    subtitle = if (state.notificationAccess) {
                        "Granted"
                    } else {
                        "Not granted — badges and previews stay empty"
                    },
                    onClick = onRequestNotificationAccess,
                )
            }

            Spacer(Modifier.height(16.dp))

            SettingsCard(Icons.Filled.NotificationsActive, OrangeBadges) {
                SwitchRow(
                    title = "Notification Badges",
                    subtitle = if (state.showNotificationBadges) {
                        "Show app notification counts"
                    } else {
                        "Hide app notification counts"
                    },
                    checked = state.showNotificationBadges,
                    onCheckedChange = onBadges,
                )
            }

            Spacer(Modifier.height(16.dp))

            SettingsCard(Icons.Filled.NotificationsNone, BluePreviews) {
                SwitchRow(
                    title = "Notification Previews",
                    subtitle = if (state.showNotificationPreviews) {
                        "Show the latest notification under the app name"
                    } else {
                        "Hide notification text in the app list"
                    },
                    checked = state.showNotificationPreviews,
                    onCheckedChange = onPreviews,
                )
            }

            Spacer(Modifier.height(32.dp))
            CategoryHeader("System", Icons.Filled.PhoneAndroid)
            Spacer(Modifier.height(16.dp))

            // Also new: the Flutter build only reached hidden apps by a double
            // swipe, which is not something anyone finds on their own.
            SettingsCard(Icons.Filled.VisibilityOff, AmberHidden) {
                NavigationRow(
                    title = "Hidden Apps",
                    subtitle = when (state.hiddenAppCount) {
                        0 -> "Nothing hidden"
                        1 -> "1 app hidden"
                        else -> "${state.hiddenAppCount} apps hidden"
                    },
                    onClick = onManageHidden,
                )
            }

            Spacer(Modifier.height(16.dp))

            SettingsCard(Icons.Filled.Wallpaper, GreenWallpaper) {
                NavigationRow(
                    title = "Change Wallpaper",
                    subtitle = "Set a new wallpaper for your device",
                    onClick = onChangeWallpaper,
                )
            }

            Spacer(Modifier.height(32.dp))
            CategoryHeader("About", Icons.Filled.Info)
            Spacer(Modifier.height(16.dp))

            SettingsCard(Icons.Outlined.Info, GreyAbout) {
                NavigationRow(
                    title = "About FuseLauncher",
                    subtitle = "Version info and developer details",
                    onClick = onAbout,
                )
            }

            Spacer(Modifier.height(32.dp))
        }
    }

    when (sheet) {
        null -> Unit

        SettingsSheet.SEARCH_BAR -> OptionSheet("Search Bar Position", { sheet = null }) {
            RadioRow(
                "Top", "Search bar appears at the top",
                selected = state.searchBarAtTop,
            ) { onSearchBarAtTop(true); sheet = null }
            RadioRow(
                "Bottom", "Search bar appears at the bottom",
                selected = !state.searchBarAtTop,
            ) { onSearchBarAtTop(false); sheet = null }
        }

        // Stays open after picking a layout, because the column slider below
        // only appears once Grid is chosen and is the next thing you want.
        SettingsSheet.LAYOUT -> OptionSheet("App Layout", { sheet = null }) {
            RadioRow(
                "List View", "Apps displayed in a vertical list",
                selected = state.layout == AppLayoutType.LIST,
            ) { onLayout(AppLayoutType.LIST) }
            RadioRow(
                "Grid View", "Apps displayed in a grid layout",
                selected = state.layout == AppLayoutType.GRID,
            ) { onLayout(AppLayoutType.GRID) }

            if (state.layout == AppLayoutType.GRID) {
                Spacer(Modifier.height(16.dp))
                Box(Modifier.fillMaxWidth().height(1.dp).background(Color.White.copy(alpha = 0.12f)))
                Spacer(Modifier.height(16.dp))

                Row(
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp),
                ) {
                    Text(
                        "Grid Columns",
                        color = TitleColor,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Box(
                        Modifier
                            .clip(RoundedCornerShape(12.dp))
                            .background(Accent.copy(alpha = 0.1f))
                            .padding(horizontal = 12.dp, vertical = 6.dp),
                    ) {
                        Text(
                            state.gridColumns.toString(),
                            color = AccentLight,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                }

                Slider(
                    value = state.gridColumns.toFloat(),
                    onValueChange = { onGridColumns(it.toInt()) },
                    valueRange = 2f..6f,
                    steps = 3,
                    colors = SliderDefaults.colors(
                        thumbColor = Accent,
                        activeTrackColor = Accent,
                    ),
                    modifier = Modifier.padding(horizontal = 20.dp),
                )
            }
        }
    }
}

/** Gradient banner at the top of the list. */
@Composable
private fun HeroCard() = Row(
    verticalAlignment = Alignment.CenterVertically,
    modifier = Modifier
        .fillMaxWidth()
        .clip(RoundedCornerShape(20.dp))
        .background(
            Brush.linearGradient(listOf(Accent, Accent.copy(alpha = 0.8f)))
        )
        .padding(24.dp),
) {
    Box(
        Modifier
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White.copy(alpha = 0.2f))
            .padding(16.dp),
    ) {
        Icon(
            Icons.Filled.Settings,
            contentDescription = null,
            tint = Color.White,
            modifier = Modifier.size(32.dp),
        )
    }
    Spacer(Modifier.width(20.dp))
    Column {
        Text(
            "FuseLauncher",
            color = Color.White,
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold,
        )
        Spacer(Modifier.height(4.dp))
        Text(
            "Customize your experience",
            color = Color.White.copy(alpha = 0.8f),
            fontSize = 14.sp,
        )
    }
}

@Composable
private fun CategoryHeader(title: String, icon: ImageVector) = Row(
    verticalAlignment = Alignment.CenterVertically,
    modifier = Modifier.padding(start = 4.dp, bottom = 8.dp),
) {
    Box(
        Modifier
            .clip(RoundedCornerShape(8.dp))
            .background(AccentLight.copy(alpha = 0.1f))
            .padding(6.dp),
    ) {
        Icon(icon, null, tint = AccentLight, modifier = Modifier.size(16.dp))
    }
    Spacer(Modifier.width(12.dp))
    Text(
        title.uppercase(),
        color = AccentLight,
        fontSize = 13.sp,
        fontWeight = FontWeight.SemiBold,
        letterSpacing = 1.2.sp,
    )
}

/** Rounded card with a tinted icon tile down its left edge. */
@Composable
private fun SettingsCard(
    icon: ImageVector,
    iconColor: Color,
    content: @Composable () -> Unit,
) = Row(
    verticalAlignment = Alignment.CenterVertically,
    modifier = Modifier
        .fillMaxWidth()
        .clip(RoundedCornerShape(20.dp))
        .background(CardSurface),
) {
    Box(
        Modifier
            .padding(20.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(iconColor.copy(alpha = 0.1f))
            .padding(12.dp),
    ) {
        Icon(icon, null, tint = iconColor, modifier = Modifier.size(24.dp))
    }
    Box(Modifier.weight(1f)) { content() }
}

@Composable
private fun NavigationRow(title: String, subtitle: String, onClick: () -> Unit) = Row(
    verticalAlignment = Alignment.CenterVertically,
    modifier = Modifier
        .fillMaxWidth()
        .clickable(onClick = onClick)
        .padding(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 8.dp),
) {
    Column(Modifier.weight(1f)) {
        Text(title, color = TitleColor, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
        Text(subtitle, color = SubtitleColor, fontSize = 14.sp)
    }
    Icon(
        Icons.AutoMirrored.Filled.KeyboardArrowRight,
        contentDescription = null,
        tint = ChevronColor,
    )
}

@Composable
private fun SwitchRow(
    title: String,
    subtitle: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) = Row(
    verticalAlignment = Alignment.CenterVertically,
    modifier = Modifier
        .fillMaxWidth()
        .clickable { onCheckedChange(!checked) }
        .padding(start = 20.dp, end = 12.dp, top = 8.dp, bottom = 8.dp),
) {
    Column(Modifier.weight(1f)) {
        Text(title, color = TitleColor, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
        Text(subtitle, color = SubtitleColor, fontSize = 14.sp)
    }
    Switch(
        checked = checked,
        onCheckedChange = onCheckedChange,
        colors = SwitchDefaults.colors(checkedTrackColor = Accent),
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun OptionSheet(
    title: String,
    onDismiss: () -> Unit,
    content: @Composable () -> Unit,
) = ModalBottomSheet(
    onDismissRequest = onDismiss,
    containerColor = PopupSurface,
) {
    Column(Modifier.navigationBarsPadding()) {
        Text(
            title,
            color = TitleColor,
            fontSize = 20.sp,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(20.dp),
        )
        content()
        Spacer(Modifier.height(16.dp))
    }
}

@Composable
private fun RadioRow(
    title: String,
    subtitle: String,
    selected: Boolean,
    onClick: () -> Unit,
) = Row(
    verticalAlignment = Alignment.CenterVertically,
    modifier = Modifier
        .fillMaxWidth()
        .clickable(onClick = onClick)
        .padding(horizontal = 12.dp, vertical = 4.dp),
) {
    RadioButton(
        selected = selected,
        onClick = onClick,
        colors = RadioButtonDefaults.colors(selectedColor = Accent),
    )
    Spacer(Modifier.width(8.dp))
    Column {
        Text(title, color = TitleColor, fontSize = 16.sp)
        Text(subtitle, color = SubtitleColor, fontSize = 14.sp)
    }
}
