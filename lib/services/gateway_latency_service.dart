import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:network_info_plus/network_info_plus.dart';

class GatewayLatencyService {
  final NetworkInfo _networkInfo = NetworkInfo();
  static const int _measurementCount = 10; // 增加测量次数以提高准确性
  static const Duration _connectionTimeout = Duration(milliseconds: 800);
  static const List<int> _testPorts = [80, 443, 53]; // 尝试多个常用端口
  
  // 延迟到信号强度的映射参数
  static const double _minLatency = 10.0; // 最小延迟（毫秒）
  static const double _maxLatency = 100.0; // 最大延迟范围
  static const double _referenceLatency1 = 20.0; // 参考点1：20ms对应-40dBm
  static const double _referenceLatency2 = 80.0; // 参考点2：80ms对应-80dBm
  static const int _maxSignal = -35; // 最佳信号强度（dBm）
  static const int _minSignal = -85; // 最差信号强度（dBm）

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

  // 测量单个端口的TCP连接延迟
  Future<double?> _measurePortLatency(String gatewayIP, int port) async {
    final stopwatch = Stopwatch()..start();
    Socket? socket;
    
    try {
      socket = await Socket.connect(
        gatewayIP,
        port,
        timeout: _connectionTimeout,
      );
      
      final latency = stopwatch.elapsedMilliseconds.toDouble();
      return latency;
    } catch (e) {
      print('TCP连接测量失败(端口$port): $e');
      return null;
    } finally {
      stopwatch.stop();
      socket?.destroy();
    }
  }

  // 测量单次TCP连接延迟（尝试多个端口，每次测试之间添加延迟）
  Future<double?> _measureSingleLatency(String gatewayIP) async {
    for (final port in _testPorts) {
      // 每次端口测试前添加短暂延迟
      await Future.delayed(const Duration(milliseconds: 50));
      
      final latency = await _measurePortLatency(gatewayIP, port);
      if (latency != null) {
        return latency;
      }
    }
    print('所有端口连接都失败');
    return null;
  }

  // 进行多次测量并计算平均延迟
  Future<double?> _measureAverageLatency(String gatewayIP) async {
    final latencies = <double>[];
    
    for (var i = 0; i < _measurementCount; i++) {
      final latency = await _measureSingleLatency(gatewayIP);
      if (latency != null) {
        latencies.add(latency);
      }
      
      // 增加测量间隔，避免过于频繁的测量
      await Future.delayed(const Duration(milliseconds: 200));
    }
    
    if (latencies.isEmpty) return null;
    
    // 计算平均值
    final avgLatency = latencies.reduce((a, b) => a + b) / latencies.length;
    return avgLatency;
  }

  // 将延迟映射到信号强度（基于参考点的线性映射）
  int _mapLatencyToSignal(double latency) {
    // 添加较小的随机波动（±2dBm）
    final random = DateTime.now().millisecondsSinceEpoch % 5 - 2;
    
    // 将延迟限制在有效范围内
    final clampedLatency = latency.clamp(_minLatency, _maxLatency);
    
    int baseSignal;
    if (clampedLatency <= _referenceLatency1) {
      // 10-20ms: -35到-40dBm
      final ratio = (clampedLatency - _minLatency) / (_referenceLatency1 - _minLatency);
      baseSignal = -35 - (5 * ratio).round();
    } else if (clampedLatency <= _referenceLatency2) {
      // 20-80ms: -40到-80dBm
      final ratio = (clampedLatency - _referenceLatency1) / (_referenceLatency2 - _referenceLatency1);
      baseSignal = -40 - (40 * ratio).round();
    } else {
      // 80-100ms: -80到-85dBm
      final ratio = (clampedLatency - _referenceLatency2) / (_maxLatency - _referenceLatency2);
      baseSignal = -80 - (5 * ratio).round();
    }
    
    // 添加随机波动并确保在有效范围内
    return (baseSignal + random).clamp(_minSignal, _maxSignal);
  }

  // 获取模拟信号强度
  Future<Map<String, dynamic>> getSimulatedSignalStrength() async {
    try {
      final gatewayIP = await _getGatewayIP();
      if (gatewayIP == null) {
        print('未能获取网关IP');
        if (Platform.isIOS) {
          return {
            'signal': -65,  // 返回中等信号强度作为默认值
            'latency': 'N/A',
          };
        } else {
          return {'signal': -65};  // 返回中等信号强度作为默认值
        }
      }
      
      final avgLatency = await _measureAverageLatency(gatewayIP);
      if (avgLatency == null) {
        print('延迟测量失败');
        // 返回一个随机的较弱信号强度（范围更大）
        final defaultSignal = -85 + (DateTime.now().millisecondsSinceEpoch % 20);
        if (Platform.isIOS) {
          return {
            'signal': defaultSignal,
            'latency': 'N/A',
          };
        } else {
          return {'signal': defaultSignal};
        }
      }
      
      final signalStrength = _mapLatencyToSignal(avgLatency);
      
      if (Platform.isIOS) {
        return {
          'signal': signalStrength,
          'latency': '${avgLatency.toStringAsFixed(1)}ms (10次平均)',
        };
      } else {
        return {'signal': signalStrength};
      }
    } catch (e) {
      print('获取模拟信号强度失败: $e');
      if (Platform.isIOS) {
        return {
          'signal': -65,  // 返回中等信号强度作为默认值
          'latency': 'N/A',
        };
      } else {
        return {'signal': -65};  // 返回中等信号强度作为默认值
      }
    }
  }
}
