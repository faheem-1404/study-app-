package com.studyearn.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "study_earn/native_cv"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> result.success(false)
                "detectFace" -> result.success(false)
                else -> result.notImplemented()
            }
        }
    }
}