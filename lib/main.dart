// main.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:usb_serial/usb_serial.dart';

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
        cardTheme: const CardTheme(
          color: Color(0xFF141416),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF242428),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          isDense: true,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ==========================================
// КАРТОЧКА ВЫБОРА ПО ID (ВЫПАДАЮЩИЙ СПИСОК)
// ==========================================
class XFireDropdownCard extends StatelessWidget {
  final String title;
  final String commandName;
  final int value;
  final Map<int, String> options;
  final ValueChanged<int> onChanged;

  const XFireDropdownCard({
    super.key,
    required this.title,
    required this.commandName,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final safeValue = options.containsKey(value) ? value : options.keys.first;
    final items = options.entries.toList();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 11.0, vertical: 6.0),
      color: const Color(0xFF141416),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.3,
                    ),
                    softWrap: true,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    commandName,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF242428),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: safeValue,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF242428),
                  borderRadius: BorderRadius.circular(12),
                  icon: const Icon(
                    Icons.arrow_drop_down_rounded,
                    color: Colors.amberAccent,
                    size: 26,
                  ),
                  items: items.map((entry) {
                    return DropdownMenuItem<int>(
                      value: entry.key,
                      child: Text(
                        entry.value,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        softWrap: true,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) onChanged(val);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
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

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    );
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainContainer()),
        );
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
        child: Text(
          "XFire v3.27",
          style: TextStyle(
            fontSize: 52,
            fontWeight: FontWeight.bold,
            letterSpacing: 4.0,
            color: Colors.white,
          ),
        ),
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
  late StreamSubscription<String> _logSub;
  StreamSubscription<UsbEvent>? _usbEventSub;

  final List<Widget> _tabs = [
    const InfoConnectionTab(),
    const SettingsTab(),
    const RemoteControlTab(),
    const RadioTab(),
    const ProfilesTab(),
    const TerminalTab(),
  ];

  final List<String> _tabNames = [
    "Инфо",
    "Полетный контроллер FC",
    "Пульт RC",
    "Радиомодуль RTX",
    "Профили и калькулятор",
    "Терминал CLI",
  ];

  @override
  void initState() {
    super.initState();
    _logSub = SerialService.logController.stream.listen((_) {
      if (mounted) setState(() {});
    });

    _usbEventSub = UsbSerial.usbEventStream?.listen((UsbEvent event) async {
      if (event.event == UsbEvent.ACTION_USB_DETACHED &&
          SerialService.isConnected) {
        final detachedId = event.device?.deviceId;
        final activeId = SerialService.activeDevice?.deviceId;
        if (detachedId == null || activeId == null || detachedId == activeId) {
          await SerialService.disconnect();
          if (mounted) setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _logSub.cancel();
    _usbEventSub?.cancel();
    super.dispose();
  }

  Future<UsbDevice?> _pickUsbDevice(List<UsbDevice> devices) async {
    if (devices.length == 1) return devices.first;
    return showDialog<UsbDevice>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Выберите USB устройство",
          style: TextStyle(
            color: Colors.amberAccent,
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: devices.length,
            separatorBuilder: (_, __) => const Divider(color: Colors.white12),
            itemBuilder: (_, index) {
              final d = devices[index];
              final label =
                  (d.productName != null && d.productName!.trim().isNotEmpty)
                      ? "${d.productName} (${d.deviceName})"
                      : d.deviceName;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.usb, color: Colors.blueAccent),
                title: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                subtitle: Text(
                  "VID: ${d.vid ?? '-'}  PID: ${d.pid ?? '-'}",
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                ),
                onTap: () => Navigator.pop(ctx, d),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Отмена", style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleUsbConnectionFromDropdown() async {
    if (SerialService.isBusy) return;

    if (SerialService.isConnected) {
      await SerialService.disconnect();
      if (mounted) setState(() {});
      return;
    }

    try {
      final List<UsbDevice> devices = await UsbSerial.listDevices();
      if (devices.isEmpty) {
        SerialService.appendLog(">> ERROR: No USB devices found\n");
        if (mounted) {
          showAppDialog(
            context,
            "Ошибка соединения",
            "USB устройства не найдены!\nПодключите плату по USB OTG.",
            isError: true,
          );
        }
        return;
      }

      if (!mounted) return;
      final UsbDevice? chosen = await _pickUsbDevice(devices);
      if (chosen == null) return;

      final bool connected = await SerialService.connectDevice(
        chosen,
        baudRate: 115200,
        autoDisconnectIfSame: false,
      );

      if (!connected && mounted) {
        showAppDialog(
          context,
          "Ошибка соединения",
          "Сбой подключения к serial device:\n${SerialService.lastResponse}",
          isError: true,
        );
      }
    } catch (e) {
      SerialService.appendLog(">> ERROR: USB Exception: $e\n");
      if (mounted) {
        showAppDialog(
          context,
          "Ошибка соединения",
          "Сбой подключения USB Serial:\n$e",
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() {});
    }
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
            width: 315,
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
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                        softWrap: true,
                        maxLines: 2,
                      ),
                    );
                  }),
                  DropdownMenuItem<int>(
                    value: _tabs.length,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            SerialService.isBusy
                                ? "Подключение\nUSB Serial..."
                                : "Соединение\nUSB Serial",
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                            softWrap: true,
                            maxLines: 2,
                          ),
                        ),
                        IgnorePointer(
                          child: Switch(
                            value: SerialService.isConnected,
                            onChanged: (_) {},
                            activeTrackColor: Colors.blueAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                onChanged: (val) {
                  if (val == null) return;
                  if (val < _tabs.length) {
                    setState(() => _currentIndex = val);
                  } else {
                    unawaited(_toggleUsbConnectionFromDropdown());
                  }
                },
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: _tabs[_currentIndex],
        ),
      ),
    );
  }
}

// ==========================================
// ВКЛАДКА 0: ИНФО
// ==========================================
class InfoConnectionTab extends StatefulWidget {
  const InfoConnectionTab({super.key});

  @override
  State<InfoConnectionTab> createState() => _InfoConnectionTabState();
}

class _InfoConnectionTabState extends State<InfoConnectionTab> {
  List<DocSection> _sections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocumentation();
  }

  Future<void> _loadDocumentation() async {
    try {
      final String fileContent = await rootBundle.loadString('assets/doc.txt');
      final List<DocSection> parsedSections = [];
      final RegExp regExp =
          RegExp(r'/([^/]+)/\s*\[([^\]]*)\]', multiLine: true, dotAll: true);
      for (final match in regExp.allMatches(fileContent)) {
        final String title = match.group(1)?.trim() ?? '';
        final String content = match.group(2)?.trim() ?? '';
        if (title.isNotEmpty) {
          parsedSections.add(DocSection(title: title, content: content));
        }
      }
      if (parsedSections.isEmpty) {
        parsedSections.add(
          DocSection(title: 'Справочник CLI команд', content: fileContent),
        );
      }
      if (!mounted) return;
      setState(() {
        _sections = parsedSections;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sections = [
          DocSection(title: 'Ошибка загрузки doc.txt', content: 'Ошибка:\n$e')
        ];
        _isLoading = false;
      });
    }
  }

  List<Widget> _buildContentWidgets(String rawContent) {
    final List<Widget> widgets = [];
    final RegExp imgRegex = RegExp(r'\b(img\d+)\b', caseSensitive: false);
    int lastMatchEnd = 0;
    for (final Match match in imgRegex.allMatches(rawContent)) {
      if (match.start > lastMatchEnd) {
        widgets.add(
          Text(
            rawContent.substring(lastMatchEnd, match.start).trim(),
            style: const TextStyle(
              fontSize: 17,
              color: Colors.white70,
              height: 1.45,
              fontFamily: 'monospace',
            ),
            softWrap: true,
          ),
        );
        widgets.add(const SizedBox(height: 10));
      }
      final String imgTag = match.group(1)!.toLowerCase();
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/$imgTag.jpg',
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 100,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  "Изображение не найдено\n($imgTag.jpg)",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: Colors.amberAccent),
                ),
              ),
            ),
          ),
        ),
      );
      widgets.add(const SizedBox(height: 10));
      lastMatchEnd = match.end;
    }
    if (lastMatchEnd < rawContent.length) {
      widgets.add(
        Text(
          rawContent.substring(lastMatchEnd).trim(),
          style: const TextStyle(
            fontSize: 17,
            color: Colors.white70,
            height: 1.45,
            fontFamily: 'monospace',
          ),
          softWrap: true,
        ),
      );
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'XFire Ecosystem',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: Colors.amberAccent,
                        ),
                        softWrap: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'v.3.27 (CLI)',
                        style: TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Аппаратно-программная экосистема\nдля управления дронами.\nМоторы: 2312, Пропы: 9450, 4S, LoRa RTX.',
                  style: TextStyle(fontSize: 17, color: Colors.white70, height: 1.45),
                  softWrap: true,
                ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          child: Text(
            'СПРАВОЧНИК CLI КОМАНД\n(doc.txt)',
            style: TextStyle(
              color: Colors.amberAccent,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              height: 1.3,
            ),
            softWrap: true,
          ),
        ),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(color: Colors.blueAccent),
            ),
          )
        else
          ..._sections.map(
            (sec) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11.0, vertical: 4.0),
              child: Card(
                margin: EdgeInsets.zero,
                child: ExpansionTile(
                  title: Text(
                    sec.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Colors.white,
                    ),
                    softWrap: true,
                  ),
                  iconColor: Colors.amberAccent,
                  collapsedIconColor: Colors.white54,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _buildContentWidgets(sec.content),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ==========================================
// ВКЛАДКА: ПРОФИЛИ (КАЛЬКУЛЯТОР СЕТАПА И ПОЛЕТА)
// ==========================================
class ProfilesTab extends StatefulWidget {
  const ProfilesTab({super.key});

  @override
  State<ProfilesTab> createState() => _ProfilesTabState();
}

class _ProfilesTabState extends State<ProfilesTab> {
  double _propSize = 9.0;
  double _propPitch = 4.5;
  double _bladesCount = 2.0;
  double _motorKv = 920.0;
  double _batteryCells = 4.0;
  int _behaviorIndex = 1;

  double _auwGrams = 1200.0;
  double _batteryMah = 4000.0;
  double _frameSizeMm = 450.0;

  double _totalRintMohm = 48.0;
  double _calcMaxTilt = 25.0;
  double _calcMaxVz = 1.2;

  double get _minPitch => 3.0;
  double get _maxPitch => _propSize <= 6.0 ? 6.0 : 5.5;

  double get _minKv =>
      _propSize <= 6.0 ? 1500.0 : (_propSize <= 8.0 ? 1000.0 : 350.0);
  double get _maxKv =>
      _propSize <= 6.0 ? 2800.0 : (_propSize <= 8.0 ? 1800.0 : 950.0);

  Color _getCurrentColor(double ampPerMotor) {
    if (ampPerMotor <= 2.0) return Colors.greenAccent;
    if (ampPerMotor <= 2.75) return Colors.lightGreenAccent;
    if (ampPerMotor <= 3.5) return Colors.yellowAccent;
    if (ampPerMotor <= 5.0) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  Color _getVoltageColor(double vPerCell) {
    if (vPerCell >= 3.8) return Colors.greenAccent;
    if (vPerCell >= 3.6) return Colors.lightGreenAccent;
    if (vPerCell >= 3.4) return Colors.yellowAccent;
    if (vPerCell >= 3.3) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  Color _getTimeColor(double minutes) {
    if (minutes >= 30.0) return Colors.greenAccent;
    if (minutes >= 20.0) return Colors.lightGreenAccent;
    if (minutes >= 15.0) return Colors.yellowAccent;
    if (minutes >= 10.0) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  Color _getHoverThrottleColor(double throttle) {
    if (throttle < 20.0) return Colors.greenAccent;
    if (throttle <= 30.0) return Colors.lightGreenAccent;
    if (throttle <= 40.0) return Colors.yellowAccent;
    if (throttle <= 50.0) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  Map<String, dynamic> calculateOptimalSettings() {
    final double ocVoltageFresh = _batteryCells * 4.2;
    final double ocVoltageNominal = _batteryCells * 3.7;
    const double cutoffLoadVoltagePerCell = 3.3;

    final double totalWeightKg = _auwGrams / 1000.0;
    final double rInt = (_totalRintMohm / 1000.0)
        .clamp((_batteryCells * 3.0) / 1000.0, (_batteryCells * 30.0) / 1000.0);
    const double etaEsc = 0.96;
    const double etaMotor = 0.80;

    final double pitchFactor = _propPitch / 4.5;
    final double bladeFactor = _bladesCount == 2 ? 1.0 : 1.15;

    final double rpmLoad = _motorKv * ocVoltageNominal * 0.80;
    final double thrustPerMotorGrams = math.pow(_propSize, 3.2).toDouble() *
        _propPitch *
        math.pow(rpmLoad / 1000.0, 2.0).toDouble() *
        (_bladesCount == 2 ? 1.0 : 0.88) *
        0.045;
    final double totalThrustGrams = thrustPerMotorGrams * 4.0;
    final double twr = totalThrustGrams / _auwGrams;

    final double hoverThrustRatio = (_auwGrams / totalThrustGrams).clamp(0.12, 0.90);
    final double hoverThrottle = (hoverThrustRatio * 100.0 * 1.18).clamp(15.0, 90.0);

    final double frameRadiusM = _frameSizeMm / 2000.0;
    final double momentOfInertia = totalWeightKg * math.pow(frameRadiusM, 2).toDouble();
    final double behaviorMultiplier =
        _behaviorIndex == 0 ? 0.8 : (_behaviorIndex == 1 ? 1.0 : 1.35);

    final double specificPowerWPerKg = 130.0 *
        (math.pow(9.0 / _propSize, 0.85).toDouble()) *
        (math.pow(_motorKv / 900.0, 0.1).toDouble());
    final double hoverPowerMech = totalWeightKg *
        specificPowerWPerKg *
        math.sqrt(hoverThrustRatio) *
        pitchFactor *
        bladeFactor;
    final double pEscIn = hoverPowerMech / (etaMotor * etaEsc);

    final double a = rInt;
    final double b = -ocVoltageNominal;
    final double c = pEscIn;
    final double discriminant = (b * b) - (4 * a * c);

    double hoverAmps = 10.0;
    if (discriminant >= 0) {
      hoverAmps = (-b - math.sqrt(discriminant)) / (2 * a);
    } else {
      hoverAmps = ocVoltageNominal / (2 * a);
    }

    final double freshLoadVoltage = ocVoltageFresh - (hoverAmps * rInt);
    final double freshLoadVPerCell = freshLoadVoltage / _batteryCells;

    final double loadVoltage = ocVoltageNominal - (hoverAmps * rInt);
    final double loadVPerCell = loadVoltage / _batteryCells;
    final double batteryThermalLossWatts = math.pow(hoverAmps, 2).toDouble() * rInt;

    final double cutoffOcvPerCell =
        cutoffLoadVoltagePerCell + (hoverAmps * rInt / _batteryCells);
    final double usableOcvSpan = (4.2 - cutoffOcvPerCell.clamp(3.5, 4.1)).clamp(0.0, 0.7);
    final double usableFraction = (usableOcvSpan / 0.7).clamp(0.05, 0.88);
    final double usableBatteryAh = (_batteryMah / 1000.0) * usableFraction;

    final double hoverTimeMinutes = (usableBatteryAh / hoverAmps) * 60.0;

    const double tiltAngleRad30 = 30.0 * math.pi / 180.0;
    final double thrustMultiplier30 = 1.0 / math.cos(tiltAngleRad30);
    final double powerMultiplier30 = math.pow(thrustMultiplier30, 1.5).toDouble();
    final double flightAmps30 = hoverAmps * powerMultiplier30;
    final double dynamicFlightMinutes = (usableBatteryAh / flightAmps30) * 60.0 * 0.90;

    final double tiltRad = _calcMaxTilt * math.pi / 180.0;
    final double maxTiltAmps =
        hoverAmps * math.pow(1.0 / math.cos(tiltRad), 1.5).toDouble();
    final double maxTiltVoltage = ocVoltageNominal - (maxTiltAmps * rInt);

    final double climbPowerMech = totalWeightKg * 9.81 * _calcMaxVz;
    final double totalClimbEscPower = pEscIn + (climbPowerMech / (etaMotor * etaEsc));
    final double aClimb = rInt, bClimb = -ocVoltageNominal, cClimb = totalClimbEscPower;
    final double discClimb = (bClimb * bClimb) - (4 * aClimb * cClimb);
    double maxVzAmps = hoverAmps * 1.6;
    if (discClimb >= 0) maxVzAmps = (-bClimb - math.sqrt(discClimb)) / (2 * aClimb);
    final double maxVzVoltage = ocVoltageNominal - (maxVzAmps * rInt);

    final double baseKp =
        (0.25 * (momentOfInertia / 0.02) * (4.0 / twr)).clamp(0.20, 1.20);
    const double baseKi = 0.010;
    final double baseKd = (baseKp * 0.035).clamp(0.005, 0.050);

    final double rollPitchKp = double.parse((baseKp * behaviorMultiplier).toStringAsFixed(3));
    final double rollPitchKd = double.parse((baseKd * behaviorMultiplier).toStringAsFixed(3));
    final double yawKp = (rollPitchKp * 1.2).clamp(0.3, 1.5);
    final double yawKd = (rollPitchKd * 0.4).clamp(0.0, 0.025);

    final double rcRate =
        _behaviorIndex == 0 ? 0.25 : (_behaviorIndex == 1 ? 0.38 : 0.55);
    final double superExpo =
        _behaviorIndex == 0 ? 0.02 : (_behaviorIndex == 1 ? 0.04 : 0.08);

    final double maxRps = (_motorKv * loadVoltage) / 60.0;
    final double bladePassFreq = maxRps * _bladesCount;
    final double notchFreq = (bladePassFreq * 0.75).clamp(20.0, 120.0);

    return {
      'roll_kp': rollPitchKp,
      'roll_ki': baseKi,
      'roll_kd': rollPitchKd,
      'pitch_kp': rollPitchKp,
      'pitch_ki': baseKi,
      'pitch_kd': rollPitchKd,
      'yaw_kp': double.parse(yawKp.toStringAsFixed(3)),
      'yaw_ki': 0.010,
      'yaw_kd': double.parse(yawKd.toStringAsFixed(3)),
      'rc_rate': rcRate,
      'rc_super_expo': superExpo,
      'filter_notch_freq': double.parse(notchFreq.toStringAsFixed(1)),
      'twr': twr.toStringAsFixed(1),
      'hover_throttle': hoverThrottle.toStringAsFixed(0),
      'hover_amps': hoverAmps.toStringAsFixed(1),
      'fresh_load_voltage': freshLoadVoltage.toStringAsFixed(2),
      'fresh_load_v_cell': freshLoadVPerCell.toStringAsFixed(2),
      'load_voltage': loadVoltage.toStringAsFixed(2),
      'bat_thermal_loss': batteryThermalLossWatts.toStringAsFixed(1),
      'flight_time': hoverTimeMinutes.toStringAsFixed(1),
      'flight_time_30deg': dynamicFlightMinutes.toStringAsFixed(1),
      'total_rint_mohm': _totalRintMohm.toStringAsFixed(1),
      'max_tilt_amps': maxTiltAmps.toStringAsFixed(1),
      'max_tilt_voltage': maxTiltVoltage.toStringAsFixed(2),
      'max_vz_amps': maxVzAmps.toStringAsFixed(1),
      'max_vz_voltage': maxVzVoltage.toStringAsFixed(2),
      'color_hover_amps': _getCurrentColor(hoverAmps / 4.0),
      'color_fresh_voltage': _getVoltageColor(freshLoadVPerCell),
      'color_load_voltage': _getVoltageColor(loadVPerCell),
      'color_flight_time': _getTimeColor(hoverTimeMinutes),
      'color_flight_time_30': _getTimeColor(dynamicFlightMinutes),
      'color_hover_throttle': _getHoverThrottleColor(hoverThrottle),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_propPitch < _minPitch) _propPitch = _minPitch;
    if (_propPitch > _maxPitch) _propPitch = _maxPitch;
    if (_motorKv < _minKv) _motorKv = _minKv;
    if (_motorKv > _maxKv) _motorKv = _maxKv;

    final double minRint = _batteryCells * 3.0;
    final double maxRint = _batteryCells * 30.0;
    if (_totalRintMohm < minRint) _totalRintMohm = minRint;
    if (_totalRintMohm > maxRint) _totalRintMohm = maxRint;

    final optimal = calculateOptimalSettings();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      children: [
        XFireExpansionCard(
          title: "Калькулятор сетапа и полета",
          subtitle: "Расчет PID, просадки с 4.2В до 3.3В\nи времени полета",
          icon: Icons.tune_rounded,
          children: [
            XFireSliderCard(
              title: "Размер пропеллера",
              commandName: "prop_size_inch",
              value: _propSize,
              min: 5.0,
              max: 13.0,
              divisions: 8,
              unit: "\"",
              onChanged: (v) => setState(() => _propSize = v),
              onChangeEnd: (_) {},
            ),
            XFireSliderCard(
              title: "Шаг пропеллера",
              commandName: "prop_pitch_inch",
              value: _propPitch,
              min: _minPitch,
              max: _maxPitch,
              divisions: ((_maxPitch - _minPitch) * 10).round(),
              unit: "\"",
              onChanged: (v) => setState(() => _propPitch = v),
              onChangeEnd: (_) {},
            ),
            XFireSegmentedCard(
              title: "Количество лопастей пропа",
              commandName: "prop_blades",
              options: const ["2 лопасти", "3 лопасти"],
              selectedIndex: _bladesCount == 2 ? 0 : 1,
              onSelected: (val) => setState(() => _bladesCount = val == 0 ? 2.0 : 3.0),
            ),
            XFireSliderCard(
              title: "KV двигателя",
              commandName: "motor_kv",
              value: _motorKv,
              min: _minKv,
              max: _maxKv,
              divisions: 50,
              unit: "KV",
              onChanged: (v) => setState(() => _motorKv = v),
              onChangeEnd: (_) {},
            ),
            XFireSliderCard(
              title: "Количество банок аккумулятора",
              commandName: "battery_cells",
              value: _batteryCells,
              min: 3.0,
              max: 6.0,
              divisions: 3,
              unit: "S",
              onChanged: (v) {
                setState(() {
                  _batteryCells = v;
                  final double newMin = _batteryCells * 3.0;
                  final double newMax = _batteryCells * 30.0;
                  _totalRintMohm = _totalRintMohm.clamp(newMin, newMax);
                });
              },
              onChangeEnd: (_) {},
            ),
            XFireSliderCard(
              title: "Внутреннее сопротивление батареи\n(3-30 мОм/банку)",
              commandName: "bat_rint_mohm",
              value: _totalRintMohm,
              min: minRint,
              max: maxRint,
              divisions: (maxRint - minRint).round().clamp(1, 200),
              unit: "мОм",
              onChanged: (v) => setState(() => _totalRintMohm = v),
              onChangeEnd: (_) {},
            ),
            XFireSliderCard(
              title: "Максимальный угол наклона\n(fm_roll_max)",
              commandName: "fm_roll_max",
              value: _calcMaxTilt,
              min: 1.0,
              max: 85.0,
              divisions: 84,
              unit: "°",
              onChanged: (v) => setState(() => _calcMaxTilt = v),
              onChangeEnd: (_) {},
            ),
            XFireSliderCard(
              title: "Максимальная вертикальная скорость\n(fm_vz_speed_max)",
              commandName: "fm_vz_speed_max",
              value: _calcMaxVz,
              min: 0.1,
              max: 10.0,
              divisions: 99,
              unit: "м/с",
              onChanged: (v) => setState(() => _calcMaxVz = v),
              onChangeEnd: (_) {},
            ),
            XFireSliderCard(
              title: "Взлетный вес дрона\n(AUW)",
              commandName: "auw_grams",
              value: _auwGrams,
              min: 400.0,
              max: 3500.0,
              divisions: 62,
              unit: "г",
              onChanged: (v) => setState(() => _auwGrams = v),
              onChangeEnd: (_) {},
            ),
            XFireSliderCard(
              title: "Емкость аккумулятора",
              commandName: "battery_mah",
              value: _batteryMah,
              min: 1300.0,
              max: 16000.0,
              divisions: 58,
              unit: "mAh",
              onChanged: (v) => setState(() => _batteryMah = v),
              onChangeEnd: (_) {},
            ),
            XFireSliderCard(
              title: "Диагональ рамы\n(от мотора до мотора)",
              commandName: "frame_size_mm",
              value: _frameSizeMm,
              min: 220.0,
              max: 650.0,
              divisions: 43,
              unit: "мм",
              onChanged: (v) => setState(() => _frameSizeMm = v),
              onChangeEnd: (_) {},
            ),
            XFireSegmentedCard(
              title: "Характер поведения дрона",
              commandName: "drone_behavior",
              options: const ["Плавное", "Уверенное", "Резвое"],
              selectedIndex: _behaviorIndex,
              onSelected: (val) => setState(() => _behaviorIndex = val),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13.0, vertical: 6.0),
          child: Container(
            padding: const EdgeInsets.all(15.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "ФИЗИЧЕСКИЙ РАСЧЕТ\nИ НАГРУЗКИ (v.3.27)",
                        style: TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          height: 1.3,
                        ),
                        softWrap: true,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.insights, color: Colors.amberAccent, size: 22),
                  ],
                ),
                const SizedBox(height: 12),
                _calcResultRow("Тяговооруженность (TWR):", "${optimal['twr']} : 1", Colors.white),
                _calcResultRow(
                  "Газ висения\n(Hover Throttle):",
                  "${optimal['hover_throttle']} %",
                  optimal['color_hover_throttle'],
                ),
                _calcResultRow(
                  "Сопротивление батареи\n(суммарное):",
                  "${optimal['total_rint_mohm']} мОм\n(${(_totalRintMohm / _batteryCells).toStringAsFixed(1)} мОм/банку)",
                  Colors.white,
                ),
                const Divider(color: Colors.white12, height: 16),
                _calcResultRow(
                  "Ток висения\n(суммарный):",
                  "${optimal['hover_amps']} А",
                  optimal['color_hover_amps'],
                ),
                _calcResultRow(
                  "Напряжение свежего аккума\n(4.2В) под нагрузкой:",
                  "${optimal['fresh_load_voltage']} В\n(${optimal['fresh_load_v_cell']} В/б)",
                  optimal['color_fresh_voltage'],
                ),
                _calcResultRow(
                  "Напряжение под нагрузкой\n(на плато 3.7В):",
                  "${optimal['load_voltage']} В",
                  optimal['color_load_voltage'],
                ),
                _calcResultRow(
                  "Тепловые потери батареи\n(висение):",
                  "${optimal['bat_thermal_loss']} Вт",
                  Colors.white,
                ),
                const Divider(color: Colors.white12, height: 16),
                _calcResultRow(
                  "Ток при макс. наклоне\n(${_calcMaxTilt.toStringAsFixed(0)}°):",
                  "${optimal['max_tilt_amps']} А",
                  Colors.white,
                ),
                _calcResultRow(
                  "Напряжение при макс.\nнаклоне:",
                  "${optimal['max_tilt_voltage']} В",
                  Colors.white,
                ),
                _calcResultRow(
                  "Ток при макс. взлете\n(${_calcMaxVz.toStringAsFixed(1)} м/с):",
                  "${optimal['max_vz_amps']} А",
                  Colors.white,
                ),
                _calcResultRow(
                  "Напряжение при макс.\nвзлете:",
                  "${optimal['max_vz_voltage']} В",
                  Colors.white,
                ),
                const Divider(color: Colors.white12, height: 16),
                _calcResultRow(
                  "Время висения\n(до отсечки 3.3В):",
                  "${optimal['flight_time']} мин",
                  optimal['color_flight_time'],
                ),
                _calcResultRow(
                  "Время в полете\n(наклон 30° + взлеты):",
                  "${optimal['flight_time_30deg']} мин",
                  optimal['color_flight_time_30'],
                ),
                const Divider(color: Colors.white12, height: 16),
                _calcResultRow(
                  "Roll/Pitch Kp / Ki / Kd:",
                  "${optimal['roll_kp']} / ${optimal['roll_ki']} / ${optimal['roll_kd']}",
                  Colors.white,
                ),
                _calcResultRow(
                  "Yaw Kp / Ki / Kd:",
                  "${optimal['yaw_kp']} / ${optimal['yaw_ki']} / ${optimal['yaw_kd']}",
                  Colors.white,
                ),
                _calcResultRow(
                  "RC Rate / Super Expo:",
                  "${optimal['rc_rate']} / ${optimal['rc_super_expo']}",
                  Colors.white,
                ),
                _calcResultRow(
                  "Notch (от BPF винта):",
                  "${optimal['filter_notch_freq']} Гц",
                  Colors.white,
                ),
              ],
            ),
          ),
        ),
        XFireResetCard(
          hint: "Сброс калькулятора сетапа\nи полета",
          onReset: () => setState(() {
            _propSize = 9.0;
            _propPitch = 4.5;
            _bladesCount = 2.0;
            _motorKv = 920.0;
            _batteryCells = 4.0;
            _totalRintMohm = 48.0;
            _calcMaxTilt = 25.0;
            _calcMaxVz = 1.2;
            _behaviorIndex = 1;
            _auwGrams = 1200.0;
            _batteryMah = 4000.0;
            _frameSizeMm = 450.0;
          }),
        ),
        XFireBatchApplyCard(
          hint: "Применение рассчитанных PID\nи лимитов к контроллеру",
          parameters: [
            "fm_roll_max $_calcMaxTilt",
            "fm_pitch_max $_calcMaxTilt",
            "fm_vz_speed_max $_calcMaxVz",
            "roll_kp ${optimal['roll_kp']}",
            "roll_ki ${optimal['roll_ki']}",
            "roll_kd ${optimal['roll_kd']}",
            "pitch_kp ${optimal['pitch_kp']}",
            "pitch_ki ${optimal['pitch_ki']}",
            "pitch_kd ${optimal['pitch_kd']}",
            "yaw_kp ${optimal['yaw_kp']}",
            "yaw_ki ${optimal['yaw_ki']}",
            "yaw_kd ${optimal['yaw_kd']}",
            "rc_rate ${optimal['rc_rate']}",
            "rc_super_expo ${optimal['rc_super_expo']}",
            "filter_notch_freq ${optimal['filter_notch_freq']}",
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _calcResultRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, color: Colors.white70, height: 1.3),
              softWrap: true,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: 'monospace',
              height: 1.3,
            ),
            softWrap: true,
          ),
        ],
      ),
    );
  }
}

// ==========================================
// МОДЕЛЬ И ПАНЕЛЬ ПОЛНОЙ ДИАГНОСТИКИ DFU
// ==========================================
enum DfuDiagStatus { idle, running, success, error }

class DfuDiagEntry {
  final DateTime timestamp;
  final String stage;
  final String message;
  final double progress;
  final bool isError;

  DfuDiagEntry({
    required this.timestamp,
    required this.stage,
    required this.message,
    required this.progress,
    this.isError = false,
  });

  String formatLine() {
    final hh = timestamp.hour.toString().padLeft(2, '0');
    final mm = timestamp.minute.toString().padLeft(2, '0');
    final ss = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    final pct = (progress * 100).clamp(0, 100).toStringAsFixed(0);
    return "[$hh:$mm:$ss.$ms] ($pct%) [$stage] $message";
  }
}

class DfuDiagnosticsPanel extends StatelessWidget {
  final DfuDiagStatus status;
  final String currentStage;
  final String? failureStage;
  final String? failureDetails;
  final double progress;
  final List<DfuDiagEntry> entries;
  final List<String> usbDeviceSummary;
  final bool isScanningUsb;
  final VoidCallback onScanUsb;
  final VoidCallback onClearLog;

  const DfuDiagnosticsPanel({
    super.key,
    required this.status,
    required this.currentStage,
    required this.failureStage,
    required this.failureDetails,
    required this.progress,
    required this.entries,
    required this.usbDeviceSummary,
    required this.isScanningUsb,
    required this.onScanUsb,
    required this.onClearLog,
  });

  Color get _accentColor {
    switch (status) {
      case DfuDiagStatus.running:
        return Colors.blueAccent;
      case DfuDiagStatus.success:
        return Colors.greenAccent;
      case DfuDiagStatus.error:
        return Colors.redAccent;
      case DfuDiagStatus.idle:
        return Colors.amberAccent;
    }
  }

  String get _statusBadgeText {
    switch (status) {
      case DfuDiagStatus.running:
        return "В ПРОЦЕССЕ";
      case DfuDiagStatus.success:
        return "УСПЕШНО";
      case DfuDiagStatus.error:
        return "СБОЙ DFU";
      case DfuDiagStatus.idle:
        return "ОЖИДАНИЕ";
    }
  }

  String _explainFailure(String? err) {
    if (err == null || err.isEmpty) return "";
    final lower = err.toLowerCase();
    if (lower.contains("getstatus")) {
      return "Причина: хост отправил DFU_GETSTATUS, но контроллер не ответил, вернул некорректный пакет или ушёл в dfuERROR.\n"
          "Проверьте:\n"
          "1) Плата переведена в аппаратный ROM DFU через BOOT0=1 перед подачей USB.\n"
          "2) USB Serial полностью отключён и не держит интерфейс.\n"
          "3) Кабель/OTG-переходник имеет линии D+/D- без просадки 5V.\n"
          "4) На плате запаян кварц 8 или 25 МГц и снят RDP.";
    }
    if (lower.contains("dnload")) {
      return "Причина: ошибка передачи блока прошивки (DFU_DNLOAD) или записи страницы Flash.";
    }
    if (lower.contains("detach") || lower.contains("claim") || lower.contains("interface")) {
      return "Причина: не удалось захватить USB DFU интерфейс Android (проверьте разрешение USB Host).";
    }
    if (lower.contains("not found") || lower.contains("не найден")) {
      return "Причина: STM32 в режиме DFU (VID 0x0483, PID 0xDF11) не обнаружен на шине USB.";
    }
    return "Проверьте подключение OTG, режим BOOT0 и полный лог ниже.";
  }

  @override
  Widget build(BuildContext context) {
    final fullLogText = entries.map((e) => e.formatLine()).join('\n');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 11.0, vertical: 6.0),
      color: const Color(0xFF14141
