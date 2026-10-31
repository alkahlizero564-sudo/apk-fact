package app.main

import android.content.Context
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Home
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp

// Self-test app for the Kotlin template (scripts/kotlin_project.py --sample).
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent { AppTheme { Home() } }
    }
}

@Composable
fun AppTheme(content: @Composable () -> Unit) {
    val scheme = if (isSystemInDarkTheme()) darkColorScheme(primary = Color(0xFF8AB4F8))
    else lightColorScheme(primary = Color(0xFF1A73E8))
    MaterialTheme(colorScheme = scheme, content = content)
}

@Composable
fun Home() {
    val prefs = LocalContext.current.getSharedPreferences("app", Context.MODE_PRIVATE)
    var count by remember { mutableIntStateOf(prefs.getInt("count", 0)) }
    Scaffold(
        topBar = { CenterAlignedTopAppBar(title = { Text("الرئيسية") }) },
        bottomBar = {
            NavigationBar {
                NavigationBarItem(selected = true, onClick = {}, icon = { Icon(Icons.Filled.Home, null) }, label = { Text("الرئيسية") })
            }
        },
        floatingActionButton = {
            FloatingActionButton(onClick = { count++; prefs.edit().putInt("count", count).apply() }) {
                Icon(Icons.Filled.Add, contentDescription = "إضافة")
            }
        },
    ) { inner ->
        Column(
            Modifier.fillMaxSize().padding(inner).padding(24.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text("العدد: $count", style = MaterialTheme.typography.headlineMedium)
        }
    }
}
