import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class VPNDetector {
  static final _networkInfo = NetworkInfo();
  static final _connectivity = Connectivity();
  
  /// 检查是否存在VPN连接
  static Future<bool> isVPNActive() async {
    try {
      print('========= VPN检测开始 =========');
      print('当前平台: ${Platform.isIOS ? "iOS" : Platform.isAndroid ? "Android" : "其他平台"}');

      // 首先检查网络连接类型
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.vpn) {
        print('通过 connectivity_plus 检测到VPN连接');
        return true;
      }

      // 如果connectivity_plus没有检测到VPN，使用网络接口检测作为备选方案
      final interfaces = await NetworkInterface.list();
      
      if (Platform.isIOS) {
        // iOS平台的VPN检测
        for (var interface in interfaces) {
          print('检查接口: ${interface.name}');
          
          // 跳过iOS系统的utun接口
          if (interface.name.toLowerCase().startsWith('utun')) {
            print('  [iOS] 跳过utun接口');
            continue;
          }
          
          // 检查是否是VPN接口
          if (interface.name.toLowerCase().contains('tun') ||  // OpenVPN
              interface.name.toLowerCase().contains('ppp') ||  // PPTP
              interface.name.toLowerCase().contains('ipsec')) {  // IPSec
            print('  [iOS] 检测到VPN接口: ${interface.name}');
            return true;
          }
        }
      } else if (Platform.isAndroid) {
        // Android平台的VPN检测
        bool hasVPNInterface = false;
        bool hasWlan0 = false;
        
        for (var interface in interfaces) {
          print('检查接口: ${interface.name}');
          
          // 检查是否存在wlan0接口
          if (interface.name.toLowerCase() == 'wlan0') {
            hasWlan0 = true;
            continue;
          }
          
          // 检查VPN接口特征
          if (interface.name.toLowerCase().contains('tun') ||   // OpenVPN/WireGuard
              interface.name.toLowerCase().contains('ppp') ||   // PPTP
              interface.name.toLowerCase().contains('ipsec')) { // IPSec
            print('  [Android] 检测到VPN接口: ${interface.name}');
            hasVPNInterface = true;
            
            // 检查接口的IP地址
            for (var addr in interface.addresses) {
              if (addr.type == InternetAddressType.IPv4) {
                print('    IP地址: ${addr.address}');
              }
            }
          }
        }
        
        // Android上通常同时存在VPN接口和wlan0时才确认VPN已连接
        if (hasVPNInterface && hasWlan0) {
          print('  [Android] 确认VPN连接：检测到VPN接口且存在wlan0');
          return true;
        }
      }
      
      print('未检测到VPN连接');
      return false;
    } catch (e) {
      print('VPN检测出错: $e');
      return false;
    }
  }
}
