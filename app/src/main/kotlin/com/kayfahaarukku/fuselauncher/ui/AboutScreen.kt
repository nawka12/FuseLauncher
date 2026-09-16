package com.kayfahaarukku.fuselauncher.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBackIos
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.StarBorder
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kayfahaarukku.fuselauncher.R

private val Accent = Color(0xFF6750A4)
private val CardSurface = Color(0xFF2D2D2D)
private val TitleColor = Color.White
private val SubtitleColor = Color.White.copy(alpha = 0.6f)

private val BlueVersion = Color(0xFF2196F3)
private val PurpleDeveloper = Color(0xFF9C27B0)
private val GreenFeatures = Color(0xFF4CAF50)

private val FEATURES = listOf(
    "Clean and modern interface",
    "Customizable app layout",
    "Smart app organization",
    "Widget support",
    "Notification badges",
)

/**
 * Transparent like the settings screen: the wallpaper and its scrim carry
 * through behind the cards, matching the Flutter build's Scaffold.
 */
@Composable
fun AboutScreen(versionName: String, versionCode: Long, onBack: () -> Unit) {
    // Flutter pushed a fresh page each time, so it always opened at the top.
    val scroll = rememberScrollState()
    LaunchedEffect(Unit) { scroll.scrollTo(0) }
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
            Text("About", color = TitleColor, fontSize = 24.sp, fontWeight = FontWeight.SemiBold)
        }

        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier
                .verticalScroll(scroll)
                .padding(20.dp),
        ) {
            Spacer(Modifier.height(40.dp))

            HeroCard()

            Spacer(Modifier.height(32.dp))

            InfoCard(
                icon = Icons.Outlined.Info,
                iconColor = BlueVersion,
                title = "Version Information",
                subtitle = "Version $versionName (Build $versionCode)",
            )

            Spacer(Modifier.height(16.dp))

            InfoCard(
                icon = Icons.Outlined.Person,
                iconColor = PurpleDeveloper,
                title = "Developer",
                subtitle = "KayfaHaarukku (nawka12)",
            )

            Spacer(Modifier.height(16.dp))

            FeaturesCard()

            Spacer(Modifier.height(40.dp))
        }
    }
}

@Composable
private fun HeroCard() = Column(
    horizontalAlignment = Alignment.CenterHorizontally,
    modifier = Modifier
        .fillMaxWidth()
        .clip(RoundedCornerShape(24.dp))
        .background(Brush.linearGradient(listOf(Accent, Accent.copy(alpha = 0.8f))))
        .padding(32.dp),
) {
    Image(
        painter = painterResource(R.drawable.app_logo),
        contentDescription = null,
        contentScale = ContentScale.Crop,
        modifier = Modifier
            .size(120.dp)
            .clip(RoundedCornerShape(28.dp))
            .background(Color.White.copy(alpha = 0.1f)),
    )

    Spacer(Modifier.height(24.dp))

    Text(
        "FuseLauncher",
        color = Color.White,
        fontSize = 32.sp,
        fontWeight = FontWeight.Bold,
        letterSpacing = 0.5.sp,
    )

    Spacer(Modifier.height(8.dp))

    Text(
        "A modern Android launcher",
        color = Color.White.copy(alpha = 0.8f),
        fontSize = 16.sp,
    )
}

/** Tinted icon tile beside a title and one line of detail. */
@Composable
private fun InfoCard(
    icon: ImageVector,
    iconColor: Color,
    title: String,
    subtitle: String,
) = Row(
    verticalAlignment = Alignment.CenterVertically,
    modifier = Modifier
        .fillMaxWidth()
        .clip(RoundedCornerShape(20.dp))
        .background(CardSurface)
        .padding(24.dp),
) {
    IconTile(icon, iconColor)
    Spacer(Modifier.width(16.dp))
    Column {
        Text(title, color = TitleColor, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.height(4.dp))
        Text(subtitle, color = SubtitleColor, fontSize = 14.sp)
    }
}

@Composable
private fun FeaturesCard() = Column(
    Modifier
        .fillMaxWidth()
        .clip(RoundedCornerShape(20.dp))
        .background(CardSurface)
        .padding(24.dp),
) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        IconTile(Icons.Outlined.StarBorder, GreenFeatures)
        Spacer(Modifier.width(16.dp))
        Text("Key Features", color = TitleColor, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
    }

    Spacer(Modifier.height(16.dp))

    FEATURES.forEach { feature ->
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(bottom = 8.dp),
        ) {
            Box(Modifier.size(6.dp).clip(RoundedCornerShape(3.dp)).background(Accent))
            Spacer(Modifier.width(12.dp))
            Text(feature, color = SubtitleColor, fontSize = 14.sp)
        }
    }
}

@Composable
private fun IconTile(icon: ImageVector, tint: Color) = Box(
    Modifier
        .clip(RoundedCornerShape(14.dp))
        .background(tint.copy(alpha = 0.1f))
        .padding(12.dp),
) {
    Icon(icon, null, tint = tint, modifier = Modifier.size(24.dp))
}
