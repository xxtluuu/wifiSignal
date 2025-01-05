import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/speed_test_screen.dart';
import 'screens/ip_check_screen.dart';
import 'services/service_locator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  setupServiceLocator();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    SpeedTestScreen(),
    IpCheckScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WiFi信号优化助手',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: _screens[_currentIndex],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.wifi),
              label: 'WiFi信号监测',
            ),
            NavigationDestination(
              icon: Icon(Icons.speed),
              label: '网速测试',
            ),
            NavigationDestination(
              icon: Icon(Icons.public),
              label: '公网IP检查',
            ),
          ],
        ),
      ),
    );
  }
}
