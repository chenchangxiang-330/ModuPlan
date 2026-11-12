package cn.bingbing.day_blocks_demo

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    private var exportText: String? = null
    private val exportRequest = 4101
    private val importRequest = 4102
    private val maxBytes = 10 * 1024 * 1024

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cn.bingbing.dayblocks/files")
            .setMethodCallHandler { call, result ->
                if (pending != null) {
                    result.error("BUSY", "文件选择器正在使用中", null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "export" -> {
                        val text = call.argument<String>("text")
                        if (text == null || text.toByteArray(Charsets.UTF_8).size > maxBytes) {
                            result.error("INVALID", "备份内容为空或超过 10 MB", null)
                            return@setMethodCallHandler
                        }
                        pending = result
                        exportText = text
                        launchDocument(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "application/json"
                            putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "day_blocks_backup.json")
                        }, exportRequest)
                    }
                    "import" -> {
                        pending = result
                        launchDocument(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                        }, importRequest)
                    }
                    else -> result.notImplemented()
                }
            }
    }
    private fun launchDocument(intent: Intent, request: Int) {
        try { startActivityForResult(intent, request) }
        catch (e: Exception) {
            pending?.error("FILE_PICKER", "无法打开系统文件选择器：${e.message}", null)
            pending = null; exportText = null
        }
    }
    @Deprecated("Activity result API used for Flutter embedding compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != exportRequest && requestCode != importRequest) return
        val callback = pending ?: return
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pending = null; exportText = null
            callback.success(if (requestCode == exportRequest) false else null)
            return
        }
        val text = exportText
        Thread {
            try {
                val value: Any? = if (requestCode == exportRequest) {
                    val out = contentResolver.openOutputStream(uri, "wt") ?: error("无法写入所选文件")
                    out.use { it.write((text ?: error("导出内容已丢失，请重试")).toByteArray(Charsets.UTF_8)) }
                    true
                } else {
                    val input = contentResolver.openInputStream(uri) ?: error("无法读取文件")
                    val bytes = ByteArrayOutputStream()
                    input.use {
                        val buffer = ByteArray(8192)
                        while (true) {
                            val count = it.read(buffer)
                            if (count < 0) break
                            if (bytes.size() + count > maxBytes) error("备份超过 10 MB")
                            bytes.write(buffer, 0, count)
                        }
                    }
                    Charsets.UTF_8.newDecoder().decode(java.nio.ByteBuffer.wrap(bytes.toByteArray())).toString()
                }
                runOnUiThread { pending = null; exportText = null; callback.success(value) }
            } catch (e: Exception) {
                runOnUiThread { pending = null; exportText = null; callback.error("FILE_IO", e.message ?: "文件操作失败", null) }
            }
        }.start()
    }
}
