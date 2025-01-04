package wifi.luuu.com

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity: FlutterActivity() {
    private val CHANNEL = "wifi.luuu.com/wifi"
    private val PERMISSION_REQUEST_CODE = 123
    private var pendingResult: MethodChannel.Result? = null
    private var pendingOperation: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getWifiSignalStrength" -> {
                    if (checkPermissions()) {
                        getWifiSignalStrength(result)
                    } else {
                        pendingResult = result
                        pendingOperation = "getWifiSignalStrength"
                        requestPermissions()
                    }
                }
                "getWifiFrequency" -> {
                    if (checkPermissions()) {
                        getWifiFrequency(result)
                    } else {
                        pendingResult = result
                        pendingOperation = "getWifiFrequency"
                        requestPermissions()
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun checkPermissions(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestPermissions() {
        ActivityCompat.requestPermissions(
            this,
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            ),
            PERMISSION_REQUEST_CODE
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == PERMISSION_REQUEST_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                // 权限被授予，执行待处理的操作
                when (pendingOperation) {
                    "getWifiSignalStrength" -> pendingResult?.let { getWifiSignalStrength(it) }
                    "getWifiFrequency" -> pendingResult?.let { getWifiFrequency(it) }
                }
            } else {
                // 权限被拒绝
                pendingResult?.error("PERMISSION_DENIED", "需要位置权限来获取WiFi信息", null)
            }
            // 清理待处理的操作
            pendingResult = null
            pendingOperation = null
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    private fun getWifiSignalStrength(result: MethodChannel.Result) {
        try {
            val wifiManager = context.getSystemService(Context.WIFI_SERVICE) as WifiManager
            if (!wifiManager.isWifiEnabled) {
                println("DEBUG: WiFi未启用")
                result.success(0)
                return
            }

            val wifiInfo = wifiManager.connectionInfo
            if (wifiInfo == null) {
                println("DEBUG: 无法获取WiFi信息")
                result.success(0)
                return
            }

            val signalStrength = wifiInfo.rssi
            println("DEBUG: 获取到信号强度: $signalStrength dBm")
            result.success(signalStrength)
            
        } catch (e: Exception) {
            println("DEBUG: 获取信号强度时出错: ${e.message}")
            result.error("WIFI_ERROR", "获取WiFi信号强度失败: ${e.message}", null)
        }
    }

    private fun getWifiFrequency(result: MethodChannel.Result) {
        try {
            val wifiManager = context.getSystemService(Context.WIFI_SERVICE) as WifiManager
            if (!wifiManager.isWifiEnabled) {
                println("DEBUG: WiFi未启用")
                result.success(0)
                return
            }

            val wifiInfo = wifiManager.connectionInfo
            if (wifiInfo == null) {
                println("DEBUG: 无法获取WiFi信息")
                result.success(0)
                return
            }

            val frequency = wifiInfo.frequency
            println("DEBUG: 获取到WiFi频率: $frequency MHz")
            result.success(frequency)
            
        } catch (e: Exception) {
            println("DEBUG: 获取WiFi频率时出错: ${e.message}")
            result.error("WIFI_ERROR", "获取WiFi频率失败: ${e.message}", null)
        }
    }
}
