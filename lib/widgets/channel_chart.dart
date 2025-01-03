import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/channel_info.dart';

class ChannelChart extends StatelessWidget {
  final List<ChannelInfo> channels;
  final List<int> recommendedChannels;

  const ChannelChart({
    super.key,
    required this.channels,
    required this.recommendedChannels,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 300,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 100,
              minY: 0,
              groupsSpace: 12,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  tooltipBgColor: Colors.blueGrey,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final channel = channels[groupIndex];
                    return BarTooltipItem(
                      '信道: ${channel.channel}\n'
                      '占用率: ${channel.usage}%\n'
                      '信号: ${channel.signalStrength.round()} dBm\n'
                      '网络数: ${channel.networks.length}',
                      const TextStyle(color: Colors.white),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value >= 0 && value < channels.length) {
                        return Text(
                          channels[value.toInt()].channel.toString(),
                          style: const TextStyle(fontSize: 10),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${value.toInt()}%',
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: const FlGridData(
                show: true,
                drawVerticalLine: false,
              ),
              borderData: FlBorderData(show: false),
              barGroups: channels.asMap().entries.map((entry) {
                final index = entry.key;
                final info = entry.value;
                final isRecommended = recommendedChannels.contains(info.channel);
                
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: info.usage.toDouble(),
                      color: isRecommended ? Colors.green : 
                             info.isCongested() ? Colors.red : Colors.blue,
                      width: 16,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 推荐信道显示
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.recommend, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      '推荐信道',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: recommendedChannels.map((channel) {
                    final info = channels.firstWhere(
                      (c) => c.channel == channel,
                      orElse: () => ChannelInfo(
                        channel: channel,
                        frequency: ChannelInfo.getFrequency(channel),
                        signalStrength: 0,
                        usage: 0,
                        networks: [],
                      ),
                    );
                    return Chip(
                      avatar: const Icon(Icons.check_circle, color: Colors.green, size: 18),
                      label: Text(
                        '信道 $channel (${info.usage}%)',
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.green.withOpacity(0.1),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
