package com.example.ai_health

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private lateinit var samsungHealthPlugin: SamsungHealthPlugin

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        samsungHealthPlugin = SamsungHealthPlugin(this, applicationContext)

        // MethodChannel: request/response calls
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SamsungHealthPlugin.CHANNEL
        ).setMethodCallHandler(samsungHealthPlugin)

        // EventChannel: real-time data stream
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SamsungHealthPlugin.EVENT_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                samsungHealthPlugin.setEventSink(events)
            }
            override fun onCancel(arguments: Any?) {
                samsungHealthPlugin.setEventSink(null)
            }
        })
    }
}
