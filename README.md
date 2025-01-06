# WiFi优化助手说明文档

## 项目概述
WiFi优化助手是一款基于 Flutter 框架开发的移动端应用，专注于测量当前连接 WiFi 网络的信号强度。应用支持实时信号强度监测，特别适用于测试用户在室内移动时的信号变化，并支持 Mesh 网络下多节点的信号识别。

## 系统要求
- **Flutter 版本**：3.19.0 或更高版本
- **Android**：Android 10 (API Level 29) 或更高版本
- **iOS**：iOS 15.0 或更高版本
- 设备需要 WiFi 硬件支持
- 需要位置权限（用于 WiFi 信号测量）

## 功能特性

### 1. 实时信号测量
- 实时获取当前连接 WiFi 网络的信号强度（RSSI）
- 支持用户移动时的动态信号强度更新
- 信号强度更新频率：每秒一次
- 信号数据实时可视化展示

### 2. Mesh网络支持
- 自动识别当前连接的 Mesh 网络节点
- 显示所有 Mesh 节点的信号强度
- 通过 BSSID 区分不同节点
- 实时更新各节点信号强度数据

### 3. 可视化界面
- 实时信号强度数值显示
- 信号强度等级指示器
- 信号趋势实时图表
- Mesh节点信号对比视图

### 4. 信道分析
- 检测周围的 WiFi 信号，分析信道占用情况
- 提供推荐信道，避免信号干扰
- 通过图表展示信号强度随时间的变化

### 5. 局域网IP扫描
- 扫描局域网中的在线设备的IP 地址

### 6. 网络拓扑图
- 自动生成局域网拓扑图，展示设备间的连接关系
- 支持手动调整节点位置
- 提供节点详细信息，包括设备名称、带宽使用情况等

## 技术实现

### Flutter实现
```dart
import 'package:wifi_iot/wifi_iot.dart';
import 'package:network_info_plus/network_info_plus.dart';

class WifiSignalMonitor {
  Timer? _timer;
  final _networkInfo = NetworkInfo();
  
  // 开始实时监测
  void startMonitoring() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      final signal = await getCurrentSignalStrength();
      // 更新UI
    });
  }
  
  // 获取当前WiFi信号强度
  Future<int> getCurrentSignalStrength() async {
    try {
      final wifiName = await _networkInfo.getWifiName(); // 获取SSID
      final signal = await WiFiForIoTPlugin.getCurrentSignalStrength();
      return signal;
    } catch (e) {
      print('信号获取错误: $e');
      return 0;
    }
  }
  
  // 获取Mesh节点信息
  Future<List<MeshNode>> getMeshNodes() async {
    // 实现Mesh节点识别逻辑
  }
}

// Mesh节点数据结构
class MeshNode {
  final String bssid;      // MAC地址
  final String nodeName;   // 节点名称
  int signalStrength;      // 信号强度(dBm)
  DateTime lastUpdate;     // 最后更新时间
  
  MeshNode({
    required this.bssid,
    required this.nodeName,
    required this.signalStrength,
    required this.lastUpdate,
  });
}
```

### 信号强度标准
- 极好：≥ -50 dBm
- 很好：-50 ~ -60 dBm
- 好：-60 ~ -70 dBm
- 一般：-70 ~ -80 dBm
- 差：< -80 dBm

## 用户界面设计

### 主界面功能
1. **信号强度显示区**
   - 大数字显示当前信号强度（dBm）
   - 信号强度等级指示（极好/很好/好/一般/差）
   - 动态信号强度指示器

2. **实时趋势图**
   - 最近30秒信号强度变化曲线
   - 实时更新的动态图表
   - 支持缩放和滑动查看

3. **Mesh节点面板**（当检测到Mesh网络时显示）
   - 列出所有检测到的Mesh节点
   - 显示各节点的实时信号强度
   - 节点信号强度对比图表

4. **信道分析面板**
   - 显示当前区域内所有WiFi信号
   - 信道占用率热力图
   - 推荐信道显示
   - 信号强度时间变化图表

5. **设备管理面板**
   - 在线设备列表
   - 设备详细信息（IP、MAC、名称）
   - 未知设备标记
   - 设备控制选项

6. **网络拓扑面板**
   - 可交互的网络拓扑图
   - 节点拖拽功能
   - 设备信息悬浮窗
   - 带宽使用情况展示

### 操作设计
- 开始/暂停按钮：控制信号监测
- 自动屏幕常亮（测量时）
- 支持后台运行测量
- 横竖屏自适应布局

## 使用流程

### 基本操作步骤
1. **启动应用**
   - 确保设备已连接WiFi网络
   - 授予必要权限（位置信息）

2. **开始测量**
   - 点击"开始"按钮
   - 观察实时信号数据
   - 移动测试不同位置的信号强度

3. **查看Mesh信息**（如适用）
   - 自动显示Mesh节点信息
   - 查看各节点信号强度对比

4. **信道分析**
   - 查看周围WiFi信号
   - 分析信道占用情况
   - 获取推荐信道

5. **设备管理**
   - 扫描在线设备
   - 查看设备详情
   - 管理设备连接

6. **查看网络拓扑**
   - 浏览网络结构
   - 调整节点位置
   - 查看设备详情

## 权限要求

### Android权限
```xml
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
```

### iOS权限
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>需要位置权限以获取WiFi信号强度数据</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>需要后台位置权限以持续监测WiFi信号强度</string>
```

## 注意事项

### 测量建议
- 测量时保持设备正常握持方向
- 移动时保持匀速行走
- 注意避开大型金属物体的遮挡

### 使用限制
- 仅支持测量已连接的WiFi网络
- 部分设备可能需要开启GPS才能获取信号数据
- 后台测量时可能受系统限制
- 设备管理功能需要路由器支持相应接口

## 开发计划

### 第一阶段：基础功能
- [x] Flutter项目初始化
- [x] WiFi信号获取实现
- [ ] 实时信号显示UI
- [ ] 基础图表实现

### 第二阶段：功能完善
- [ ] Mesh节点识别
- [ ] 实时趋势图表
- [ ] 性能优化
- [ ] 后台运行支持

### 第三阶段：高级功能
- [ ] 信道分析功能
- [ ] 设备扫描与管理
- [ ] 网络拓扑图生成
- [ ] 路由器接口集成

## 版本历史
- **v0.1.0** (2025-01-01)
  - 初始版本
  - 基础信号测量功能
  - 实时信号强度显示

## 许可证
本项目采用 MIT 开源许可证。
