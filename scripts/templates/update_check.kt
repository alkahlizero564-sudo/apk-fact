// In-app updates (added by APK Fact at build time; not part of the app's own code).
package app.main

import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.net.Uri
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

private const val APKFACT_VERSION = __APKFACT_VERSION__
private const val APKFACT_MANIFEST = "__APKFACT_MANIFEST__"

fun Activity.apkfactCheckForUpdate() {
    thread(isDaemon = true) {
        try {
            val conn = URL(APKFACT_MANIFEST + "?t=" + System.currentTimeMillis()).openConnection() as HttpURLConnection
            conn.connectTimeout = 10000
            conn.readTimeout = 10000
            if (conn.responseCode != 200) return@thread
            val manifest = JSONObject(conn.inputStream.bufferedReader().use { it.readText() })
            val version = manifest.optInt("version", 0)
            val apk = manifest.optString("apk", "")
            if (version <= APKFACT_VERSION || apk.isEmpty()) return@thread
            val name = manifest.optString("versionName", version.toString())
            val notes = manifest.optString("notes", "")
            runOnUiThread {
                if (isFinishing) return@runOnUiThread
                AlertDialog.Builder(this)
                    .setTitle("تحديث جديد متوفر ($name)")
                    .setMessage(if (notes.isNotEmpty()) notes else "اضغط تحديث لتنزيل النسخة الجديدة وتثبيتها.")
                    .setPositiveButton("تحديث") { _, _ ->
                        try {
                            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(apk)))
                        } catch (e: Exception) {
                            // No browser: nothing to do.
                        }
                    }
                    .setNegativeButton("لاحقاً", null)
                    .show()
            }
        } catch (e: Exception) {
            // Offline or no manifest yet: try again next launch.
        }
    }
}
