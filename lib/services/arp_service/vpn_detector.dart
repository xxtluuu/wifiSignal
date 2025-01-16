import 'dart:io';

class VPNDetector {
  // VPN相关的网络接口名称
  static const List<String> vpnInterfaces = [
    'tun',      // OpenVPN
    'ppp',      // PPTP VPN
    'ipsec',    // IPSec VPN
    'nordlynx', // NordVPN WireGuard
    'wg',       // WireGuard
    'vpn',      // 通用VPN标识
  ];

  /// 检查是否存在VPN连接
  static Future<bool> isVPNActive() async {
    try {
      final interfaces = await NetworkInterface.list();
      
      print('========= 网络接口检测开始 =========');
      print('当前平台: ${Platform.isIOS ? "iOS" : Platform.isAndroid ? "Android" : "其他平台"}');
      
      // 用于Android的特殊检测
      bool hasWlan0 = false;
      bool hasVPNInterface = false;
      
      for (var interface in interfaces) {
        print('\n检查接口: ${interface.name}');
        print('接口地址:');
        for (var addr in interface.addresses) {
          print('  - ${addr.address} (${addr.type == InternetAddressType.IPv4 ? "IPv4" : "IPv6"})');
        }

        // iOS平台的处理
        if (Platform.isIOS) {
          if (interface.name.toLowerCase().startsWith('utun')) {
            print('  [iOS] 跳过utun接口检测');
            continue;
          }
          // 检查是否是VPN接口
          if (vpnInterfaces.any((vpn) => interface.name.toLowerCase().contains(vpn))) {
            print('  [iOS] 检测到VPN接口: ${interface.name}');
            return true;
          }
        }
        // Android平台的处理
        else if (Platform.isAndroid) {
          // 记录是否存在wlan0接口
          if (interface.name.toLowerCase() == 'wlan0') {
            hasWlan0 = true;
          }
          
          // 检查VPN特征
          if (vpnInterfaces.any((vpn) => interface.name.toLowerCase().contains(vpn))) {
            hasVPNInterface = true;
          }
          
          // 检查接口的IP地址特征
          for (var addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4) {
              // 在Android上，VPN通常会创建一个IP地址为10.0.0.x的tun接口
              if (addr.address.startsWith('10.') && interface.name.toLowerCase().contains('tun')) {
                print('  [Android] 检测到VPN接口: ${interface.name} with IP ${addr.address}');
                hasVPNInterface = true;
              }
            }
          }
        }
      }
      
      // Android平台的最终判断
      if (Platform.isAndroid) {
        // 如果检测到VPN接口并且存在wlan0，则认为VPN处于活动状态
        if (hasVPNInterface && hasWlan0) {
          print('  [Android] 确认VPN连接：检测到VPN接口且存在wlan0');
          return true;
        }
      }
      
      print('========= 网络接口检测完成 =========');
      print('未检测到VPN连接');
      return false;
    } catch (e) {
      print('VPN检测错误: $e');
      return false;
    }
  }
}
