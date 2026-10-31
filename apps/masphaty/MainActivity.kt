package app.main

import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material.icons.outlined.Book
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.DarkMode
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.VolumeUp
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.Mosque
import androidx.compose.material.icons.rounded.NightsStay
import androidx.compose.material.icons.rounded.WbSunny
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject

// ============================================================================
// THEME & COLOR PALETTE DEFINITION (Emerald Serenity Palette)
// ============================================================================

private val LightColorScheme = lightColorScheme(
    primary = Color(0xFF006B4D),
    onPrimary = Color(0xFFFFFFFF),
    primaryContainer = Color(0xFF83F8C9),
    onPrimaryContainer = Color(0xFF002115),
    secondary = Color(0xFF4D6356),
    onSecondary = Color(0xFFFFFFFF),
    secondaryContainer = Color(0xFFCFE9D7),
    onSecondaryContainer = Color(0xFF092015),
    tertiary = Color(0xFF835400),
    onTertiary = Color(0xFFFFFFFF),
    tertiaryContainer = Color(0xFFFFDDAE),
    onTertiaryContainer = Color(0xFF2A1700),
    background = Color(0xFFF5FBF6),
    onBackground = Color(0xFF171D1A),
    surface = Color(0xFFF5FBF6),
    onSurface = Color(0xFF171D1A),
    surfaceVariant = Color(0xFFDBE5DD),
    onSurfaceVariant = Color(0xFF404943),
    outline = Color(0xFF707973),
    outlineVariant = Color(0xFFBFC9C1)
)

private val DarkColorScheme = darkColorScheme(
    primary = Color(0xFF66DBAE),
    onPrimary = Color(0xFF003826),
    primaryContainer = Color(0xFF005239),
    onPrimaryContainer = Color(0xFF83F8C9),
    secondary = Color(0xFFB3CCBC),
    onSecondary = Color(0xFF1F3529),
    secondaryContainer = Color(0xFF354B3F),
    onSecondaryContainer = Color(0xFFCFE9D7),
    tertiary = Color(0xFFFFBA66),
    onTertiary = Color(0xFF462A00),
    tertiaryContainer = Color(0xFF643E00),
    onTertiaryContainer = Color(0xFFFFDDAE),
    background = Color(0xFF0F1512),
    onBackground = Color(0xFFE0E4E0),
    surface = Color(0xFF0F1512),
    onSurface = Color(0xFFE0E4E0),
    surfaceVariant = Color(0xFF404943),
    onSurfaceVariant = Color(0xFFBFC9C1),
    outline = Color(0xFF89938C),
    outlineVariant = Color(0xFF404943)
)

@Composable
fun AppTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme
    MaterialTheme(
        colorScheme = colorScheme,
        content = content
    )
}

// ============================================================================
// DATA MODELS
// ============================================================================

data class DhikrItem(
    val id: String,
    val text: String,
    val benefit: String,
    val defaultTarget: Int,
    val category: String
)

data class AdhkarCategory(
    val title: String,
    val countText: String,
    val iconType: String,
    val initialProgress: Float
)

// ============================================================================
// MAIN ACTIVITY
// ============================================================================

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            val context = LocalContext.current
            val prefs = remember { context.getSharedPreferences("masphaty_prefs", Context.MODE_PRIVATE) }
            var isDarkTheme by remember { mutableStateOf(prefs.getBoolean("dark_theme", false)) }

            AppTheme(darkTheme = isDarkTheme) {
                CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
                    App(
                        prefs = prefs,
                        isDarkTheme = isDarkTheme,
                        onToggleTheme = {
                            isDarkTheme = !isDarkTheme
                            prefs.edit().putBoolean("dark_theme", isDarkTheme).apply()
                        }
                    )
                }
            }
        }
    }
}

// ============================================================================
// MAIN APP COMPOSABLE & NAVIGATION
// ============================================================================

@Composable
fun App(
    prefs: SharedPreferences,
    isDarkTheme: Boolean,
    onToggleTheme: () -> Unit
) {
    val navController = rememberNavController()
    val snackbarHostState = remember { SnackbarHostState() }
    val coroutineScope = rememberCoroutineScope()

    // Counter States persisted
    var count by remember { mutableIntStateOf(prefs.getInt("current_count", 14)) }
    var target by remember { mutableIntStateOf(prefs.getInt("current_target", 33)) }
    var totalDaily by remember { mutableIntStateOf(prefs.getInt("total_daily", 650)) }
    var currentDhikrText by remember { mutableStateOf(prefs.getString("current_dhikr", "سُبْحَانَ اللَّهِ") ?: "سُبْحَانَ اللَّهِ") }
    var currentDhikrSub by remember { mutableStateOf(prefs.getString("current_dhikr_sub", "فضل الذكر: غراس الجنة وأحب الكلام إلى الله") ?: "فضل الذكر: غراس الجنة وأحب الكلام إلى الله") }
    var soundEnabled by remember { mutableStateOf(prefs.getBoolean("sound_enabled", true)) }
    var hapticsEnabled by remember { mutableStateOf(prefs.getBoolean("haptics_enabled", true)) }

    // Custom Dhikr list state persisted in JSON
    val customDhikrs = remember { mutableStateListOf<DhikrItem>() }

    LaunchedEffect(Unit) {
        val jsonStr = prefs.getString("custom_dhikrs_json", null)
        if (!jsonStr.isNullOrEmpty()) {
            try {
                val array = JSONArray(jsonStr)
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    customDhikrs.add(
                        DhikrItem(
                            id = obj.getString("id"),
                            text = obj.getString("text"),
                            benefit = obj.getString("benefit"),
                            defaultTarget = obj.getInt("defaultTarget"),
                            category = obj.getString("category")
                        )
                    )
                }
            } catch (_: Exception) {}
        }
    }

    fun saveCountState(newCount: Int, newTarget: Int) {
        count = newCount
        target = newTarget
        prefs.edit()
            .putInt("current_count", newCount)
            .putInt("current_target", newTarget)
            .putInt("total_daily", totalDaily)
            .putString("current_dhikr", currentDhikrText)
            .apply()
    }

    var showTargetSheet by remember { mutableStateOf(false) }
    var showAddCustomSheet by remember { mutableStateOf(false) }

    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route ?: "counter"

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.Center
                    ) {
                        Icon(
                            imageVector = Icons.Rounded.Mosque,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(26.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = when (currentRoute) {
                                "counter" -> "المسبحة الإلكترونية"
                                "library" -> "حصن المسلم والأذكار"
                                "reader" -> "قراءة الذكر"
                                "stats" -> "إحصائيات التسبيح"
                                "settings" -> "إعدادات التطبيق"
                                else -> "تسبيح"
                            },
                            fontWeight = FontWeight.Bold,
                            fontSize = 20.sp
                        )
                    }
                },
                actions = {
                    IconButton(onClick = onToggleTheme) {
                        Icon(
                            imageVector = Icons.Outlined.DarkMode,
                            contentDescription = "المظهر",
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    if (currentRoute == "counter") {
                        IconButton(onClick = { showTargetSheet = true }) {
                            Icon(
                                imageVector = Icons.Filled.Edit,
                                contentDescription = "تعديل الهدف",
                                tint = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface
                )
            )
        },
        bottomBar = {
            NavigationBar(
                containerColor = MaterialTheme.colorScheme.surfaceContainer,
                tonalElevation = 4.dp
            ) {
                NavigationBarItem(
                    selected = currentRoute == "counter",
                    onClick = { navController.navigate("counter") },
                    icon = { Icon(Icons.Outlined.Refresh, contentDescription = null) },
                    label = { Text("المسبحة") },
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = MaterialTheme.colorScheme.onSecondaryContainer,
                        selectedTextColor = MaterialTheme.colorScheme.onSurface,
                        indicatorColor = MaterialTheme.colorScheme.secondaryContainer
                    )
                )
                NavigationBarItem(
                    selected = currentRoute == "library",
                    onClick = { navController.navigate("library") },
                    icon = { Icon(Icons.Outlined.Book, contentDescription = null) },
                    label = { Text("الأذكار") },
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = MaterialTheme.colorScheme.onSecondaryContainer,
                        selectedTextColor = MaterialTheme.colorScheme.onSurface,
                        indicatorColor = MaterialTheme.colorScheme.secondaryContainer
                    )
                )
                NavigationBarItem(
                    selected = currentRoute == "stats",
                    onClick = { navController.navigate("stats") },
                    icon = { Icon(Icons.Outlined.BarChart, contentDescription = null) },
                    label = { Text("الإحصائيات") },
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = MaterialTheme.colorScheme.onSecondaryContainer,
                        selectedTextColor = MaterialTheme.colorScheme.onSurface,
                        indicatorColor = MaterialTheme.colorScheme.secondaryContainer
                    )
                )
                NavigationBarItem(
                    selected = currentRoute == "settings",
                    onClick = { navController.navigate("settings") },
                    icon = { Icon(Icons.Outlined.Settings, contentDescription = null) },
                    label = { Text("الإعدادات") },
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = MaterialTheme.colorScheme.onSecondaryContainer,
                        selectedTextColor = MaterialTheme.colorScheme.onSurface,
                        indicatorColor = MaterialTheme.colorScheme.secondaryContainer
                    )
                )
            }
        }
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = "counter",
            modifier = Modifier.padding(innerPadding)
        ) {
            composable("counter") {
                CounterScreen(
                    count = count,
                    target = target,
                    totalDaily = totalDaily,
                    dhikrText = currentDhikrText,
                    dhikrSub = currentDhikrSub,
                    soundEnabled = soundEnabled,
                    onIncrement = {
                        val newC = if (count >= target) target else count + 1
                        val newTot = totalDaily + 1
                        totalDaily = newTot
                        saveCountState(newC, target)
                    },
                    onReset = { saveCountState(0, target) },
                    onToggleSound = {
                        soundEnabled = !soundEnabled
                        prefs.edit().putBoolean("sound_enabled", soundEnabled).apply()
                    },
                    onSelectDhikr = { title, sub, t ->
                        currentDhikrText = title
                        currentDhikrSub = sub
                        saveCountState(0, t)
                    },
                    onOpenTargetModal = { showTargetSheet = true }
                )
            }

            composable("library") {
                LibraryScreen(
                    customDhikrs = customDhikrs,
                    onSelectCategory = { navController.navigate("reader") },
                    onOpenAddModal = { showAddCustomSheet = true }
                )
            }

            composable("reader") {
                ReaderScreen(
                    onBack = { navController.popBackStack() },
                    onCompleted = {
                        coroutineScope.launch {
                            snackbarHostState.showSnackbar("تقبل الله طاعتكم وأثابكم خير الجزاء")
                        }
                    }
                )
            }

            composable("stats") {
                StatsScreen(totalCount = totalDaily + 13600)
            }

            composable("settings") {
                SettingsScreen(
                    isDarkTheme = isDarkTheme,
                    onToggleTheme = onToggleTheme,
                    soundEnabled = soundEnabled,
                    onToggleSound = {
                        soundEnabled = !soundEnabled
                        prefs.edit().putBoolean("sound_enabled", soundEnabled).apply()
                    },
                    hapticsEnabled = hapticsEnabled,
                    onToggleHaptics = {
                        hapticsEnabled = !hapticsEnabled
                        prefs.edit().putBoolean("haptics_enabled", hapticsEnabled).apply()
                    }
                )
            }
        }

        // Target Modal Bottom Sheet
        if (showTargetSheet) {
            ModalBottomSheet(
                onDismissRequest = { showTargetSheet = false },
                sheetState = rememberModalBottomSheetState()
            ) {
                TargetSheetContent(
                    currentTarget = target,
                    onSaveTarget = { newTarget ->
                        saveCountState(count.coerceAtMost(newTarget), newTarget)
                        showTargetSheet = false
                    }
                )
            }
        }

        // Add Custom Dhikr Bottom Sheet
        if (showAddCustomSheet) {
            ModalBottomSheet(
                onDismissRequest = { showAddCustomSheet = false },
                sheetState = rememberModalBottomSheetState()
            ) {
                AddCustomSheetContent(
                    onAdd = { newItem ->
                        customDhikrs.add(newItem)
                        showAddCustomSheet = false
                        // Save JSON array to prefs
                        val jsonArr = JSONArray()
                        customDhikrs.forEach { d ->
                            val obj = JSONObject()
                            obj.put("id", d.id)
                            obj.put("text", d.text)
                            obj.put("benefit", d.benefit)
                            obj.put("defaultTarget", d.defaultTarget)
                            obj.put("category", d.category)
                            jsonArr.put(obj)
                        }
                        prefs.edit().putString("custom_dhikrs_json", jsonArr.toString()).apply()
                        coroutineScope.launch {
                            snackbarHostState.showSnackbar("تمت إضافة الذكر المخصص بنجاح")
                        }
                    }
                )
            }
        }
    }
}

// ============================================================================
// SCREEN 1: COUNTER SCREEN
// ============================================================================

@Composable
fun CounterScreen(
    count: Int,
    target: Int,
    totalDaily: Int,
    dhikrText: String,
    dhikrSub: String,
    soundEnabled: Boolean,
    onIncrement: () -> Unit,
    onReset: () -> Unit,
    onToggleSound: () -> Unit,
    onSelectDhikr: (String, String, Int) -> Unit,
    onOpenTargetModal: () -> Unit
) {
    val presets = listOf(
        Triple("سُبْحَانَ اللَّهِ", "فضل الذكر: غراس الجنة وأحب الكلام إلى الله", 33),
        Triple("الْحَمْدُ لِلَّهِ", "فضل الذكر: تملأ الميزان بالخيرات والحسنات", 33),
        Triple("اللَّهُ أَكْبَرُ", "فضل الذكر: من أعظم الأذكار قدرًا وأجرًا", 33),
        Triple("أَسْتَغْفِرُ اللَّهَ", "فضل الذكر: تفتتح بها أبواب الرزق والفرج", 100),
        Triple("لَا إِلَهَ إِلَّا اللَّهُ", "فضل الذكر: أفضل ما قال النبيون وأفضل الذكر", 100)
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Daily Streak Banner
        Card(
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.primaryContainer,
                contentColor = MaterialTheme.colorScheme.onPrimaryContainer
            ),
            shape = RoundedCornerShape(20.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .size(40.dp)
                            .background(Color.White.copy(alpha = 0.25f), CircleShape),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Rounded.LocalFireDepartment,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onPrimaryContainer
                        )
                    }
                    Spacer(modifier = Modifier.width(12.dp))
                    Column {
                        Text(
                            text = "سلسلة التسبيح اليومي",
                            fontWeight = FontWeight.Bold,
                            fontSize = 15.sp
                        )
                        Text(
                            text = "7 أيام متتالية من المواظبة والأذكار",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.8f)
                        )
                    }
                }
                Surface(
                    color = MaterialTheme.colorScheme.onPrimaryContainer,
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Text(
                        text = "ممتاز",
                        color = MaterialTheme.colorScheme.primaryContainer,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.ExtraBold,
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp)
                    )
                }
            }
        }

        // Horizontal Dhikr Preset Selector Chips
        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(presets) { item ->
                val isSelected = dhikrText == item.first
                FilterChip(
                    selected = isSelected,
                    onClick = { onSelectDhikr(item.first, item.second, item.third) },
                    label = { Text("${item.first} (${item.third})") },
                    colors = FilterChipDefaults.filterChipColors(
                        selectedContainerColor = MaterialTheme.colorScheme.secondaryContainer,
                        selectedLabelColor = MaterialTheme.colorScheme.onSecondaryContainer
                    )
                )
            }
        }

        // Current Active Dhikr Info Card
        Card(
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
            shape = RoundedCornerShape(16.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(14.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = dhikrText,
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = dhikrSub,
                    fontSize = 13.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center
                )
            }
        }

        // Main Hero Circular Gauge Counter Button
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f),
            contentAlignment = Alignment.Center
        ) {
            val primaryColor = MaterialTheme.colorScheme.primary
            val trackColor = MaterialTheme.colorScheme.surfaceContainerHighest
            val progress = (count.toFloat() / target.toFloat()).coerceIn(0f, 1f)

            Box(
                modifier = Modifier
                    .size(240.dp)
                    .clip(CircleShape)
                    .clickable { onIncrement() },
                contentAlignment = Alignment.Center
            ) {
                Canvas(modifier = Modifier.fillMaxSize()) {
                    val strokeWidth = 12.dp.toPx()
                    val radius = (size.minDimension - strokeWidth) / 2
                    val center = Offset(size.width / 2, size.height / 2)

                    // Track Ring
                    drawCircle(
                        color = trackColor,
                        radius = radius,
                        center = center,
                        style = Stroke(width = strokeWidth)
                    )

                    // Progress Ring
                    drawArc(
                        color = primaryColor,
                        startAngle = -90f,
                        sweepAngle = 360f * progress,
                        useCenter = false,
                        topLeft = Offset(center.x - radius, center.y - radius),
                        size = Size(radius * 2, radius * 2),
                        style = Stroke(width = strokeWidth, cap = StrokeCap.Round)
                    )
                }

                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = "$count",
                        fontSize = 56.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Text(
                        text = "الهدف: $target",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }

        // Quick Control Actions Grid
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            OutlinedButton(
                onClick = onReset,
                modifier = Modifier.weight(1f),
                shape = RoundedCornerShape(12.dp)
            ) {
                Icon(Icons.Outlined.Refresh, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(modifier = Modifier.width(4.dp))
                Text("إعادة", fontSize = 13.sp)
            }
            OutlinedButton(
                onClick = onToggleSound,
                modifier = Modifier.weight(1f),
                shape = RoundedCornerShape(12.dp)
            ) {
                Icon(Icons.Outlined.VolumeUp, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(modifier = Modifier.width(4.dp))
                Text(if (soundEnabled) "صوت: مفعل" else "صوت: صامت", fontSize = 13.sp)
            }
            OutlinedButton(
                onClick = onOpenTargetModal,
                modifier = Modifier.weight(1f),
                shape = RoundedCornerShape(12.dp)
            ) {
                Icon(Icons.Filled.Edit, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(modifier = Modifier.width(4.dp))
                Text("تعديل", fontSize = 13.sp)
            }
        }

        // Daily Progress Card
        ElevatedCard(
            shape = RoundedCornerShape(16.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(text = "هدف التسبيح اليومي العام", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                    Text(
                        text = "${((totalDaily.toFloat() / 1000f) * 100).toInt().coerceAtMost(100)}%",
                        color = MaterialTheme.colorScheme.primary,
                        fontWeight = FontWeight.Bold,
                        fontSize = 14.sp
                    )
                }
                Spacer(modifier = Modifier.height(8.dp))
                LinearProgressIndicator(
                    progress = { (totalDaily.toFloat() / 1000f).coerceIn(0f, 1f) },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(10.dp)
                        .clip(CircleShape),
                    color = MaterialTheme.colorScheme.primary,
                    trackColor = MaterialTheme.colorScheme.surfaceContainerHighest
                )
                Spacer(modifier = Modifier.height(6.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(text = "تم إنجاز: $totalDaily تسبيحة", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(text = "الهدف: 1000", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }
}

// ============================================================================
// SCREEN 2: ADHKAR LIBRARY SCREEN
// ============================================================================

@Composable
fun LibraryScreen(
    customDhikrs: List<DhikrItem>,
    onSelectCategory: () -> Unit,
    onOpenAddModal: () -> Unit
) {
    var searchQuery by remember { mutableStateOf("") }
    var selectedTab by remember { mutableIntStateOf(0) }

    val categories = listOf(
        AdhkarCategory("أذكار الصباح", "24 ذكراً • مكتمل 12/24", "morning", 0.5f),
        AdhkarCategory("أذكار المساء", "20 ذكراً • يبدأ بعد قليل", "night", 0.0f),
        AdhkarCategory("أذكار بعد الصلاة", "10 أذكار • مكتمل 100%", "prayer", 1.0f),
        AdhkarCategory("أذكار النوم والاستيقاظ", "15 ذكراً", "sleep", 0.2f)
    )

    Box(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // Search Outlined Input
            OutlinedTextField(
                value = searchQuery,
                onValueChange = { searchQuery = it },
                placeholder = { Text("ابحث في أذكار حصن المسلم...") },
                trailingIcon = { Icon(Icons.Filled.Search, contentDescription = null) },
                singleLine = true,
                shape = RoundedCornerShape(24.dp),
                colors = OutlinedTextFieldDefaults.colors(
                    unfocusedContainerColor = MaterialTheme.colorScheme.surfaceContainerLow,
                    focusedContainerColor = MaterialTheme.colorScheme.surfaceContainerLow
                ),
                modifier = Modifier.fillMaxWidth()
            )

            // Category Filter Chips
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                val filters = listOf("الكل", "أذكار الصباح والمساء", "بعد الصلاة", "أدعية قرآنية")
                items(filters.size) { index ->
                    FilterChip(
                        selected = selectedTab == index,
                        onClick = { selectedTab = index },
                        label = { Text(filters[index]) }
                    )
                }
            }

            // Categories List
            LazyColumn(
                verticalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.weight(1f)
            ) {
                items(categories) { cat ->
                    Card(
                        onClick = onSelectCategory,
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow),
                        shape = RoundedCornerShape(20.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(16.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Box(
                                    modifier = Modifier
                                        .size(48.dp)
                                        .background(
                                            when (cat.iconType) {
                                                "morning" -> MaterialTheme.colorScheme.primaryContainer
                                                "night" -> MaterialTheme.colorScheme.secondaryContainer
                                                else -> MaterialTheme.colorScheme.tertiaryContainer
                                            },
                                            RoundedCornerShape(12.dp)
                                        ),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Icon(
                                        imageVector = when (cat.iconType) {
                                            "morning" -> Icons.Rounded.WbSunny
                                            "night" -> Icons.Rounded.NightsStay
                                            else -> Icons.Rounded.Mosque
                                        },
                                        contentDescription = null,
                                        tint = when (cat.iconType) {
                                            "morning" -> MaterialTheme.colorScheme.onPrimaryContainer
                                            "night" -> MaterialTheme.colorScheme.onSecondaryContainer
                                            else -> MaterialTheme.colorScheme.onTertiaryContainer
                                        }
                                    )
                                }
                                Spacer(modifier = Modifier.width(14.dp))
                                Column {
                                    Text(text = cat.title, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                                    Text(
                                        text = cat.countText,
                                        fontSize = 12.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                    Spacer(modifier = Modifier.height(6.dp))
                                    LinearProgressIndicator(
                                        progress = { cat.initialProgress },
                                        modifier = Modifier
                                            .width(140.dp)
                                            .height(4.dp)
                                            .clip(CircleShape)
                                    )
                                }
                            }
                            Icon(
                                imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.outline
                            )
                        }
                    }
                }

                // Custom Dhikrs Header & Section if any
                if (customDhikrs.isNotEmpty()) {
                    item {
                        Text(
                            text = "أذكاري المخصصة",
                            fontWeight = FontWeight.Bold,
                            fontSize = 16.sp,
                            color = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.padding(top = 8.dp)
                        )
                    }
                    items(customDhikrs) { item ->
                        Card(
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerHigh),
                            shape = RoundedCornerShape(16.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(14.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(text = item.text, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                                    Text(text = "الهدف: ${item.defaultTarget} مرة • ${item.benefit}", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                                Icon(Icons.Filled.Star, contentDescription = null, tint = MaterialTheme.colorScheme.tertiary)
                            }
                        }
                    }
                }
            }
        }

        // Floating Action Button for Adding Custom Dhikr
        FloatingActionButton(
            onClick = onOpenAddModal,
            containerColor = MaterialTheme.colorScheme.primaryContainer,
            contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(20.dp)
        ) {
            Row(
                modifier = Modifier.padding(horizontal = 16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(Icons.Filled.Add, contentDescription = null)
                Spacer(modifier = Modifier.width(8.dp))
                Text("ذكر مخصص", fontWeight = FontWeight.Bold)
            }
        }
    }
}

// ============================================================================
// SCREEN 3: ADHKAR READER SCREEN
// ============================================================================

@Composable
fun ReaderScreen(
    onBack: () -> Unit,
    onCompleted: () -> Unit
) {
    var repeatCount by remember { mutableIntStateOf(3) }
    var currentRepeat by remember { mutableIntStateOf(1) }

    val readerList = listOf(
        Pair(
            "اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَنْ ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلَّا بِإِذْنِهِ...",
            "الفضل: من قالها حين يصبح أُجير من الجن حتى يمسي، ومن قالها حين يمسي أُجير منهم حتى يصبح."
        ),
        Pair(
            "قُلْ هُوَ اللَّهُ أَحَدٌ (1) اللَّهُ الصَّمَدُ (2) لَمْ يَلِدْ وَلَمْ يُولَدْ (3) وَلَمْ يَكُنْ لَهُ كُفُوًا أَحَدٌ",
            "الفضل: تكفيك من كل شيء إذا قرأتها ثلاث مرات صباحًا ومساءً."
        )
    )

    var currentIndex by remember { mutableIntStateOf(0) }
    val item = readerList[currentIndex]

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Top Header Info
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text(
                    text = "أذكار الصباح (${currentIndex + 1} من ${readerList.size})",
                    fontSize = 13.sp,
                    color = MaterialTheme.colorScheme.primary,
                    fontWeight = FontWeight.SemiBold
                )
                Text(
                    text = if (currentIndex == 0) "آية الكرسي" else "سورة الإخلاص",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold
                )
            }
            IconButton(onClick = onBack) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "رجوع")
            }
        }

        // Reader Linear Progress
        LinearProgressIndicator(
            progress = { (currentIndex + 1).toFloat() / readerList.size.toFloat() },
            modifier = Modifier
                .fillMaxWidth()
                .height(6.dp)
                .clip(CircleShape)
        )

        // Main Reader Card
        Card(
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow),
            shape = RoundedCornerShape(24.dp),
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(20.dp),
                verticalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = item.first,
                    fontSize = 22.sp,
                    lineHeight = 40.sp,
                    fontWeight = FontWeight.Medium,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 16.dp)
                )

                Surface(
                    color = MaterialTheme.colorScheme.surfaceContainer,
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(
                        text = item.second,
                        fontSize = 13.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(12.dp)
                    )
                }
            }
        }

        // Stepper Count Action Button
        Button(
            onClick = {
                if (currentRepeat < repeatCount) {
                    currentRepeat++
                } else {
                    if (currentIndex < readerList.size - 1) {
                        currentIndex++
                        currentRepeat = 1
                    } else {
                        onCompleted()
                    }
                }
            },
            colors = ButtonDefaults.buttonColors(
                containerColor = if (currentRepeat >= repeatCount && currentIndex == readerList.size - 1) Color(0xFF4CAF50) else MaterialTheme.colorScheme.primary
            ),
            shape = RoundedCornerShape(32.dp),
            modifier = Modifier
                .fillMaxWidth()
                .height(60.dp)
        ) {
            Icon(Icons.Filled.Check, contentDescription = null)
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = if (currentRepeat >= repeatCount && currentIndex == readerList.size - 1) "تم الانتهاء ✓" else "تكرار: $currentRepeat / $repeatCount",
                fontSize = 17.sp,
                fontWeight = FontWeight.Bold
            )
        }

        // Navigation Stepper Buttons
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            OutlinedButton(
                onClick = { if (currentIndex > 0) currentIndex-- },
                enabled = currentIndex > 0,
                modifier = Modifier.weight(1f),
                shape = RoundedCornerShape(12.dp)
            ) {
                Text("السابق")
            }
            OutlinedButton(
                onClick = { if (currentIndex < readerList.size - 1) currentIndex++ },
                enabled = currentIndex < readerList.size - 1,
                modifier = Modifier.weight(1f),
                shape = RoundedCornerShape(12.dp)
            ) {
                Text("التالي")
            }
        }
    }
}

// ============================================================================
// SCREEN 4: STATISTICS SCREEN
// ============================================================================

@Composable
fun StatsScreen(totalCount: Int) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(text = "ملخص النشاط والتسبيح", fontWeight = FontWeight.Bold, fontSize = 18.sp)

        // KPI Summary Cards
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            ElevatedCard(
                shape = RoundedCornerShape(20.dp),
                modifier = Modifier.weight(1f)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(text = "إجمالي التسبيحات", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(text = "$totalCount", fontSize = 24.sp, fontWeight = FontWeight.ExtraBold, color = MaterialTheme.colorScheme.primary)
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(text = "▲ 12% هذا الأسبوع", fontSize = 11.sp, color = Color(0xFF4CAF50), fontWeight = FontWeight.Bold)
                }
            }

            ElevatedCard(
                shape = RoundedCornerShape(20.dp),
                modifier = Modifier.weight(1f)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(text = "الأيام المتتالية", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(text = "7 أيام", fontSize = 24.sp, fontWeight = FontWeight.ExtraBold, color = MaterialTheme.colorScheme.tertiary)
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(text = "أفضل سلسلة: 14 يوم", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }

        // Weekly Activity Custom Bar Chart Card
        Card(
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow),
            shape = RoundedCornerShape(20.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(text = "النشاط الأسبوعي", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                    Text(text = "المجموع: 3,400", fontSize = 12.sp, color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                }

                Spacer(modifier = Modifier.height(16.dp))

                val weeklyData = listOf(
                    Pair("الأحد", 0.45f),
                    Pair("الإثنين", 0.70f),
                    Pair("الثلاثاء", 0.90f),
                    Pair("الأربعاء", 0.35f),
                    Pair("الخميس", 0.60f),
                    Pair("الجمعة", 1.0f),
                    Pair("السبت", 0.50f)
                )

                val primaryColor = MaterialTheme.colorScheme.primary
                val containerColor = MaterialTheme.colorScheme.primaryContainer

                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(130.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.Bottom
                ) {
                    weeklyData.forEach { pair ->
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.Bottom,
                            modifier = Modifier.fillMaxHeight()
                        ) {
                            Box(
                                modifier = Modifier
                                    .width(26.dp)
                                    .fillMaxHeight(pair.second)
                                    .clip(RoundedCornerShape(topStart = 6.dp, topEnd = 6.dp))
                                    .background(if (pair.second == 1.0f) primaryColor else containerColor)
                            )
                            Spacer(modifier = Modifier.height(6.dp))
                            Text(text = pair.first, fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
            }
        }

        // Top Repeated Adhkar List Card
        Card(
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow),
            shape = RoundedCornerShape(20.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(text = "الأذكار الأكثر تكراراً", fontWeight = FontWeight.Bold, fontSize = 15.sp)

                val breakdown = listOf(
                    Pair("أستغفر الله العظيم", 0.75f to "5,200 مرة"),
                    Pair("سبحان الله وبحمده", 0.55f to "3,800 مرة"),
                    Pair("الصلاة على النبي ﷺ", 0.40f to "2,900 مرة")
                )

                breakdown.forEach { b ->
                    Column {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text(text = b.first, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                            Text(text = b.second.second, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Spacer(modifier = Modifier.height(4.dp))
                        LinearProgressIndicator(
                            progress = { b.second.first },
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(6.dp)
                                .clip(CircleShape),
                            color = MaterialTheme.colorScheme.primary,
                            trackColor = MaterialTheme.colorScheme.surfaceContainerHighest
                        )
                    }
                }
            }
        }
    }
}

// ============================================================================
// SCREEN 5: SETTINGS SCREEN
// ============================================================================

@Composable
fun SettingsScreen(
    isDarkTheme: Boolean,
    onToggleTheme: () -> Unit,
    soundEnabled: Boolean,
    onToggleSound: () -> Unit,
    hapticsEnabled: Boolean,
    onToggleHaptics: () -> Unit
) {
    var fontSlider by remember { mutableFloatStateOf(22f) }
    var reminderEnabled by remember { mutableStateOf(true) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(text = "إعدادات التطبيق", fontWeight = FontWeight.Bold, fontSize = 18.sp)

        Card(
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow),
            shape = RoundedCornerShape(20.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    text = "التنبيهات والصوت",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary
                )

                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 8.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(text = "صوت النقر", fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
                        Text(text = "إصدار صوت خفيف عند كل تسبيحة", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Switch(checked = soundEnabled, onCheckedChange = { onToggleSound() })
                }

                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 8.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(text = "الاهتزاز (Haptics)", fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
                        Text(text = "اهتزاز هادئ عند اكتمال الهدف", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Switch(checked = hapticsEnabled, onCheckedChange = { onToggleHaptics() })
                }

                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 8.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(text = "تذكير الأذكار اليومية", fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
                        Text(text = "إشعارات في وقت الفجر والمغرب", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Switch(checked = reminderEnabled, onCheckedChange = { reminderEnabled = it })
                }
            }
        }

        Card(
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow),
            shape = RoundedCornerShape(20.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    text = "المظهر والخط",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary
                )

                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 8.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(text = "الوضع الداكن (Dark Mode)", fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
                        Text(text = "تغيير ألوان التطبيق", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Switch(checked = isDarkTheme, onCheckedChange = { onToggleTheme() })
                }

                Column(modifier = Modifier.padding(vertical = 8.dp)) {
                    Text(text = "حجم خط الأذكار", fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
                    Spacer(modifier = Modifier.height(4.dp))
                    Slider(
                        value = fontSlider,
                        onValueChange = { fontSlider = it },
                        valueRange = 16f..32f,
                        colors = SliderDefaults.colors(thumbColor = MaterialTheme.colorScheme.primary)
                    )
                }
            }
        }

        Card(
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerHighest),
            shape = RoundedCornerShape(16.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(text = "تطبيق مسبحتي والأذكار • v1.0.0", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                Spacer(modifier = Modifier.height(4.dp))
                Text(text = "مطور بلغة Kotlin و Jetpack Compose", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

// ============================================================================
// MODAL BOTTOM SHEETS CONTENT
// ============================================================================

@Composable
fun TargetSheetContent(
    currentTarget: Int,
    onSaveTarget: (Int) -> Unit
) {
    var customVal by remember { mutableStateOf("") }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(text = "تحديد هدف العداد", fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Text(text = "اختر الهدف المطلوب للذكر الحالي:", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            listOf(33, 100, 1000).forEach { t ->
                OutlinedButton(
                    onClick = { onSaveTarget(t) },
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Text("$t مرة")
                }
            }
        }

        OutlinedTextField(
            value = customVal,
            onValueChange = { customVal = it },
            placeholder = { Text("أو أدخل عدداً مخصصاً...") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp)
        )

        Button(
            onClick = {
                val parsed = customVal.toIntOrNull()
                if (parsed != null && parsed > 0) {
                    onSaveTarget(parsed)
                }
            },
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp),
            shape = RoundedCornerShape(12.dp)
        ) {
            Text("حفظ الهدف", fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
fun AddCustomSheetContent(
    onAdd: (DhikrItem) -> Unit
) {
    var text by remember { mutableStateOf("") }
    var targetStr by remember { mutableStateOf("100") }
    var benefit by remember { mutableStateOf("") }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Text(text = "إضافة ذكر مخصص جديد", fontWeight = FontWeight.Bold, fontSize = 18.sp)

        OutlinedTextField(
            value = text,
            onValueChange = { text = it },
            label = { Text("نص الذكر") },
            placeholder = { Text("مثال: لا حول ولا قوة إلا بالله") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp)
        )

        OutlinedTextField(
            value = targetStr,
            onValueChange = { targetStr = it },
            label = { Text("الهدف اليومي") },
            placeholder = { Text("100") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp)
        )

        OutlinedTextField(
            value = benefit,
            onValueChange = { benefit = it },
            label = { Text("فضل الذكر (اختياري)") },
            placeholder = { Text("كنز من كنوز الجنة") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp)
        )

        Button(
            onClick = {
                if (text.isNotBlank()) {
                    onAdd(
                        DhikrItem(
                            id = System.currentTimeMillis().toString(),
                            text = text,
                            benefit = benefit.ifBlank { "ذكر مخصص" },
                            defaultTarget = targetStr.toIntOrNull() ?: 100,
                            category = "مخصص"
                        )
                    )
                }
            },
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp),
            shape = RoundedCornerShape(12.dp)
        ) {
            Text("إضافة الذكر", fontWeight = FontWeight.Bold)
        }
    }
}
