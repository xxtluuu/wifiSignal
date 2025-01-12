import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/wifi_scanner.dart';
import '../models/wifi_network.dart';

class WifiSignalDisplay extends StatefulWidget {
  final WifiScanner wifiScanner;

  const WifiSignalDisplay({
    Key? key,
    required this.wifiScanner,
  }) : super(key: key);

  @override
  State<WifiSignalDisplay> createState() => _WifiSignalDisplayState();
}

class _WifiSignalDisplayState extends State<WifiSignalDisplay> {
  final List<FlSpot> _signalData = [];
  static const int _maxDataPoints = 45; // 显示最近90秒的数据
  WifiNetwork? _currentNetwork;
  StreamSubscription? _signalSubscription;

  @override
  void initState() {
    super.initState();
    // 订阅信号强度更新
    _signalSubscription = widget.wifiScanner.signalStream.listen((signal) {
      if (!mounted) return; // 确保组件仍然挂载
      setState(() {
        // 添加新的数据点
        if (_signalData.length >= _maxDataPoints) {
          _signalData.removeAt(0);
        }
        
        // 确保x坐标连续
        double nextX = _signalData.isEmpty ? 0 : _signalData.last.x + 1;
        _signalData.add(FlSpot(nextX, signal.toDouble()));
        
        // 更新所有点的x坐标以保持连续性
        for (int i = 0; i < _signalData.length; i++) {
          _signalData[i] = FlSpot(i.toDouble(), _signalData[i].y);
        }
      });
    });
    _loadCurrentNetwork();
  }

  void _loadCurrentNetwork() async {
    if (!mounted) return;
    _currentNetwork = await widget.wifiScanner.getCurrentNetwork();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _signalSubscription?.cancel();
    _signalSubscription = null;
    widget.wifiScanner.stopMonitoring();
    super.dispose();
  }

  // 获取信号强度对应的颜色
  Color _getSignalColor(int strength) {
    if (strength >= -40) return Colors.green;
    if (strength >= -60) return Colors.blue;
    if (strength >= -80) return Colors.orange;
    return Colors.red;
  }

  // 信号强度标准表格
  Widget _buildSignalStandardTable() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '信号强度标准',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 5),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(2),
              },
              children: const [
                TableRow(
                  children: [
                    TableCell(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Text('极好', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    TableCell(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Text('-20 ~ -40 dBm', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    TableCell(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Text('很好', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    TableCell(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Text('-40 ~ -60 dBm', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    TableCell(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Text('一般', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    TableCell(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Text('-60 ~ -80 dBm', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    TableCell(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Text('差', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    TableCell(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Text('< -80 dBm', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 当前网络信息
        Card(
          margin: const EdgeInsets.all(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前网络: ${_currentNetwork?.ssid ?? '未连接'}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 8),
                Text('BSSID: ${_currentNetwork?.bssid ?? '-'}'),
                Text('IP地址: ${_currentNetwork?.ipAddress ?? '-'}'),
              ],
            ),
          ),
        ),
        
        // 信号强度显示
        if (_signalData.isNotEmpty)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${_signalData.last.y.toInt()} dBm',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getSignalColor(_signalData.last.y.toInt()),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          widget.wifiScanner.getSignalLevel(_signalData.last.y.toInt()),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // 信号趋势图
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(show: true),
                        titlesData: const FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: true),
                        minX: 0,
                        maxX: (_maxDataPoints - 1).toDouble(),
                        minY: -100,
                        maxY: -20,
                        lineBarsData: [
                          LineChartBarData(
                            spots: _signalData,
                            isCurved: true,
                            color: Colors.yellow,
                            barWidth: 2,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.yellow.withOpacity(0.2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 信号强度标准
                  _buildSignalStandardTable(),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
