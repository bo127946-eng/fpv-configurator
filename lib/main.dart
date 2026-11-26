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
        cardTheme: CardThemeData(
          color: const Color(0xFF1C1C1E),
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 13.0, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
// ВКЛАДКА 1: ПОЛЕТНЫЙ КОНТРОЛЛЕР FC
// ==========================================
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  double _rtxEn = 1;
  double _rtxProtId = 0;
  double _rtxId = 1;
  double _rtxBand = 2;

  double _escProt = 0;
  double _fltEscLimit = 45.0;
  double _imuId = 0;
  double _imuAlign = 0;

  double _comEn = 0;
  double _comId = 0;
  double _comAlign = 0;
  double _magBiasX = 0.0;
  double _magBiasY = 0.0;
  double _magBiasZ = 0.0;

  double _baroEn = 1;
  double _barId = 0;

  double _lidarEn = 1;
  double _lidId = 0;
  double _lidarFilterAlpha = 0.15;
  double _lidarOffsetM = 0.0;

  double _vtxEn = 1;
  double _vtxProt = 0;
  double _vtxMhz = 5658;
  double _vtxMw = 25;

  double _batScaleV = 4.85;
  double _batVMax = 16.8;
  bool _batCompEn = true;
  double _batFilterAlpha = 0.05;
  double _batOffsetA = 0.0;
  double _batScaleA = 1.0;

  double _fmMode = 1;
  double _fmRollMax = 25.0;
  double _fmPitchMax = 25.0;
  double _fmVzSpeedMax = 1.2;
  double _rcRate = 0.35;
  double _rcSuperExpo = 0.03;
  double _rcStickExpo = 0.45;
  double _rcYawRate = 0.30;
  double _rcYawSuperExpo = 0.03;
  double _rcYawExpo = 0.35;
  double _rcDeadband = 15.0;
  double _rcHorizonTransition = 0.75;
  double _rcFilterSmoothing = 0.35;

  double _fsBatEn = 1;
  double _fsRtxEn = 1;
  double _fsVzSpeed = 0.5;
  double _batFsV = 13.8;

  double _fltAmbEn = 1;
  double _fltLpfEn = 1;
  double _fltNotEn = 1;
  double _gyroFilterAlpha = 0.10;
  double _accFilterAlpha = 0.10;
  double _filterNotchFreq = 120.0;
  double _filterNotchBw = 20.0;
  double _fltAmb = 0.05;
  double _fltAmbMin = 0.003;

  double _rollKp = 0.45, _rollKi = 0.010, _rollKd = 0.018;
  double _pitchKp = 0.45, _pitchKi = 0.010, _pitchKd = 0.018;
  double _yawKp = 0.60, _yawKi = 0.010, _yawKd = 0.0;
  double _vzKp = 7.0, _vzKi = 1.2, _vzKd = 0.30;

  double _calBatVoltageArg = 14.8;
  double _calCurrAmpsArg = 0.0;

  @override
  void initState() {
    super.initState();
    if (SerialService.isConnected && SerialService.usbPort != null) {
      unawaited(SerialService.sendCommand("mon"));
    }
  }

  @override
  void dispose() {
    if (SerialService.isConnected && SerialService.usbPort != null) {
      unawaited(SerialService.sendCommand("stop"));
    }
    super.dispose();
  }

  void _sendIfConnected(String cmd) {
    if (SerialService.isConnected && SerialService.usbPort != null) {
      unawaited(SerialService.sendCommand(cmd));
    }
  }

  void _resetRadioGroup() {
    setState(() {
      _rtxEn = 1;
      _rtxProtId = 0;
      _rtxId = 1;
      _rtxBand = 2;
    });
    _sendIfConnected("test_rtx");
  }

  void _resetImuGroup() {
    setState(() {
      _escProt = 0;
      _fltEscLimit = 45.0;
      _imuId = 0;
      _imuAlign = 0;
    });
  }

  void _resetCompassGroup() {
    setState(() {
      _comEn = 0;
      _comId = 0;
      _comAlign = 0;
      _magBiasX = 0.0;
      _magBiasY = 0.0;
      _magBiasZ = 0.0;
    });
  }

  void _resetBaroGroup() {
    setState(() {
      _baroEn = 1;
      _barId = 0;
    });
  }

  void _resetLidarGroup() {
    setState(() {
      _lidarEn = 1;
      _lidId = 0;
      _lidarFilterAlpha = 0.15;
      _lidarOffsetM = 0.0;
    });
  }

  void _resetVtxGroup() {
    setState(() {
      _vtxEn = 1;
      _vtxProt = 0;
      _vtxMhz = 5658;
      _vtxMw = 25;
    });
  }

  void _resetBatteryGroup() {
    setState(() {
      _batScaleV = 4.85;
      _batVMax = 16.8;
      _batCompEn = true;
      _batFilterAlpha = 0.05;
      _batOffsetA = 0.0;
      _batScaleA = 1.0;
    });
  }

  void _resetFlightRcGroup() {
    setState(() {
      _fmMode = 1;
      _fmRollMax = 25.0;
      _fmPitchMax = 25.0;
      _fmVzSpeedMax = 1.2;
      _rcRate = 0.35;
      _rcSuperExpo = 0.03;
      _rcStickExpo = 0.45;
      _rcYawRate = 0.30;
      _rcYawSuperExpo = 0.03;
      _rcYawExpo = 0.35;
      _rcDeadband = 15.0;
      _rcHorizonTransition = 0.75;
      _rcFilterSmoothing = 0.35;
    });
  }

  void _resetFailsafeGroup() {
    setState(() {
      _fsBatEn = 1;
      _fsRtxEn = 1;
      _fsVzSpeed = 0.5;
      _batFsV = 13.8;
    });
  }

  void _resetFiltersGroup() {
    setState(() {
      _fltAmbEn = 1;
      _fltLpfEn = 1;
      _fltNotEn = 1;
      _gyroFilterAlpha = 0.10;
      _accFilterAlpha = 0.10;
      _filterNotchFreq = 120.0;
      _filterNotchBw = 20.0;
      _fltAmb = 0.05;
      _fltAmbMin = 0.003;
    });
  }

  void _resetPidGroup() {
    setState(() {
      _rollKp = 0.45;
      _rollKi = 0.010;
      _rollKd = 0.018;
      _pitchKp = 0.45;
      _pitchKi = 0.010;
      _pitchKd = 0.018;
      _yawKp = 0.60;
      _yawKi = 0.010;
      _yawKd = 0.0;
      _vzKp = 7.0;
      _vzKi = 1.2;
      _vzKd = 0.30;
    });
  }

  void _resetAllFcSettings() {
    _resetRadioGroup();
    _resetImuGroup();
    _resetCompassGroup();
    _resetBaroGroup();
    _resetLidarGroup();
    _resetVtxGroup();
    _resetBatteryGroup();
    _resetFlightRcGroup();
    _resetFailsafeGroup();
    _resetFiltersGroup();
    _resetPidGroup();
    _sendIfConnected("default");
    showAppDialog(
      context,
      "Общий сброс FC",
      "Все параметры сброшены к заводским\nзначениям и сохранены во Flash.",
    );
  }

  void _runCalOrTest(String cmd, String title, String message, {bool isWarning = false}) {
    if (!SerialService.isConnected || SerialService.usbPort == null) {
      showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true);
    } else {
      unawaited(SerialService.sendCommand(cmd));
      showAppDialog(context, title, message, isError: isWarning);
    }
  }

  Widget _buildSensorBar(
    String label,
    double value,
    double min,
    double max,
    String unit,
    Color color,
  ) {
    final double percent = ((value - min) / (max - min)).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 16, color: Colors.white70)),
              Text(
                "${value.toStringAsFixed(2)} $unit",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percent,
            color: color,
            backgroundColor: Colors.white12,
            minHeight: 7,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeFltAmbMinMax = _fltAmb.clamp(0.001, 1.0);
    final safeFltAmbMinVal = _fltAmbMin.clamp(0.0005, safeFltAmbMinMax);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      children: [
        XFireExpansionCard(
          title: "Радиомодуль",
          subtitle: "Диагностика LoRa RTX (test_rtx)\nи параметры линка",
          icon: Icons.cell_tower_rounded,
          children: [
            XFireSwitchCard(
              title: "Включение радиомодуля",
              commandName: "rtx_en",
              value: _rtxEn == 1,
              onChanged: (v) => setState(() => _rtxEn = v ? 1.0 : 0.0),
            ),
            XFireSliderCard(
              title: "ID протокола радиоканала",
              commandName: "rtx_prot_id",
              value: _rtxProtId,
              min: 0,
              max: 255,
              divisions: 255,
              unit: "",
              onChanged: (v) => setState(() => _rtxProtId = v),
              onChangeEnd: (_) {},
            ),
            XFireSliderCard(
              title: "Уникальный ID пары / сети",
              commandName: "rtx_id",
              value: _rtxId,
              min: 0,
              max: 65535,
              divisions: 255,
              unit: "",
              onChanged: (v) => setState(() => _rtxId = v),
              onChangeEnd: (_) {},
            ),
            XFireSegmentedCard(
              title: "Частотный диапазон",
              commandName: "rtx_band",
              options: const ["0: 433 МГц", "1: 868 МГц", "2: 915 МГц"],
              selectedIndex: _rtxBand.round().clamp(0, 2),
              onSelected: (val) => setState(() => _rtxBand = val.toDouble()),
            ),
            XFireActionCard(
              title: "Статус LoRa RTX (AFC, LQ, IRQ)",
              commandName: "test_rtx",
              onTap: () => _runCalOrTest(
                "test_rtx",
                "Статус LoRa RTX",
                "Запрошен статус LoRa RTX\n(активность, чип, канал, AFC, LQ, IRQ).",
              ),
            ),
            XFireResetCard(
              hint: "Сброс локальных значений\nблока радиомодуля",
              onReset: _resetRadioGroup,
            ),
          ],
        ),
        XFireExpansionCard(
          title: "IMU (гироскоп и акселерометр)",
          subtitle: "Тип IMU, поворот осей, ESC,\nкалибровка и тест (test_imu)",
          icon: Icons.screen_rotation_alt_rounded,
          children: [
            XFireDropdownCard(
              title: "Тип IMU",
              commandName: "imu_id",
              value: _imuId.round(),
              options: const {
                0: "0 — автоопределение",
                1: "1 — датчик 1",
                2: "2 — датчик 2",
                3: "3 — датчик 3",
                4: "4 — датчик 4",
                5: "5 — датчик 5",
                6: "6 — датчик 6",
              },
              onChanged: (val) {
                setState(() => _imuId = val.toDouble());
                _sendIfConnected("imu_id $val");
              },
            ),
            XFireSegmentedCard(
              title: "Поворот XY осей IMU",
              commandName: "imu_align",
              options: const ["0 (0°)", "1 (90°)", "2 (180°)", "3 (270°)"],
              selectedIndex: _imuAlign.round().clamp(0, 3),
              onSelected: (val) {
                setState(() => _imuAlign = val.toDouble());
                _sendIfConnected("imu_align $val");
              },
            ),
            XFireSegmentedCard(
              title: "Протокол ШИМ/ESC",
              commandName: "esc_prot",
              options: const ["0: PWM", "1: Oneshot125"],
              selectedIndex: _escProt.round().clamp(0, 1),
              onSelected: (val) {
                setState(() => _escProt = val.toDouble());
                _sendIfConnected("esc_prot $val");
              },
            ),
            XFireSliderCard(
              title: "Макс. шаг выхода мотора\n(slew rate за цикл)",
              commandName: "flt_esc_limit",
              value: _fltEscLimit,
              min: 1.0,
              max: 250.0,
              divisions: 249,
              unit: "",
              onChanged: (v) => setState(() => _fltEscLimit = v),
              onChangeEnd: (v) => _sendIfConnected("flt_esc_limit ${v.toStringAsFixed(1)}"),
            ),
            XFireActionCard(
              title: "Полная калибровка IMU (гиро + акс)",
              commandName: "cal_imu",
              onTap: () => _runCalOrTest(
                "cal_imu",
                "Калибровка IMU",
                "Аппарат должен лежать неподвижно\nи горизонтально. Запись во Flash.",
              ),
            ),
            XFireActionCard(
              title: "Калибровка гироскопа и темп.",
              commandName: "cal_gyro",
              onTap: () => _runCalOrTest(
                "cal_gyro",
                "Калибровка гироскопа",
                "Калибровка смещения гироскопа\nи базовой температуры с записью во Flash.",
              ),
            ),
            XFireActionCard(
              title: "Калибровка акселерометра",
              commandName: "cal_acc",
              onTap: () => _runCalOrTest(
                "cal_acc",
                "Калибровка акселерометра",
                "Калибровка на горизонтальной\nповерхности с записью во Flash.",
              ),
            ),
            XFireActionCard(
              title: "Разовый тест IMU (acc / gyr)",
              commandName: "test_imu",
              onTap: () => _runCalOrTest(
                "test_imu",
                "Тест IMU",
                "Запрошен вывод состояния IMU\nи текущих значений acc / gyr.",
              ),
            ),
            XFireResetCard(
              hint: "Сброс локальных значений\nблока IMU",
              onReset: _resetImuGroup,
            ),
            XFireBatchApplyCard(
              hint: "Пакетная отправка настроек\nIMU и ESC",
              parameters: [
                "imu_id ${_imuId.round()}",
                "imu_align ${_imuAlign.round()}",
                "esc_prot ${_escProt.round()}",
                "flt_esc_limit ${_fltEscLimit.toStringAsFixed(1)}",
              ],
            ),
          ],
        ),
        XFireExpansionCard(
          title: "Компас",
          subtitle: "Опрос, тип, поворот XY,\nсмещения ±2000 и тест (test_mag)",
          icon: Icons.explore_rounded,
          children: [
            XFireSwitchCard(
              title: "Включение компаса/магнитометра",
              commandName: "com_en",
              value: _comEn == 1,
              onChanged: (v) {
                setState(() => _comEn = v ? 1.0 : 0.0);
                _sendIfConnected("com_en ${_comEn.round()}");
              },
            ),
            XFireDropdownCard(
              title: "Тип магнитометра",
              commandName: "com_id",
              value: _comId.round(),
              options: const {
                0: "0 — автоопределение",
                1: "1 — датчик 1",
                2: "2 — датчик 2",
                3: "3 — датчик 3",
                4: "4 — датчик 4",
                5: "5 — датчик 5",
                6: "6 — датчик 6",
              },
              onChanged: (val) {
                setState(() => _comId = val.toDouble());
                _sendIfConnected("com_id $val");
              },
            ),
            XFireSegmentedCard(
              title: "Поворот XY осей компаса",
              commandName: "com_align",
              options: const ["0 (0°)", "1 (90°)", "2 (180°)", "3 (270°)"],
              selectedIndex: _comAlign.round().clamp(0, 3),
              onSelected: (val) {
                setState(() => _comAlign = val.toDouble());
                _sendIfConnected("com_align $val");
              },
            ),
            XFireSliderCard(
              title: "Смещение магнитометра по X",
              commandName: "mag_bias_x",
              value: _magBiasX,
              min: -2000.0,
              max: 2000.0,
              divisions: 4000,
              unit: "",
              onChanged: (v) => setState(() => _magBiasX = v),
              onChangeEnd: (v) => _sendIfConnected("mag_bias_x ${v.toStringAsFixed(1)}"),
            ),
            XFireSliderCard(
              title: "Смещение магнитометра по Y",
              commandName: "mag_bias_y",
              value: _magBiasY,
              min: -2000.0,
              max: 2000.0,
              divisions: 4000,
              unit: "",
              onChanged: (v) => setState(() => _magBiasY = v),
              onChangeEnd: (v) => _sendIfConnected("mag_bias_y ${v.toStringAsFixed(1)}"),
            ),
            XFireSliderCard(
              title: "Смещение магнитометра по Z",
              commandName: "mag_bias_z",
              value: _magBiasZ,
              min: -2000.0,
              max: 2000.0,
              divisions: 4000,
              unit: "",
              onChanged: (v) => setState(() => _magBiasZ = v),
              onChangeEnd: (v) => _sendIfConnected("mag_bias_z ${v.toStringAsFixed(1)}"),
            ),
            XFireActionCard(
              title: "Калибровка магнитометра (8 сек)",
              commandName: "cal_mag",
              onTap: () => _runCalOrTest(
                "cal_mag",
                "Калибровка компаса (8 сек)",
                "Вращайте аппарат во всех осях\nв течение 8 сек; смещения сохранятся во Flash.",
              ),
            ),
            XFireActionCard(
              title: "Разовый тест компаса (xyz / hdg)",
              commandName: "test_mag",
              onTap: () => _runCalOrTest(
                "test_mag",
                "Тест компаса",
                "Запрошен статус магнитометра,\nоси xyz и курс hdg.",
              ),
            ),
            XFireResetCard(
              hint: "Сброс локальных значений\nблока компаса",
              onReset: _resetCompassGroup,
            ),
            XFireBatchApplyCard(
              hint: "Пакетная отправка настроек\nкомпаса",
              parameters: [
                "com_en ${_comEn.round()}",
                "com_id ${_comId.round()}",
                "com_align ${_comAlign.round()}",
                "mag_bias_x ${_magBiasX.toStringAsFixed(1)}",
                "mag_bias_y ${_magBiasY.toStringAsFixed(1)}",
                "mag_bias_z ${_magBiasZ.toStringAsFixed(1)}",
              ],
            ),
          ],
        ),
        XFireExpansionCard(
          title: "Барометр",
          subtitle: "Опрос, выбор чипа (0..7),\nобнуление (cal_bar) и тест (test_bar)",
          icon: Icons.compress_rounded,
          children: [
            XFireSwitchCard(
              title: "Включение барометра",
              commandName: "baro_en",
              value: _baroEn == 1,
              onChanged: (v) {
                setState(() => _baroEn = v ? 1.0 : 0.0);
                _sendIfConnected("baro_en ${_baroEn.round()}");
              },
            ),
            XFireDropdownCard(
              title: "Тип барометра",
              commandName: "bar_id",
              value: _barId.round(),
              options: const {
                0: "0 — автоопределение",
                1: "1 — датчик 1",
                2: "2 — датчик 2",
                3: "3 — датчик 3",
                4: "4 — датчик 4",
                5: "5 — датчик 5",
                6: "6 — датчик 6",
                7: "7 — датчик 7",
              },
              onChanged: (val) {
                setState(() => _barId = val.toDouble());
                _sendIfConnected("bar_id $val");
              },
            ),
            XFireActionCard(
              title: "Обнуление высоты барометра",
              commandName: "cal_bar",
              onTap: () => _runCalOrTest(
                "cal_bar",
                "Обнуление барометра",
                "Обнулена baro_ground_alt_m\nи сброшены фильтры высоты/Vz.",
              ),
            ),
            XFireActionCard(
              title: "Замер высоты барометра",
              commandName: "test_bar",
              onTap: () => _runCalOrTest(
                "test_bar",
                "Тест барометра",
                "Запрошен замер барометрической\nвысоты (alt) и статуса датчика.",
              ),
            ),
            XFireResetCard(
              hint: "Сброс локальных значений\nблока барометра",
              onReset: _resetBaroGroup,
            ),
            XFireBatchApplyCard(
              hint: "Пакетная отправка настроек\nбарометра",
              parameters: [
                "baro_en ${_baroEn.round()}",
                "bar_id ${_barId.round()}",
              ],
            ),
          ],
        ),
        XFireExpansionCard(
          title: "Лидар",
          subtitle: "Опрос, тип (0..4), фильтр,\nсмещение ±5.0 м, cal_lid и test_lid",
          icon: Icons.radar_rounded,
          children: [
            XFireSwitchCard(
              title: "Включение лидара",
              commandName: "lidar_en",
              value: _lidarEn == 1,
              onChanged: (v) {
                setState(() => _lidarEn = v ? 1.0 : 0.0);
                _sendIfConnected("lidar_en ${_lidarEn.round()}");
              },
            ),
            XFireDropdownCard(
              title: "Тип лидара",
              commandName: "lid_id",
              value: _lidId.round(),
              options: const {
                0: "0 — автоопределение",
                1: "1 — датчик 1",
                2: "2 — датчик 2",
                3: "3 — датчик 3",
                4: "4 — датчик 4",
              },
              onChanged: (val) {
                setState(() => _lidId = val.toDouble());
                _sendIfConnected("lid_id $val");
              },
            ),
            XFireSliderCard(
              title: "Alpha фильтра лидара\n(0.001..1.0)",
              commandName: "lidar_filter_alpha",
              value: _lidarFilterAlpha,
              min: 0.001,
              max: 1.0,
              divisions: 999,
              unit: "",
              onChanged: (v) => setState(() => _lidarFilterAlpha = v),
              onChangeEnd: (v) =>
                  _sendIfConnected("lidar_filter_alpha ${v.toStringAsFixed(3)}"),
            ),
            XFireSliderCard(
              title: "Смещение высоты лидара\n(-5.0..5.0 м)",
              commandName: "lidar_offset_m",
              value: _lidarOffsetM,
              min: -5.0,
              max: 5.0,
              divisions: 1000,
              unit: "м",
              onChanged: (v) => setState(() => _lidarOffsetM = v),
              onChangeEnd: (v) =>
                  _sendIfConnected("lidar_offset_m ${v.toStringAsFixed(3)}"),
            ),
            XFireActionCard(
              title: "Калибровка смещения лидара",
              commandName: "cal_lid",
              onTap: () => _runCalOrTest(
                "cal_lid",
                "Калибровка лидара",
                "Калибровка lidar_offset_m по текущему\nзамеру до земли с записью во Flash.",
              ),
            ),
            XFireActionCard(
              title: "Разовый замер лидара",
              commandName: "test_lid",
              onTap: () => _runCalOrTest(
                "test_lid",
                "Тест лидара",
                "Запрошен замер дистанции лидара (m)\nс учётом наклона и смещения.",
              ),
            ),
            XFireResetCard(
              hint: "Сброс локальных значений\nблока лидара",
              onReset: _resetLidarGroup,
            ),
            XFireBatchApplyCard(
              hint: "Пакетная отправка настроек\nлидара",
              parameters: [
                "lidar_en ${_lidarEn.round()}",
                "lid_id ${_lidId.round()}",
                "lidar_filter_alpha ${_lidarFilterAlpha.toStringAsFixed(3)}",
                "lidar_offset_m ${_lidarOffsetM.toStringAsFixed(3)}",
              ],
            ),
          ],
        ),
        XFireExpansionCard(
          title: "VTX (USART6)",
          subtitle: "Управление передатчиком,\n0 Auto / 1 Tramp / 2 SmartAudio",
          icon: Icons.sensors_rounded,
          children: [
            XFireSwitchCard(
              title: "Включение управления VTX",
              commandName: "vtx_en",
              value: _vtxEn == 1,
              onChanged: (v) {
                setState(() => _vtxEn = v ? 1.0 : 0.0);
                _sendIfConnected("vtx_en ${_vtxEn.round()}");
              },
            ),
            XFireDropdownCard(
              title: "Протокол VTX",
              commandName: "vtx_prot",
              value: _vtxProt.round(),
              options: const {
                0: "0 — Auto",
                1: "1 — Tramp",
                2: "2 — SmartAudio",
              },
              onChanged: (val) {
                setState(() => _vtxProt = val.toDouble());
                _sendIfConnected("vtx_prot $val");
              },
            ),
            XFireSliderCard(
              title: "Частота VTX\n(5000..6000 МГц, по умолч. 5658)",
              commandName: "vtx_mhz",
              value: _vtxMhz,
              min: 5000,
              max: 6000,
              divisions: 1000,
              unit: "МГц",
              onChanged: (v) => setState(() => _vtxMhz = v),
              onChangeEnd: (v) => _sendIfConnected("vtx_mhz ${v.round()}"),
            ),
            XFireSliderCard(
              title: "Мощность VTX\n(1..10000 мВт, по умолч. 25)",
              commandName: "vtx_mw",
              value: _vtxMw,
              min: 1,
              max: 10000,
              divisions: 9999,
              unit: "мВт",
              onChanged: (v) => setState(() => _vtxMw = v),
              onChangeEnd: (v) => _sendIfConnected("vtx_mw ${v.round()}"),
            ),
            XFireActionCard(
              title: "Опрос VTX и вывод статуса",
              commandName: "test_vtx",
              onTap: () => _runCalOrTest(
                "test_vtx",
                "Тест VTX",
                "Запущен опрос VTX: протокол,\nстатус связи (link), mhz и mw.",
              ),
            ),
            XFireResetCard(
              hint: "Сброс локальных значений\nблока VTX",
              onReset: _resetVtxGroup,
            ),
            XFireBatchApplyCard(
              hint: "Пакетная отправка настроек\nVTX",
              parameters: [
                "vtx_en ${_vtxEn.round()}",
                "vtx_prot ${_vtxProt.round()}",
                "vtx_mhz ${_vtxMhz.round()}",
                "vtx_mw ${_vtxMw.round()}",
              ],
            ),
          ],
        ),
        XFireExpansionCard(
          title: "Питание и батарея",
          subtitle: "Напряжение, компенсация просадки,\nток, калибровка и тест (test_bat)",
          icon: Icons.battery_charging_full,
          children: [
            XFireSliderCard(
              title: "Масштаб измерения напряжения\n(0.1..50.0, по умолч. 4.85)",
              commandName: "bat_scale_v",
              value: _batScaleV,
              min: 0.1,
              max: 50.0,
              divisions: 499,
              unit: "",
              onChanged: (v) => setState(() => _batScaleV = v),
              onChangeEnd: (v) =>
                  _sendIfConnected("bat_scale_v ${v.toStringAsFixed(3)}"),
            ),
            XFireSliderCard(
              title: "Макс. напряжение батареи\n(7.0..25.2 В, по умолч. 16.8)",
              commandName: "bat_v_max",
              value: _batVMax,
              min: 7.0,
              max: 25.2,
              divisions: 182,
              unit: "В",
              onChanged: (v) => setState(() => _batVMax = v),
              onChangeEnd: (v) =>
                  _sendIfConnected("bat_v_max ${v.toStringAsFixed(2)}"),
            ),
            XFireSwitchCard(
              title: "Компенсация просадки батареи\nна тяге",
              commandName: "bat_comp_en",
              value: _batCompEn,
              onChanged: (v) {
                setState(() => _batCompEn = v);
                _sendIfConnected("bat_comp_en ${v ? 1 : 0}");
              },
            ),
            XFireSliderCard(
              title: "Alpha ФНЧ напряжения батареи\n(0.001..1.0, по умолч. 0.05)",
              commandName: "bat_filter_alpha",
              value: _batFilterAlpha,
              min: 0.001,
              max: 1.0,
              divisions: 999,
              unit: "",
              onChanged: (v) => setState(() => _batFilterAlpha = v),
              onChangeEnd: (v) =>
                  _sendIfConnected("bat_filter_alpha ${v.toStringAsFixed(3)}"),
            ),
            XFireSliderCard(
              title: "Смещение нуля датчика тока\n(-200.0..200.0 А)",
              commandName: "bat_offset_a",
              value: _batOffsetA,
              min: -200.0,
              max: 200.0,
              divisions: 4000,
              unit: "А",
              onChanged: (v) => setState(() => _batOffsetA = v),
              onChangeEnd: (v) =>
                  _sendIfConnected("bat_offset_a ${v.toStringAsFixed(3)}"),
            ),
            XFireSliderCard(
              title: "Масштабный коэффициент тока\n(0.05..20.0, по умолч. 1.0)",
              commandName: "bat_scale_a",
              value: _batScaleA,
              min: 0.05,
              max: 20.0,
              divisions: 399,
              unit: "",
              onChanged: (v) => setState(() => _batScaleA = v),
              onChangeEnd: (v) =>
                  _sendIfConnected("bat_scale_a ${v.toStringAsFixed(3)}"),
            ),
            XFireSliderCard(
              title: "Эталонное напряжение для\nкалибровки делителя (cal_bat)",
              commandName: "cal_bat <V>",
              value: _calBatVoltageArg,
              min: 5.0,
              max: 25.2,
              divisions: 202,
              unit: "В",
              onChanged: (v) => setState(() => _calBatVoltageArg = v),
              onChangeEnd: (_) {},
            ),
            XFireActionCard(
              title: "Калибровка напряжения батареи",
              commandName: "cal_bat ${_calBatVoltageArg.toStringAsFixed(2)}",
              onTap: () => _runCalOrTest(
                "cal_bat ${_calBatVoltageArg.toStringAsFixed(2)}",
                "Калибровка напряжения",
                "Отправлено: cal_bat ${_calBatVoltageArg.toStringAsFixed(2)}\nс записью во Flash.",
              ),
            ),
            XFireActionCard(
              title: "Калибровка нуля датчика тока",
              commandName: "cal_curr",
              onTap: () => _runCalOrTest(
                "cal_curr",
                "Калибровка нуля тока",
                "Калибровка нуля тока (bat_offset_a)\nс записью во Flash.",
              ),
            ),
            XFireSliderCard(
              title: "Эталонный ток для калибровки\nмасштаба (cal_curr [A])",
              commandName: "cal_curr [A]",
              value: _calCurrAmpsArg,
              min: 0.1,
              max: 150.0,
              divisions: 1499,
              unit: "А",
              onChanged: (v) => setState(() => _calCurrAmpsArg = v),
              onChangeEnd: (_) {},
            ),
            XFireActionCard(
              title: "Калибровка масштаба тока по А",
              commandName: "cal_curr ${_calCurrAmpsArg.toStringAsFixed(2)}",
              onTap: () => _runCalOrTest(
                "cal_curr ${_calCurrAmpsArg.toStringAsFixed(2)}",
                "Калибровка масштаба тока",
                "Отправлено: cal_curr ${_calCurrAmpsArg.toStringAsFixed(2)}\nс записью во Flash.",
              ),
            ),
            XFireActionCard(
              title: "Тест батареи (v, i, w)",
              commandName: "test_bat",
              onTap: () => _runCalOrTest(
                "test_bat",
                "Тест батареи",
                "Запрошен вывод текущих v, i, w\nи состояния датчика батареи.",
              ),
            ),
            XFireResetCard(
              hint: "Сброс локальных значений\nблока питания",
              onReset: _resetBatteryGroup,
            ),
            XFireBatchApplyCard(
              hint: "Пакетная отправка настроек\nпитания и тока",
              parameters: [
                "bat_scale_v ${_batScaleV.toStringAsFixed(3)}",
                "bat_v_max ${_batVMax.toStringAsFixed(2)}",
                "bat_comp_en ${_batCompEn ? 1 : 0}",
                "bat_filter_alpha ${_batFilterAlpha.toStringAsFixed(3)}",
                "bat_offset_a ${_batOffsetA.toStringAsFixed(3)}",
                "bat_scale_a ${_batScaleA.toStringAsFixed(3)}",
              ],
            ),
          ],
        ),
        XFireExpansionCard(
          title: "Режимы полёта и стики\n(RC)",
          subtitle: "Acro/Angle/Horizon/AltHold,\nуглы, Vz и кривые RC",
          icon: Icons.flight,
          children: [
            XFireSegmentedCard(
              title: "Режим полёта\n(0 Acro, 1 Angle, 2 Horizon, 3 Alt/Vz)",
              commandName: "fm_mode",
              options: const ["0: Acro", "1: Angle", "2: Horizon", "3: Alt/Vz"],
              selectedIndex: _fmMode.round().clamp(0, 3),
              onSelected: (val) {
                setState(() => _fmMode = val.toDouble());
                _sendIfConnected("fm_mode $val");
              },
            ),
            XFireSliderCard(
              title: "Макс. угол Roll, град\n(1.0..85.0)",
              commandName: "fm_roll_max",
              value: _fmRollMax,
              min: 1.0,
              max: 85.0,
              divisions: 840,
              unit: "°",
              onChanged: (v) => setState(() => _fmRollMax = v),
              onChangeEnd: (v) =>
                  _sendIfConnected("fm_roll_max ${v.toStringAsFixed(1)}"),
            ),
            XFireSliderCard(
              title: "Макс. угол Pitch, град\n(1.0..85.0)",
              commandName: "fm_pitch_max",
              value: _fmPitchMax,
              min: 1.0,
              max: 85.0,
              divisions: 840,
              unit: "°",
              onChanged: (v) => setState(() => _fmPitchMax = v),
              onChangeEnd: (v) =>
                  _sendIfConnected("fm_pitch_max ${v.toStringAsFixed(1)}"),
            ),
            XFireSliderCard(
              title: "Макс. вертикальная скорость\nв удержании высоты (0.1..10.0)",
              commandName: "fm_vz_speed_max",
              value: _fmVzSpeedMax,
              min: 0.1,
              max: 10.0,
              divisions: 99,
              unit: "м/с",
              onChanged: (v) => setState(() => _fmVzSpeedMax = v),
              onChangeEnd: (v) =>
                  _sendIfConnected("fm_vz_speed_max ${v.toStringAsFixed(2)}"),
            ),
            XFireSliderCard(
              title: "Базовая скорость Roll / Pitch\n(0.01..2.5)",
              commandName: "rc_rate",
              value: _rcRate,
              min: 0.01,
              max: 2.5,
              divisions: 249,
              unit: "",
              onChanged: (v) => setState(() => _rcRate = v),
              onChangeEnd: (v) =>
                  _sendIfConnected("rc_rate ${v.toStringAsFixed(3)}"),
            ),
            XFireSliderCard(
              title: "Супер-экспонента Roll / Pitch\n(0.0..1.0)",
              commandName: "rc_super_expo",
              value: _rcSuperExpo,
              min: 0.0,
              max: 1.0,
              divisions: 100,
              unit: "",
              onChanged: (v) => setState(() => _rcSuperExpo = v),
              onChangeEnd: (v) =>
                  _sendIfConnected("rc_super_expo ${v.toStringAsFixed(3)}"),
            ),
            XFireSliderCard(
              title: "Экспонента стиков Roll / Pitch\n(0.0..1.0)",
              commandName: "rc_stick_expo",
              value: _rcStickExpo,
              min: 0.0,
              max: 1.0,
              divisions: 100,
              unit: "",
              onChanged: (v) => setState(() => _rcStickExpo = v),
              onChangeEnd: (v) =>
                  _sendIfConnected("rc_stick_expo ${v.toStringAsFixed(3)}"),
            ),
            XFireSliderCard(
              title: "Базовая скорость Yaw\n(0.01..2.5)",
              commandName: "rc_yaw_rate",
              value: _rcYawRate,
              min: 0.01,
              max: 2.5,
              divisions: 249,
              unit: "",
              onChanged: (v) => setState(() => _rcYawRate = v),
              onChangeEnd: (v) =>
                  _sendIfConnected("rc_yaw_rate ${v.toStringAsFixed(3)}"),
            ),
            XFireSliderCard(
              title: "Супер-экспонента Yaw\n(0.0..1.0)",
              commandName: "rc_yaw_super_expo",
              value: _rcYawSuperExpo,
              min: 0.0,
              max: 1.0,
              divisions: 100,
              unit: "",
              onChanged: (v) => setState(() => _rcYawSuperExpo = v),
              onChangeEnd: (v) =>
                  _sendIfConnected("rc_yaw_super_expo ${v.toStringAsFixed(3)}"),
            ),
            XFireSliderCard(
              title: "Экспонента стика Yaw\n(0.0..1.0)",
              commandName: "rc_yaw_expo",
              value: _rcYawExpo,
              min: 0.0,
              max: 1.0,
              divisions: 100,
              unit: "",
              onChanged: (v) => setState(() => _rcYawExpo = v),
              onChangeEnd: (v) =>
                  _sendIfConnected("rc_yaw_expo ${v.toStringAsFixed(3)}"),
            ),
            XFireSliderCard(
              title: "Мёртвая зона вокруг центра\n(500.0, диапазон 0.0..200.0)",
              commandName: "rc_deadband",
              value: _rcDeadband,
              min: 0.0,
              max: 200.0,
              divisions: 200,
              unit: "",
              onChanged: (v) => setState(() => _rcDeadband = v),
              onChangeEnd: (v) =>
                  _sendIfConnected("rc_deadband ${v.toStringAsFixed(1)}"),
            ),
            XFireSliderCard(
              title: "Порог перехода Angle -> Acro\nв Horizon (0.05..1.0)",
              commandName: "rc_horizon_transition",
              value: _rcHorizonTransition,
              min: 0.05,
              max: 1.0,
              divisions: 95,
              unit: "",
              onChanged: (v) => setState(() => _rcHorizonTransition = v),
              onChangeEnd: (v) => _sendIfConnected(
                "rc_horizon_transition ${v.toStringAsFixed(3)}",
              ),
            ),
            XFireSliderCard(
              title: "Сглаживание входящих стиков\n(0.001..1.0)",
              commandName: "rc_filter_smoothing",
              value: _rcFilterSmoothing,
              min: 0.001,
              max: 1.0,
              divisions: 999,
              unit: "",
              onChanged: (v) => setState(() => _rcFilterSmoothing = v),
              onChangeEnd: (v) => _sendIfConnected(
                "rc_filter_smoothing ${v.toStringAsFixed(3)}",
              ),
            ),
            XFireResetCard(
              hint: "Сброс локальных значений\nрежимов полёта и RC",
              onReset: _resetFlightRcGroup,
            ),
            XFireBatchApplyCard(
              hint: "Пакетная отправка режимов\nполёта и кривых RC",
              parameters: [
                "fm_mode ${_fmMode.round()}",
                "fm_roll_max ${_fmRollMax.toStringAsFixed(1)}",
                "fm_pitch_max ${_fmPitchMax.toStringAsFixed(1)}",
                "fm_vz_speed_max ${_fmVzSpeedMax.toStringAsFixed(2)}",
                "rc_rate ${_rcRate.toStringAsFixed(3)}",
                "rc_super_expo ${_rcSuperExpo.toStringAsFixed(3)}",
                "rc_stick_expo ${_rcStickExpo.toStringAsFixed(3)}",
                "rc_yaw_rate ${_rcYawRate.toStringAsFixed(3)}",
                "rc_yaw_super_expo ${_rcYawSuperExpo.toStringAsFixed(3)}",
                "rc_yaw_expo ${_rcYawExpo.toStringAsFixed(3)}",
                "rc_deadband ${_rcDeadband.toStringAsFixed(1)}",
                "rc_horizon_transition ${_rcHorizonTransition.toStringAsFixed(3)}",
                "rc_filter_smoothing ${_rcFilterSmoothing.toStringAsFixed(3)}",
              ],
            ),
          ],
        ),
        XFireExpansionCard(
          title: "Failsafe и аварийная посадка",
          subtitle: "Порог батареи, потеря RC\nи скорость снижения в удержании",
          icon: Icons.warning_amber_rounded,
          children: [
            XFireSwitchCard(
              title: "Failsafe при просадке\nнапряжения батареи",
              commandName: "fs_bat_en",
              value: _fsBatEn == 1,
              onChanged: (v) {
                setState(() => _fsBatEn = v ? 1.0 : 0.0);
                _sendIfConnected("fs_bat_en ${_fsBatEn.round()}");
              },
            ),
            XFireSwitchCard(
              title: "Failsafe при потере\nRC-пакетов",
              commandName: "fs_rtx_en",
              value: _fsRtxEn == 1,
              onChanged: (v) {
                setState(() => _fsRtxEn = v ? 1.0 : 0.0);
                _sendIfConnected("fs_rtx_en ${_fsRtxEn.round()}");
              },
            ),
            XFireSliderCard(
              title: "Порог напряжения failsafe\nпо батарее (5.0..25.0 В)",
              commandName: "bat_fs_v",
              value: _batFsV,
              min: 5.0,
              max: 25.0,
              divisions: 200,
              unit: "В",
              onChanged: (v) => setState(() => _batFsV = v),
              onChangeEnd: (v) =>
                  _sendIfConnected("bat_fs_v ${v.toStringAsFixed(2)}"),
            ),
            XFireSliderCard(
              title: "Скорость снижения при failsafe\nв удержании высоты (0.05..10.0)",
              commandName: "fs_vz_speed",
              value: _fsVzSpeed,
              min: 0.05,
              max: 10.0,
              divisions: 199,
              unit: "м/с",
              onChanged: (v) => setState(() => _fsVzSpeed = v),
              onChangeEnd: (v) =>
                  _sendIfConnected("fs_vz_speed ${v.toStringAsFixed(2)}"),
            ),
            XFireResetCard(
              hint: "Сброс локальных значений\nблока Failsafe",
              onReset: _resetFailsafeGroup,
            ),
            XFireBatchApplyCard(
              hint: "Пакетная отправка настроек\nfailsafe и аварийной посадки",
              parameters: [
                "fs_bat_en ${_fsBatEn.round()}",
                "fs_rtx_en ${_fsRtxEn.round()}",
                "bat_fs_v ${_batFsV.toStringAsFixed(2)}",
                "fs_vz_speed ${_fsVzSpeed.toStringAsFixed(2)}",
              ],
            ),
          ],
        ),
        XFireExpansionCard(
          title: "Фильтры IMU и адаптивный Маджвик",
          subtitle: "ФНЧ, Notch-фильтр гироскопа\nи адаптивный beta Маджвика",
          icon: Icons.waves,
          children: [
            XFireSwitchCard(
              title: "Включение ФНЧ гироскопа\nи акселерометра",
              commandName: "flt_lpf_en",
              value: _fltLpfEn == 1,
              onChanged: (v) {
                setState(() => _fltLpfEn = v ? 1.0 : 0.0);
                _sendIfConnected("flt_lpf_en ${_fltLpfEn.round()}");
              },
            ),
            XFireSwitchCard(
              title: "Включение Notch-фильтра\nгироскопа",
              commandName: "flt_not_en",
              value: _fltNotEn == 1,
              onChanged: (v) {
                setState(() => _fltNotEn = v ? 1.0 : 0.0);
                _sendIfConnected("flt_not_en ${_fltNotEn.round()}");
              },
            ),
            XFireSwitchCard(
              title: "Адаптивный вес акселерометра\nв Маджвике",
              commandName: "flt_amb_en",
              value: _fltAmbEn == 1,
              onChanged: (v) {
                setState(() => _fltAmbEn = v ? 1.0 : 0.0);
                _sendIfConnected("flt_amb_en ${_fltAmbEn.round()}");
              },
            ),
            XFireSliderCard(
              title: "Alpha ФНЧ гироскопа\n(0.001..1.0, по умолч. 0.10)",
              commandName: "gyro_filter_alpha",
              value: _gyroFilterAlpha,
              min: 0.001,
              max: 1.0,
              divisions: 999,
              unit: "",
              onChanged: (v) => setState(() => _gyroFilterAlpha = v),
              onChangeEnd: (v) =>
                  _sendIfConnected("gyro_filter_alpha ${v.toStringAsFixed(3)}"),
            ),
            XFireSliderCard(
              title: "Alpha ФНЧ акселерометра\n(0.001..1.0, по умолч. 0.10)",
              commandName: "acc_filter_alpha",
              value: _accFilterAlpha,
              min: 0.001,
              max: 1.0,
              divisions: 999,
              unit: "",
              onChanged: (v) => setState(() => _accFilterAlpha = v),
              onChangeEnd: (v) =>
                  _sendIfConnected("acc_filter_alpha ${v.toStringAsFixed(3)}"),
            ),
            XFireSliderCard(
              title: "Частота Notch-фильтра\n(20.0..120.0 Гц, по умолч. 120.0)",
              commandName: "filter_notch_freq",
              value: _filterNotchFreq,
              min: 20.0,
              max: 120.0,
              divisions: 1000,
              unit: "Гц",
              onChanged: (v) => setState(() => _filterNotchFreq = v),
              onChangeEnd: (v) =>
                  _sendIfConnected("filter_notch_freq ${v.toStringAsFixed(1)}"),
            ),
            XFireSliderCard(
              title: "Ширина полосы Notch-фильтра\n(1.0..100.0 Гц, по умолч. 20.0)",
              commandName: "filter_notch_bw",
              value: _filterNotchBw,
              min: 1.0,
              max: 100.0,
              divisions: 990,
              unit: "Гц",
              onChanged: (v) => setState(() => _filterNotchBw = v),
              onChangeEnd: (v) =>
                  _sendIfConnected("filter_notch_bw ${v.toStringAsFixed(1)}"),
            ),
            XFireSliderCard(
              title: "Верхняя граница beta Маджвика\n(0.001..1.0, по умолч. 0.05)",
              commandName: "flt_amb",
              value: _fltAmb,
              min: 0.001,
              max: 1.0,
              divisions: 999,
              unit: "",
              onChanged: (v) {
                setState(() {
                  _fltAmb = v;
                  if (_fltAmbMin > _fltAmb) _fltAmbMin = _fltAmb;
                });
              },
              onChangeEnd: (v) =>
                  _sendIfConnected("flt_amb ${v.toStringAsFixed(4)}"),
            ),
            XFireSliderCard(
              title: "Нижняя граница beta Маджвика\n(0.0005..flt_amb, по умолч. 0.003)",
              commandName: "flt_amb_min",
              value: safeFltAmbMinVal,
              min: 0.0005,
              max: safeFltAmbMinMax,
              divisions: 995,
              unit: "",
              onChanged: (v) => setState(() => _fltAmbMin = v),
              onChangeEnd: (v) =>
                  _sendIfConnected("flt_amb_min ${v.toStringAsFixed(4)}"),
            ),
            XFireResetCard(
              hint: "Сброс локальных значений\nблока фильтров",
              onReset: _resetFiltersGroup,
            ),
            XFireBatchApplyCard(
              hint: "Пакетная отправка настроек\nфильтров и Маджвика",
              parameters: [
                "flt_lpf_en ${_fltLpfEn.round()}",
                "flt_not_en ${_fltNotEn.round()}",
                "flt_amb_en ${_fltAmbEn.round()}",
                "gyro_filter_alpha ${_gyroFilterAlpha.toStringAsFixed(3)}",
                "acc_filter_alpha ${_accFilterAlpha.toStringAsFixed(3)}",
                "filter_notch_freq ${_filterNotchFreq.toStringAsFixed(1)}",
                "filter_notch_bw ${_filterNotchBw.toStringAsFixed(1)}",
                "flt_amb ${_fltAmb.toStringAsFixed(4)}",
                "flt_amb_min ${safeFltAmbMinVal.toStringAsFixed(4)}",
              ],
            ),
          ],
        ),
        XFireExpansionCard(
          title: "PID-регуляторы\n(Roll, Pitch, Yaw, Vz)",
          subtitle: "Настройки Kp, Ki, Kd для осей\nRoll, Pitch, Yaw и Vz",
          icon: Icons.tune,
          children: [
            PidAxisCardWidget(
              axisName: "Roll Axis",
              kpCmd: "roll_kp",
              kiCmd: "roll_ki",
              kdCmd: "roll_kd",
              kp: _rollKp,
              ki: _rollKi,
              kd: _rollKd,
              kpMin: 0.0,
              kpMax: 10.0,
              kiMin: 0.0,
              kiMax: 5.0,
              kdMin: 0.0,
              kdMax: 1.0,
              kpDecimals: 3,
              kiDecimals: 3,
              kdDecimals: 3,
              onUpdate: (p, i, d) {
                setState(() {
                  _rollKp = p;
                  _rollKi = i;
                  _rollKd = d;
                });
                _sendIfConnected("roll_kp $p");
                _sendIfConnected("roll_ki $i");
                _sendIfConnected("roll_kd $d");
              },
            ),
            PidAxisCardWidget(
              axisName: "Pitch Axis",
              kpCmd: "pitch_kp",
              kiCmd: "pitch_ki",
              kdCmd: "pitch_kd",
              kp: _pitchKp,
              ki: _pitchKi,
              kd: _pitchKd,
              kpMin: 0.0,
              kpMax: 10.0,
              kiMin: 0.0,
              kiMax: 5.0,
              kdMin: 0.0,
              kdMax: 1.0,
              kpDecimals: 3,
              kiDecimals: 3,
              kdDecimals: 3,
              onUpdate: (p, i, d) {
                setState(() {
                  _pitchKp = p;
                  _pitchKi = i;
                  _pitchKd = d;
                });
                _sendIfConnected("pitch_kp $p");
                _sendIfConnected("pitch_ki $i");
                _sendIfConnected("pitch_kd $d");
              },
            ),
            PidAxisCardWidget(
              axisName: "Yaw Axis",
              kpCmd: "yaw_kp",
              kiCmd: "yaw_ki",
              kdCmd: "yaw_kd",
              kp: _yawKp,
              ki: _yawKi,
              kd: _yawKd,
              kpMin: 0.0,
              kpMax: 10.0,
              kiMin: 0.0,
              kiMax: 5.0,
              kdMin: 0.0,
              kdMax: 1.0,
              kpDecimals: 3,
              kiDecimals: 3,
              kdDecimals: 3,
              onUpdate: (p, i, d) {
                setState(() {
                  _yawKp = p;
                  _yawKi = i;
                  _yawKd = d;
                });
                _sendIfConnected("yaw_kp $p");
                _sendIfConnected("yaw_ki $i");
                _sendIfConnected("yaw_kd $d");
              },
            ),
            PidAxisCardWidget(
              axisName: "Vertical Speed Axis (Vz)",
              kpCmd: "vz_kp",
              kiCmd: "vz_ki",
              kdCmd: "vz_kd",
              kp: _vzKp,
              ki: _vzKi,
              kd: _vzKd,
              kpMin: 0.0,
              kpMax: 50.0,
              kiMin: 0.0,
              kiMax: 20.0,
              kdMin: 0.0,
              kdMax: 10.0,
              kpDecimals: 2,
              kiDecimals: 2,
              kdDecimals: 2,
              onUpdate: (p, i, d) {
                setState(() {
                  _vzKp = p;
                  _vzKi = i;
                  _vzKd = d;
                });
                _sendIfConnected("vz_kp $p");
                _sendIfConnected("vz_ki $i");
                _sendIfConnected("vz_kd $d");
              },
            ),
            XFireResetCard(
              hint: "Сброс локальных значений\nблока PID",
              onReset: _resetPidGroup,
            ),
            XFireBatchApplyCard(
              hint: "Пакетная отправка ПИД-коэффициентов\nосей",
              parameters: [
                "roll_kp $_rollKp",
                "roll_ki $_rollKi",
                "roll_kd $_rollKd",
                "pitch_kp $_pitchKp",
                "pitch_ki $_pitchKi",
                "pitch_kd $_pitchKd",
                "yaw_kp $_yawKp",
                "yaw_ki $_yawKi",
                "yaw_kd $_yawKd",
                "vz_kp $_vzKp",
                "vz_ki $_vzKi",
                "vz_kd $_vzKd",
              ],
            ),
          ],
        ),
        XFireExpansionCard(
          title: "Тесты моторов, PID и автокалибровка",
          subtitle: "test_mot (макс. 250), test_pid (макс. 120)\nи auto_cal / auto_stop",
          icon: Icons.rule,
          children: [
            XFireActionCard(
              title: "Стендовый тест моторов (10 сек, <=250)",
              commandName: "test_mot",
              onTap: () => _runCalOrTest(
                "test_mot",
                "Внимание: test_mot",
                "10-секундный тест плавного вращения\nмоторов (тяга <=250, только в disarmed).",
                isWarning: true,
              ),
            ),
            XFireActionCard(
              title: "Стендовый тест PID по гироскопу (<=120)",
              commandName: "test_pid",
              onTap: () => _runCalOrTest(
                "test_pid",
                "Тест PID (test_pid)",
                "10-секундный тест угловых PID\nс ограничением выхода до 120 (disarmed).",
              ),
            ),
            XFireActionCard(
              title: "Автоматический взлёт, калибровка и посадка",
              commandName: "auto_cal",
              onTap: () => _runCalOrTest(
                "auto_cal",
                "Автокалибровка (auto_cal)",
                "Запуск авто-взлёта, калибровки висения/PID\nи посадки по лидару (нужны IMU и лидар, disarmed).",
                isWarning: true,
              ),
            ),
            XFireActionCard(
              title: "Аварийная остановка автокалибровки",
              commandName: "auto_stop",
              onTap: () => _runCalOrTest(
                "auto_stop",
                "Остановка (auto_stop)",
                "Принудительная остановка автокалибровки\nи отключение моторов.",
                isWarning: true,
              ),
            ),
          ],
        ),
        XFireExpansionCard(
          title: "Телеметрия",
          subtitle: "Авиогоризонт, HUD и показания\nгироскопа / акселерометра",
          icon: Icons.radar,
          children: [
            StreamBuilder<void>(
              stream: SerialService.telemetryController.stream,
              builder: (context, snapshot) {
                final double pitchDeg = SerialService.gyroPitch * 57.2958;
                double yawDeg = SerialService.gyroYaw * 57.2958;
                while (yawDeg > 180) yawDeg -= 360;
                while (yawDeg < -180) yawDeg += 360;

                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
                      padding: const EdgeInsets.all(8),
                      height: 260,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Column(
                        children: [
                          Transform.translate(
                            offset: const Offset(0, 16),
                            child: SizedBox(
                              height: 28,
                              child: CustomPaint(
                                painter: YawHudScalePainter(
                                  value: yawDeg,
                                  minVal: -180,
                                  maxVal: 180,
                                  isTop: true,
                                ),
                                size: const Size(double.infinity, 28),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Transform.translate(
                                    offset: const Offset(-24, 0),
                                    child: CustomPaint(
                                      painter: PitchHudScalePainter(
                                        value: pitchDeg,
                                        minVal: -90,
                                        maxVal: 90,
                                        isLeftSide: true,
                                      ),
                                      size: const Size(double.infinity, double.infinity),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: Center(
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        CustomPaint(
                                          size: const Size(155, 155),
                                          painter: ArtificialHorizonPainter(
                                            roll: SerialService.gyroRoll,
                                            pitch: SerialService.gyroPitch,
                                          ),
                                        ),
                                        const Icon(Icons.add, color: Colors.white, size: 24),
                                      ],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Transform.translate(
                                    offset: const Offset(24, 0),
                                    child: CustomPaint(
                                      painter: PitchHudScalePainter(
                                        value: pitchDeg,
                                        minVal: -90,
                                        maxVal: 90,
                                        isLeftSide: false,
                                      ),
                                      size: const Size(double.infinity, double.infinity),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Transform.translate(
                            offset: const Offset(0, -16),
                            child: SizedBox(
                              height: 28,
                              child: CustomPaint(
                                painter: YawHudScalePainter(
                                  value: yawDeg,
                                  minVal: -180,
                                  maxVal: 180,
                                  isTop: false,
                                ),
                                size: const Size(double.infinity, 28),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 13.0, vertical: 4.0),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "GYROSCOPE",
                              style: TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _buildSensorBar(
                              "Gyro Roll",
                              SerialService.gyroRoll,
                              -3.14,
                              3.14,
                              "rad/s",
                              Colors.blueAccent,
                            ),
                            _buildSensorBar(
                              "Gyro Pitch",
                              SerialService.gyroPitch,
                              -3.14,
                              3.14,
                              "rad/s",
                              Colors.blueAccent,
                            ),
                            _buildSensorBar(
                              "Gyro Yaw",
                              SerialService.gyroYaw,
                              -3.14,
                              3.14,
                              "rad/s",
                              Colors.blueAccent,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "ACCELEROMETER",
                              style: TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _buildSensorBar(
                              "Accel X",
                              SerialService.accelX,
                              -2.0,
                              2.0,
                              "G",
                              Colors.cyanAccent,
                            ),
                            _buildSensorBar(
                              "Accel Y",
                              SerialService.accelY,
                              -2.0,
                              2.0,
                              "G",
                              Colors.cyanAccent,
                            ),
                            _buildSensorBar(
                              "Accel Z",
                              SerialService.accelZ,
                              -2.0,
                              2.0,
                              "G",
                              Colors.cyanAccent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        XFireExpansionCard(
          title: "Прошивка DFU и память Flash",
          subtitle: "Сохранение в ОЗУ->Flash (save),\nсводка (info) и прошивка STM32F401 по DFU",
          icon: Icons.memory,
          children: [
            XFireActionCard(
              title: "Сохранить конфигурацию во Flash",
              commandName: "save",
              onTap: () => _runCalOrTest(
                "save",
                "Сохранение во Flash",
                "Запись текущей конфигурации из ОЗУ\nво Flash (работает в disarmed и вне auto_cal).",
              ),
            ),
            XFireActionCard(
              title: "Сводка состояния и конфига",
              commandName: "info",
              onTap: () => _runCalOrTest(
                "info",
                "Сводка системы (info)",
                "Запрошен вывод INFO, CFG_FM, CFG_RC,\nCFG_FLT, CFG_PID, CFG_BAT и CFG_HW.",
              ),
            ),
            XFireFlashCard(
              title: "Прошить STM32F401 по DFU\n(v3.27)",
              targetName: "Полетный контроллер STM32F401 (DFU)",
              onFlash: (onProgress) async {
                if (SerialService.isConnected) {
                  onProgress("Закрытие USB Serial перед DFU...", 0.01);
                  await SerialService.disconnect();
                }
                await DfuService.flashF401(
                  assetPath: 'assets/fc401.bin',
                  startAddress: 0x08000000,
                  onProgress: onProgress,
                );
              },
            ),
          ],
        ),
        XFireResetCard(
          hint: "Сброс всех параметров к заводским\nи сохранение во Flash (default)",
          onReset: _resetAllFcSettings,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ==========================================
// ВКЛАДКА 2: ПУЛЬТ RC (OSD / RX5808 / VTX)
// ==========================================
class RemoteControlTab extends StatefulWidget {
  const RemoteControlTab({super.key});

  @override
  State<RemoteControlTab> createState() => _RemoteControlTabState();
}

class _RemoteControlTabState extends State<RemoteControlTab> {
  bool _osdEn = true;
  bool _rx58En = true;
  double _rx58Ch = 32.0;

  double _vtxCh0 = 32.0;
  double _vtxCh1 = 33.0;
  double _vtxCh2 = 34.0;
  double _vtxCh3 = 35.0;

  double _vtxRssiTh = 50.0;
  double _vtxRssiHyst = 12.0;
  bool _vtxAutoStart = true;
  int _vtxBtnMode = 0;

  void _sendIfConnected(String cmd) {
    if (SerialService.isConnected && SerialService.usbPort != null) {
      unawaited(SerialService.sendCommand(cmd));
    }
  }

  void _resetRcDefaults() {
    setState(() {
      _osdEn = true;
      _rx58En = true;
      _rx58Ch = 32.0;
      _vtxCh0 = 32.0;
      _vtxCh1 = 33.0;
      _vtxCh2 = 34.0;
      _vtxCh3 = 35.0;
      _vtxRssiTh = 50.0;
      _vtxRssiHyst = 12.0;
      _vtxAutoStart = true;
      _vtxBtnMode = 0;
    });
    _sendIfConnected("default");
    showAppDialog(
      context,
      "Сброс настроек пульта",
      "Настройки OSD, RX5808 и VTX\nсброшены по умолчанию (default).",
    );
  }

  List<String> _buildBatchParams() {
    return [
      "osd_en ${_osdEn ? 1 : 0}",
      "rx58_en ${_rx58En ? 1 : 0}",
      "rx58_ch ${_rx58Ch.round()}",
      "vtx_ch0 ${_vtxCh0.round()}",
      "vtx_ch1 ${_vtxCh1.round()}",
      "vtx_ch2 ${_vtxCh2.round()}",
      "vtx_ch3 ${_vtxCh3.round()}",
      "vtx_rssi_th ${_vtxRssiTh.round()}",
      "vtx_rssi_hyst ${_vtxRssiHyst.round()}",
      "vtx_auto_start ${_vtxAutoStart ? 1 : 0}",
      "vtx_btn_mode $_vtxBtnMode",
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      children: [
        XFireExpansionCard(
          title: "OSD (MAX7456) и приёмник RX5808",
          subtitle: "Включение OSD и RX5808,\nиндекс канала RX5808 (0..39)",
          icon: Icons.tv_rounded,
          children: [
            XFireSwitchCard(
              title: "Включение MAX7456 OSD",
              commandName: "osd_en",
              value: _osdEn,
              onChanged: (v) {
                setState(() => _osdEn = v);
                _sendIfConnected("osd_en ${v ? 1 : 0}");
              },
            ),
            XFireSwitchCard(
              title: "Приёмник RX5808 и авто-RSSI",
              commandName: "rx58_en",
              value: _rx58En,
              onChanged: (v) {
                setState(() => _rx58En = v);
                _sendIfConnected("rx58_en ${v ? 1 : 0}");
              },
            ),
            XFireSliderCard(
              title: "Индекс канала RX5808\n(0..39 по таблице частот)",
              commandName: "rx58_ch",
              value: _rx58Ch,
              min: 0,
              max: 39,
              divisions: 39,
              unit: "CH",
              onChanged: (v) => setState(() => _rx58Ch = v),
              onChangeEnd: (v) => _sendIfConnected("rx58_ch ${v.round()}"),
            ),
          ],
        ),
        XFireExpansionCard(
          title: "Каналы VTX по ступеням (0..3)",
          subtitle: "Индексы каналов 0..39\nдля ступеней VTX 0..3",
          icon: Icons.settings_input_antenna,
          children: [
            XFireSliderCard(
              title: "Канал VTX — ступень 0\n(по умолч. 32)",
              commandName: "vtx_ch0",
              value: _vtxCh0,
              min: 0,
              max: 39,
              divisions: 39,
              unit: "CH",
              onChanged: (v) => setState(() => _vtxCh0 = v),
              onChangeEnd: (v) => _sendIfConnected("vtx_ch0 ${v.round()}"),
            ),
            XFireSliderCard(
              title: "Канал VTX — ступень 1\n(по умолч. 33)",
              commandName: "vtx_ch1",
              value: _vtxCh1,
              min: 0,
              max: 39,
              divisions: 39,
              unit: "CH",
              onChanged: (v) => setState(() => _vtxCh1 = v),
              onChangeEnd: (v) => _sendIfConnected("vtx_ch1 ${v.round()}"),
            ),
            XFireSliderCard(
              title: "Канал VTX — ступень 2\n(по умолч. 34)",
              commandName: "vtx_ch2",
              value: _vtxCh2,
              min: 0,
              max: 39,
              divisions: 39,
              unit: "CH",
              onChanged: (v) => setState(() => _vtxCh2 = v),
              onChangeEnd: (v) => _sendIfConnected("vtx_ch2 ${v.round()}"),
            ),
            XFireSliderCard(
              title: "Канал VTX — ступень 3\n(по умолч. 35)",
              commandName: "vtx_ch3",
              value: _vtxCh3,
              min: 0,
              max: 39,
              divisions: 39,
              unit: "CH",
              onChanged: (v) => setState(() => _vtxCh3 = v),
              onChangeEnd: (v) => _sendIfConnected("vtx_ch3 ${v.round()}"),
            ),
          ],
        ),
        XFireExpansionCard(
          title: "Авто-RSSI и кнопка VTX",
          subtitle: "Порог и гистерезис RSSI,\nстарт и режим кнопки VTX",
          icon: Icons.smart_button_rounded,
          children: [
            XFireSliderCard(
              title: "Целевой порог RSSI RX5808\nдля авто-ступеней VTX",
              commandName: "vtx_rssi_th",
              value: _vtxRssiTh,
              min: 0,
              max: 100,
              divisions: 100,
              unit: "%",
              onChanged: (v) => setState(() => _vtxRssiTh = v),
              onChangeEnd: (v) => _sendIfConnected("vtx_rssi_th ${v.round()}"),
            ),
            XFireSliderCard(
              title: "Гистерезис вокруг порога RSSI\n(th - hyst / th + hyst)",
              commandName: "vtx_rssi_hyst",
              value: _vtxRssiHyst,
              min: 0,
              max: 40,
              divisions: 40,
              unit: "%",
              onChanged: (v) => setState(() => _vtxRssiHyst = v),
              onChangeEnd: (v) => _sendIfConnected("vtx_rssi_hyst ${v.round()}"),
            ),
            XFireSwitchCard(
              title: "Старт в AUTO RSSI\n(выкл = старт в MIN / ступень 0)",
              commandName: "vtx_auto_start",
              value: _vtxAutoStart,
              onChanged: (v) {
                setState(() => _vtxAutoStart = v);
                _sendIfConnected("vtx_auto_start ${v ? 1 : 0}");
              },
            ),
            XFireSegmentedCard(
              title: "Режим кнопки VTX\n(при vtx_btn_mode = 0 старт по vtx_auto_start)",
              commandName: "vtx_btn_mode",
              options: const ["0: MIN <-> AUTO RSSI", "1: MIN <-> MAX (ст. 3)"],
              selectedIndex: _vtxBtnMode.clamp(0, 1),
              onSelected: (val) {
                setState(() => _vtxBtnMode = val);
                _sendIfConnected("vtx_btn_mode $val");
              },
            ),
          ],
        ),
        XFireResetCard(
          hint: "Сброс настроек пульта\nпо умолчанию (default)",
          onReset: _resetRcDefaults,
        ),
        XFireBatchApplyCard(
          hint: "Пакетная отправка настроек\nOSD, RX5808 и VTX (config)",
          parameters: _buildBatchParams(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ==========================================
// ВКЛАДКА 3: РАДИОМОДУЛЬ RTX / LoRa
// ==========================================
class RadioTab extends StatefulWidget {
  const RadioTab({super.key});

  @override
  State<RadioTab> createState() => _RadioTabState();
}

class _RadioTabState extends State<RadioTab> {
  double _rtxProtId = 0;
  double _rtxId = 1;
  double _rtxEn = 1;
  double _rtxBand = 2;

  bool _rtxHwCrcEn = true;
  bool _rtxAddrEn = false;
  double _rtxAddr = 0;
  String _rtxSyncWordHex = "0x12";
  bool _rtxIqInv = false;

  double _priChan = 0;
  double _priSf = 7;
  double _priBw = 7;
  double _priCr = 1;
  double _priPower = 14;

  double _bakChan = 1;
  double _bakSf = 8;
  double _bakBw = 7;
  double _bakCr = 2;
  double _bakPower = 17;

  bool _hasProtectiveSleeve = true;
  double _sleeveThicknessMm = 1.0;
  double _dipoleTubeDiameterMm = 3.0;
  double _dipoleTopWireSqMm = 1.0;
  double _kharchenkoWireSqMm = 2.0;

  final List<double> _bwTable = [
    7800.0,
    10400.0,
    15600.0,
    20800.0,
    31250.0,
    41700.0,
    62500.0,
    125000.0,
    250000.0,
    500000.0,
  ];
  final Map<int, double> _snrTable = {
    6: -5.0,
    7: -7.5,
    8: -10.0,
    9: -12.5,
    10: -15.0,
    11: -17.5,
    12: -20.0,
  };

  void _sendIfConnected(String cmd) {
    if (SerialService.isConnected && SerialService.usbPort != null) {
      unawaited(SerialService.sendCommand(cmd));
    }
  }

  double _bandBaseMhz(int band) {
    if (band == 0) return 433.0;
    if (band == 1) return 868.0;
    return 915.0;
  }

  double get _priFreqMhz => _bandBaseMhz(_rtxBand.round()) + (_priChan * 0.2);
  double get _bakFreqMhz => _bandBaseMhz(_rtxBand.round()) + (_bakChan * 0.2);

  int _parseByte(String raw, {int fallback = 0x12}) {
    final cleaned = raw.trim().toLowerCase().replaceFirst('0x', '');
    final parsed = int.tryParse(
      cleaned,
      radix: raw.trim().toLowerCase().startsWith('0x') ? 16 : 10,
    );
    if (parsed == null) return fallback;
    return parsed.clamp(0, 255);
  }

  double _calculateSensitivity(double bwParam, double sfParam) {
    final bwHz = _bwTable[bwParam.round().clamp(0, _bwTable.length - 1)];
    final sfInt = sfParam.round().clamp(6, 12);
    final snr = _snrTable[sfInt] ?? -7.5;
    return -174.0 + (10.0 * (math.log(bwHz) / math.ln10)) + 6.0 + snr;
  }

  double _calculateAirDataRate(double bwParam, double sfParam, double crParam) {
    final bwHz = _bwTable[bwParam.round().clamp(0, _bwTable.length - 1)];
    final sfInt = sfParam.round().clamp(6, 12);
    final crInt = crParam.round().clamp(1, 4);
    final symbolRate = bwHz / math.pow(2, sfInt).toDouble();
    return sfInt * symbolRate * (4.0 / (4.0 + crInt));
  }

  Map<String, dynamic> _calculateLinkBudget(
    double freqMhz,
    double bw,
    double sf,
    double cr,
    double power,
  ) {
    final sensitivity = _calculateSensitivity(bw, sf);
    const eirp = 2.15;
    final maxPathLoss =
        (power + eirp + 2.15 - 1.0 - sensitivity - 15.0).clamp(0.0, 200.0);
    final freqLog = 20.0 * (math.log(freqMhz) / math.ln10);
    final distanceKm =
        math.pow(10.0, (maxPathLoss - 32.44 - freqLog) / 20.0).toDouble();
    final bitRate = _calculateAirDataRate(bw, sf, cr);
    return {'sensitivity': sensitivity, 'distanceKm': distanceKm, 'bitRate': bitRate};
  }

  Map<String, dynamic> _calculateAntennaDimensions() {
    final freqHz = _bakFreqMhz * 1e6;
    final lambdaMm = (299792458.0 / (freqHz * 1.0003)) * 1000.0;
    final quarterLambda = lambdaMm / 4.0;

    double dielectricLoading = 1.0;
    if (_hasProtectiveSleeve) {
      dielectricLoading = 1.0 + (0.018 * 1.6 * (_sleeveThicknessMm / 1.0));
    }

    final radiusBot = _dipoleTubeDiameterMm / 2.0;
    final kFactorDipoleBot =
        (0.97 - (2.5 / (2.0 * math.log(lambdaMm / radiusBot)))) / dielectricLoading;

    final radiusTop = math.sqrt(_dipoleTopWireSqMm / math.pi);
    final kFactorDipoleTop =
        (0.97 - (2.0 / (2.0 * math.log(lambdaMm / radiusTop)))) / dielectricLoading;

    final dipoleArmTopMm = quarterLambda * kFactorDipoleTop - 0.006;
    final dipoleArmBotMm = quarterLambda * kFactorDipoleBot - 0.006;
    final kharchenkoSideMm = quarterLambda *
        (0.96 -
            (1.8 /
                (2.0 *
                    math.log(
                      lambdaMm / (2.0 * math.sqrt(_kharchenkoWireSqMm / math.pi)),
                    ))));

    return {
      'lambdaMm': lambdaMm,
      'dipoleArmTopMm': dipoleArmTopMm,
      'dipoleArmBotMm': dipoleArmBotMm,
      'kharchenkoSideMm': kharchenkoSideMm,
    };
  }

  void _resetCommon() {
    setState(() {
      _rtxProtId = 0;
      _rtxId = 1;
      _rtxEn = 1;
      _rtxBand = 2;
      _rtxHwCrcEn = true;
      _rtxAddrEn = false;
      _rtxAddr = 0;
      _rtxSyncWordHex = "0x12";
      _rtxIqInv = false;
    });
  }

  void _resetPrimary() {
    setState(() {
      _priChan = 0;
      _priSf = 7;
      _priBw = 7;
      _priCr = 1;
      _priPower = 14;
    });
  }

  void _resetBackup() {
    setState(() {
      _bakChan = 1;
      _bakSf = 8;
      _bakBw = 7;
      _bakCr = 2;
      _bakPower = 17;
    });
  }

  void _resetAllRadio() {
    _resetCommon();
    _resetPrimary();
    _resetBackup();
    setState(() {
      _hasProtectiveSleeve = true;
      _sleeveThicknessMm = 1.0;
      _dipoleTubeDiameterMm = 3.0;
      _dipoleTopWireSqMm = 1.0;
      _kharchenkoWireSqMm = 2.0;
    });
    _sendIfConnected("default");
  }

  @override
  Widget build(BuildContext context) {
    final priResults =
        _calculateLinkBudget(_priFreqMhz, _priBw, _priSf, _priCr, _priPower);
    final bakResults =
        _calculateLinkBudget(_bakFreqMhz, _bakBw, _bakSf, _bakCr, _bakPower);
    final antResults = _calculateAntennaDimensions();
    final syncByte = _parseByte(_rtxSyncWordHex, fallback: 0x12);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      children: [
        XFireExpansionCard(
          title: "Общие настройки радиомодуля",
          subtitle: "Протокол, ID сети, диапазон,\nCRC, адресация и sync word",
          icon: Icons.settings_applications_rounded,
          children: [
            XFireSliderCard(
              title: "ID протокола радиоканала",
              commandName: "rtx_prot_id",
              value: _rtxProtId,
              min: 0,
              max: 255,
              divisions: 255,
              unit: "",
              onChanged: (v) => setState(() => _rtxProtId = v),
              onChangeEnd: (v) => _sendIfConnected("rtx_prot_id ${v.round()}"),
            ),
            XFireSliderCard(
              title: "Уникальный ID пары / сети",
              commandName: "rtx_id",
              value: _rtxId,
              min: 0,
              max: 65535,
              divisions: 255,
              unit: "",
              onChanged: (v) => setState(() => _rtxId = v),
              onChangeEnd: (v) => _sendIfConnected("rtx_id ${v.round()}"),
            ),
            XFireSwitchCard(
              title: "Включение радиомодуля",
              commandName: "rtx_en",
              value: _rtxEn == 1,
              onChanged: (v) {
                setState(() => _rtxEn = v ? 1.0 : 0.0);
                _sendIfConnected("rtx_en ${_rtxEn.round()}");
              },
            ),
            XFireSegmentedCard(
              title: "Частотный диапазон",
              commandName: "rtx_band",
              options: const ["0: 433 МГц", "1: 868 МГц", "2: 915 МГц"],
              selectedIndex: _rtxBand.round().clamp(0, 2),
              onSelected: (val) {
                setState(() => _rtxBand = val.toDouble());
                _sendIfConnected("rtx_band $val");
              },
            ),
            XFireSwitchCard(
              title: "Аппаратная проверка CRC",
              commandName: "rtx_hw_crc_en",
              value: _rtxHwCrcEn,
              onChanged: (v) {
                setState(() => _rtxHwCrcEn = v);
                _sendIfConnected("rtx_hw_crc_en ${v ? 1 : 0}");
              },
            ),
            XFireSwitchCard(
              title: "Адресация по адресу узла",
              commandName: "rtx_addr_en",
              value: _rtxAddrEn,
              onChanged: (v) {
                setState(() => _rtxAddrEn = v);
                _sendIfConnected("rtx_addr_en ${v ? 1 : 0}");
              },
            ),
            XFireSliderCard(
              title: "Адрес узла\n(при rtx_addr_en = 1)",
              commandName: "rtx_addr",
              value: _rtxAddr,
              min: 0,
              max: 255,
              divisions: 255,
              unit: "",
              onChanged: (v) => setState(() => _rtxAddr = v),
              onChangeEnd: (v) => _sendIfConnected("rtx_addr ${v.round()}"),
            ),
            XFireTextHexCard(
              title: "Sync word LoRa\n(0..255, по умолч. 0x12)",
              commandName: "rtx_sync_word",
              initialValue: _rtxSyncWordHex,
              onChanged: (v) => setState(() => _rtxSyncWordHex = v),
              onSubmitEnd: (v) {
                final val = _parseByte(v, fallback: 0x12);
                _sendIfConnected("rtx_sync_word $val");
              },
            ),
            XFireSwitchCard(
              title: "Инверсия IQ-сигнала",
              commandName: "rtx_iq_inv",
              value: _rtxIqInv,
              onChanged: (v) {
                setState(() => _rtxIqInv = v);
                _sendIfConnected("rtx_iq_inv ${v ? 1 : 0}");
              },
            ),
            XFireResetCard(
              hint: "Сброс локальных общих\nнастроек RTX",
              onReset: _resetCommon,
            ),
            XFireBatchApplyCard(
              hint: "Пакетная отправка общих\nнастроек RTX",
              parameters: [
                "rtx_prot_id ${_rtxProtId.round()}",
                "rtx_id ${_rtxId.round()}",
                "rtx_en ${_rtxEn.round()}",
                "rtx_band ${_rtxBand.round()}",
                "rtx_hw_crc_en ${_rtxHwCrcEn ? 1 : 0}",
                "rtx_addr_en ${_rtxAddrEn ? 1 : 0}",
                "rtx_addr ${_rtxAddr.round()}",
                "rtx_sync_word $syncByte",
                "rtx_iq_inv ${_rtxIqInv ? 1 : 0}",
              ],
            ),
          ],
        ),
        XFireExpansionCard(
          title: "Основной канал связи\n(Primary)",
          subtitle: "Канал, SF6..12, BW 0..9,\nCR 1..4 и мощность -9..22 дБм",
          icon: Icons.flash_on_rounded,
          children: [
            XFireSliderCard(
              title: "Номер основного канала",
              commandName: "rtx_pri_chan",
              value: _priChan,
              min: 0,
              max: 255,
              divisions: 255,
              unit: "",
              onChanged: (v) => setState(() => _priChan = v),
              onChangeEnd: (v) => _sendIfConnected("rtx_pri_chan ${v.round()}"),
            ),
            XFireSliderCard(
              title: "Spreading Factor\n(SF6..SF12)",
              commandName: "rtx_pri_sf",
              value: _priSf,
              min: 6,
              max: 12,
              divisions: 6,
              unit: "",
              onChanged: (v) => setState(() => _priSf = v),
              onChangeEnd: (v) => _sendIfConnected("rtx_pri_sf ${v.round()}"),
            ),
            XFireSliderCard(
              title: "Индекс полосы BW\n(0..9)",
              commandName: "rtx_pri_bw",
              value: _priBw,
              min: 0,
              max: 9,
              divisions: 9,
              unit: "",
              onChanged: (v) => setState(() => _priBw = v),
              onChangeEnd: (v) => _sendIfConnected("rtx_pri_bw ${v.round()}"),
            ),
            XFireSliderCard(
              title: "Coding Rate\n(1: 4/5 .. 4: 4/8)",
              commandName: "rtx_pri_cr",
              value: _priCr,
              min: 1,
              max: 4,
              divisions: 3,
              unit: "",
              onChanged: (v) => setState(() => _priCr = v),
              onChangeEnd: (v) => _sendIfConnected("rtx_pri_cr ${v.round()}"),
            ),
            XFireSliderCard(
              title: "Мощность передатчика\n(-9..22 дБм)",
              commandName: "rtx_pri_power",
              value: _priPower,
              min: -9,
              max: 22,
              divisions: 31,
              unit: "дБм",
              onChanged: (v) => setState(() => _priPower = v),
              onChangeEnd: (v) => _sendIfConnected("rtx_pri_power ${v.round()}"),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13.0, vertical: 6.0),
              child: RtxLinkCalculatorCard(
                title: "Оценка основного канала",
                themeColor: Colors.blueAccent,
                currentFreqMhz: _priFreqMhz,
                sensitivity: priResults['sensitivity'],
                distKm: priResults['distanceKm'],
                bitRate: priResults['bitRate'],
                sensitivityProgress:
                    ((priResults['sensitivity'] - (-140.0)) / 40.0).clamp(0.0, 1.0),
                bitRateProgress: (priResults['bitRate'] / 30000.0).clamp(0.0, 1.0),
              ),
            ),
            XFireResetCard(
              hint: "Сброс локальных настроек\nосновного канала",
              onReset: _resetPrimary,
            ),
            XFireBatchApplyCard(
              hint: "Пакетная отправка основного\nканала",
              parameters: [
                "rtx_pri_chan ${_priChan.round()}",
                "rtx_pri_sf ${_priSf.round()}",
                "rtx_pri_bw ${_priBw.round()}",
                "rtx_pri_cr ${_priCr.round()}",
                "rtx_pri_power ${_priPower.round()}",
              ],
            ),
          ],
        ),
        XFireExpansionCard(
          title: "Резервный канал связи\n(Backup)",
          subtitle: "Канал, SF6..12, BW 0..9,\nCR 1..4 и мощность -9..22 дБм",
          icon: Icons.shield_rounded,
          children: [
            XFireSliderCard(
              title: "Номер резервного канала",
              commandName: "rtx_bak_chan",
              value: _bakChan,
              min: 0,
              max: 255,
              divisions: 255,
              unit: "",
              onChanged: (v) => setState(() => _bakChan = v),
              onChangeEnd: (v) => _sendIfConnected("rtx_bak_chan ${v.round()}"),
            ),
            XFireSliderCard(
              title: "Spreading Factor\n(SF6..SF12)",
              commandName: "rtx_bak_sf",
              value: _bakSf,
              min: 6,
              max: 12,
              divisions: 6,
              unit: "",
              onChanged: (v) => setState(() => _bakSf = v),
              onChangeEnd: (v) => _sendIfConnected("rtx_bak_sf ${v.round()}"),
            ),
            XFireSliderCard(
              title: "Индекс полосы BW\n(0..9)",
              commandName: "rtx_bak_bw",
              value: _bakBw,
              min: 0,
              max: 9,
              divisions: 9,
              unit: "",
              onChanged: (v) => setState(() => _bakBw = v),
              onChangeEnd: (v) => _sendIfConnected("rtx_bak_bw ${v.round()}"),
            ),
            XFireSliderCard(
              title: "Coding Rate\n(1: 4/5 .. 4: 4/8)",
              commandName: "rtx_bak_cr",
              value: _bakCr,
              min: 1,
              max: 4,
              divisions: 3,
              unit: "",
              onChanged: (v) => setState(() => _bakCr = v),
              onChangeEnd: (v) => _sendIfConnected("rtx_bak_cr ${v.round()}"),
            ),
            XFireSliderCard(
              title: "Мощность передатчика\n(-9..22 дБм)",
              commandName: "rtx_bak_power",
              value: _bakPower,
              min: -9,
              max: 22,
              divisions: 31,
              unit: "дБм",
              onChanged: (v) => setState(() => _bakPower = v),
              onChangeEnd: (v) => _sendIfConnected("rtx_bak_power ${v.round()}"),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13.0, vertical: 6.0),
              child: RtxLinkCalculatorCard(
                title: "Оценка резервного канала",
                themeColor: Colors.greenAccent,
                currentFreqMhz: _bakFreqMhz,
                sensitivity: bakResults['sensitivity'],
                distKm: bakResults['distanceKm'],
                bitRate: bakResults['bitRate'],
                sensitivityProgress:
                    ((bakResults['sensitivity'] - (-140.0)) / 40.0).clamp(0.0, 1.0),
                bitRateProgress: (bakResults['bitRate'] / 30000.0).clamp(0.0, 1.0),
              ),
            ),
            XFireResetCard(
              hint: "Сброс локальных настроек\nрезервного канала",
              onReset: _resetBackup,
            ),
            XFireBatchApplyCard(
              hint: "Пакетная отправка резервного\nканала",
              parameters: [
                "rtx_bak_chan ${_bakChan.round()}",
                "rtx_bak_sf ${_bakSf.round()}",
                "rtx_bak_bw ${_bakBw.round()}",
                "rtx_bak_cr ${_bakCr.round()}",
                "rtx_bak_power ${_bakPower.round()}",
              ],
            ),
          ],
        ),
        DipoleAntennaBlock(
          hasProtectiveSleeve: _hasProtectiveSleeve,
          sleeveThicknessMm: _sleeveThicknessMm,
          dipoleTubeDiameterMm: _dipoleTubeDiameterMm,
          dipoleTopWireSqMm: _dipoleTopWireSqMm,
          antResults: antResults,
          onSleeveToggle: (v) => setState(() => _hasProtectiveSleeve = v),
          onSleeveThickChanged: (v) => setState(() => _sleeveThicknessMm = v),
          onTubeDiamChanged: (v) => setState(() => _dipoleTubeDiameterMm = v),
          onTopWireChanged: (v) => setState(() => _dipoleTopWireSqMm = v),
        ),
        KharchenkoAntennaBlock(
          kharchenkoWireSqMm: _kharchenkoWireSqMm,
          antResults: antResults,
          onKharcChanged: (v) => setState(() => _kharchenkoWireSqMm = v),
        ),
        XFireResetCard(
          hint: "Общий сброс всех настроек\nрадиомодуля и антенн (default)",
          onReset: _resetAllRadio,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ==========================================
// ВКЛАДКА 4: ТЕРМИНАЛ CLI
// ==========================================
class TerminalTab extends StatefulWidget {
  const TerminalTab({super.key});

  @override
  State<TerminalTab> createState() => _TerminalTabState();
}

class _TerminalTabState extends State<TerminalTab> {
  late StreamSubscription<String> _sub;
  String _displayLog = "";
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<String> _suggestions = [];

  final List<String> _cliCommands = [
    "info", "mon", "stop", "config", "save", "default", "help",
    "auto_cal", "auto_stop",
    "fm_mode", "fm_roll_max", "fm_pitch_max", "fm_vz_speed_max",
    "esc_prot", "flt_esc_limit",
    "rc_rate", "rc_super_expo", "rc_stick_expo",
    "rc_yaw_rate", "rc_yaw_super_expo", "rc_yaw_expo",
    "rc_deadband", "rc_horizon_transition", "rc_filter_smoothing",
    "flt_lpf_en", "flt_not_en", "flt_amb_en",
    "gyro_filter_alpha", "acc_filter_alpha",
    "filter_notch_freq", "filter_notch_bw",
    "flt_amb", "flt_amb_min",
    "imu_id", "imu_align",
    "baro_en", "bar_id",
    "com_en", "com_id", "com_align",
    "mag_bias_x", "mag_bias_y", "mag_bias_z",
    "lidar_en", "lid_id", "lidar_filter_alpha", "lidar_offset_m",
    "bat_scale_v", "bat_v_max", "bat_comp_en", "bat_filter_alpha",
    "bat_offset_a", "bat_scale_a", "bat_fs_v",
    "fs_bat_en", "fs_rtx_en", "fs_vz_speed",
    "roll_kp", "roll_ki", "roll_kd",
    "pitch_kp", "pitch_ki", "pitch_kd",
    "yaw_kp", "yaw_ki", "yaw_kd",
    "vz_kp", "vz_ki", "vz_kd",
    "vtx_en", "vtx_prot", "vtx_mhz", "vtx_mw",
    "cal_imu", "cal_gyro", "cal_acc", "cal_mag", "cal_bar", "cal_lid", "cal_bat", "cal_curr",
    "test_imu", "test_mag", "test_bar", "test_lid", "test_bat", "test_rtx", "test_vtx", "test_mot", "test_pid",
    "osd_en", "rx58_en", "rx58_ch",
    "vtx_ch0", "vtx_ch1", "vtx_ch2", "vtx_ch3",
    "vtx_rssi_th", "vtx_rssi_hyst", "vtx_auto_start", "vtx_btn_mode",
    "rtx_prot_id", "rtx_id", "rtx_en", "rtx_band", "rtx_hw_crc_en", "rtx_addr_en", "rtx_addr", "rtx_sync_word", "rtx_iq_inv",
    "rtx_pri_chan", "rtx_pri_sf", "rtx_pri_bw", "rtx_pri_cr", "rtx_pri_power",
    "rtx_bak_chan", "rtx_bak_sf", "rtx_bak_bw", "rtx_bak_cr", "rtx_bak_power",
  ];

  @override
  void initState() {
    super.initState();
    _displayLog = SerialService.terminalLog;
    _sub = SerialService.logController.stream.listen((log) {
      if (mounted) setState(() => _displayLog = log);
    });
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final text = _controller.text.trim();
    setState(() {
      if (text.isEmpty) {
        _suggestions = [];
      } else {
        _suggestions = _cliCommands
            .where((cmd) => cmd.toLowerCase().contains(text.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitCommand(String val) {
    final cmd = val.trim();
    if (cmd.isNotEmpty) {
      unawaited(SerialService.sendCommand(cmd));
      _controller.clear();
      setState(() => _suggestions = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: SingleChildScrollView(
                reverse: true,
                child: Text(
                  _displayLog,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Colors.greenAccent,
                    fontSize: 17,
                    height: 1.4,
                  ),
                  softWrap: true,
                ),
              ),
            ),
          ),
          if (_suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 13),
              constraints: const BoxConstraints(maxHeight: 170),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final item = _suggestions[index];
                  return InkWell(
                    onTap: () {
                      _controller.text = item;
                      _controller.selection =
                          TextSelection.fromPosition(TextPosition(offset: item.length));
                      setState(() => _suggestions = []);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14.0,
                        vertical: 11.0,
                      ),
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 17,
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                        ),
                        softWrap: true,
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: null,
                    style: const TextStyle(fontSize: 18, fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      hintText: "Enter CLI command...",
                      hintStyle: TextStyle(fontSize: 15),
                    ),
                    onSubmitted: _submitCommand,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 48,
                  width: 48,
                  child: IconButton.filled(
                    onPressed: () => unawaited(SerialService.sendCommand("info")),
                    icon: const Icon(Icons.info_outline, size: 22, color: Colors.white),
                    tooltip: "Read Config Info",
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 48,
                  width: 48,
                  child: IconButton.filled(
                    onPressed: () {
                      SerialService.terminalLog = "";
                      SerialService.appendLog("");
                    },
                    icon: const Icon(
                      Icons.cleaning_services,
                      size: 22,
                      color: Colors.white,
                    ),
                    tooltip: "Clear Log",
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  icon: const Icon(Icons.send_rounded, size: 22, color: Colors.white),
                  onPressed: () => _submitCommand(_controller.text),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
