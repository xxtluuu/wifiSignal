import 'dart:async';
import '../models/channel_info.dart';
import '../models/wifi_network.dart' as models;
import 'package:wifi_iot/wifi_iot.dart' as wifi_iot;

class ChannelAnalyzer {
  Timer? _scanTimer;
  final _channelController = StreamController<List<ChannelInfo>>.broadcast();
  
  Stream<List<ChannelInfo>> get channelStream => _channelController.stream;
  
  // 开始周期性扫描
  void startScanning() {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      scanChannels();
    });
    scanChannels(); // 立即开始第一次扫描
  }
  
  // 停止扫描
  void stopScanning() {
    _scanTimer?.cancel();
    _scanTimer = null;
  }
  
  // 扫描所有信道
  Future<void> scanChannels() async {
    try {
      // 获取周围的WiFi网络
      var wifiList = await wifi_iot.WiFiForIoTPlugin.loadWifiList() ?? [];
      List<models.WifiNetwork> networks = wifiList.map((network) => models.WifiNetwork(
        ssid: network.ssid ?? 'Unknown',
        bssid: network.bssid ?? '',
        signalStrength: (network.level ?? -100).toDouble(),
        timestamp: DateTime.now(),
        frequency: network.frequency ?? 0,
      )).toList();
      
      // 按信道分组网络
      Map<int, List<models.WifiNetwork>> channelGroups = {};
      for (var network in networks) {
        int channel = _getChannelFromFrequency(network.frequency ?? 0);
        channelGroups.putIfAbsent(channel, () => []).add(network);
      }
      
      // 生成信道信息列表
      List<ChannelInfo> channelInfos = [];
      channelGroups.forEach((channel, networkList) {
        // 计算平均信号强度
        double avgSignal = networkList.fold(0.0, (sum, network) => 
          sum + (network.signalStrength ?? -100)) / networkList.length;
        
        // 计算信道占用率（根据网络数量估算）
        int usage = (networkList.length / 5 * 100).round().clamp(0, 100);
        
        channelInfos.add(ChannelInfo(
          channel: channel,
          frequency: ChannelInfo.getFrequency(channel),
          signalStrength: avgSignal,
          usage: usage,
          networks: networkList.map((n) => n.ssid).where((ssid) => ssid != null).map((ssid) => ssid!).toList(),
        ));
      });
      
      // 按信道号排序
      channelInfos.sort((a, b) => a.channel.compareTo(b.channel));
      
      _channelController.add(channelInfos);
    } catch (e) {
      print('信道扫描错误: $e');
      _channelController.addError(e);
    }
  }
  
  // 获取推荐信道
  List<int> getRecommendedChannels(List<ChannelInfo> channels) {
    // 按质量评分排序
    var sortedChannels = List<ChannelInfo>.from(channels)
      ..sort((a, b) => b.getQualityScore().compareTo(a.getQualityScore()));
    
    // 返回前3个最佳信道
    return sortedChannels.take(3).map((c) => c.channel).toList();
  }
  
  // 根据频率获取信道号
  int _getChannelFromFrequency(int frequency) {
    if (frequency >= 2412 && frequency <= 2484) {
      // 2.4GHz频段
      return ((frequency - 2412) ~/ 5) + 1;
    } else if (frequency >= 5170 && frequency <= 5825) {
      // 5GHz频段
      return ((frequency - 5170) ~/ 5) + 34;
    }
    return 0;
  }
  
  void dispose() {
    stopScanning();
    _channelController.close();
  }
}
