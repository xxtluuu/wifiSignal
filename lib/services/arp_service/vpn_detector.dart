import 'dart:io';

class VPNDetector {
  // VPN相关的网络接口名称
  static const List<String> vpnInterfaces = [
    'tun', // OpenVPN
    'ppp', // PPTP VPN
    'ipsec', // IPSec VPN
    'tap', // OpenVPN TAP
    'nordlynx', // NordVPN WireGuard
    'wg', // WireGuard
  ];  // Removed 'utun' as it's used for regular connections on iOS

  /// 检查是否存在VPN连接
  static Future<bool> isVPNActive() async {
    try {
      final interfaces = await NetworkInterface.list();
      
      for (var interface in interfaces) {
        // 检查接口名称是否包含VPN相关标识
        if (vpnInterfaces.any((vpn) => interface.name.toLowerCase().contains(vpn))) {
          print('检测到VPN接口: ${interface.name}');
          return true;
        }
        
        // iOS上不再使用IP地址范围检测，因为这可能导致误报
        if (!Platform.isIOS) {
          // 在非iOS平台上保留IP地址检测逻辑
          for (var addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4) {
              if (addr.address.startsWith('10.') || 
                  (addr.address.startsWith('172.') && 
                   int.parse(addr.address.split('.')[1]) >= 16 && 
                   int.parse(addr.address.split('.')[1]) <= 31)) {
                print('检测到可能的VPN IP地址: ${addr.address} on ${interface.name}');
                if (vpnInterfaces.any((vpn) => interface.name.toLowerCase().contains(vpn))) {
                  return true;
                }
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
}
