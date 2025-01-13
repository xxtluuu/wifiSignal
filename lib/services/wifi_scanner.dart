import 'dart:async';
import 'dart:io' show Platform;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../models/wifi_network.dart';

class WifiScanner {
  Timer? _timer;
  Timer? _vibrationTimer;
  final _networkInfo = NetworkInfo();
  bool _isVibrating = false;
  
  // 信号强度流控制器
  final _signalController = StreamController<int>.broadcast();
  Stream<int> get signalStream => _signalController.stream;

  // 震动参数
  static const int _minSignal = -80; // 最低信号强度
  static const int _maxSignal = -50; // 最高信号强度
  static const int _signalRange = _maxSignal - _minSignal; // 信号范围（30）
  static const int _minInterval = 100; // 最短震动间隔（信号最好时）
  static const int _maxInterval = 1000; // 最长震动间隔（信号最差时）
  static const int _vibrationDuration = 100; // 震动持续时间（毫秒）
  static const List<int> _vibrationPattern = [0, 30]; // 震动强度模式，设置为30%

  // 平台通道
  static const platform = MethodChannel('wifi.luuu.com/wifi');
  
  // 存储所有WiFi网络列表
  List<WifiNetwork> _allNetworks = [];
  final _networksController = StreamController<List<WifiNetwork>>.broadcast();
  Stream<List<WifiNetwork>> get networksStream => _networksController.stream;

  // 开始实时监测
  Future<void> startMonitoring() async {
    // 确保先停止之前的监测并等待资源释放
    await stopMonitoring();
    
    // 等待一小段时间确保资源完全释放
    await Future.delayed(const Duration(milliseconds: 500));
    
    _isVibrating = true;
    
    // 启动信号监测定时器
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!_isVibrating) return;
      final signal = await getCurrentSignalStrength();
      _signalController.add(signal);
    });

    // 启动震动
    _startVibrating();
  }

  // 停止监测
  Future<void> stopMonitoring() async {
    // 首先设置标志，防止新的操作开始
    _isVibrating = false;
    
    // 取消定时器
    _timer?.cancel();
    _timer = null;
    
    _vibrationTimer?.cancel();
    _vibrationTimer = null;

    // 停止震动
    await Vibration.cancel();

    // 等待一小段时间确保资源释放完成
    await Future.delayed(const Duration(milliseconds: 300));
  }

  // 开始震动
  void _startVibrating() async {
    if (!_isVibrating) return;
    
    _vibrateWithSignal();
  }

  // 根据信号强度控制震动
  void _vibrateWithSignal() async {
    if (!_isVibrating) return;
    
    try {
      final signal = await getCurrentSignalStrength();
      
      // 将信号强度限制在指定范围内
      final clampedSignal = signal.clamp(_minSignal, _maxSignal);
      
      // 计算归一化值（0到1，信号越好越大）
      final normalizedSignal = (clampedSignal - _minSignal) / _signalRange;
      
      // 计算下一次震动间隔
      // 信号越好，间隔越短
      final nextInterval = (_maxInterval - (_maxInterval - _minInterval) * normalizedSignal).toInt();
      
      print('DEBUG: 信号: $signal dBm (限制后: $clampedSignal dBm)'); // 调试输出
      print('DEBUG: 归一化值: $normalizedSignal, 间隔: ${nextInterval}ms'); // 调试输出
      
      // 执行震动
      if (_isVibrating) {
        try {
          if (await Vibration.hasVibrator() ?? false) {
            // 使用30%的震动强度
            await Vibration.vibrate(duration: _vibrationDuration, amplitude: 30);
          }
        } catch (e) {
          print('震动执行失败: $e');
        }
        
        // 设置下一次震动
        _vibrationTimer?.cancel();
        _vibrationTimer = Timer(Duration(milliseconds: nextInterval), () {
          if (_isVibrating) {
            _vibrateWithSignal(); // 递归调用实现连续震动
          }
        });
      }
    } catch (e) {
      print('震动控制出错: $e');
      // 出错时也要继续尝试震动
      _vibrationTimer = Timer(const Duration(milliseconds: 500), () {
        if (_isVibrating) {
          _vibrateWithSignal();
        }
      });
    }
  }

  // 获取当前WiFi信号强度
  Future<int> getCurrentSignalStrength() async {
    try {
      if (Platform.isAndroid) {
        try {
          // 直接尝试获取信号强度
          final int signal = await platform.invokeMethod('getWifiSignalStrength');
          print('DEBUG: Android - 获取到信号强度: $signal dBm');
          return signal;
        } catch (e) {
          print('DEBUG: Android - 平台通道错误: $e');
          return 0;
        }
      } else {
        // iOS平台
        final wifiName = await _networkInfo.getWifiName();
        print('DEBUG: iOS - WiFi名称: $wifiName');
        
        if (wifiName != null) {
          return -60; // iOS上返回固定的中等信号强度
        }
        return 0;
      }
    } catch (e) {
      print('DEBUG: 信号获取过程出错: $e');
      return 0;
    }
  }

  // 获取当前WiFi网络信息
  Future<WifiNetwork?> getCurrentNetwork() async {
    try {
      if (Platform.isAndroid) {
        // Android平台
        final signal = await getCurrentSignalStrength();
        if (signal == 0) {
          print('DEBUG: Android - 未获取到信号强度');
          return null;
        }

        final ssid = await _networkInfo.getWifiName();
        final bssid = await _networkInfo.getWifiBSSID();
        final ip = await _networkInfo.getWifiIP();

        print('DEBUG: Android - 网络信息:');
        print('DEBUG: Android - SSID: $ssid');
        print('DEBUG: Android - BSSID: $bssid');
        print('DEBUG: Android - IP: $ip');
        print('DEBUG: Android - 信号: $signal dBm');

        if (ssid == null || bssid == null) {
          print('DEBUG: Android - 网络信息不完整');
          return null;
        }

        // 获取频率信息（通过平台通道）
        int frequency = 0;
        try {
          frequency = await platform.invokeMethod('getWifiFrequency') ?? 0;
        } catch (e) {
          print('DEBUG: Android - 获取频率失败: $e');
        }

        return WifiNetwork(
          ssid: ssid.replaceAll('"', ''),
          bssid: bssid,
          signalStrength: signal.toDouble(),
          ipAddress: ip,
          timestamp: DateTime.now(),
          frequency: frequency,
        );
      } else {
        // iOS平台
        final ssid = await _networkInfo.getWifiName();
        if (ssid == null) {
          print('DEBUG: iOS - 未获取到WiFi名称');
          return null;
        }

        final bssid = await _networkInfo.getWifiBSSID() ?? '';
        final ip = await _networkInfo.getWifiIP();
        final signal = -60; // iOS使用固定信号强度

        print('DEBUG: iOS - 网络信息:');
        print('DEBUG: iOS - SSID: $ssid');
        print('DEBUG: iOS - BSSID: $bssid');
        print('DEBUG: iOS - IP: $ip');
        print('DEBUG: iOS - 信号: $signal dBm');

        // iOS上暂不支持获取频率信息
        return WifiNetwork(
          ssid: ssid.replaceAll('"', ''),
          bssid: bssid,
          signalStrength: signal.toDouble(),
          ipAddress: ip,
          timestamp: DateTime.now(),
          frequency: null,
        );
      }
    } catch (e) {
      print('网络信息获取错误: $e');
      return null;
    }
  }

  // 获取信号强度等级
  String getSignalLevel(int strength) {
    if (strength >= -40) return '极好';
    if (strength >= -60) return '很好';
    if (strength >= -80) return '一般';
    return '差';
  }

  // 释放资源
  // 获取所有WiFi网络列表
  Future<List<WifiNetwork>> getAllNetworks() async {
    if (Platform.isAndroid) {
      try {
        final List<dynamic> networks = await platform.invokeMethod('getAllWifiNetworks') ?? [];
        _allNetworks = networks.map((network) {
          return WifiNetwork(
            ssid: network['ssid']?.toString().replaceAll('"', '') ?? '',
            bssid: network['bssid'] ?? '',
            signalStrength: (network['signalStrength'] as int?)?.toDouble() ?? 0,
            frequency: network['frequency'] as int?,
            timestamp: DateTime.now(),
          );
        }).toList();
        
        // 按信号强度排序
        _allNetworks.sort((a, b) => b.signalStrength.compareTo(a.signalStrength));
        _networksController.add(_allNetworks);
        return _allNetworks;
      } catch (e) {
        print('获取WiFi列表失败: $e');
        return [];
      }
    }
    return [];
  }

  void dispose() {
    stopMonitoring();
    _signalController.close();
    _networksController.close();
  }
}
