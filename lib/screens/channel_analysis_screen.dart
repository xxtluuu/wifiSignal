import 'package:flutter/material.dart';
import '../models/channel_info.dart';
import '../services/channel_analyzer.dart';
import '../widgets/channel_chart.dart';

class ChannelAnalysisScreen extends StatefulWidget {
  const ChannelAnalysisScreen({super.key});

  @override
  State<ChannelAnalysisScreen> createState() => _ChannelAnalysisScreenState();
}

class _ChannelAnalysisScreenState extends State<ChannelAnalysisScreen> {
  final _analyzer = ChannelAnalyzer();
  List<ChannelInfo> _channels = [];
  List<int> _recommendedChannels = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _setupAnalyzer();
    _toggleScanning(); // 自动开始扫描
  }

  void _setupAnalyzer() {
    _analyzer.channelStream.listen(
      (channels) {
        if (mounted) {
          setState(() {
            _channels = channels;
            _recommendedChannels = _analyzer.getRecommendedChannels(channels);
          });
        }
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('扫描出错: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  void _toggleScanning() {
    setState(() {
      _isScanning = !_isScanning;
      if (_isScanning) {
        _analyzer.startScanning();
      } else {
        _analyzer.stopScanning();
      }
    });
  }

  @override
  void dispose() {
    _analyzer.dispose();
    super.dispose();
  }

  Widget _buildChannelSection(String title, List<ChannelInfo> channels) {
    if (channels.isEmpty) return const SizedBox();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${channels.length} 个信道)',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '图表显示各信道的占用率，绿色表示推荐信道，红色表示拥挤信道',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            ChannelChart(
              channels: channels,
              recommendedChannels: _recommendedChannels,
            ),
            const SizedBox(height: 16),
            const Text(
              '检测到的网络',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: channels.length,
              itemBuilder: (context, index) {
                final channel = channels[index];
                if (channel.networks.isEmpty) return const SizedBox();
                return ExpansionTile(
                  title: Text('信道 ${channel.channel}'),
                  subtitle: Text(
                    '${channel.networks.length}个网络 · ${channel.usage}%占用',
                  ),
                  children: channel.networks.map((ssid) {
                    return ListTile(
                      leading: const Icon(Icons.wifi),
                      title: Text(ssid),
                      dense: true,
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('信道分析'),
      ),
      body: _channels.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在扫描WiFi信道...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildChannelSection('2.4GHz', _channels.where((c) => c.frequency < 5000).toList()),
                  const SizedBox(height: 16),
                  _buildChannelSection('5GHz', _channels.where((c) => c.frequency >= 5000).toList()),
                ],
              ),
            ),
    );
  }
}
