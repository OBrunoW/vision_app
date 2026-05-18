package br.com.vision.vision_app

import android.content.Intent
import com.pravera.flutter_foreground_task.service.ForegroundService
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onDestroy() {
        if (isFinishing) {
            stopService(Intent(this, ForegroundService::class.java))
        }
        super.onDestroy()
    }
}
