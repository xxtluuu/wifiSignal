import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import '../models/device_info.dart';

class ARPService {
  static const int _timeout = 300; // 超时时间(毫秒)
  static const int _maxConcurrent = 20; // 最大并发扫描数
  
  // VPN相关的网络接口名称
  static const List<String> _vpnInterfaces = [
    'tun', // OpenVPN
    'ppp', // PPTP VPN
    'ipsec', // IPSec VPN
    'utun', // iOS/macOS VPN
    'ras', // Windows VPN
    'tap', // OpenVPN TAP
    'nordlynx', // NordVPN WireGuard
    'wg', // WireGuard
  ];

  /// 检查是否存在VPN连接
  Future<bool> isVPNActive() async {
    try {
      final interfaces = await NetworkInterface.list();
      
      for (var interface in interfaces) {
        // 检查接口名称是否包含VPN相关标识
        if (_vpnInterfaces.any((vpn) => interface.name.toLowerCase().contains(vpn))) {
          print('检测到VPN接口: ${interface.name}');
          return true;
        }
        
        // 检查IP地址特征
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            // 检查是否是VPN典型的IP段
            if (addr.address.startsWith('10.') || 
                (addr.address.startsWith('172.') && 
                 int.parse(addr.address.split('.')[1]) >= 16 && 
                 int.parse(addr.address.split('.')[1]) <= 31)) {
              print('检测到可能的VPN IP地址: ${addr.address} on ${interface.name}');
              // 进一步验证是否确实是VPN接口
              if (_vpnInterfaces.any((vpn) => interface.name.toLowerCase().contains(vpn))) {
                return true;
              }
            }
          }
        }
      }
      return false;
    } catch (e) {
      print('VPN检测错误: $e');
      return false;
    }
  }
  
  // 整合后的常见设备端口列表
  static const List<int> _commonPorts = [
    // 基础网络服务
    20,    // FTP - 数据传输
    21,    // FTP - 控制连接
    22,    // SSH - 安全远程访问
    23,    // Telnet - 远程登录
    25,    // SMTP - 邮件发送
    53,    // DNS - 域名解析
    67,    // DHCP - 服务器端
    68,    // DHCP - 客户端
    69,    // TFTP - 简单文件传输
    80,    // HTTP - Web服务
    110,   // POP3 - 邮件接收
    143,   // IMAP - 邮件访问
    161,   // SNMP - 网络管理
    162,   // SNMP Trap
    443,   // HTTPS - 安全Web服务
    
    // 文件共享和打印服务
    137,   // NetBIOS - 名称服务
    138,   // NetBIOS - 数据报
    139,   // NetBIOS - 会话服务
    445,   // SMB/CIFS - 文件共享
    515,   // LPD/LPR - 打印服务
    631,   // IPP - 互联网打印协议
    9100,  // RAW/JetDirect 打印

    // 数据库和管理服务
    1433,  // MS SQL Server
    1521,  // Oracle数据库
    3306,  // MySQL/MariaDB
    5432,  // PostgreSQL
    3389,  // RDP - 远程桌面
    10000, // Webmin管理界面

    // IoT和智能设备
    1883,  // MQTT - IoT消息协议
    5683,  // CoAP - 物联网协议
    5353,  // mDNS - 设备发现
    1900,  // SSDP - 设备发现
    49152, // UPnP - 设备发现
    
    // 流媒体和娱乐
    554,   // RTSP - 实时流协议
    1935,  // RTMP - 实时消息协议
    3074,  // Xbox Live游戏服务
    3478,  // STUN/TURN - VoIP服务
    3479,  // STUN/TURN - VoIP备用
    32469, // Plex媒体服务器
    8554,  // Live555 RTSP服务
    
    // 移动设备服务
    5000,  // Android开发服务
    5555,  // Android ADB调试
    62078, // iOS服务
    
    // NAS和媒体服务器
    548,   // AFP - Apple文件共享
    8096,  // Jellyfin媒体服务器
    8123,  // Home Assistant智能家居
    5001,  // Synology NAS服务
    
    // 替代端口
    8080,  // 替代HTTP端口
    8443,  // 替代HTTPS端口
    
    // 额外的服务发现端口
    5357,  // WSDAPI - Web服务发现
    3689,  // DAAP - iTunes音乐共享
  ];
  
  // 取消标志
  bool get isCancelled => _isCancelled;
  bool _isCancelled = false;
  List<StreamSubscription>? _activeSubscriptions;

  /// 根据开放端口判断设备类型
  DeviceType _determineDeviceType(List<int> openPorts) {
    // 检查是否是网关/路由器
    if (openPorts.any((port) => [80, 443, 8080].contains(port))) {
      return DeviceType.gateway;
    }
    
    // 检查是否是打印机
    if (openPorts.any((port) => [515, 631, 9100].contains(port))) {
      return DeviceType.printer;
    }
    
    // 检查是否是游戏机
    if (openPorts.contains(3074)) {
      return DeviceType.gameConsole;
    }
    
    // 检查是否是移动设备
    if (openPorts.any((port) => [5000, 5555, 62078].contains(port))) {
      return DeviceType.mobile;
    }
    
    // 检查是否是桌面设备
    if (openPorts.contains(3389)) {
      return DeviceType.desktop;
    }
    
    // 检查是否是NAS设备
    if (openPorts.any((port) => [548, 8096, 5001].contains(port))) {
      return DeviceType.nas;
    }
    
    // 检查是否是IoT设备
    if (openPorts.any((port) => [1883, 5683, 1900, 49152].contains(port))) {
      return DeviceType.iot;
    }
    
    return DeviceType.unknown;
  }

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
      if (await isVPNActive()) {
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
      final futures = _commonPorts.map((port) => _checkPort(ip, port));
      final results = await Future.wait(futures);
      
      // 收集开放的端口
      final openPorts = <int>[];
      for (int i = 0; i < results.length; i++) {
        if (results[i]) {
          openPorts.add(_commonPorts[i]);
        }
      }
      
      if (openPorts.isNotEmpty) {
        final deviceType = _determineDeviceType(openPorts);
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
