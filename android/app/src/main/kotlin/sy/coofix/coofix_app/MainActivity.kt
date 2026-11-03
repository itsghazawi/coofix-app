package sy.coofix.coofix_app

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cfx/wa").setMethodCallHandler { call, result ->
            if (call.method != "send") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                val file = File(call.argument<String>("path")!!)
                val uri = FileProvider.getUriForFile(this, "$packageName.cfx.files", file)
                val phone = call.argument<String>("phone") ?: ""
                val text = call.argument<String>("text") ?: ""
                val mime = call.argument<String>("mime") ?: "application/pdf"
                for (pkg in listOf("com.whatsapp", "com.whatsapp.w4b")) {
                    val i = Intent(Intent.ACTION_SEND).apply {
                        type = mime
                        setPackage(pkg)
                        putExtra(Intent.EXTRA_STREAM, uri)
                        if (text.isNotEmpty()) putExtra(Intent.EXTRA_TEXT, text)
                        if (phone.isNotEmpty()) putExtra("jid", "$phone@s.whatsapp.net")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    if (i.resolveActivity(packageManager) != null) {
                        startActivity(i)
                        result.success(true)
                        return@setMethodCallHandler
                    }
                }
                result.success(false)
            } catch (e: Exception) {
                result.error("ERR", e.message, null)
            }
        }
    }
}
