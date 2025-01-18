import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math';
import '../services/service_locator.dart';
import '../services/arp_service.dart';
import '../services/arp_service/vpn_detector.dart';
import '../models/device_info.dart';

class IpScannerScreen extends StatefulWidget {
  const IpScannerScreen({super.key});

  @override
  State<IpScannerScreen> createState() => _IpScannerScreenState();
}

class _IpScannerScreenState extends State<IpScannerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final _arpService = getIt<ARPService>();
  final ValueNotifier<bool> _isScanning = ValueNotifier<bool>(false);
  final ValueNotifier<DeviceInfo?> _localDevice = ValueNotifier<DeviceInfo?>(null);
  final ValueNotifier<List<DeviceInfo>> _activeDevices = ValueNotifier<List<DeviceInfo>>([]);
  final ValueNotifier<int> _deviceCount = ValueNotifier<int>(0);
  final ValueNotifier<bool> _hasVPN = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    
    // 立即开始新的扫描
    _startScan();
  }

  @override
  void dispose() {
    // 取消正在进行的扫描
    _arpService.cancel();
    _animationController.dispose();
    _isScanning.dispose();
    _localDevice.dispose();
    _activeDevices.dispose();
    _deviceCount.dispose();
    _hasVPN.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    // 如果正在扫描，先取消当前扫描
    if (_isScanning.value) {
      _arpService.cancel();
    }
    
    // 重置所有状态
    _isScanning.value = true;
    _localDevice.value = null;
    _activeDevices.value = [];
    _deviceCount.value = 0;
    _hasVPN.value = false;

    try {
      // 检查VPN状态
      if (await VPNDetector.isVPNActive()) {
        _hasVPN.value = true;
        return; // 直接返回，不抛出异常
      }
      
      // 确保之前的扫描已经完全取消
      await Future.delayed(const Duration(milliseconds: 100));
      
      final devices = await _arpService.scanNetwork(
        onDeviceFound: (device) {
          if (mounted) {
            if (device.isLocalDevice) {
              _localDevice.value = device;
            } else {
              _activeDevices.value = [..._activeDevices.value, device];
              _deviceCount.value = _activeDevices.value.length;
            }
          }
        },
      );

    } catch (e) {
      debugPrint('扫描错误: $e');
      if (mounted && !_hasVPN.value) { // 只在非VPN错误时显示SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('扫描出错，请重试'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        _isScanning.value = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('局域网设备扫描'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // 重置扫描状态
            setState(() {
              _isScanning.value = false;
              _localDevice.value = null;
              _activeDevices.value = [];
              _deviceCount.value = 0;
              _hasVPN.value = false;
            });
            // 开始新的扫描
            await _startScan();
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    // 扫描动画和状态显示
                    ValueListenableBuilder<bool>(
                      valueListenable: _isScanning,
                      builder: (context, isScanning, child) {
                        if (!isScanning && _activeDevices.value.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Text(
                                '未发现设备\n下拉可重新扫描',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          );
                        }
                        
                        if (isScanning) {
                          return Column(
                            children: [
                              const SizedBox(height: 20),
                              // 雷达扫描动画
                              SizedBox(
                                width: 200,
                                height: 200,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // 旋转的外圈
                                    RotationTransition(
                                      turns: _animationController,
                                      child: CustomPaint(
                                        size: const Size(200, 200),
                                        painter: _ScannerPainter(
                                          color: Colors.blue.withOpacity(0.3),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              // 扫描状态信息
                              Column(
                                children: [
                                  Icon(
                                    Icons.wifi_find,
                                    size: 32,
                                    color: Colors.blue[700],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '正在扫描局域网设备...',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ValueListenableBuilder<int>(
                                    valueListenable: _deviceCount,
                                    builder: (context, count, child) {
                                      return Text(
                                        '已发现 $count 个设备',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          );
                        }
                        
                        return const SizedBox.shrink();
                      },
                    ),
                    // 扫描结果统计
                    if (!_isScanning.value && _activeDevices.value.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: ValueListenableBuilder<int>(
                          valueListenable: _deviceCount,
                          builder: (context, count, child) {
                            return Text(
                              '发现 $count 个在线设备',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            );
                          },
                        ),
                      ),
                    // VPN警告
                    ValueListenableBuilder<bool>(
                      valueListenable: _hasVPN,
                      builder: (context, hasVPN, child) {
                        if (!hasVPN) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[300]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.red[700]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '检测到VPN连接，请关闭VPN后下拉刷新重试',
                                  style: TextStyle(color: Colors.red[700]),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    // 本地设备信息
                    ValueListenableBuilder<DeviceInfo?>(
                      valueListenable: _localDevice,
                      builder: (context, localDevice, child) {
                        if (localDevice == null) return const SizedBox.shrink();
                        return ListTile(
                          leading: Icon(localDevice.icon, color: localDevice.color),
                          title: Text(
                            '本机IP: ${localDevice.ip}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                    // 扫描到的设备列表
                    ValueListenableBuilder<List<DeviceInfo>>(
                      valueListenable: _activeDevices,
                      builder: (context, devices, child) {
                        if (devices.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                _isScanning.value ? '正在扫描...' : '未发现设备\n下拉可重新扫描',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: devices.map((device) => ListTile(
                            leading: Icon(device.icon, color: device.color),
                            title: Text(
                              device.ip,
                              style: TextStyle(
                                color: device.color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              device.typeDescription,
                              style: TextStyle(color: device.color.withOpacity(0.7)),
                            ),
                            trailing: Text(
                              '${device.openPorts.length}个端口',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          )).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 自定义扫描动画画笔
class _ScannerPainter extends CustomPainter {
  final Color color;
  final Paint _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  
  _ScannerPainter({required this.color}) {
    _paint.color = color;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // 绘制两个同心圆
    for (int i = 1; i <= 2; i++) {
      final radius = (size.width / 2) * (i / 2);
      final path = Path();
      
      // 每个圆绘制4个弧形
      for (var j = 0; j < 4; j++) {
        final startAngle = (j * pi / 2);
        final sweepAngle = pi / 4;
        path.addArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
        );
      }
      
      // 根据圆的大小调整透明度
      final opacity = 0.8 - (i - 1) * 0.3;
      _paint.color = color.withOpacity(opacity);
      canvas.drawPath(path, _paint);
    }
  }

  @override
  bool shouldRepaint(_ScannerPainter oldDelegate) => 
    oldDelegate.color != color;
}
