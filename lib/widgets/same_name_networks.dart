import 'dart:async';
import 'package:flutter/material.dart';
import '../models/wifi_network.dart';
import '../services/wifi_scanner.dart';

class SameNameNetworks extends StatefulWidget {
  final WifiScanner wifiScanner;
  final WifiNetwork currentNetwork;

  const SameNameNetworks({
    Key? key,
    required this.wifiScanner,
    required this.currentNetwork,
  }) : super(key: key);

  @override
  State<SameNameNetworks> createState() => _SameNameNetworksState();
}

class _SameNameNetworksState extends State<SameNameNetworks> {
  List<WifiNetwork> _sameNameNetworks = [];
  StreamSubscription? _networksSubscription;
  Timer? _scanTimer;

  @override
  void initState() {
    super.initState();
    _startNetworkScanning();
  }

  void _startNetworkScanning() {
    // 订阅网络列表更新
    _networksSubscription = widget.wifiScanner.networksStream.listen((networks) {
      if (!mounted) return;
      setState(() {
        // 过滤出与当前网络同名的其他网络
        _sameNameNetworks = networks
            .where((network) => 
              network.ssid == widget.currentNetwork.ssid && 
              network.bssid != widget.currentNetwork.bssid)
            .toList();
      });
    });

    // 定期扫描网络
    _scanTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      widget.wifiScanner.getAllNetworks();
    });

    // 立即进行第一次扫描
    widget.wifiScanner.getAllNetworks();
  }

  @override
  void dispose() {
    _networksSubscription?.cancel();
    _scanTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_sameNameNetworks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Text(
          '同名网络:',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ...(_sameNameNetworks.map((network) => Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BSSID: ${network.bssid}'),
              Text('信号强度: ${network.signalStrength.toInt()} dBm (${network.getSignalLevel()})'),
              Text('频率: ${network.frequency != null ? '${network.frequency} MHz' : '-'}'),
              Text('信道: ${network.getChannel() ?? '-'}'),
              const Divider(),
            ],
          ),
        ))),
      ],
    );
  }
}
