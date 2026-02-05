package com.nobsalon.nailedu

import android.app.NotificationManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // ✅ iOS와 동일한 채널명 사용
    private val CHANNEL = "com.nobsalon.nailedu/badge"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ✅ Badge 관리용 Method Channel 등록
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "clearBadge" -> {
                        // Android: 모든 알림을 취소하면 배지도 함께 사라짐
                        // (Android 8+ 에서 배지는 알림과 연동됨)
                        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        notificationManager.cancelAll()
                        result.success(true)
                    }
                    "setBadge" -> {
                        // Android에서는 직접 배지 숫자 설정이 어려움
                        // 대신 알림 개수가 배지에 반영됨
                        result.success(true)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }
}
