import '../../models/device_info.dart';

class DeviceTypeDetector {
  /// 根据开放端口判断设备类型
  static DeviceType determineDeviceType(List<int> openPorts) {
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
}
