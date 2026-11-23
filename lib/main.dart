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
    "Инфо",
    "Полетный контроллер FC",
    "Пульт RC",
    "Радиомодуль RTX (915 МГц)",
    "Профили (Калькулятор сетапа)",
    "Терминал CLI",
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
      String fileContent = await rootBundle.loadString('assets/doc.txt');
      List<DocSection> parsedSections = [];
      RegExp regExp = RegExp(r'/([^/]+)/\s*\[([^\]]*)\]', multiLine: true, dotAll: true);
      for (var match in regExp.allMatches(fileContent)) {
        String title = match.group(1)?.trim() ?? '';
        String content = match.group(2)?.trim() ?? '';
        if (title.isNotEmpty) parsedSections.add(DocSection(title: title, content: content));
      }
      if (parsedSections.isEmpty) parsedSections.add(DocSection(title: 'Справочник CLI команд', content: fileContent));
      setState(() {
        _sections = parsedSections;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _sections = [DocSection(title: 'Ошибка загрузки doc.txt', content: 'Ошибка: $e')];
        _isLoading = false;
      });
    }
  }

  List<Widget> _buildContentWidgets(String rawContent) {
    List<Widget> widgets = [];
    RegExp imgRegex = RegExp(r'\b(img\d+)\b', caseSensitive: false);
    int lastMatchEnd = 0;
    for (Match match in imgRegex.allMatches(rawContent)) {
      if (match.start > lastMatchEnd) {
        widgets.add(Text(rawContent.substring(lastMatchEnd, match.start).trim(), style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4, fontFamily: 'monospace')));
        widgets.add(const SizedBox(height: 10));
      }
      String imgTag = match.group(1)!.toLowerCase();
      widgets.add(Padding(
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
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
              child: Text("Изображение не найдено ($imgTag.jpg)", style: const TextStyle(fontSize: 11, color: Colors.amberAccent)),
            ),
          ),
        ),
      ));
      widgets.add(const SizedBox(height: 10));
      lastMatchEnd = match.end;
    }
    if (lastMatchEnd < rawContent.length) {
      widgets.add(Text(rawContent.substring(lastMatchEnd).trim(), style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4, fontFamily: 'monospace')));
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
                    const Text('XFire Ecosystem', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: const Text('v.3.27 (CLI)', style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('Аппаратно-программная экосистема для управления дронами (Моторы: 2312, Пропы: 9450, 4S, 915 МГц).', style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.4)),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          child: Text('СПРАВОЧНИК CLI КОМАНД (doc.txt)', style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        ),
        if (_isLoading)
          const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(color: Colors.blueAccent)))
        else
          ..._sections.map((sec) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 11.0, vertical: 4.0),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: ExpansionTile(
                    title: Text(sec.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                    iconColor: Colors.amberAccent,
                    collapsedIconColor: Colors.white54,
                    children: [Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _buildContentWidgets(sec.content)))],
                  ),
                ),
              )),
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

  double get _minKv => _propSize <= 6.0 ? 1500.0 : (_propSize <= 8.0 ? 1000.0 : 350.0);
  double get _maxKv => _propSize <= 6.0 ? 2800.0 : (_propSize <= 8.0 ? 1800.0 : 950.0);

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
    double ocVoltageFresh = _batteryCells * 4.2;
    double ocVoltageNominal = _batteryCells * 3.7;
    double cutoffLoadVoltagePerCell = 3.3;

    double totalWeightKg = _auwGrams / 1000.0;
    double rInt = (_totalRintMohm / 1000.0).clamp((_batteryCells * 3.0) / 1000.0, (_batteryCells * 30.0) / 1000.0);
    double etaEsc = 0.96;
    double etaMotor = 0.80;

    double pitchFactor = _propPitch / 4.5;
    double bladeFactor = _bladesCount == 2 ? 1.0 : 1.15;

    double rpmLoad = _motorKv * ocVoltageNominal * 0.80;
    double thrustPerMotorGrams = math.pow(_propSize, 3.2).toDouble() * _propPitch * math.pow(rpmLoad / 1000.0, 2.0).toDouble() * (_bladesCount == 2 ? 1.0 : 0.88) * 0.045;
    double totalThrustGrams = thrustPerMotorGrams * 4.0;
    double twr = totalThrustGrams / _auwGrams;

    double hoverThrustRatio = (_auwGrams / totalThrustGrams).clamp(0.12, 0.90);
    double hoverThrottle = (hoverThrustRatio * 100.0 * 1.18).clamp(15.0, 90.0);

    double frameRadiusM = (_frameSizeMm / 2000.0);
    double momentOfInertia = totalWeightKg * math.pow(frameRadiusM, 2).toDouble();
    double behaviorMultiplier = _behaviorIndex == 0 ? 0.8 : (_behaviorIndex == 1 ? 1.0 : 1.35);

    double specificPowerWPerKg = 130.0 * (math.pow(9.0 / _propSize, 0.85).toDouble()) * (math.pow(_motorKv / 900.0, 0.1).toDouble());
    double hoverPowerMech = totalWeightKg * specificPowerWPerKg * math.sqrt(hoverThrustRatio) * pitchFactor * bladeFactor;
    double pEscIn = hoverPowerMech / (etaMotor * etaEsc);

    double a = rInt;
    double b = -ocVoltageNominal;
    double c = pEscIn;
    double discriminant = (b * b) - (4 * a * c);

    double hoverAmps = 10.0;
    if (discriminant >= 0) {
      hoverAmps = (-b - math.sqrt(discriminant)) / (2 * a);
    } else {
      hoverAmps = ocVoltageNominal / (2 * a);
    }

    double freshLoadVoltage = ocVoltageFresh - (hoverAmps * rInt);
    double freshLoadVPerCell = freshLoadVoltage / _batteryCells;

    double loadVoltage = ocVoltageNominal - (hoverAmps * rInt);
    double loadVPerCell = loadVoltage / _batteryCells;
    double batteryThermalLossWatts = math.pow(hoverAmps, 2).toDouble() * rInt;

    double cutoffOcvPerCell = cutoffLoadVoltagePerCell + (hoverAmps * rInt / _batteryCells);
    double usableOcvSpan = (4.2 - cutoffOcvPerCell.clamp(3.5, 4.1)).clamp(0.0, 0.7);
    double usableFraction = (usableOcvSpan / 0.7).clamp(0.05, 0.88);
    double usableBatteryAh = (_batteryMah / 1000.0) * usableFraction;

    double hoverTimeMinutes = (usableBatteryAh / hoverAmps) * 60.0;

    double tiltAngleRad30 = 30.0 * math.pi / 180.0;
    double thrustMultiplier30 = 1.0 / math.cos(tiltAngleRad30);
    double powerMultiplier30 = math.pow(thrustMultiplier30, 1.5).toDouble();
    double flightAmps30 = hoverAmps * powerMultiplier30;
    double dynamicFlightMinutes = (usableBatteryAh / flightAmps30) * 60.0 * 0.90;

    double tiltRad = _calcMaxTilt * math.pi / 180.0;
    double maxTiltAmps = hoverAmps * math.pow(1.0 / math.cos(tiltRad), 1.5).toDouble();
    double maxTiltVoltage = ocVoltageNominal - (maxTiltAmps * rInt);

    double climbPowerMech = totalWeightKg * 9.81 * _calcMaxVz;
    double totalClimbEscPower = pEscIn + (climbPowerMech / (etaMotor * etaEsc));
    double aClimb = rInt, bClimb = -ocVoltageNominal, cClimb = totalClimbEscPower;
    double discClimb = (bClimb * bClimb) - (4 * aClimb * cClimb);
    double maxVzAmps = hoverAmps * 1.6;
    if (discClimb >= 0) maxVzAmps = (-bClimb - math.sqrt(discClimb)) / (2 * aClimb);
    double maxVzVoltage = ocVoltageNominal - (maxVzAmps * rInt);

    double baseKp = (0.25 * (momentOfInertia / 0.02) * (4.0 / twr)).clamp(0.20, 1.20);
    double baseKi = 0.010;
    double baseKd = (baseKp * 0.035).clamp(0.005, 0.050);

    double rollPitchKp = double.parse((baseKp * behaviorMultiplier).toStringAsFixed(3));
    double rollPitchKd = double.parse((baseKd * behaviorMultiplier).toStringAsFixed(3));
    double yawKp = (rollPitchKp * 1.2).clamp(0.3, 1.5);
    double yawKd = (rollPitchKd * 0.4).clamp(0.0, 0.025);

    double rcRate = _behaviorIndex == 0 ? 0.25 : (_behaviorIndex == 1 ? 0.38 : 0.55);
    double superExpo = _behaviorIndex == 0 ? 0.02 : (_behaviorIndex == 1 ? 0.04 : 0.08);

    double maxRps = (_motorKv * loadVoltage) / 60.0;
    double bladePassFreq = maxRps * _bladesCount;
    double notchFreq = (bladePassFreq * 0.75).clamp(70.0, 220.0);

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

    double minRint = _batteryCells * 3.0;
    double maxRint = _batteryCells * 30.0;
    if (_totalRintMohm < minRint) _totalRintMohm = minRint;
    if (_totalRintMohm > maxRint) _totalRintMohm = maxRint;

    var optimal = calculateOptimalSettings();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      children: [
        XFireExpansionCard(
          title: "Калькулятор сетапа и полета",
          subtitle: "Расчет PID, просадки с 4.2В до 3.3В и времени полета",
          icon: Icons.tune_rounded,
          children: [
            XFireSliderCard(title: "Размер пропеллера", commandName: "prop_size_inch", value: _propSize, min: 5.0, max: 13.0, divisions: 8, unit: "\"", onChanged: (v) => setState(() => _propSize = v), onChangeEnd: (_) {}),
            XFireSliderCard(title: "Шаг пропеллера", commandName: "prop_pitch_inch", value: _propPitch, min: _minPitch, max: _maxPitch, divisions: ((_maxPitch - _minPitch) * 10).round(), unit: "\"", onChanged: (v) => setState(() => _propPitch = v), onChangeEnd: (_) {}),
            XFireSegmentedCard(title: "Количество лопастей пропа", commandName: "prop_blades", options: const ["2 лопасти", "3 лопасти"], selectedIndex: _bladesCount == 2 ? 0 : 1, onSelected: (val) => setState(() => _bladesCount = val == 0 ? 2.0 : 3.0)),
            XFireSliderCard(title: "KV двигателя", commandName: "motor_kv", value: _motorKv, min: _minKv, max: _maxKv, divisions: 50, unit: "KV", onChanged: (v) => setState(() => _motorKv = v), onChangeEnd: (_) {}),
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
                  double newMin = _batteryCells * 3.0;
                  double newMax = _batteryCells * 30.0;
                  _totalRintMohm = _totalRintMohm.clamp(newMin, newMax);
                });
              },
              onChangeEnd: (_) {},
            ),
            XFireSliderCard(
              title: "Внутреннее сопротивление батареи (3-30 мОм/банку)",
              commandName: "bat_rint_mohm",
              value: _totalRintMohm,
              min: minRint,
              max: maxRint,
              divisions: (maxRint - minRint).round().clamp(1, 200),
              unit: "мОм",
              onChanged: (v) => setState(() => _totalRintMohm = v),
              onChangeEnd: (_) {},
            ),
            XFireSliderCard(title: "Максимальный угол наклона (fl_roll_max)", commandName: "fl_roll_max", value: _calcMaxTilt, min: 10.0, max: 75.0, divisions: 13, unit: "°", onChanged: (v) => setState(() => _calcMaxTilt = v), onChangeEnd: (_) {}),
            XFireSliderCard(title: "Максимальная вертикальная скорость (fl_vz_speed_max)", commandName: "fl_vz_speed_max", value: _calcMaxVz, min: 0.5, max: 3.0, divisions: 25, unit: "м/с", onChanged: (v) => setState(() => _calcMaxVz = v), onChangeEnd: (_) {}),
            XFireSliderCard(title: "Взлетный вес дрона (AUW)", commandName: "auw_grams", value: _auwGrams, min: 400.0, max: 3500.0, divisions: 62, unit: "г", onChanged: (v) => setState(() => _auwGrams = v), onChangeEnd: (_) {}),
            XFireSliderCard(title: "Емкость аккумулятора", commandName: "battery_mah", value: _batteryMah, min: 1300.0, max: 16000.0, divisions: 58, unit: "mAh", onChanged: (v) => setState(() => _batteryMah = v), onChangeEnd: (_) {}),
            XFireSliderCard(title: "Диагональ рамы (от мотора до мотора)", commandName: "frame_size_mm", value: _frameSizeMm, min: 220.0, max: 650.0, divisions: 43, unit: "мм", onChanged: (v) => setState(() => _frameSizeMm = v), onChangeEnd: (_) {}),
            XFireSegmentedCard(title: "Характер поведения дрона", commandName: "drone_behavior", options: const ["Плавное", "Уверенное", "Резвое"], selectedIndex: _behaviorIndex, onSelected: (val) => setState(() => _behaviorIndex = val)),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13.0, vertical: 4.0),
          child: Container(
            padding: const EdgeInsets.all(14.0),
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
                        "ФИЗИЧЕСКИЙ РАСЧЕТ И НАГРУЗКИ (v.3.27)",
                        style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.insights, color: Colors.amberAccent, size: 16),
                  ],
                ),
                const SizedBox(height: 12),
                _calcResultRow("Тяговооруженность (TWR):", "${optimal['twr']} : 1", Colors.white),
                _calcResultRow("Газ висения (Hover Throttle):", "${optimal['hover_throttle']} %", optimal['color_hover_throttle']),
                _calcResultRow("Сопротивление батареи (суммарное):", "${optimal['total_rint_mohm']} мОм (${(_totalRintMohm / _batteryCells).toStringAsFixed(1)} мОм/банку)", Colors.white),
                const Divider(color: Colors.white12, height: 16),
                _calcResultRow("Ток висения (суммарный):", "${optimal['hover_amps']} А", optimal['color_hover_amps']),
                _calcResultRow("Напряжение свежего аккума (4.2В) под нагрузкой:", "${optimal['fresh_load_voltage']} В (${optimal['fresh_load_v_cell']} В/б)", optimal['color_fresh_voltage']),
                _calcResultRow("Напряжение под нагрузкой (на плато 3.7В):", "${optimal['load_voltage']} В", optimal['color_load_voltage']),
                _calcResultRow("Тепловые потери батареи (висение):", "${optimal['bat_thermal_loss']} Вт", Colors.white),
                const Divider(color: Colors.white12, height: 16),
                _calcResultRow("Ток при макс. наклоне (${_calcMaxTilt.toStringAsFixed(0)}°):", "${optimal['max_tilt_amps']} А", Colors.white),
                _calcResultRow("Напряжение при макс. наклоне:", "${optimal['max_tilt_voltage']} В", Colors.white),
                _calcResultRow("Ток при макс. взлете (${_calcMaxVz.toStringAsFixed(1)} м/с):", "${optimal['max_vz_amps']} А", Colors.white),
                _calcResultRow("Напряжение при макс. взлете:", "${optimal['max_vz_voltage']} В", Colors.white),
                const Divider(color: Colors.white12, height: 16),
                _calcResultRow("Время висения (до отсечки 3.3В под нагрузкой):", "${optimal['flight_time']} мин", optimal['color_flight_time']),
                _calcResultRow("Время в полете (наклон 30° + взлеты):", "${optimal['flight_time_30deg']} мин", optimal['color_flight_time_30']),
                const Divider(color: Colors.white12, height: 16),
                _calcResultRow("Roll/Pitch Kp / Ki / Kd (от инерции):", "${optimal['roll_kp']} / ${optimal['roll_ki']} / ${optimal['roll_kd']}", Colors.white),
                _calcResultRow("Yaw Kp / Ki / Kd:", "${optimal['yaw_kp']} / ${optimal['yaw_ki']} / ${optimal['yaw_kd']}", Colors.white),
                _calcResultRow("RC Rate / Super Expo:", "${optimal['rc_rate']} / ${optimal['rc_super_expo']}", Colors.white),
                _calcResultRow("Notch (от BPF винта):", "${optimal['filter_notch_freq']} Гц", Colors.white),
              ],
            ),
          ),
        ),
        XFireResetCard(
          hint: "Сброс калькулятора сетапа и полета",
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
          hint: "Применение рассчитанных PID и лимитов к контроллеру",
          parameters: [
            "fl_roll_max $_calcMaxTilt",
            "fl_pitch_max $_calcMaxTilt",
            "fl_vz_speed_max $_calcMaxVz",
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
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color, fontFamily: 'monospace')),
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
  // 1. Аппаратура, датчики и калибровка
  double _escProtocol = 0;
  double _imuAlign = 0;
  double _comAlign = 0;
  double _imuId = 0;
  double _barId = 0;
  double _comId = 0;
  double _lidId = 0;
  double _baroEn = 1;
  double _comEn = 0;
  double _lidarEn = 1;
  double _lidarFilterAlpha = 0.15;
  double _lidarOffsetM = 0.0;
  double _magBiasX = 0.0;
  double _magBiasY = 0.0;
  double _magBiasZ = 0.0;

  // 2. Питание и датчик тока
  double _batVoltageScale = 4.85;
  double _batFilterAlpha = 0.05;
  double _currZeroOffsetA = 0.0;
  double _currScale = 1.0;

  // 3. Режимы полёта и кривые стиков (RC)
  double _flMode = 1;
  double _flRollMax = 25.0;
  double _flPitchMax = 25.0;
  double _flVzSpeedMax = 1.2;
  double _rcRate = 0.35;
  double _rcSuperExpo = 0.03;
  double _rcStickExpo = 0.45;
  double _rcYawRate = 0.30;
  double _rcYawSuperExpo = 0.03;
  double _rcYawExpo = 0.35;
  double _rcDeadband = 15.0;
  double _rcHorizonTransition = 0.75;
  double _rcFilterSmoothing = 0.35;

  // 4. Failsafe
  double _fsBatEn = 1;
  double _fsRtxEn = 1;
  double _fsVzSpeed = 0.5;
  double _batFsV = 13.8;

  // 5. Фильтры (LPF, Notch, Madgwick)
  double _filAmbEn = 1;
  double _filLpfEn = 1;
  double _filNotEn = 1;
  double _gyroFilterAlpha = 0.10;
  double _accFilterAlpha = 0.10;
  double _filterNotchFreq = 120.0;
  double _filterNotchBw = 20.0;
  double _filAmb = 0.05;
  double _filAmbMin = 0.003;

  // 6. ПИД-коэффициенты (Roll, Pitch, Yaw, Vz)
  double _rollKp = 0.45, _rollKi = 0.010, _rollKd = 0.018;
  double _pitchKp = 0.45, _pitchKi = 0.010, _pitchKd = 0.018;
  double _yawKp = 0.60, _yawKi = 0.010, _yawKd = 0.0;
  double _vzKp = 7.0, _vzKi = 1.2, _vzKd = 0.30;

  @override
  void initState() {
    super.initState();
    SerialService.sendCommand("mon");
  }

  @override
  void dispose() {
    SerialService.sendCommand("stop");
    super.dispose();
  }

  void _resetHardwareGroup() {
    setState(() {
      _escProtocol = 0;
      _imuAlign = 0;
      _comAlign = 0;
      _imuId = 0;
      _barId = 0;
      _comId = 0;
      _lidId = 0;
      _baroEn = 1;
      _comEn = 0;
      _lidarEn = 1;
      _lidarFilterAlpha = 0.15;
      _lidarOffsetM = 0.0;
      _magBiasX = 0.0;
      _magBiasY = 0.0;
      _magBiasZ = 0.0;
    });
    SerialService.sendCommand("default hw");
  }

  void _resetPowerGroup() {
    setState(() {
      _batVoltageScale = 4.85;
      _batFilterAlpha = 0.05;
      _currZeroOffsetA = 0.0;
      _currScale = 1.0;
    });
    SerialService.sendCommand("default bat");
  }

  void _resetFlightRcGroup() {
    setState(() {
      _flMode = 1;
      _flRollMax = 25.0;
      _flPitchMax = 25.0;
      _flVzSpeedMax = 1.2;
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
    SerialService.sendCommand("default fl");
  }

  void _resetFailsafeGroup() {
    setState(() {
      _fsBatEn = 1;
      _fsRtxEn = 1;
      _fsVzSpeed = 0.5;
      _batFsV = 13.8;
    });
    SerialService.sendCommand("default fs");
  }

  void _resetFiltersGroup() {
    setState(() {
      _filAmbEn = 1;
      _filLpfEn = 1;
      _filNotEn = 1;
      _gyroFilterAlpha = 0.10;
      _accFilterAlpha = 0.10;
      _filterNotchFreq = 120.0;
      _filterNotchBw = 20.0;
      _filAmb = 0.05;
      _filAmbMin = 0.003;
    });
    SerialService.sendCommand("default fil");
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
    SerialService.sendCommand("default pid");
  }

  void _resetAllFcSettings() {
    _resetHardwareGroup();
    _resetPowerGroup();
    _resetFlightRcGroup();
    _resetFailsafeGroup();
    _resetFiltersGroup();
    _resetPidGroup();
    SerialService.sendCommand("default");
    showAppDialog(context, "Общий сброс FC", "Все настройки полётного контроллера сброшены по умолчанию.");
  }

  Widget _buildSensorBar(String label, double value, double min, double max, String unit, Color color) {
    double percent = ((value - min) / (max - min)).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
              Text("${value.toStringAsFixed(2)} $unit", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 2),
          LinearProgressIndicator(value: percent, color: color, backgroundColor: Colors.white12, minHeight: 5, borderRadius: BorderRadius.circular(3)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      children: [
        // 1. Аппаратура, датчики и калибровка
        XFireExpansionCard(
          title: "Аппаратура, датчики и калибровка",
          subtitle: "ESC, ориентация IMU/компаса, ID датчиков, лидар и смещения",
          icon: Icons.sensors,
          children: [
            XFireSegmentedCard(
              title: "Протокол ESC",
              commandName: "esc_protocol",
              options: const ["PWM", "Oneshot125"],
              selectedIndex: _escProtocol.round().clamp(0, 1),
              onSelected: (val) {
                setState(() => _escProtocol = val.toDouble());
                SerialService.sendCommand("esc_protocol $val");
              },
            ),
            XFireSegmentedCard(
              title: "Поворот XY осей IMU",
              commandName: "imu_align",
              options: const ["0°", "90°", "180°", "270°"],
              selectedIndex: _imuAlign.round().clamp(0, 3),
              onSelected: (val) {
                setState(() => _imuAlign = val.toDouble());
                SerialService.sendCommand("imu_align $val");
              },
            ),
            XFireSegmentedCard(
              title: "Поворот XY осей компаса",
              commandName: "com_align",
              options: const ["0°", "90°", "180°", "270°"],
              selectedIndex: _comAlign.round().clamp(0, 3),
              onSelected: (val) {
                setState(() => _comAlign = val.toDouble());
                SerialService.sendCommand("com_align $val");
              },
            ),
            XFireSliderCard(
              title: "Тип IMU (0-авто, 1-MPU6050..6-QMI8658)",
              commandName: "imu_id",
              value: _imuId,
              min: 0,
              max: 6,
              divisions: 6,
              unit: "ID",
              onChanged: (v) => setState(() => _imuId = v),
              onChangeEnd: (v) => SerialService.sendCommand("imu_id ${v.round()}"),
            ),
            XFireSliderCard(
              title: "Тип барометра (0-авто..7-DPS310)",
              commandName: "bar_id",
              value: _barId,
              min: 0,
              max: 7,
              divisions: 7,
              unit: "ID",
              onChanged: (v) => setState(() => _barId = v),
              onChangeEnd: (v) => SerialService.sendCommand("bar_id ${v.round()}"),
            ),
            XFireSliderCard(
              title: "Тип компаса (0-авто..6-AK09911)",
              commandName: "com_id",
              value: _comId,
              min: 0,
              max: 6,
              divisions: 6,
              unit: "ID",
              onChanged: (v) => setState(() => _comId = v),
              onChangeEnd: (v) => SerialService.sendCommand("com_id ${v.round()}"),
            ),
            XFireSliderCard(
              title: "Тип лидара (0-авто..4-VL53L4CX)",
              commandName: "lid_id",
              value: _lidId,
              min: 0,
              max: 4,
              divisions: 4,
              unit: "ID",
              onChanged: (v) => setState(() => _lidId = v),
              onChangeEnd: (v) => SerialService.sendCommand("lid_id ${v.round()}"),
            ),
            XFireSwitchCard(
              title: "Включение опроса барометра",
              commandName: "baro_en",
              value: _baroEn == 1,
              onChanged: (v) {
                setState(() => _baroEn = v ? 1.0 : 0.0);
                SerialService.sendCommand("baro_en ${_baroEn.round()}");
              },
            ),
            XFireSwitchCard(
              title: "Включение опроса компаса",
              commandName: "com_en",
              value: _comEn == 1,
              onChanged: (v) {
                setState(() => _comEn = v ? 1.0 : 0.0);
                SerialService.sendCommand("com_en ${_comEn.round()}");
              },
            ),
            XFireSwitchCard(
              title: "Включение опроса лидара",
              commandName: "lidar_en",
              value: _lidarEn == 1,
              onChanged: (v) {
                setState(() => _lidarEn = v ? 1.0 : 0.0);
                SerialService.sendCommand("lidar_en ${_lidarEn.round()}");
              },
            ),
            XFireSliderCard(
              title: "Сглаживание лидара (медиана + EMA)",
              commandName: "lidar_filter_alpha",
              value: _lidarFilterAlpha,
              min: 0.01,
              max: 1.0,
              divisions: 99,
              unit: "",
              onChanged: (v) => setState(() => _lidarFilterAlpha = v),
              onChangeEnd: (v) => SerialService.sendCommand("lidar_filter_alpha $v"),
            ),
            XFireSliderCard(
              title: "Смещение высоты лидара",
              commandName: "lidar_offset_m",
              value: _lidarOffsetM,
              min: -1.0,
              max: 1.0,
              divisions: 200,
              unit: "м",
              onChanged: (v) => setState(() => _lidarOffsetM = v),
              onChangeEnd: (v) => SerialService.sendCommand("lidar_offset_m $v"),
            ),
            XFireSliderCard(
              title: "Смещение компаса X",
              commandName: "mag_bias_x",
              value: _magBiasX,
              min: -200.0,
              max: 200.0,
              divisions: 400,
              unit: "мкТл",
              onChanged: (v) => setState(() => _magBiasX = v),
              onChangeEnd: (v) => SerialService.sendCommand("mag_bias_x $v"),
            ),
            XFireSliderCard(
              title: "Смещение компаса Y",
              commandName: "mag_bias_y",
              value: _magBiasY,
              min: -200.0,
              max: 200.0,
              divisions: 400,
              unit: "мкТл",
              onChanged: (v) => setState(() => _magBiasY = v),
              onChangeEnd: (v) => SerialService.sendCommand("mag_bias_y $v"),
            ),
            XFireSliderCard(
              title: "Смещение компаса Z",
              commandName: "mag_bias_z",
              value: _magBiasZ,
              min: -200.0,
              max: 200.0,
              divisions: 400,
              unit: "мкТл",
              onChanged: (v) => setState(() => _magBiasZ = v),
              onChangeEnd: (v) => SerialService.sendCommand("mag_bias_z $v"),
            ),
            XFireResetCard(hint: "Сброс группы аппаратуры (default hw)", onReset: _resetHardwareGroup),
            XFireBatchApplyCard(
              hint: "Пакетная отправка аппаратуры и смещений датчиков",
              parameters: [
                "esc_protocol ${_escProtocol.round()}",
                "imu_align ${_imuAlign.round()}",
                "com_align ${_comAlign.round()}",
                "imu_id ${_imuId.round()}",
                "bar_id ${_barId.round()}",
                "com_id ${_comId.round()}",
                "lid_id ${_lidId.round()}",
                "baro_en ${_baroEn.round()}",
                "com_en ${_comEn.round()}",
                "lidar_en ${_lidarEn.round()}",
                "lidar_filter_alpha $_lidarFilterAlpha",
                "lidar_offset_m $_lidarOffsetM",
                "mag_bias_x $_magBiasX",
                "mag_bias_y $_magBiasY",
                "mag_bias_z $_magBiasZ",
              ],
            ),
          ],
        ),

        // 2. Питание и датчик тока
        XFireExpansionCard(
          title: "Питание и датчик тока",
          subtitle: "Делитель напряжения (PA4) и шунт тока 0.01 Ом (PA5)",
          icon: Icons.battery_charging_full,
          children: [
            XFireSliderCard(
              title: "Масштаб делителя напряжения (PA4)",
              commandName: "bat_voltage_scale",
              value: _batVoltageScale,
              min: 1.0,
              max: 15.0,
              divisions: 280,
              unit: "",
              onChanged: (v) => setState(() => _batVoltageScale = v),
              onChangeEnd: (v) => SerialService.sendCommand("bat_voltage_scale $v"),
            ),
            XFireSliderCard(
              title: "LPF фильтрация напряжения батареи",
              commandName: "bat_filter_alpha",
              value: _batFilterAlpha,
              min: 0.01,
              max: 1.0,
              divisions: 99,
              unit: "",
              onChanged: (v) => setState(() => _batFilterAlpha = v),
              onChangeEnd: (v) => SerialService.sendCommand("bat_filter_alpha $v"),
            ),
            XFireSliderCard(
              title: "Ток покоя / смещение нуля (PA5)",
              commandName: "curr_zero_offset_a",
              value: _currZeroOffsetA,
              min: -10.0,
              max: 10.0,
              divisions: 400,
              unit: "А",
              onChanged: (v) => setState(() => _currZeroOffsetA = v),
              onChangeEnd: (v) => SerialService.sendCommand("curr_zero_offset_a $v"),
            ),
            XFireSliderCard(
              title: "Калибровочный множитель тока (>=0.01)",
              commandName: "curr_scale",
              value: _currScale,
              min: 0.01,
              max: 5.0,
              divisions: 499,
              unit: "",
              onChanged: (v) => setState(() => _currScale = v),
              onChangeEnd: (v) => SerialService.sendCommand("curr_scale $v"),
            ),
            XFireResetCard(hint: "Сброс питания и тока (default bat)", onReset: _resetPowerGroup),
            XFireBatchApplyCard(
              hint: "Пакетная отправка параметров питания и тока",
              parameters: [
                "bat_voltage_scale $_batVoltageScale",
                "bat_filter_alpha $_batFilterAlpha",
                "curr_zero_offset_a $_currZeroOffsetA",
                "curr_scale $_currScale",
              ],
            ),
          ],
        ),

        // 3. Режимы полёта и кривые стиков (RC)
        XFireExpansionCard(
          title: "Режимы полёта и кривые стиков (RC)",
          subtitle: "Acro/Angle/Horizon, углы, Vz и кривые RC",
          icon: Icons.flight,
          children: [
            XFireSegmentedCard(
              title: "Режим полёта (1-Angle, 2-Horizon, иначе Rate)",
              commandName: "fl_mode",
              options: const ["0 (Rate)", "1 (Angle)", "2 (Horizon)", "3 (Rate)"],
              selectedIndex: _flMode.round().clamp(0, 3),
              onSelected: (val) {
                setState(() => _flMode = val.toDouble());
                SerialService.sendCommand("fl_mode $val");
              },
            ),
            XFireSliderCard(title: "Макс. угол крена (Roll)", commandName: "fl_roll_max", value: _flRollMax, min: 5.0, max: 80.0, divisions: 150, unit: "°", onChanged: (v) => setState(() => _flRollMax = v), onChangeEnd: (v) => SerialService.sendCommand("fl_roll_max $v")),
            XFireSliderCard(title: "Макс. угол тангажа (Pitch)", commandName: "fl_pitch_max", value: _flPitchMax, min: 5.0, max: 80.0, divisions: 150, unit: "°", onChanged: (v) => setState(() => _flPitchMax = v), onChangeEnd: (v) => SerialService.sendCommand("fl_pitch_max $v")),
            XFireSliderCard(title: "Макс. вертикальная скорость", commandName: "fl_vz_speed_max", value: _flVzSpeedMax, min: 0.2, max: 5.0, divisions: 48, unit: "м/с", onChanged: (v) => setState(() => _flVzSpeedMax = v), onChangeEnd: (v) => SerialService.sendCommand("fl_vz_speed_max $v")),
            XFireSliderCard(title: "RC Rate (Roll/Pitch)", commandName: "rc_rate", value: _rcRate, min: 0.05, max: 2.0, divisions: 195, unit: "", onChanged: (v) => setState(() => _rcRate = v), onChangeEnd: (v) => SerialService.sendCommand("rc_rate $v")),
            XFireSliderCard(title: "RC Super Expo (Roll/Pitch)", commandName: "rc_super_expo", value: _rcSuperExpo, min: 0.0, max: 0.9, divisions: 90, unit: "", onChanged: (v) => setState(() => _rcSuperExpo = v), onChangeEnd: (v) => SerialService.sendCommand("rc_super_expo $v")),
            XFireSliderCard(title: "RC Stick Expo (Roll/Pitch)", commandName: "rc_stick_expo", value: _rcStickExpo, min: 0.0, max: 1.0, divisions: 100, unit: "", onChanged: (v) => setState(() => _rcStickExpo = v), onChangeEnd: (v) => SerialService.sendCommand("rc_stick_expo $v")),
            XFireSliderCard(title: "Yaw Rate", commandName: "rc_yaw_rate", value: _rcYawRate, min: 0.05, max: 2.0, divisions: 195, unit: "", onChanged: (v) => setState(() => _rcYawRate = v), onChangeEnd: (v) => SerialService.sendCommand("rc_yaw_rate $v")),
            XFireSliderCard(title: "Yaw Super Expo", commandName: "rc_yaw_super_expo", value: _rcYawSuperExpo, min: 0.0, max: 0.9, divisions: 90, unit: "", onChanged: (v) => setState(() => _rcYawSuperExpo = v), onChangeEnd: (v) => SerialService.sendCommand("rc_yaw_super_expo $v")),
            XFireSliderCard(title: "Yaw Expo", commandName: "rc_yaw_expo", value: _rcYawExpo, min: 0.0, max: 1.0, divisions: 100, unit: "", onChanged: (v) => setState(() => _rcYawExpo = v), onChangeEnd: (v) => SerialService.sendCommand("rc_yaw_expo $v")),
            XFireSliderCard(title: "Мёртвая зона вокруг центра (500.0)", commandName: "rc_deadband", value: _rcDeadband, min: 0.0, max: 100.0, divisions: 100, unit: "", onChanged: (v) => setState(() => _rcDeadband = v), onChangeEnd: (v) => SerialService.sendCommand("rc_deadband $v")),
            XFireSliderCard(title: "Порог перехода Horizon", commandName: "rc_horizon_transition", value: _rcHorizonTransition, min: 0.0, max: 1.0, divisions: 100, unit: "", onChanged: (v) => setState(() => _rcHorizonTransition = v), onChangeEnd: (v) => SerialService.sendCommand("rc_horizon_transition $v")),
            XFireSliderCard(title: "Сглаживание стиков (0.01..1.0)", commandName: "rc_filter_smoothing", value: _rcFilterSmoothing, min: 0.01, max: 1.0, divisions: 99, unit: "", onChanged: (v) => setState(() => _rcFilterSmoothing = v), onChangeEnd: (v) => SerialService.sendCommand("rc_filter_smoothing $v")),
            XFireResetCard(hint: "Сброс режимов полёта и RC (default fl)", onReset: _resetFlightRcGroup),
            XFireBatchApplyCard(
              hint: "Пакетная отправка режимов полёта и кривых RC",
              parameters: [
                "fl_mode ${_flMode.round()}",
                "fl_roll_max $_flRollMax",
                "fl_pitch_max $_flPitchMax",
                "fl_vz_speed_max $_flVzSpeedMax",
                "rc_rate $_rcRate",
                "rc_super_expo $_rcSuperExpo",
                "rc_stick_expo $_rcStickExpo",
                "rc_yaw_rate $_rcYawRate",
                "rc_yaw_super_expo $_rcYawSuperExpo",
                "rc_yaw_expo $_rcYawExpo",
                "rc_deadband $_rcDeadband",
                "rc_horizon_transition $_rcHorizonTransition",
                "rc_filter_smoothing $_rcFilterSmoothing",
              ],
            ),
          ],
        ),

        // 4. Failsafe
        XFireExpansionCard(
          title: "Failsafe",
          subtitle: "Порог батареи, потеря пакетов RC и скорость снижения",
          icon: Icons.warning_amber_rounded,
          children: [
            XFireSwitchCard(
              title: "Failsafe по низкому напряжению батареи",
              commandName: "fs_bat_en",
              value: _fsBatEn == 1,
              onChanged: (v) {
                setState(() => _fsBatEn = v ? 1.0 : 0.0);
                SerialService.sendCommand("fs_bat_en ${_fsBatEn.round()}");
              },
            ),
            XFireSwitchCard(
              title: "Failsafe при потере пакетов RC",
              commandName: "fs_rtx_en",
              value: _fsRtxEn == 1,
              onChanged: (v) {
                setState(() => _fsRtxEn = v ? 1.0 : 0.0);
                SerialService.sendCommand("fs_rtx_en ${_fsRtxEn.round()}");
              },
            ),
            XFireSliderCard(
              title: "Скорость снижения при failsafe",
              commandName: "fs_vz_speed",
              value: _fsVzSpeed,
              min: 0.1,
              max: 3.0,
              divisions: 29,
              unit: "м/с",
              onChanged: (v) => setState(() => _fsVzSpeed = v),
              onChangeEnd: (v) => SerialService.sendCommand("fs_vz_speed $v"),
            ),
            XFireSliderCard(
              title: "Порог напряжения батареи для failsafe",
              commandName: "bat_fs_v",
              value: _batFsV,
              min: 6.0,
              max: 25.0,
              divisions: 190,
              unit: "В",
              onChanged: (v) => setState(() => _batFsV = v),
              onChangeEnd: (v) => SerialService.sendCommand("bat_fs_v $v"),
            ),
            XFireResetCard(hint: "Сброс настроек failsafe (default fs)", onReset: _resetFailsafeGroup),
            XFireBatchApplyCard(
              hint: "Пакетная отправка настроек failsafe",
              parameters: [
                "fs_bat_en ${_fsBatEn.round()}",
                "fs_rtx_en ${_fsRtxEn.round()}",
                "fs_vz_speed $_fsVzSpeed",
                "bat_fs_v $_batFsV",
              ],
            ),
          ],
        ),

        // 5. Фильтры (LPF, Notch, Madgwick)
        XFireExpansionCard(
          title: "Фильтры (LPF, Notch, Madgwick)",
          subtitle: "LPF, Biquad Notch и адаптивный beta Madgwick",
          icon: Icons.waves,
          children: [
            XFireSwitchCard(
              title: "Адаптивный beta Madgwick по вибрациям",
              commandName: "fil_amb_en",
              value: _filAmbEn == 1,
              onChanged: (v) {
                setState(() => _filAmbEn = v ? 1.0 : 0.0);
                SerialService.sendCommand("fil_amb_en ${_filAmbEn.round()}");
              },
            ),
            XFireSwitchCard(
              title: "Включение LPF (гироскоп и акселерометр)",
              commandName: "fil_lpf_en",
              value: _filLpfEn == 1,
              onChanged: (v) {
                setState(() => _filLpfEn = v ? 1.0 : 0.0);
                SerialService.sendCommand("fil_lpf_en ${_filLpfEn.round()}");
              },
            ),
            XFireSwitchCard(
              title: "Включение Biquad Notch по осям гироскопа",
              commandName: "fil_not_en",
              value: _filNotEn == 1,
              onChanged: (v) {
                setState(() => _filNotEn = v ? 1.0 : 0.0);
                SerialService.sendCommand("fil_not_en ${_filNotEn.round()}");
              },
            ),
            XFireSliderCard(title: "Альфа LPF гироскопа (0.03..0.35 авто)", commandName: "gyro_filter_alpha", value: _gyroFilterAlpha, min: 0.01, max: 1.0, divisions: 99, unit: "", onChanged: (v) => setState(() => _gyroFilterAlpha = v), onChangeEnd: (v) => SerialService.sendCommand("gyro_filter_alpha $v")),
            XFireSliderCard(title: "Альфа LPF акселерометра (0.03..0.35 авто)", commandName: "acc_filter_alpha", value: _accFilterAlpha, min: 0.01, max: 1.0, divisions: 99, unit: "", onChanged: (v) => setState(() => _accFilterAlpha = v), onChangeEnd: (v) => SerialService.sendCommand("acc_filter_alpha $v")),
            XFireSliderCard(title: "Центральная частота Notch (70..220 Гц авто)", commandName: "filter_notch_freq", value: _filterNotchFreq, min: 20.0, max: 400.0, divisions: 380, unit: "Гц", onChanged: (v) => setState(() => _filterNotchFreq = v), onChangeEnd: (v) => SerialService.sendCommand("filter_notch_freq $v")),
            XFireSliderCard(title: "Полоса Notch фильтра", commandName: "filter_notch_bw", value: _filterNotchBw, min: 2.0, max: 100.0, divisions: 98, unit: "Гц", onChanged: (v) => setState(() => _filterNotchBw = v), onChangeEnd: (v) => SerialService.sendCommand("filter_notch_bw $v")),
            XFireSliderCard(title: "Базовый beta Madgwick (0.001..1.0)", commandName: "fil_amb", value: _filAmb, min: 0.001, max: 1.0, divisions: 999, unit: "", onChanged: (v) => setState(() => _filAmb = v), onChangeEnd: (v) => SerialService.sendCommand("fil_amb $v")),
            XFireSliderCard(title: "Мин. beta Madgwick (0.0005..fil_amb)", commandName: "fil_amb_min", value: _filAmbMin, min: 0.0005, max: 0.2, divisions: 399, unit: "", onChanged: (v) => setState(() => _filAmbMin = v), onChangeEnd: (v) => SerialService.sendCommand("fil_amb_min $v")),
            XFireResetCard(hint: "Сброс фильтров (default fil)", onReset: _resetFiltersGroup),
            XFireBatchApplyCard(
              hint: "Пакетная отправка настроек фильтров",
              parameters: [
                "fil_amb_en ${_filAmbEn.round()}",
                "fil_lpf_en ${_filLpfEn.round()}",
                "fil_not_en ${_filNotEn.round()}",
                "gyro_filter_alpha $_gyroFilterAlpha",
                "acc_filter_alpha $_accFilterAlpha",
                "filter_notch_freq $_filterNotchFreq",
                "filter_notch_bw $_filterNotchBw",
                "fil_amb $_filAmb",
                "fil_amb_min $_filAmbMin",
              ],
            ),
          ],
        ),

        // 6. ПИД-коэффициенты (Roll, Pitch, Yaw, Vz)
        XFireExpansionCard(
          title: "ПИД-коэффициенты (Roll, Pitch, Yaw, Vz)",
          subtitle: "Настройки Kp, Ki, Kd для осей Roll, Pitch, Yaw и Vz",
          icon: Icons.tune,
          children: [
            PidAxisCardWidget(
              axisName: "Roll Axis (Rate)",
              kpCmd: "roll_kp",
              kiCmd: "roll_ki",
              kdCmd: "roll_kd",
              kp: _rollKp,
              ki: _rollKi,
              kd: _rollKd,
              onUpdate: (p, i, d) {
                setState(() {
                  _rollKp = p;
                  _rollKi = i;
                  _rollKd = d;
                });
                SerialService.sendCommand("roll_kp $p");
                SerialService.sendCommand("roll_ki $i");
                SerialService.sendCommand("roll_kd $d");
              },
            ),
            PidAxisCardWidget(
              axisName: "Pitch Axis (Rate)",
              kpCmd: "pitch_kp",
              kiCmd: "pitch_ki",
              kdCmd: "pitch_kd",
              kp: _pitchKp,
              ki: _pitchKi,
              kd: _pitchKd,
              onUpdate: (p, i, d) {
                setState(() {
                  _pitchKp = p;
                  _pitchKi = i;
                  _pitchKd = d;
                });
                SerialService.sendCommand("pitch_kp $p");
                SerialService.sendCommand("pitch_ki $i");
                SerialService.sendCommand("pitch_kd $d");
              },
            ),
            PidAxisCardWidget(
              axisName: "Yaw Axis (Rate)",
              kpCmd: "yaw_kp",
              kiCmd: "yaw_ki",
              kdCmd: "yaw_kd",
              kp: _yawKp,
              ki: _yawKi,
              kd: _yawKd,
              onUpdate: (p, i, d) {
                setState(() {
                  _yawKp = p;
                  _yawKi = i;
                  _yawKd = d;
                });
                SerialService.sendCommand("yaw_kp $p");
                SerialService.sendCommand("yaw_ki $i");
                SerialService.sendCommand("yaw_kd $d");
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
              onUpdate: (p, i, d) {
                setState(() {
                  _vzKp = p;
                  _vzKi = i;
                  _vzKd = d;
                });
                SerialService.sendCommand("vz_kp $p");
                SerialService.sendCommand("vz_ki $i");
                SerialService.sendCommand("vz_kd $d");
              },
            ),
            XFireResetCard(hint: "Сброс ПИД-коэффициентов (default pid)", onReset: _resetPidGroup),
            XFireBatchApplyCard(
              hint: "Пакетная отправка ПИД-коэффициентов осей",
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

        // 7. Калибровки датчиков
        XFireExpansionCard(
          title: "Калибровка датчиков",
          subtitle: "Гироскоп, акселерометр, лидар и компас",
          icon: Icons.explore,
          children: [
            XFireActionCard(
              title: "Калибровка гироскопа",
              commandName: "cal_gyro",
              onTap: () {
                if (!SerialService.isConnected) {
                  showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true);
                } else {
                  SerialService.sendCommand("cal_gyro");
                  showAppDialog(context, "Успех", "Калибровка гироскопа запущена.");
                }
              },
            ),
            XFireActionCard(
              title: "Калибровка акселерометра",
              commandName: "cal_acc",
              onTap: () {
                if (!SerialService.isConnected) {
                  showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true);
                } else {
                  SerialService.sendCommand("cal_acc");
                  showAppDialog(context, "Успех", "Калибровка акселерометра запущена.");
                }
              },
            ),
            XFireActionCard(
              title: "Калибровка смещения лидара",
              commandName: "cal_lid",
              onTap: () {
                if (!SerialService.isConnected) {
                  showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true);
                } else {
                  SerialService.sendCommand("cal_lid");
                  showAppDialog(context, "Успех", "Калибровка лидара (cal_lid) запущена.");
                }
              },
            ),
            XFireActionCard(
              title: "Калибровка компаса",
              commandName: "cal_mag",
              onTap: () {
                if (!SerialService.isConnected) {
                  showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true);
                } else {
                  SerialService.sendCommand("cal_mag");
                  showAppDialog(context, "Успех", "Калибровка компаса (cal_mag) запущена.");
                }
              },
            ),
          ],
        ),

        // 8. Тесты оборудования
        XFireExpansionCard(
          title: "Тесты оборудования",
          subtitle: "Проверки датчиков, радио, моторов, PID и линка RC",
          icon: Icons.rule,
          children: [
            XFireActionCard(
              title: "Тест IMU (MPU / датчики)",
              commandName: "test_mpu",
              onTap: () {
                if (!SerialService.isConnected) {
                  showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true);
                } else {
                  SerialService.sendCommand("test_mpu");
                  showAppDialog(context, "Тест IMU", "Команда test_mpu отправлена.");
                }
              },
            ),
            XFireActionCard(
              title: "Тест радиомодуля SX126x (915 МГц)",
              commandName: "test_sx",
              onTap: () {
                if (!SerialService.isConnected) {
                  showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true);
                } else {
                  SerialService.sendCommand("test_sx");
                  showAppDialog(context, "Тест SX126x", "Проверка SPI радиомодуля запущена.");
                }
              },
            ),
            XFireActionCard(
              title: "Тест лидара",
              commandName: "test_lidar",
              onTap: () {
                if (!SerialService.isConnected) {
                  showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true);
                } else {
                  SerialService.sendCommand("test_lidar");
                  showAppDialog(context, "Тест лидара", "Команда test_lidar отправлена.");
                }
              },
            ),
            XFireActionCard(
              title: "Тест моторов (25%)",
              commandName: "test_motor",
              onTap: () {
                if (!SerialService.isConnected) {
                  showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true);
                } else {
                  SerialService.sendCommand("test_motor");
                  showAppDialog(context, "Внимание", "Тест моторов (25%) активирован!", isError: true);
                }
              },
            ),
            XFireActionCard(
              title: "Тест PID (25%)",
              commandName: "test_pid",
              onTap: () {
                if (!SerialService.isConnected) {
                  showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true);
                } else {
                  SerialService.sendCommand("test_pid");
                  showAppDialog(context, "Тест PID", "Тест PID активирован.");
                }
              },
            ),
            XFireActionCard(
              title: "Тест связи с пультом",
              commandName: "test_rc",
              onTap: () {
                if (!SerialService.isConnected) {
                  showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true);
                } else {
                  SerialService.sendCommand("test_rc");
                  showAppDialog(context, "Тест RC", "Диагностика связи с пультом запущена.");
                }
              },
            ),
            XFireActionCard(
              title: "Тест смены канала связи с пультом",
              commandName: "test_rc_can",
              onTap: () {
                if (!SerialService.isConnected) {
                  showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true);
                } else {
                  SerialService.sendCommand("test_rc_can");
                  showAppDialog(context, "Смена канала", "Команда test_rc_can отправлена.");
                }
              },
            ),
          ],
        ),

        // 9. Телеметрия (датчики и авиогоризонт)
        XFireExpansionCard(
          title: "Телеметрия",
          subtitle: "Авиогоризонт, HUD и показания гироскопа / акселерометра",
          icon: Icons.radar,
          children: [
            StreamBuilder<void>(
              stream: SerialService.telemetryController.stream,
              builder: (context, snapshot) {
                double rollDeg = SerialService.gyroRoll * 57.2958;
                double pitchDeg = SerialService.gyroPitch * 57.2958;
                double yawDeg = SerialService.gyroYaw * 57.2958;
                while (yawDeg > 180) yawDeg -= 360;
                while (yawDeg < -180) yawDeg += 360;

                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
                      padding: const EdgeInsets.all(8),
                      height: 260,
                      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
                      child: Column(
                        children: [
                          Transform.translate(
                            offset: const Offset(0, 16),
                            child: SizedBox(
                              height: 26,
                              child: CustomPaint(
                                painter: YawHudScalePainter(value: yawDeg, minVal: -180, maxVal: 180, isTop: true),
                                size: const Size(double.infinity, 26),
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
                                      painter: PitchHudScalePainter(value: pitchDeg, minVal: -90, maxVal: 90, isLeftSide: true),
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
                                        CustomPaint(size: const Size(155, 155), painter: ArtificialHorizonPainter(roll: SerialService.gyroRoll, pitch: SerialService.gyroPitch)),
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
                                      painter: PitchHudScalePainter(value: pitchDeg, minVal: -90, maxVal: 90, isLeftSide: false),
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
                              height: 26,
                              child: CustomPaint(
                                painter: YawHudScalePainter(value: yawDeg, minVal: -180, maxVal: 180, isTop: false),
                                size: const Size(double.infinity, 26),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 13.0, vertical: 4.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("GYROSCOPE", style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                            const SizedBox(height: 4),
                            _buildSensorBar("Gyro Roll", SerialService.gyroRoll, -3.14, 3.14, "rad/s", Colors.blueAccent),
                            _buildSensorBar("Gyro Pitch", SerialService.gyroPitch, -3.14, 3.14, "rad/s", Colors.blueAccent),
                            _buildSensorBar("Gyro Yaw", SerialService.gyroYaw, -3.14, 3.14, "rad/s", Colors.blueAccent),
                            const SizedBox(height: 6),
                            const Text("ACCELEROMETER", style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                            const SizedBox(height: 4),
                            _buildSensorBar("Accel X", SerialService.accelX, -2.0, 2.0, "G", Colors.cyanAccent),
                            _buildSensorBar("Accel Y", SerialService.accelY, -2.0, 2.0, "G", Colors.cyanAccent),
                            _buildSensorBar("Accel Z", SerialService.accelZ, -2.0, 2.0, "G", Colors.cyanAccent),
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

        // 10. Прошивка полетного контроллера
        XFireExpansionCard(
          title: "Прошивка полетного контроллера",
          subtitle: "Обновление прошивки STM32 (нажмите для прошивки)",
          icon: Icons.memory,
          children: [
            XFireFlashCard(
              title: "Прошить полетный контроллер (v3.27)",
              targetName: "Полетный контроллер FC",
              onFlash: (onProgress) async {
                onProgress("Стирание флеш-памяти STM32...", 0.2);
                await Future.delayed(const Duration(milliseconds: 800));
                if (SerialService.isConnected && SerialService.usbPort != null) {
                  await SerialService.usbPort!.write(Uint8List.fromList([0x7F]));
                }
                onProgress("Запись блоков прошивки v3.27...", 0.6);
                await Future.delayed(const Duration(milliseconds: 1200));
                onProgress("Проверка контрольной суммы CRC...", 0.9);
                await Future.delayed(const Duration(milliseconds: 600));
                onProgress("Готово!", 1.0);
              },
            ),
          ],
        ),

        // 11. Общий сброс всех настроек FC
        XFireResetCard(
          hint: "Общий сброс всех настроек полётного контроллера (default)",
          onReset: _resetAllFcSettings,
        ),

        const SizedBox(height: 24),
      ],
    );
  }
}

// ==========================================
// ВКЛАДКА 2: ПУЛЬТ RC
// ==========================================
class RemoteControlTab extends StatefulWidget {
  const RemoteControlTab({super.key});

  @override
  State<RemoteControlTab> createState() => _RemoteControlTabState();
}

class _RemoteControlTabState extends State<RemoteControlTab> {
  double _stickDeadband = 10.0;
  double _rcProtocol = 1.0;
  double _txPowerW = 100.0;
  double _rcRate = 0.35;
  double _rcSuperExpo = 0.03;
  double _rcStickExpo = 0.45;
  double _rcYawRate = 0.30;
  double _rcYawSuperExpo = 0.03;
  double _rcYawExpo = 0.35;
  double _rcDeadband = 15.0;
  double _rcFilterSmoothing = 0.35;
  double _rcFsEn = 1.0;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      children: [
        XFireExpansionCard(
          title: "Калибровка стиков",
          subtitle: "Настройка нейтрали и мертвых зон",
          icon: Icons.gamepad,
          children: [
            XFireActionCard(
              title: "Калибровка нейтрали стиков",
              commandName: "rc_cal_sticks",
              onTap: () {
                if (!SerialService.isConnected) {
                  showAppDialog(context, "Ошибка", "Устройство пульта не подключено!", isError: true);
                } else {
                  SerialService.sendCommand("rc_cal_sticks");
                  showAppDialog(context, "Калибровка", "Команда калибровки нейтрали отправлена в пульт.");
                }
              },
            ),
            XFireSliderCard(title: "Мертвая зона стиков (Deadband)", commandName: "rc_tx_deadband", value: _stickDeadband, min: 0, max: 50, divisions: 50, unit: "PWM", onChanged: (v) => setState(() => _stickDeadband = v), onChangeEnd: (v) => SerialService.sendCommand("rc_tx_deadband ${v.round()}")),
            XFireResetCard(
              hint: "Сброс калибровки стиков пульта",
              onReset: () {
                setState(() {
                  _stickDeadband = 10.0;
                });
                SerialService.sendCommand("default rc_sticks");
              },
            ),
            XFireBatchApplyCard(
              hint: "Пакетная отправка мертвой зоны стиков пульта",
              parameters: ["rc_tx_deadband ${_stickDeadband.round()}"],
            ),
          ],
        ),
        XFireExpansionCard(
          title: "Прошивка пульта управления",
          subtitle: "Обновление ПО пульта (нажмите для прошивки)",
          icon: Icons.memory,
          children: [
            XFireFlashCard(
              title: "Прошить пульт управления (v3.27)",
              targetName: "Пульт управления RC",
              onFlash: (onProgress) async {
                onProgress("Стирание памяти пульта...", 0.25);
                await Future.delayed(const Duration(milliseconds: 700));
                if (SerialService.isConnected && SerialService.usbPort != null) {
                  await SerialService.usbPort!.write(Uint8List.fromList([0x7F]));
                }
                onProgress("Запись прошивки пульта v3.27...", 0.65);
                await Future.delayed(const Duration(milliseconds: 1300));
                onProgress("Проверка целостности...", 0.9);
                await Future.delayed(const Duration(milliseconds: 500));
                onProgress("Готово!", 1.0);
              },
            ),
          ],
        ),
        XFireExpansionCard(
          title: "Протокол и мощность",
          subtitle: "Выбор протокола связи и мощности передатчика",
          icon: Icons.wifi,
          children: [
            XFireSegmentedCard(
              title: "Протокол связи с модулем",
              commandName: "rc_proto",
              options: const ["CRSF", "XFire RTX (915MHz)", "SBUS"],
              selectedIndex: _rcProtocol.round(),
              onSelected: (val) {
                setState(() => _rcProtocol = val.toDouble());
                SerialService.sendCommand("rc_proto $val");
              },
            ),
            XFireSliderCard(title: "Выходная мощность передатчика пульта", commandName: "tx_power_mw", value: _txPowerW, min: 10, max: 1000, divisions: 99, unit: "мВт", onChanged: (v) => setState(() => _txPowerW = v), onChangeEnd: (v) => SerialService.sendCommand("tx_power_mw ${v.round()}")),
            XFireResetCard(
              hint: "Сброс протокола и мощности передатчика",
              onReset: () {
                setState(() {
                  _rcProtocol = 1.0;
                  _txPowerW = 100.0;
                });
                SerialService.sendCommand("default rc_proto");
              },
            ),
            XFireBatchApplyCard(
              hint: "Пакетная отправка типа протокола и мощности Tx",
              parameters: ["rc_proto ${_rcProtocol.round()}", "tx_power_mw ${_txPowerW.round()}"],
            ),
          ],
        ),
        XFireExpansionCard(
          title: "Радиоуправление и экспоненты пульта",
          subtitle: "RC Rate, Super Expo, кривые и сглаживание",
          icon: Icons.tune,
          children: [
            XFireSliderCard(title: "RC Rate (Roll/Pitch)", commandName: "rc_rate", value: _rcRate, min: 0.1, max: 2.0, divisions: 19, unit: "", onChanged: (v) => setState(() => _rcRate = v), onChangeEnd: (v) => SerialService.sendCommand("rc_rate $v")),
            XFireSliderCard(title: "RC Super Expo", commandName: "rc_super_expo", value: _rcSuperExpo, min: 0.0, max: 0.9, divisions: 18, unit: "", onChanged: (v) => setState(() => _rcSuperExpo = v), onChangeEnd: (v) => SerialService.sendCommand("rc_super_expo $v")),
            XFireSliderCard(title: "RC Stick Expo", commandName: "rc_stick_expo", value: _rcStickExpo, min: 0.0, max: 1.0, divisions: 20, unit: "", onChanged: (v) => setState(() => _rcStickExpo = v), onChangeEnd: (v) => SerialService.sendCommand("rc_stick_expo $v")),
            XFireSliderCard(title: "Yaw Rate", commandName: "rc_yaw_rate", value: _rcYawRate, min: 0.1, max: 2.0, divisions: 19, unit: "", onChanged: (v) => setState(() => _rcYawRate = v), onChangeEnd: (v) => SerialService.sendCommand("rc_yaw_rate $v")),
            XFireSliderCard(title: "Yaw Super Expo", commandName: "rc_yaw_super_expo", value: _rcYawSuperExpo, min: 0.0, max: 0.9, divisions: 18, unit: "", onChanged: (v) => setState(() => _rcYawSuperExpo = v), onChangeEnd: (v) => SerialService.sendCommand("rc_yaw_super_expo $v")),
            XFireSliderCard(title: "Yaw Expo", commandName: "rc_yaw_expo", value: _rcYawExpo, min: 0.0, max: 1.0, divisions: 20, unit: "", onChanged: (v) => setState(() => _rcYawExpo = v), onChangeEnd: (v) => SerialService.sendCommand("rc_yaw_expo $v")),
            XFireSliderCard(title: "Мертвая зона стиков", commandName: "rc_deadband", value: _rcDeadband, min: 0, max: 50, divisions: 50, unit: "PWM", onChanged: (v) => setState(() => _rcDeadband = v), onChangeEnd: (v) => SerialService.sendCommand("rc_deadband $v")),
            XFireSliderCard(title: "Сглаживание RC", commandName: "rc_filter_smoothing", value: _rcFilterSmoothing, min: 0.05, max: 1.0, divisions: 19, unit: "", onChanged: (v) => setState(() => _rcFilterSmoothing = v), onChangeEnd: (v) => SerialService.sendCommand("rc_filter_smoothing $v")),
            XFireSwitchCard(
              title: "RC Failsafe (пакеты пульта)",
              commandName: "rc_fs_en",
              value: _rcFsEn == 1,
              onChanged: (v) {
                setState(() => _rcFsEn = v ? 1.0 : 0.0);
                SerialService.sendCommand("rc_fs_en ${_rcFsEn.round()}");
              },
            ),
            XFireResetCard(
              hint: "Сброс кривых управления пульта",
              onReset: () {
                setState(() {
                  _rcRate = 0.35;
                  _rcSuperExpo = 0.03;
                  _rcStickExpo = 0.45;
                  _rcYawRate = 0.30;
                  _rcYawSuperExpo = 0.03;
                  _rcYawExpo = 0.35;
                  _rcDeadband = 15.0;
                  _rcFilterSmoothing = 0.35;
                  _rcFsEn = 1.0;
                });
                SerialService.sendCommand("default rc_expos");
              },
            ),
            XFireBatchApplyCard(
              hint: "Пакетная отправка кривых управления и сглаживания",
              parameters: ["rc_rate $_rcRate", "rc_super_expo $_rcSuperExpo", "rc_stick_expo $_rcStickExpo", "rc_yaw_rate $_rcYawRate", "rc_yaw_super_expo $_rcYawSuperExpo", "rc_yaw_expo $_rcYawExpo", "rc_deadband $_rcDeadband", "rc_filter_smoothing $_rcFilterSmoothing", "rc_fs_en ${_rcFsEn.round()}"],
            ),
          ],
        ),
        XFireExpansionCard(
          title: "Тест каналов",
          subtitle: "Монитор каналов управления в реальном времени",
          icon: Icons.bar_chart,
          children: [
            XFireCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Каналы пульта (CH1 - CH4)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                  const SizedBox(height: 12),
                  _buildChannelBar("Channel 1 (Roll)", 1500, Colors.blueAccent),
                  _buildChannelBar("Channel 2 (Pitch)", 1500, Colors.cyanAccent),
                  _buildChannelBar("Channel 3 (Throttle)", 1000, Colors.greenAccent),
                  _buildChannelBar("Channel 4 (Yaw)", 1500, Colors.amberAccent),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildChannelBar(String label, int pwmValue, Color color) {
    double percent = ((pwmValue - 1000) / 1000.0).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
              Text("$pwmValue PWM", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 2),
          LinearProgressIndicator(value: percent, color: color, backgroundColor: Colors.white12, minHeight: 6, borderRadius: BorderRadius.circular(3)),
        ],
      ),
    );
  }
}

// ==========================================
// ВКЛАДКА 3: РАДИОМОДУЛЬ RTX (915 МГц)
// ==========================================
class RadioTab extends StatefulWidget {
  const RadioTab({super.key});

  @override
  State<RadioTab> createState() => _RadioTabState();
}

class _RadioTabState extends State<RadioTab> {
  double _rtxEn = 1;

  double _rtxBand = 9.0;
  double _rtxAmpTier = 22.0;
  int _antennaComboIndex = 1;

  double _priChan = 15.0;
  double _priSf = 7.0;
  double _priBw = 7.0;
  double _priCr = 1.0;
  double _priPower = 22.0;
  double _priFadeMargin = 15.0;

  double _bakChan = 25.0;
  double _bakSf = 10.0;
  double _bakBw = 4.0;
  double _bakCr = 1.0;
  double _bakPower = 22.0;
  double _bakFadeMargin = 15.0;

  bool _rtxAfcEn = false;
  bool _rtxHwCrcEn = true;
  bool _rtxSwCrcEn = false;
  bool _rtxAddrEn = true;
  String _rtxAddrHex = "0x0000";
  String _rtxSyncWordHex = "0x1424";
  bool _rtxLbtEn = false;
  bool _rtxIqInv = false;

  bool _hasProtectiveSleeve = true;
  double _sleeveThicknessMm = 1.0;
  double _dipoleTubeDiameterMm = 3.0;
  double _dipoleTopWireSqMm = 1.0;
  double _kharchenkoWireSqMm = 2.0;

  final List<double> _bwTable = [7800.0, 10400.0, 15600.0, 20800.0, 31250.0, 41700.0, 62500.0, 125000.0, 250000.0, 500000.0];
  final Map<int, double> _snrTable = {5: -2.5, 6: -5.0, 7: -7.5, 8: -10.0, 9: -12.5, 10: -15.0, 11: -17.5, 12: -20.0};

  double get _priFreqMhz => (_rtxBand * 100.0) + _priChan;
  double get _bakFreqMhz => (_rtxBand * 100.0) + _bakChan;

  double _calculateSensitivity(double bwParam, double sfParam) {
    int bwIdx = bwParam.round().clamp(0, _bwTable.length - 1);
    double bwHz = _bwTable[bwIdx];
    int sfInt = sfParam.round().clamp(5, 12);
    double snr = _snrTable[sfInt] ?? -7.5;
    return -174.0 + (10.0 * (math.log(bwHz) / math.ln10)) + 6.0 + snr;
  }

  double _calculateAirDataRate(double bwParam, double sfParam, double crParam) {
    int bwIdx = bwParam.round().clamp(0, _bwTable.length - 1);
    double bwHz = _bwTable[bwIdx];
    int sfInt = sfParam.round().clamp(5, 12);
    int crInt = crParam.round().clamp(1, 4);
    double symbolRate = bwHz / math.pow(2, sfInt).toDouble();
    return sfInt * symbolRate * (4.0 / (4.0 + crInt));
  }

  Map<String, dynamic> _calculateLinkBudget(double freqMhz, double bw, double sf, double cr, double power, double fadeMargin) {
    double sensitivity = _calculateSensitivity(bw, sf);
    double gTx = (_antennaComboIndex == 1) ? 5.5 : 2.15;
    double gRx = 2.15;
    double cableLoss = 1.0;

    double eirp = power + gTx - cableLoss;
    double maxPathLoss = eirp + gRx - sensitivity - fadeMargin;
    if (maxPathLoss < 0) maxPathLoss = 0;

    double freqLog = 20 * (math.log(freqMhz) / math.ln10);
    double exponent = (maxPathLoss - 32.44 - freqLog) / 20.0;
    double distanceKm = math.pow(10.0, exponent).toDouble();
    double bitRate = _calculateAirDataRate(bw, sf, cr);

    return {'sensitivity': sensitivity, 'eirp': eirp, 'distanceKm': distanceKm, 'bitRate': bitRate};
  }

  Map<String, dynamic> _calculateAntennaDimensions() {
    double freqHz = _bakFreqMhz * 1e6;
    double lambdaMm = (299792458.0 / (freqHz * 1.0003)) * 1000.0;
    double quarterLambda = lambdaMm / 4.0;

    double dielectricLoading = 1.0;
    if (_hasProtectiveSleeve) {
      dielectricLoading = 1.0 + (0.018 * 1.6 * (_sleeveThicknessMm / 1.0));
    }

    double radiusBot = _dipoleTubeDiameterMm / 2.0;
    double kFactorDipoleBot = (0.97 - (2.5 / (2.0 * math.log(lambdaMm / radiusBot)))) / dielectricLoading;

    double radiusTop = math.sqrt(_dipoleTopWireSqMm / math.pi);
    double kFactorDipoleTop = (0.97 - (2.0 / (2.0 * math.log(lambdaMm / radiusTop)))) / dielectricLoading;

    double dipoleArmTopMm = quarterLambda * kFactorDipoleTop - 0.006;
    double dipoleArmBotMm = quarterLambda * kFactorDipoleBot - 0.006;
    double kharchenkoSideMm = quarterLambda * (0.96 - (1.8 / (2.0 * math.log(lambdaMm / (2.0 * math.sqrt(_kharchenkoWireSqMm / math.pi))))));

    return {'lambdaMm': lambdaMm, 'dipoleArmTopMm': dipoleArmTopMm, 'dipoleArmBotMm': dipoleArmBotMm, 'kharchenkoSideMm': kharchenkoSideMm};
  }

  @override
  Widget build(BuildContext context) {
    if (_priPower > _rtxAmpTier) _priPower = _rtxAmpTier;
    if (_bakPower > _rtxAmpTier) _bakPower = _rtxAmpTier;

    var priResults = _calculateLinkBudget(_priFreqMhz, _priBw, _priSf, _priCr, _priPower, _priFadeMargin);
    var bakResults = _calculateLinkBudget(_bakFreqMhz, _bakBw, _bakSf, _bakCr, _bakPower, _bakFadeMargin);
    var antResults = _calculateAntennaDimensions();

    int powerTierIndex = _rtxAmpTier == 22 ? 0 : (_rtxAmpTier == 29 ? 1 : (_rtxAmpTier == 30 ? 2 : 3));

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      children: [
        XFireExpansionCard(
          title: "Общие настройки радиомодуля",
          subtitle: "Диапазон частот, мощность усилителя (PA Tier) и протокол",
          icon: Icons.settings_applications_rounded,
          children: [
            XFireSwitchCard(title: "Включить RTX модуль", commandName: "rtx_en", value: _rtxEn == 1, onChanged: (v) { setState(() => _rtxEn = v ? 1.0 : 0.0); SerialService.sendCommand("rtx_en ${_rtxEn.round()}"); }),
            XFireSliderCard(title: "Общий диапазон частот (9 = 900 МГц)", commandName: "rtx_band", value: _rtxBand, min: 1, max: 9, divisions: 8, unit: "", onChanged: (v) => setState(() => _rtxBand = v), onChangeEnd: (v) => SerialService.sendCommand("rtx_band ${v.round()}")),
            XFireSegmentedCard(
              title: "Мощность усилителя (PA Tier)",
              commandName: "rtx_amp_tier",
              options: const ["22 dBm", "29 dBm", "30 dBm", "33 dBm"],
              selectedIndex: powerTierIndex,
              onSelected: (val) {
                setState(() {
                  if (val == 0) {
                    _rtxAmpTier = 22.0;
                  } else if (val == 1) {
                    _rtxAmpTier = 29.0;
                  } else if (val == 2) {
                    _rtxAmpTier = 30.0;
                  } else {
                    _rtxAmpTier = 33.0;
                  }

                  if (_priPower > _rtxAmpTier) _priPower = _rtxAmpTier;
                  if (_bakPower > _rtxAmpTier) _bakPower = _rtxAmpTier;
                });
                SerialService.sendCommand("rtx_amp_tier ${_rtxAmpTier.round()}");
              },
            ),
            XFireCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Комбинация антенн", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                  const SizedBox(height: 2),
                  const Text("ant_combo_config", style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: const Color(0xFF242428), borderRadius: BorderRadius.circular(12)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _antennaComboIndex,
                        dropdownColor: const Color(0xFF242428),
                        borderRadius: BorderRadius.circular(12),
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.amberAccent),
                        style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text("Штырь + Штырь (2.15 dBi)")),
                          DropdownMenuItem(value: 1, child: Text("Харченко + Штырь (5.5 dBi)")),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _antennaComboIndex = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            XFireSwitchCard(title: "Аппаратный CRC", commandName: "rtx_hw_crc_en", value: _rtxHwCrcEn, onChanged: (v) { setState(() => _rtxHwCrcEn = v); SerialService.sendCommand("rtx_hw_crc_en ${v ? 1 : 0}"); }),
            XFireSwitchCard(title: "Программный CRC", commandName: "rtx_sw_crc_en", value: _rtxSwCrcEn, onChanged: (v) { setState(() => _rtxSwCrcEn = v); SerialService.sendCommand("rtx_sw_crc_en ${v ? 1 : 0}"); }),
            XFireSwitchCard(title: "Сетевой адрес (вкл/выкл)", commandName: "rtx_addr_en", value: _rtxAddrEn, onChanged: (v) { setState(() => _rtxAddrEn = v); SerialService.sendCommand("rtx_addr_en ${v ? 1 : 0}"); }),
            XFireTextHexCard(
              title: "Сетевой адрес (HEX)",
              commandName: "rtx_addr",
              initialValue: _rtxAddrHex,
              onChanged: (v) => setState(() => _rtxAddrHex = v),
              onSubmitEnd: (v) => SerialService.sendCommand("rtx_addr $v"),
            ),
            XFireTextHexCard(
              title: "Слово синхронизации (HEX)",
              commandName: "rtx_sync_word",
              initialValue: _rtxSyncWordHex,
              onChanged: (v) => setState(() => _rtxSyncWordHex = v),
              onSubmitEnd: (v) => SerialService.sendCommand("rtx_sync_word $v"),
            ),
            XFireSwitchCard(title: "Слушать перед передачей (LBT)", commandName: "rtx_lbt_en", value: _rtxLbtEn, onChanged: (v) { setState(() => _rtxLbtEn = v); SerialService.sendCommand("rtx_lbt_en ${v ? 1 : 0}"); }),
            XFireSwitchCard(title: "Инверсия IQ", commandName: "rtx_iq_inv", value: _rtxIqInv, onChanged: (v) { setState(() => _rtxIqInv = v); SerialService.sendCommand("rtx_iq_inv ${v ? 1 : 0}"); }),
            XFireSwitchCard(title: "Автоматическая подстройка частоты (AFC)", commandName: "rtx_afc_en", value: _rtxAfcEn, onChanged: (v) => setState(() => _rtxAfcEn = v)),
            XFireResetCard(
              hint: "Сброс общих настроек по умолчанию",
              onReset: () {
                setState(() {
                  _rtxEn = 1;
                  _rtxBand = 9.0;
                  _rtxAmpTier = 22.0;
                  _antennaComboIndex = 1;
                  _rtxHwCrcEn = true;
                  _rtxSwCrcEn = false;
                  _rtxAddrEn = true;
                  _rtxAddrHex = "0x0000";
                  _rtxSyncWordHex = "0x1424";
                  _rtxLbtEn = false;
                  _rtxIqInv = false;
                  _rtxAfcEn = false;
                });
                SerialService.sendCommand("default rtx_common");
              },
            ),
            XFireBatchApplyCard(
              hint: "Пакетная отправка общих настроек и усилителя",
              parameters: [
                "rtx_en ${_rtxEn.round()}",
                "rtx_band ${_rtxBand.round()}",
                "rtx_amp_tier ${_rtxAmpTier.round()}",
                "ant_combo_config $_antennaComboIndex",
                "rtx_hw_crc_en ${_rtxHwCrcEn ? 1 : 0}",
                "rtx_sw_crc_en ${_rtxSwCrcEn ? 1 : 0}",
                "rtx_addr_en ${_rtxAddrEn ? 1 : 0}",
                "rtx_addr $_rtxAddrHex",
                "rtx_sync_word $_rtxSyncWordHex",
                "rtx_lbt_en ${_rtxLbtEn ? 1 : 0}",
                "rtx_iq_inv ${_rtxIqInv ? 1 : 0}",
                "rtx_afc_en ${_rtxAfcEn ? 1 : 0}",
              ],
            ),
          ],
        ),
        XFireExpansionCard(
          title: "Основной канал связи (~5.4 кбит/с)",
          subtitle: "Штатный режим с малой задержкой (SF7, BW 125 кГц)",
          icon: Icons.flash_on_rounded,
          children: [
            XFireSliderCard(title: "Рабочий канал основного профиля", commandName: "rtx_pri_chan", value: _priChan, min: 0, max: 99, divisions: 99, unit: "МГц", onChanged: (v) => setState(() => _priChan = v), onChangeEnd: (v) => SerialService.sendCommand("rtx_pri_chan ${v.round()}")),
            XFireSliderCard(title: "Основной SF (Spreading Factor 7)", commandName: "rtx_pri_sf", value: _priSf, min: 5, max: 12, divisions: 7, unit: "", onChanged: (v) => setState(() => _priSf = v), onChangeEnd: (v) => SerialService.sendCommand("rtx_pri_sf ${v.round()}")),
            XFireSliderCard(title: "Основная полоса (BW 125 кГц)", commandName: "rtx_pri_bw", value: _priBw, min: 0, max: 9, divisions: 9, unit: "", onChanged: (v) => setState(() => _priBw = v), onChangeEnd: (v) => SerialService.sendCommand("rtx_pri_bw ${v.round()}")),
            XFireSliderCard(title: "Основной CR (Coding Rate)", commandName: "rtx_pri_cr", value: _priCr, min: 1, max: 4, divisions: 3, unit: "", onChanged: (v) => setState(() => _priCr = v), onChangeEnd: (v) => SerialService.sendCommand("rtx_pri_cr ${v.round()}")),
            XFireSliderCard(
              title: "Мощность основного канала (до ${_rtxAmpTier.round()} dBm)",
              commandName: "rtx_pri_power",
              value: _priPower,
              min: -9,
              max: _rtxAmpTier,
              divisions: (_rtxAmpTier + 9).round(),
              unit: "dBm",
              onChanged: (v) => setState(() => _priPower = v),
              onChangeEnd: (v) => SerialService.sendCommand("rtx_pri_power ${v.round()}"),
            ),
            XFireSliderCard(title: "Запас на условия (Fade Margin)", commandName: "rtx_pri_fade", value: _priFadeMargin, min: 5.0, max: 30.0, divisions: 25, unit: "dB", onChanged: (v) => setState(() => _priFadeMargin = v), onChangeEnd: (_) {}),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13.0, vertical: 4.0),
              child: RtxLinkCalculatorCard(
                title: "Калькулятор дальности основного канала",
                themeColor: Colors.blueAccent,
                currentFreqMhz: _priFreqMhz,
                sensitivity: priResults['sensitivity'],
                distKm: priResults['distanceKm'],
                bitRate: priResults['bitRate'],
                sensitivityProgress: ((priResults['sensitivity'] - (-140.0)) / ((-100.0) - (-140.0))).clamp(0.0, 1.0),
                bitRateProgress: (priResults['bitRate'] / 30000.0).clamp(0.0, 1.0),
              ),
            ),
            XFireResetCard(
              hint: "Сброс основного канала по умолчанию",
              onReset: () {
                setState(() {
                  _priChan = 15.0;
                  _priSf = 7.0;
                  _priBw = 7.0;
                  _priCr = 1.0;
                  _priPower = 22.0;
                  _priFadeMargin = 15.0;
                });
                SerialService.sendCommand("default rtx_primary");
              },
            ),
            XFireBatchApplyCard(
              hint: "Пакетная отправка настроек основного канала",
              parameters: [
                "rtx_pri_chan ${_priChan.round()}",
                "rtx_pri_sf ${_priSf.round()}",
                "rtx_pri_bw ${_priBw.round()}",
                "rtx_pri_cr ${_priCr.round()}",
                "rtx_pri_power ${_priPower.round()}",
                "rtx_pri_fade $_priFadeMargin",
              ],
            ),
          ],
        ),
        XFireExpansionCard(
          title: "Запасной канал связи (~1.0 кбит/с)",
          subtitle: "Ультра-дальний резервный линк (SF10, BW 31.25 кГц)",
          icon: Icons.shield_rounded,
          children: [
            XFireSliderCard(title: "Рабочий канал запасного профиля", commandName: "rtx_bak_chan", value: _bakChan, min: 0, max: 99, divisions: 99, unit: "МГц", onChanged: (v) => setState(() => _bakChan = v), onChangeEnd: (v) => SerialService.sendCommand("rtx_bak_chan ${v.round()}")),
            XFireSliderCard(title: "Запасной SF (Spreading Factor 10)", commandName: "rtx_bak_sf", value: _bakSf, min: 5, max: 12, divisions: 7, unit: "", onChanged: (v) => setState(() => _bakSf = v), onChangeEnd: (v) => SerialService.sendCommand("rtx_bak_sf ${v.round()}")),
            XFireSliderCard(title: "Запасная полоса (BW 31.25 кГц)", commandName: "rtx_bak_bw", value: _bakBw, min: 0, max: 9, divisions: 9, unit: "", onChanged: (v) => setState(() => _bakBw = v), onChangeEnd: (v) => SerialService.sendCommand("rtx_bak_bw ${v.round()}")),
            XFireSliderCard(title: "Запасной CR (Coding Rate)", commandName: "rtx_bak_cr", value: _bakCr, min: 1, max: 4, divisions: 3, unit: "", onChanged: (v) => setState(() => _bakCr = v), onChangeEnd: (v) => SerialService.sendCommand("rtx_bak_cr ${v.round()}")),
            XFireSliderCard(
              title: "Мощность запасного канала (до ${_rtxAmpTier.round()} dBm)",
              commandName: "rtx_bak_power",
              value: _bakPower,
              min: -9,
              max: _rtxAmpTier,
              divisions: (_rtxAmpTier + 9).round(),
              unit: "dBm",
              onChanged: (v) => setState(() => _bakPower = v),
              onChangeEnd: (v) => SerialService.sendCommand("rtx_bak_power ${v.round()}"),
            ),
            XFireSliderCard(title: "Запас на условия (Fade Margin)", commandName: "rtx_bak_fade", value: _bakFadeMargin, min: 5.0, max: 30.0, divisions: 25, unit: "dB", onChanged: (v) => setState(() => _bakFadeMargin = v), onChangeEnd: (_) {}),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13.0, vertical: 4.0),
              child: RtxLinkCalculatorCard(
                title: "Калькулятор дальности запасного канала",
                themeColor: Colors.greenAccent,
                currentFreqMhz: _bakFreqMhz,
                sensitivity: bakResults['sensitivity'],
                distKm: bakResults['distanceKm'],
                bitRate: bakResults['bitRate'],
                sensitivityProgress: ((bakResults['sensitivity'] - (-140.0)) / ((-100.0) - (-140.0))).clamp(0.0, 1.0),
                bitRateProgress: (bakResults['bitRate'] / 30000.0).clamp(0.0, 1.0),
              ),
            ),
            XFireResetCard(
              hint: "Сброс запасного канала по умолчанию",
              onReset: () {
                setState(() {
                  _bakChan = 25.0;
                  _bakSf = 10.0;
                  _bakBw = 4.0;
                  _bakCr = 1.0;
                  _bakPower = 22.0;
                  _bakFadeMargin = 15.0;
                });
                SerialService.sendCommand("default rtx_backup");
              },
            ),
            XFireBatchApplyCard(
              hint: "Пакетная отправка настроек запасного канала",
              parameters: [
                "rtx_bak_chan ${_bakChan.round()}",
                "rtx_bak_sf ${_bakSf.round()}",
                "rtx_bak_bw ${_bakBw.round()}",
                "rtx_bak_cr ${_bakCr.round()}",
                "rtx_bak_power ${_bakPower.round()}",
                "rtx_bak_fade $_bakFadeMargin",
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
    "info", "mon", "stop", "config", "default",
    "default hw", "default bat", "default fl", "default fs", "default fil", "default pid",
    "esc_protocol", "imu_align", "com_align",
    "imu_id", "bar_id", "com_id", "lid_id",
    "baro_en", "com_en", "lidar_en",
    "lidar_filter_alpha", "lidar_offset_m",
    "mag_bias_x", "mag_bias_y", "mag_bias_z",
    "bat_voltage_scale", "bat_filter_alpha", "curr_zero_offset_a", "curr_scale",
    "fl_mode", "fl_roll_max", "fl_pitch_max", "fl_vz_speed_max",
    "rc_rate", "rc_super_expo", "rc_stick_expo", "rc_yaw_rate", "rc_yaw_super_expo", "rc_yaw_expo",
    "rc_deadband", "rc_horizon_transition", "rc_filter_smoothing",
    "fs_bat_en", "fs_rtx_en", "fs_vz_speed", "bat_fs_v",
    "fil_amb_en", "fil_lpf_en", "fil_not_en",
    "gyro_filter_alpha", "acc_filter_alpha", "filter_notch_freq", "filter_notch_bw",
    "fil_amb", "fil_amb_min",
    "roll_kp", "roll_ki", "roll_kd", "pitch_kp", "pitch_ki", "pitch_kd", "yaw_kp", "yaw_ki", "yaw_kd", "vz_kp", "vz_ki", "vz_kd",
    "cal_gyro", "cal_acc", "cal_lid", "cal_mag",
    "test_mpu", "test_sx", "test_lidar", "test_motor", "test_pid", "test_rc", "test_rc_can",
    "rc_cal_sticks", "rc_tx_deadband", "rc_proto", "tx_power_mw",
    "rtx_en", "rtx_band", "rtx_amp_tier", "ant_combo_config", "rtx_hw_crc_en", "rtx_sw_crc_en", "rtx_addr_en", "rtx_addr", "rtx_sync_word", "rtx_lbt_en", "rtx_iq_inv", "rtx_afc_en",
    "rtx_pri_chan", "rtx_pri_sf", "rtx_pri_bw", "rtx_pri_cr", "rtx_pri_power", "rtx_pri_fade",
    "rtx_bak_chan", "rtx_bak_sf", "rtx_bak_bw", "rtx_bak_cr", "rtx_bak_power", "rtx_bak_fade",
    "ant_sleeve_en", "ant_sleeve_thick", "ant_tube_diam", "ant_top_wire", "ant_kharc_wire",
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
        _suggestions = _cliCommands.where((cmd) => cmd.toLowerCase().contains(text.toLowerCase())).toList();
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
    if (val.isNotEmpty) {
      SerialService.sendCommand(val);
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
                child: Text(_displayLog, style: const TextStyle(fontFamily: 'monospace', color: Colors.greenAccent, fontSize: 11)),
              ),
            ),
          ),
          if (_suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 13),
              constraints: const BoxConstraints(maxHeight: 150),
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
                      _controller.selection = TextSelection.fromPosition(TextPosition(offset: item.length));
                      setState(() => _suggestions = []);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                      child: Text(item, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
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
                    style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                    decoration: const InputDecoration(hintText: "Enter CLI command..."),
                    onSubmitted: _submitCommand,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 44,
                  width: 44,
                  child: IconButton.filled(
                    onPressed: () => SerialService.sendCommand("info"),
                    icon: const Icon(Icons.info_outline, size: 18, color: Colors.white),
                    tooltip: "Read Config Info",
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 44,
                  width: 44,
                  child: IconButton.filled(
                    onPressed: () {
                      SerialService.terminalLog = "";
                      SerialService.logController.add("");
                    },
                    icon: const Icon(Icons.cleaning_services, size: 18, color: Colors.white),
                    tooltip: "Clear Log",
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                  onPressed: () => _submitCommand(_controller.text),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.all(12),
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
