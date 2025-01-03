import 'package:flutter/material.dart';
import '../models/wifi_network.dart';

class WifiListItem extends StatelessWidget {
  final WifiNetwork network;
  final VoidCallback? onTap;

  const WifiListItem({
    super.key,
    required this.network,
    this.onTap,
  });

  Color _getSignalColor() {
    if (network.signalStrength >= -50) return Colors.green;
    if (network.signalStrength >= -60) return Colors.lightGreen;
    if (network.signalStrength >= -70) return Colors.yellow;
    if (network.signalStrength >= -80) return Colors.orange;
    return Colors.red;
  }

  IconData _getSignalIcon() {
    if (network.signalStrength >= -50) return Icons.wifi;
    if (network.signalStrength >= -60) return Icons.wifi;
    if (network.signalStrength >= -70) return Icons.wifi;
    if (network.signalStrength >= -80) return Icons.wifi_lock;
    return Icons.wifi_off;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Icon(
          _getSignalIcon(),
          color: _getSignalColor(),
          size: 28,
        ),
        title: Text(
          network.ssid,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('信号强度: ${network.signalStrength.toStringAsFixed(1)} dBm'),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getSignalColor().withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getSignalColor().withOpacity(0.5),
            ),
          ),
          child: Text(
            network.getSignalLevel(),
            style: TextStyle(
              color: _getSignalColor(),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
