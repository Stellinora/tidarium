package io.github.stellinora.tidarium

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
        private const val REQUEST_PICK_ICS = 4101
        private const val REQUEST_SAVE_ICS = 4102
    }
}
