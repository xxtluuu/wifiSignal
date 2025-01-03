class WifiNetwork {
  final String ssid;
  final String bssid;
  final double signalStrength;
  final String? ipAddress;
  final DateTime timestamp;
  final int? frequency; // 添加频率字段

  WifiNetwork({
    required this.ssid,
    required this.bssid,
    required this.signalStrength,
    this.ipAddress,
    required this.timestamp,
    this.frequency,
  });

  Map<String, dynamic> toMap() {
    return {
      'ssid': ssid,
      'bssid': bssid,
      'signalStrength': signalStrength,
      'ipAddress': ipAddress,
      'timestamp': timestamp.toIso8601String(),
      'frequency': frequency,
    };
  }

  factory WifiNetwork.fromMap(Map<String, dynamic> map) {
    return WifiNetwork(
      ssid: map['ssid'],
      bssid: map['bssid'],
      signalStrength: map['signalStrength'],
      ipAddress: map['ipAddress'],
      timestamp: DateTime.parse(map['timestamp']),
      frequency: map['frequency'],
    );
  }

  String getSignalLevel() {
    if (signalStrength >= -50) return '极好';
    if (signalStrength >= -60) return '很好';
    if (signalStrength >= -70) return '好';
    if (signalStrength >= -80) return '一般';
    return '差';
  }

  // 获取WiFi信道
  int? getChannel() {
    if (frequency == null) return null;
    
    if (frequency! >= 2412 && frequency! <= 2484) {
      // 2.4GHz频段
      return ((frequency! - 2412) ~/ 5) + 1;
    } else if (frequency! >= 5170 && frequency! <= 5825) {
      // 5GHz频段
      return ((frequency! - 5170) ~/ 5) + 34;
    }
    return null;
  }
}
