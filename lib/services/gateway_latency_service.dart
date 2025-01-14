import 'dart:async';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';

class GatewayLatencyService {
  final NetworkInfo _networkInfo = NetworkInfo();
  static const int _measurementCount = 3; // 减少测量次数，保留更多实时性
  static const Duration _connectionTimeout = Duration(milliseconds: 300);
  
  // 延迟到信号强度的映射参数
  static const double _minLatency = 10.0; // 最小延迟（毫秒）
  static const double _maxLatency = 150.0; // 最大延迟范围
  static const int _maxSignal = -35; // 最佳信号强度（dBm）
  static const int _minSignal = -95; // 最差信号强度（dBm）

  // 获取网关IP地址
  Future<String?> _getGatewayIP() async {
    try {
      final wifiIP = await _networkInfo.getWifiIP();
      if (wifiIP == null) return null;
      
      // 假设网关是 x.x.x.1
      final ipParts = wifiIP.split('.');
      if (ipParts.length != 4) return null;
      
      return '${ipParts[0]}.${ipParts[1]}.${ipParts[2]}.1';
    } catch (e) {
      print('获取网关IP失败: $e');
      return null;
    }
  }

  // 测量单次TCP连接延迟
  Future<double?> _measureSingleLatency(String gatewayIP) async {
    final stopwatch = Stopwatch()..start();
    Socket? socket;
    
    try {
      socket = await Socket.connect(
        gatewayIP,
        80, // 尝试连接到HTTP端口
        timeout: _connectionTimeout,
      );
      
      final latency = stopwatch.elapsedMilliseconds.toDouble();
      return latency;
    } catch (e) {
      print('TCP连接测量失败: $e');
      return null;
    } finally {
      stopwatch.stop();
      socket?.destroy();
    }
  }

  // 进行多次测量并计算平均延迟
  Future<double?> _measureAverageLatency(String gatewayIP) async {
    final latencies = <double>[];
    
    for (var i = 0; i < _measurementCount; i++) {
      final latency = await _measureSingleLatency(gatewayIP);
      if (latency != null) {
        latencies.add(latency);
      }
      
      // 短暂延迟，避免过于频繁的测量
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    if (latencies.isEmpty) return null;
    
    // 计算平均值
    final avgLatency = latencies.reduce((a, b) => a + b) / latencies.length;
    return avgLatency;
  }

  // 将延迟映射到信号强度（使用更线性的映射）
  int _mapLatencyToSignal(double latency) {
    // 添加更大的随机波动（±4dBm）
    final random = DateTime.now().millisecondsSinceEpoch % 9 - 4;
    
    // 将延迟限制在有效范围内
    final clampedLatency = latency.clamp(_minLatency, _maxLatency);
    
    // 使用更线性的映射，保留一些非线性特性
    final normalizedLatency = (clampedLatency - _minLatency) / (_maxLatency - _minLatency);
    final value = 1 - (0.7 * normalizedLatency + 0.3 * normalizedLatency * normalizedLatency);
    
    // 映射到更大的信号强度范围并添加随机波动
    final signal = _minSignal + ((_maxSignal - _minSignal) * value) + random;
    
    return signal.round();
  }

  // 获取模拟信号强度
  Future<int> getSimulatedSignalStrength() async {
    try {
      final gatewayIP = await _getGatewayIP();
      if (gatewayIP == null) {
        print('未能获取网关IP');
        return -65; // 返回中等信号强度作为默认值
      }
      
      final avgLatency = await _measureAverageLatency(gatewayIP);
      if (avgLatency == null) {
        print('延迟测量失败');
        // 返回一个随机的较弱信号强度（范围更大）
        return -85 + (DateTime.now().millisecondsSinceEpoch % 20);
      }
      
      final signalStrength = _mapLatencyToSignal(avgLatency);
      print('网关延迟: ${avgLatency.toStringAsFixed(2)}ms, 模拟信号强度: $signalStrength dBm');
      
      return signalStrength;
    } catch (e) {
      print('获取模拟信号强度失败: $e');
      return -65; // 返回中等信号强度作为默认值
    }
  }
}
