// main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:usb_serial/usb_serial.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;

import 'xlib.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XFire Ecosystem',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          surface: const Color(0xFF141414),
          primary: Colors.blueAccent,
          secondary: Colors.amberAccent,
          error: Colors.redAccent.shade700,
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        cardTheme: CardTheme(
          color: const Color(0xFF1C1C1E),
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 13.0, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF242428),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          isDense: true,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ==========================================
// СТАРТОВАЯ ЗАСТАВКА
// ==========================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 3500), vsync: this);
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainContainer()));
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      body: Center(
        child: Text("XFire v3.27", style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, letterSpacing: 4.0, color: Colors.white)),
      ),
    );
  }
}

class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int _currentIndex = 0;
  late StreamSubscription<String> _sub;
  
  final List<Widget> _tabs = [
    const InfoConnectionTab(),
    const SettingsTab(),
    const RemoteControlTab(),
    const RadioTab(),
    const ProfilesTab(),
    const TerminalTab(),
  ];

  final List<String> _tabNames = [
    "Инфо", "Полетный контроллер FC", "Пульт RC", "Радиомодуль RTX (915 МГц)", "Профили (Калькулятор сетапа)", "Терминал CLI",
  ];

  @override
  void initState() {
    super.initState();
    _sub = SerialService.logController.stream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  Future<void> _toggleUsbConnectionFromDropdown() async {
    if (SerialService.isConnected) {
      await SerialService.disconnect();
    } else {
      try {
        List<UsbDevice> devices = await UsbSerial.listDevices();
        if (devices.isEmpty) {
          SerialService.appendLog(">> ERROR: No USB devices found\n");
          if (mounted) showAppDialog(context, "Ошибка соединения", "USB устройства не найдены! Подключите плату по USB OTG.", isError: true);
        } else {
          SerialService.usbPort = await devices[0].create();
          bool? openResult = await SerialService.usbPort?.open();
          if (openResult != true) {
            SerialService.appendLog(">> ERROR: Failed to open USB port\n");
            if (mounted) showAppDialog(context, "Ошибка соединения", "Не удалось открыть USB порт устройства!", isError: true);
          } else {
            await SerialService.usbPort!.setPortParameters(115200, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);
            SerialService.isConnected = true;
            SerialService.appendLog(">> USB Connected: ${devices[0].deviceName}\n");
            SerialService.usbSubscription = SerialService.usbPort!.inputStream!.listen((data) => SerialService.handleIncomingData(data));
          }
        }
      } catch (e) {
        SerialService.appendLog(">> ERROR: USB Exception: $e\n");
        if (mounted) showAppDialog(context, "Ошибка соединения", "Сбой подключения USB Serial: $e", isError: true);
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121214),
        elevation: 0,
        centerTitle: true,
        title: Center(
          child: Container(
            width: 280,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _currentIndex,
                dropdownColor: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(16),
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.amberAccent),
                items: [
                  ...List.generate(_tabs.length, (index) {
                    return DropdownMenuItem<int>(
                      value: index,
                      child: Text(
                        _tabNames[index],
                        style: TextStyle(
                          color: index == 0 ? Colors.greenAccent : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                  DropdownMenuItem<int>(
                    value: _tabs.length,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Соединение USB Serial",
                          style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        IgnorePointer(
                          child: Switch(
                            value: SerialService.isConnected,
                            onChanged: (_) {},
                            activeColor: Colors.blueAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    if (val < _tabs.length) {
                      setState(() => _currentIndex = val);
                    } else {
                      _toggleUsbConnectionFromDropdown();
                    }
                  }
                },
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: _tabs[_currentIndex]),
      ),
    );
  }
}

// Остальные классы вкладок (InfoConnectionTab, ProfilesTab, SettingsTab, RemoteControlTab, RadioTab, TerminalTab) остаются без изменений.
