import 'package:flutter/material.dart';

enum DeviceType {
  unknown,
  gateway,
  mobile,
  desktop,
  printer,
  gameConsole,
  iot,
  nas,
}

class DeviceInfo {
  final String ip;
  final DeviceType type;
  final List<int> openPorts;
  final bool isLocalDevice;

  DeviceInfo({
    required this.ip,
    required this.type,
    required this.openPorts,
    this.isLocalDevice = false,
  });

  IconData get icon {
    switch (type) {
      case DeviceType.gateway:
        return Icons.router;
      case DeviceType.mobile:
        return Icons.phone_android;
      case DeviceType.desktop:
        return Icons.computer;
      case DeviceType.printer:
        return Icons.print;
      case DeviceType.gameConsole:
        return Icons.sports_esports;
      case DeviceType.iot:
        return Icons.home_max;
      case DeviceType.nas:
        return Icons.storage;
      case DeviceType.unknown:
      default:
        return Icons.devices_other;
    }
  }

  Color get color {
    switch (type) {
      case DeviceType.gateway:
        return Colors.blue; // 蓝色表示网关/路由器
      case DeviceType.mobile:
        return Colors.green; // 绿色表示移动设备
      case DeviceType.desktop:
        return Colors.purple; // 紫色表示桌面设备
      case DeviceType.printer:
        return Colors.brown; // 棕色表示打印机
      case DeviceType.gameConsole:
        return Colors.red; // 红色表示游戏机
      case DeviceType.iot:
        return Colors.orange; // 橙色表示IoT设备
      case DeviceType.nas:
        return Colors.teal; // 青色表示NAS设备
      case DeviceType.unknown:
      default:
        return Colors.grey; // 灰色表示未知设备
    }
  }

  String get typeDescription {
    switch (type) {
      case DeviceType.gateway:
        return '网关/路由器';
      case DeviceType.mobile:
        return '移动设备';
      case DeviceType.desktop:
        return '电脑/笔记本';
      case DeviceType.printer:
        return '打印机';
      case DeviceType.gameConsole:
        return '游戏机';
      case DeviceType.iot:
        return '智能家居设备';
      case DeviceType.nas:
        return 'NAS存储设备';
      case DeviceType.unknown:
      default:
        return '未知设备';
    }
  }
}
