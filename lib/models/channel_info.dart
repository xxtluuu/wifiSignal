class ChannelInfo {
  final int channel;
  final int frequency;
  final double signalStrength;
  final int usage; // 信道占用率（百分比）
  final List<String> networks; // 使用此信道的网络SSID列表

  ChannelInfo({
    required this.channel,
    required this.frequency,
    required this.signalStrength,
    required this.usage,
    required this.networks,
  });

  // 获取信道对应的频率
  static int getFrequency(int channel) {
    if (channel >= 1 && channel <= 13) {
      // 2.4GHz频段
      return 2412 + (channel - 1) * 5; // 每个信道间隔5MHz
    } else if (channel >= 36 && channel <= 165) {
      // 5GHz频段
      return 5180 + (channel - 36) * 5;
    }
    return 0;
  }

  // 判断信道是否拥挤
  bool isCongested() {
    return usage > 70; // 占用率超过70%认为拥挤
  }

  // 获取信道质量评分（0-100）
  int getQualityScore() {
    // 根据信号强度和占用率计算综合评分
    double signalScore = (signalStrength + 100) / 100 * 50; // 信号强度占50分
    double usageScore = (100 - usage) / 100 * 50; // 占用率占50分
    return (signalScore + usageScore).round();
  }
}
