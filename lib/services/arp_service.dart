import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

class ARPService {
  static const int _timeout = 300; // 超时时间(毫秒)
  static const int _maxConcurrent = 20; // 最大并发扫描数
  // 常见设备端口列表
  static const List<int> _commonPorts = [
    80,    // HTTP - 通用Web服务
    443,   // HTTPS - 安全Web服务
    445,   // SMB - Windows文件共享
    139,   // NetBIOS - Windows网络
    22,    // SSH - Mac/Linux远程访问
    5000,  // Android开发服务
    5555,  // Android ADB
    62078, // iOS服务
    548,   // AFP - Mac文件共享
    88,    // Kerberos - Windows域服务
    515,   // 打印机LPD服务
    631,   // IPP - 打印机服务
    9100,  // 打印机原始端口
    8080,  // 常用Web替代端口
    8443,  // 常用HTTPS替代端口
    32469, // Plex媒体服务器
    5353,  // mDNS - 设备发现
    1900,  // SSDP - 设备发现
    2869,  // UPNP - 设备发现
    5357,  // WSDAPI - 设备发现
    3689,  // DAAP - iTunes共享
    548,   // AFP - Apple文件共享
    5000,  // Synology NAS
    5001,  // Synology NAS
    8096,  // Jellyfin媒体服务器
    8123,  // Home Assistant
    49152, // Windows UPnP
  ];
  
  bool get isCancelled => _isCancelled;
  bool _isCancelled = false;
  List<StreamSubscription>? _activeSubscriptions;

  Future<List<String>> scanNetwork({
    Function(double)? onProgress,
    Function(String)? onDeviceFound,
  }) async {
    _isCancelled = false;
    _activeSubscriptions = [];
    final List<String> devices = [];
    String? subnet;
    String? localIP;
    
    try {
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
      
      // 首先尝试找到wlan0接口的192.168网段地址
      selectedAddress = privateAddresses.firstWhere(
        (addr) => addr['type'] == '192.168' && addr['interface'] == 'wlan0',
        orElse: () => {'address': '', 'interface': ''}
      );
      
      // 如果没找到wlan0，则尝试任意192.168网段地址
      if (selectedAddress['address']?.isEmpty == true) {
        selectedAddress = privateAddresses.firstWhere(
          (addr) => addr['type'] == '192.168',
          orElse: () => privateAddresses.isNotEmpty ? privateAddresses.first : {'address': '', 'interface': ''}
        );
      }

      print('选择的网络接口: ${selectedAddress['interface']}');
      print('选择的IP地址: ${selectedAddress['address']}');

      if (selectedAddress['address']?.isNotEmpty == true) {
        localIP = selectedAddress['address']!;
        subnet = localIP.substring(0, localIP.lastIndexOf('.'));
        print('确认本机IP: $localIP');
        devices.add(localIP); // 直接添加本机IP，因为这是从系统接口获取的可靠信息
        onDeviceFound?.call(localIP); // 通知发现了本机IP
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
        
        final batch = <Future<bool>>[];
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
          
          if (results[i]) {
            devices.add(batchIPs[i]);
            print('添加设备: ${batchIPs[i]}');
            onDeviceFound?.call(batchIPs[i]);
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
          final aNum = int.parse(a.split('.').last);
          final bNum = int.parse(b.split('.').last);
          return aNum.compareTo(bNum);
        });
        devices.replaceRange(1, devices.length, otherDevices);
      }

    } catch (e) {
      print('扫描错误: $e');
    }
    
    return _isCancelled ? [] : devices;
  }

  Future<bool> _scanHost(String ip) async {
    if (_isCancelled) return false;
    
    try {
      // 并发检查所有端口
      final futures = _commonPorts.map((port) => _checkPort(ip, port));
      final results = await Future.wait(futures);
      return results.any((isOpen) => isOpen);
    } catch (e) {
      print('扫描主机错误: $ip - $e');
      return false;
    }
  }

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

  void cancel() {
    _isCancelled = true;
    _activeSubscriptions?.forEach((subscription) => subscription.cancel());
    _activeSubscriptions?.clear();
    _activeSubscriptions = null;
  }
}
