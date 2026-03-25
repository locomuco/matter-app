package com.example.matter_home

import android.content.Intent
import android.util.Log
import com.example.matter_home.chip.AndroidThreadCredentialReader
import com.example.matter_home.chip.ChipClient
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG            = "MainActivity"
        private const val METHOD_CHANNEL = "com.example.matter_home/matter"
        private const val EVENT_CHANNEL  = "com.example.matter_home/commission_events"
    }

    private val bridge by lazy { MatterBridge(applicationContext) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        ChipClient.init(applicationContext)
        Log.i(TAG, "CHIP SDK available: ${ChipClient.isAvailable}")

        // ── EventChannel: commissioning progress ──────────────────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    bridge.setEventSink(events)
                }
                override fun onCancel(arguments: Any?) {
                    bridge.setEventSink(null)
                }
            })

        // ── MethodChannel ─────────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                Log.d(TAG, "← ${call.method}")
                when (call.method) {
                    "ping" ->
                        bridge.ping(result)

                    "commissionDevice" -> {
                        val payload          = call.argument<String>("payload") ?: ""
                        val wifiSsid         = call.argument<String>("wifiSsid")
                        val wifiPassword     = call.argument<String>("wifiPassword")
                        val threadDatasetHex = call.argument<String>("threadDatasetHex")
                        val nodeId           = call.argument<Int>("nodeId")?.toLong()
                                               ?: (System.currentTimeMillis() and 0xFFFF_FFFFL)
                        bridge.commissionDevice(payload, wifiSsid, wifiPassword, threadDatasetHex, nodeId, result)
                    }

                    "commissionViaIp" -> {
                        val ip      = call.argument<String>("ipAddress") ?: ""
                        val port    = call.argument<Int>("port") ?: 5540
                        val disc    = call.argument<Int>("discriminator") ?: 0
                        val pin     = call.argument<Int>("setupPinCode")?.toLong() ?: 0L
                        val nodeId  = call.argument<Int>("nodeId")?.toLong()
                                      ?: (System.currentTimeMillis() and 0xFFFF_FFFFL)
                        bridge.commissionViaIp(ip, port, disc, pin, nodeId, result)
                    }

                    "toggleDevice" -> {
                        val nodeId = call.argument<Int>("nodeId")?.toLong() ?: 0L
                        val on     = call.argument<Boolean>("on") ?: false
                        bridge.toggleDevice(nodeId, on, result)
                    }

                    "setLevel" -> {
                        val nodeId = call.argument<Int>("nodeId")?.toLong() ?: 0L
                        val level  = call.argument<Int>("level") ?: 0
                        bridge.setLevel(nodeId, level, result)
                    }

                    "readDeviceState" -> {
                        val nodeId = call.argument<Int>("nodeId")?.toLong() ?: 0L
                        bridge.readDeviceState(nodeId, result)
                    }

                    "readBasicInfo" -> {
                        val nodeId = call.argument<Int>("nodeId")?.toLong() ?: 0L
                        bridge.readBasicInfo(nodeId, result)
                    }

                    "readThermostat" -> {
                        val nodeId = call.argument<Int>("nodeId")?.toLong() ?: 0L
                        bridge.readThermostat(nodeId, result)
                    }

                    "writeHeatingSetpoint" -> {
                        val nodeId      = call.argument<Int>("nodeId")?.toLong() ?: 0L
                        val centidegrees = call.argument<Int>("centidegrees") ?: 0
                        bridge.writeHeatingSetpoint(nodeId, centidegrees, result)
                    }

                    "writeSystemMode" -> {
                        val nodeId = call.argument<Int>("nodeId")?.toLong() ?: 0L
                        val mode   = call.argument<Int>("mode") ?: 0
                        bridge.writeSystemMode(nodeId, mode, result)
                    }

                    "readHumidity" -> {
                        val nodeId = call.argument<Int>("nodeId")?.toLong() ?: 0L
                        bridge.readHumidity(nodeId, result)
                    }

                    "readClusters" -> {
                        val nodeId = call.argument<Int>("nodeId")?.toLong() ?: 0L
                        bridge.readClusters(nodeId, result)
                    }

                    "readDeviceType" -> {
                        val nodeId = call.argument<Int>("nodeId")?.toLong() ?: 0L
                        bridge.readDeviceType(nodeId, result)
                    }

                    "shareDevice" -> {
                        val nodeId = call.argument<Int>("nodeId")?.toLong() ?: 0L
                        bridge.openCommissioningWindow(nodeId, result)
                    }

                    "removeDevice" -> {
                        val nodeId = call.argument<Int>("nodeId")?.toLong() ?: 0L
                        bridge.removeDevice(nodeId, result)
                    }

                    "readAndroidThreadCredentials" ->
                        AndroidThreadCredentialReader.requestPreferredCredentials(this, result)

                    "discoverThreadNetworks" -> bridge.discoverThreadNetworks(result)

                    "parsePayload" -> {
                        val payload = call.argument<String>("payload") ?: ""
                        bridge.parsePayload(payload, result)
                    }

                    "getFabricId" ->
                        bridge.getFabricId(result)

                    else ->
                        result.notImplemented()
                }
            }
    }

    @Suppress("OVERRIDE_DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == AndroidThreadCredentialReader.REQUEST_CODE) {
            AndroidThreadCredentialReader.onActivityResult(resultCode, data)
        }
    }
}
