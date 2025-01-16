import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import '../models/device_info.dart';
import 'arp_service/port_config.dart';
import 'arp_service/device_type_detector.dart';
import 'arp_service/vpn_detector.dart';

class ARPService {
  static const int _timeout = 300; // 超时时间(毫秒)
  static const int _maxConcurrent = 20; // 最大并发扫描数
  
  // 取消标志
  bool get isCancelled => _isCancelled;
  bool _isCancelled = false;
  List<StreamSubscription>? _activeSubscriptions;

  /// 扫描网络设备
  /// onProgress: 扫描进度回调函数
  /// onDeviceFound: 发现设备回调函数
  /// 如果检测到VPN连接，将抛出异常
  Future<List<DeviceInfo>> scanNetwork({
    Function(double)? onProgress,
    Function(DeviceInfo)? onDeviceFound,
  }) async {
    _isCancelled = false;
    _activeSubscriptions = [];
    final List<DeviceInfo> devices = [];
    String? subnet;
    String? localIP;
    
    try {
      // 检查VPN连接
      if (await VPNDetector.isVPNActive()) {
        throw Exception('检测到VPN连接，请关闭VPN后重试');
      }
      
      // 获取本机IP和子网
      final interfaces = await NetworkInterface.list();
      
      // 打印所有网络接口信息用于调试
      print('发现的网络接口:');
      for (var interface in interfaces) {
        print('接口名称: ${interface.name}');
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            print('  IPv4地址: ${addr.address}');
          }
        }
      }
      
      // 收集所有可能的局域网IP地址
      final List<Map<String, String>> privateAddresses = [];
      
      for (var interface in interfaces) {
        print('检查接口: ${interface.name}');
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              final firstOctet = int.tryParse(parts[0]) ?? 0;
              final secondOctet = int.tryParse(parts[1]) ?? 0;
              
              if (!addr.address.startsWith('127.')) {
                if (firstOctet == 192 && secondOctet == 168) {
                  print('  找到192.168网段地址: ${addr.address}');
                  privateAddresses.add({
                    'type': '192.168',
                    'address': addr.address,
                    'interface': interface.name
                  });
                } else if (firstOctet == 10) {
                  print('  找到10.x网段地址: ${addr.address}');
                  privateAddresses.add({
                    'type': '10',
                    'address': addr.address,
                    'interface': interface.name
                  });
                } else if (firstOctet == 172 && secondOctet >= 16 && secondOctet <= 31) {
                  print('  找到172.16-31网段地址: ${addr.address}');
                  privateAddresses.add({
                    'type': '172',
                    'address': addr.address,
                    'interface': interface.name
                  });
                }
              }
            }
          }
        }
      }

      // 优先选择wlan0接口的192.168网段地址
      Map<String, String>? selectedAddress;
      
      // 根据平台选择合适的网络接口
      if (Platform.isIOS) {
        // 在iOS上，优先选择en0接口（通常是WiFi）的地址
        selectedAddress = privateAddresses.firstWhere(
          (addr) => addr['interface']?.toLowerCase() == 'en0' && addr['type'] == '192.168',
          orElse: () => privateAddresses.firstWhere(
            (addr) => addr['type'] == '192.168',
            orElse: () => privateAddresses.firstWhere(
              (addr) => true,
              orElse: () => {'address': '', 'interface': ''}
            )
          )
        );
      } else {
        // 在其他平台上保持原有的wlan0优先级
        selectedAddress = privateAddresses.firstWhere(
          (addr) => addr['type'] == '192.168' && addr['interface'] == 'wlan0',
          orElse: () => {'address': '', 'interface': ''}
        );
      }
      
      print('选择的网络接口: ${selectedAddress['interface']}');
      print('选择的IP地址: ${selectedAddress['address']}');

      if (selectedAddress['address']?.isNotEmpty == true) {
        localIP = selectedAddress['address']!;
        subnet = localIP.substring(0, localIP.lastIndexOf('.'));
        print('确认本机IP: $localIP');
        
        // 添加本机设备信息
        final localDevice = DeviceInfo(
          ip: localIP,
          type: DeviceType.desktop, // 假设本机是桌面设备
          openPorts: [],
          isLocalDevice: true,
        );
        devices.add(localDevice);
        onDeviceFound?.call(localDevice);
      }

      if (subnet == null || localIP == null || _isCancelled) {
        throw Exception('无法获取本地网络信息');
      }

      final totalHosts = 254;
      int scannedHosts = 0;
      final completer = Completer<void>();

      // 分批次扫描，控制并发数
      for (int start = 1; start <= 254; start += _maxConcurrent) {
        if (_isCancelled) break;
        
        final batch = <Future<DeviceInfo?>>[];
        final batchIPs = <String>[];
        
        // 创建一批扫描任务
        for (int i = 0; i < _maxConcurrent && start + i <= 254; i++) {
          final ip = '$subnet.${start + i}';
          if (ip != localIP) {
            batchIPs.add(ip);
            batch.add(_scanHost(ip));
          }
        }
        
        // 等待当前批次完成
        final results = await Future.wait(batch);
        for (int i = 0; i < results.length; i++) {
          if (_isCancelled) break;
          
          scannedHosts++;
          if (onProgress != null) {
            onProgress(scannedHosts / totalHosts);
          }
          
          final device = results[i];
          if (device != null) {
            devices.add(device);
            print('添加设备: ${device.ip} (${device.typeDescription})');
            onDeviceFound?.call(device);
          }
        }
      }
      
      // 扫描完成
      completer.complete();

      // 等待所有扫描完成或取消
      await completer.future.timeout(
        Duration(milliseconds: _timeout * totalHosts),
        onTimeout: () {
          cancel();
        },
      );
      
      if (!_isCancelled) {
        // 按IP地址排序（本机IP已经在第一位）
        final otherDevices = devices.sublist(1);
        otherDevices.sort((a, b) {
          final aNum = int.parse(a.ip.split('.').last);
          final bNum = int.parse(b.ip.split('.').last);
          return aNum.compareTo(bNum);
        });
        devices.replaceRange(1, devices.length, otherDevices);
      }

    } catch (e) {
      print('扫描错误: $e');
    }
    
    return _isCancelled ? [] : devices;
  }

  /// 扫描单个主机的端口
  Future<DeviceInfo?> _scanHost(String ip) async {
    if (_isCancelled) return null;
    
    try {
      // 并发检查所有端口
      final futures = PortConfig.commonPorts.map((port) => _checkPort(ip, port));
      final results = await Future.wait(futures);
      
      // 收集开放的端口
      final openPorts = <int>[];
      for (int i = 0; i < results.length; i++) {
        if (results[i]) {
          openPorts.add(PortConfig.commonPorts[i]);
        }
      }
      
      if (openPorts.isNotEmpty) {
        // 如果设备有5000和5001端口开放，则判定为NAS设备
        if (openPorts.contains(5000) && openPorts.contains(5001)) {
          return DeviceInfo(
            ip: ip,
            type: DeviceType.nas,
            openPorts: openPorts,
          );
        }
        
        final deviceType = DeviceTypeDetector.determineDeviceType(openPorts);
        return DeviceInfo(
          ip: ip,
          type: deviceType,
          openPorts: openPorts,
        );
      }
      return null;
    } catch (e) {
      print('扫描主机错误: $ip - $e');
      return null;
    }
  }

  /// 检查单个端口是否开放
  Future<bool> _checkPort(String ip, int port) async {
    if (_isCancelled) return false;
    
    try {
      final socket = await Socket.connect(
        ip,
        port,
        timeout: Duration(milliseconds: _timeout),
      );
      print('发现设备: $ip (端口: $port)');
      await socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 取消扫描操作
  void cancel() {
    _isCancelled = true;
    _activeSubscriptions?.forEach((subscription) => subscription.cancel());
    _activeSubscriptions?.clear();
    _activeSubscriptions = null;
  }
}
