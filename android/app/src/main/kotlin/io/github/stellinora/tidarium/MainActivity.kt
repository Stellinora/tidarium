package io.github.stellinora.tidarium

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private var pendingPickResult: MethodChannel.Result? = null
    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingSaveContent: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickIcs" -> pickIcs(result)
                "saveIcs" -> {
                    val fileName = call.argument<String>("fileName") ?: "tidarium.ics"
                    val content = call.argument<String>("content") ?: ""
                    saveIcs(fileName, content, result)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            TIMEZONE_CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getLocalTimezone" -> result.success(
                    java.util.TimeZone.getDefault().id,
                )
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            REMINDER_CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" ->
                    result.success(isIgnoringBatteryOptimizations())
                "requestIgnoreBatteryOptimizations" ->
                    result.success(requestIgnoreBatteryOptimizations())
                "openAutostartSettings" -> {
                    openAutostartSettings()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        return powerManager.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestIgnoreBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        if (isIgnoringBatteryOptimizations()) return true

        return try {
            startActivity(
                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                    .setData(Uri.parse("package:$packageName")),
            )
            true
        } catch (_: Exception) {
            try {
                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            } catch (_: Exception) {
                openAppDetails()
            }
            false
        }
    }

    private fun openAutostartSettings() {
        val manufacturer = Build.MANUFACTURER.lowercase(Locale.ROOT)
        val candidates = when {
            manufacturer.contains("xiaomi") || manufacturer.contains("redmi") -> listOf(
                ComponentName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.autostart.AutoStartManagementActivity",
                ),
                ComponentName(
                    "com.miui.securitycenter",
                    "com.miui.powercenter.PowerSettings",
                ),
            )
            manufacturer.contains("huawei") || manufacturer.contains("honor") -> listOf(
                ComponentName(
                    "com.huawei.systemmanager",
                    "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
                ),
                ComponentName(
                    "com.huawei.systemmanager",
                    "com.huawei.systemmanager.optimize.process.ProtectActivity",
                ),
            )
            manufacturer.contains("oppo") ||
                manufacturer.contains("realme") ||
                manufacturer.contains("oneplus") -> listOf(
                ComponentName(
                    "com.coloros.safecenter",
                    "com.coloros.safecenter.permission.startup.StartupAppListActivity",
                ),
                ComponentName(
                    "com.oppo.safe",
                    "com.oppo.safe.permission.startup.StartupAppListActivity",
                ),
                ComponentName(
                    "com.oneplus.security",
                    "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity",
                ),
            )
            manufacturer.contains("vivo") || manufacturer.contains("iqoo") -> listOf(
                ComponentName(
                    "com.vivo.permissionmanager",
                    "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
                ),
                ComponentName(
                    "com.iqoo.secure",
                    "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
                ),
            )
            manufacturer.contains("meizu") -> listOf(
                ComponentName(
                    "com.meizu.safe",
                    "com.meizu.safe.permission.SmartBGActivity",
                ),
            )
            manufacturer.contains("samsung") -> listOf(
                ComponentName(
                    "com.samsung.android.lool",
                    "com.samsung.android.sm.ui.battery.BatteryActivity",
                ),
            )
            else -> emptyList()
        }

        for (component in candidates) {
            val intent = Intent()
                .setComponent(component)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY) != null) {
                try {
                    startActivity(intent)
                    return
                } catch (_: Exception) {
                    // Try the next candidate.
                }
            }
        }

        openAppDetails()
    }

    private fun openAppDetails() {
        try {
            startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    .setData(Uri.parse("package:$packageName")),
            )
        } catch (_: Exception) {
            // Nothing else we can open.
        }
    }

    private fun pickIcs(result: MethodChannel.Result) {
        if (pendingPickResult != null) {
            result.error("busy", "Another file picker is already open", null)
            return
        }

        pendingPickResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf("text/calendar", "text/plain", "application/octet-stream"),
            )
        }

        try {
            startActivityForResult(intent, REQUEST_PICK_ICS)
        } catch (error: Exception) {
            pendingPickResult = null
            result.error("pick_failed", error.message, null)
        }
    }

    private fun saveIcs(
        fileName: String,
        content: String,
        result: MethodChannel.Result,
    ) {
        if (pendingSaveResult != null) {
            result.error("busy", "Another file saver is already open", null)
            return
        }

        pendingSaveResult = result
        pendingSaveContent = content
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "text/calendar"
            putExtra(Intent.EXTRA_TITLE, fileName)
        }

        try {
            startActivityForResult(intent, REQUEST_SAVE_ICS)
        } catch (error: Exception) {
            pendingSaveResult = null
            pendingSaveContent = null
            result.error("save_failed", error.message, null)
        }
    }

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ) {
        super.onActivityResult(requestCode, resultCode, data)

        when (requestCode) {
            REQUEST_PICK_ICS -> {
                val result = pendingPickResult ?: return
                pendingPickResult = null

                val uri = data?.data
                if (resultCode != Activity.RESULT_OK || uri == null) {
                    result.success(null)
                    return
                }

                try {
                    val input = contentResolver.openInputStream(uri)
                    if (input == null) {
                        result.error("read_failed", "Cannot open the selected file", null)
                        return
                    }
                    val content = input.use { stream ->
                        stream.bufferedReader(Charsets.UTF_8).readText()
                    }
                    result.success(content)
                } catch (error: Exception) {
                    result.error("read_failed", error.message, null)
                }
            }

            REQUEST_SAVE_ICS -> {
                val result = pendingSaveResult ?: return
                val content = pendingSaveContent
                pendingSaveResult = null
                pendingSaveContent = null

                val uri = data?.data
                if (resultCode != Activity.RESULT_OK || uri == null) {
                    result.success(false)
                    return
                }

                try {
                    val output = contentResolver.openOutputStream(uri)
                    if (output == null) {
                        result.error("write_failed", "Cannot open the output file", null)
                        return
                    }
                    output.use { stream ->
                        stream.write((content ?: "").toByteArray(Charsets.UTF_8))
                    }
                    result.success(true)
                } catch (error: Exception) {
                    result.error("write_failed", error.message, null)
                }
            }
        }
    }

    companion object {
        private const val CHANNEL_NAME = "io.github.stellinora.tidarium/files"
        private const val TIMEZONE_CHANNEL_NAME =
            "io.github.stellinora.tidarium/timezone"
        private const val REMINDER_CHANNEL_NAME =
            "io.github.stellinora.tidarium/reminders"
        private const val REQUEST_PICK_ICS = 4101
        private const val REQUEST_SAVE_ICS = 4102
    }
}
