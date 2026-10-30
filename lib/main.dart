import 'package:flutter/material.dart';
import 'package:usb_serial/usb_serial.dart';
import 'dart:async';
import 'dart:typed_data';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FPV Drone Configurator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          surface: const Color(0xFF121212),
          primary: Colors.blueAccent,
          secondary: Colors.amberAccent,
          error: Colors.redAccent.shade700,
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        cardTheme: CardTheme(
          color: const Color(0xFF1E1E1E),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: const MainContainer(),
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
  final List<Widget> _tabs = [
    const TerminalTab(),
    const SettingsTab(),
    const CommandsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const DroneStatusHeader(),
          Expanded(child: _tabs[_currentIndex]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.terminal_outlined),
            selectedIcon: Icon(Icons.terminal),
            label: 'Terminal',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Settings',
          ),
          NavigationDestination(
            icon: Icon(Icons.gamepad_outlined),
            selectedIcon: Icon(Icons.gamepad),
            label: 'Commands',
          ),
        ],
      ),
    );
  }
}

class UsbService {
  static UsbPort? port;
  static String lastResponse = ">> Ready. Connect drone via OTG.";
  static String terminalLog = "";
  static StreamController<String> logController = StreamController.broadcast();

  static Future<void> sendCommand(String cmd) async {
    if (port != null) {
      await port!.write(Uint8List.fromList('$cmd\n'.codeUnits));
      terminalLog += ">> $cmd\n";
      logController.add(terminalLog);
    } else {
      terminalLog += ">> ERROR: Port not connected\n";
      logController.add(terminalLog);
    }
  }

  static void handleIncomingData(String incoming) {
    terminalLog += incoming;
    List<String> lines = incoming.trim().split('\n');
    if (lines.isNotEmpty) {
      lastResponse = lines.last.trim();
    }
    logController.add(terminalLog);
  }
}

class DroneStatusHeader extends StatefulWidget {
  const DroneStatusHeader({super.key});

  @override
  State<DroneStatusHeader> createState() => _DroneStatusHeaderState();
}

class _DroneStatusHeaderState extends State<DroneStatusHeader> {
  String _displayResponse = UsbService.lastResponse;
  late StreamSubscription<String> _sub;

  @override
  void initState() {
    super.initState();
    _sub = UsbService.logController.stream.listen((_) {
      setState(() {
        _displayResponse = UsbService.lastResponse;
      });
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(Icons.sensors, color: Colors.amberAccent, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _displayResponse,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Colors.greenAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TerminalTab extends StatefulWidget {
  const TerminalTab({super.key});

  @override
  State<TerminalTab> createState() => _TerminalTabState();
}

class _TerminalTabState extends State<TerminalTab> {
  final TextEditingController _cmdController = TextEditingController();
  late StreamSubscription<String> _sub;
  String _displayLog = "";

  @override
  void initState() {
    super.initState();
    _displayLog = UsbService.terminalLog;
    _sub = UsbService.logController.stream.listen((log) {
      setState(() => _displayLog = log);
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    _cmdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => UsbService.sendCommand("info"),
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text("Read Config Info"),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: SingleChildScrollView(
              reverse: true,
              child: Text(
                _displayLog,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Colors.greenAccent,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cmdController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: "Enter CLI command...",
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (val) {
                    if (val.isNotEmpty) {
                      UsbService.sendCommand(val);
                      _cmdController.clear();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.send_rounded, size: 18),
                onPressed: () {
                  if (_cmdController.text.isNotEmpty) {
                    UsbService.sendCommand(_cmdController.text);
                    _cmdController.clear();
                  }
                },
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ==========================================
// РАЗДЕЛ 2: Абсолютно все настройки дрона
// ==========================================
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  // 1. Полетные режимы и лимиты
  double _flightMode = 0; // 0: Angle, 1: Horizon, 2: Acro
  double _angleMax = 20.0;
  double _vzMax = 1.2;

  // 2. RC & Rates
  double _deadband = 20.0;
  double _rcSmooth = 0.30;
  double _rcRate = 0.40, _superExpo = 0.05, _stickExpo = 0.50;
  double _yawRcRate = 0.35, _yawSuperExpo = 0.05, _yawExpo = 0.40;

  // 3. Фильтры
  double _filterMode = 3; // 0: Off, 1: LPF, 2: LPF+Notch, 3: DynNotch
  double _lpfGyro = 0.40;
  double _lpfAccel = 0.15;
  double _notchFreq = 65.0;
  double _dynNotchMin = 45.0, _dynNotchMax = 120.0;

  // 4. Питание и безопасность
  double _fsBatt = 14.0;
  double _cells = 4; // 0: Auto, 2-6
  double _fsSpeed = 0.8;

  // 5. ПИД-регуляторы
  double _rollP = 0.50, _rollI = 0.015, _rollD = 0.02;
  double _pitchP = 0.50, _pitchI = 0.015, _pitchD = 0.02;
  double _yawP = 0.65, _yawI = 0.010, _yawD = 0.0;
  double _vzP = 7.5, _vzI = 1.3, _vzD = 0.35;

  Widget _buildSliderCard({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String unit,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${value.toStringAsFixed(value.truncate() == value ? 0 : 2)} $unit",
                    style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
                onChangeEnd: onChangeEnd,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12.0),
      children: [
        // --- 1. FLIGHT MODES & LIMITS ---
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text("FLIGHT MODES & LIMITS", style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
        _buildSliderCard(
          title: "Flight Mode (0:Angle, 1:Horizon, 2:Acro)",
          value: _flightMode, min: 0, max: 2, divisions: 2, unit: "",
          onChanged: (val) => setState(() => _flightMode = val),
          onChangeEnd: (val) => UsbService.sendCommand("mode ${val.round()}"),
        ),
        _buildSliderCard(
          title: "Max Angle (angle_max)",
          value: _angleMax, min: 10.0, max: 80.0, divisions: 14, unit: "deg",
          onChanged: (val) => setState(() => _angleMax = val),
          onChangeEnd: (val) => UsbService.sendCommand("angle_max ${val.round()}"),
        ),
        _buildSliderCard(
          title: "Max Vertical Speed (vz_max)",
          value: _vzMax, min: 0.5, max: 5.0, divisions: 45, unit: "m/s",
          onChanged: (val) => setState(() => _vzMax = val),
          onChangeEnd: (val) => UsbService.sendCommand("vz_max ${val.toStringAsFixed(1)}"),
        ),

        // --- 2. RC & RATES ---
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text("RC & RATES", style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
        _buildSliderCard(
          title: "Stick Deadband (deadband)",
          value: _deadband, min: 0, max: 100, divisions: 100, unit: "us",
          onChanged: (val) => setState(() => _deadband = val),
          onChangeEnd: (val) => UsbService.sendCommand("deadband ${val.round()}"),
        ),
        _buildSliderCard(
          title: "RC Smoothing (rc_smooth)",
          value: _rcSmooth, min: 0.05, max: 1.0, divisions: 19, unit: "",
          onChanged: (val) => setState(() => _rcSmooth = val),
          onChangeEnd: (val) => UsbService.sendCommand("rc_smooth ${val.toStringAsFixed(2)}"),
        ),
        _buildSliderCard(
          title: "Roll/Pitch Rate (rates)",
          value: _rcRate, min: 0.1, max: 2.0, divisions: 19, unit: "",
          onChanged: (val) => setState(() => _rcRate = val),
          onChangeEnd: (val) => UsbService.sendCommand("rates $_rcRate $_superExpo $_stickExpo"),
        ),
        _buildSliderCard(
          title: "Yaw Rate (yaw_rates)",
          value: _yawRcRate, min: 0.1, max: 2.0, divisions: 19, unit: "",
          onChanged: (val) => setState(() => _yawRcRate = val),
          onChangeEnd: (val) => UsbService.sendCommand("yaw_rates $_yawRcRate $_yawSuperExpo $_yawExpo"),
        ),

        // --- 3. FILTERS ---
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text("SENSORS & FILTERS", style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
        _buildSliderCard(
          title: "Filter Mode (0:Off, 1:LPF, 2:Notch, 3:Dyn)",
          value: _filterMode, min: 0, max: 3, divisions: 3, unit: "",
          onChanged: (val) => setState(() => _filterMode = val),
          onChangeEnd: (val) => UsbService.sendCommand("filter ${val.round()}"),
        ),
        _buildSliderCard(
          title: "Gyro LPF Alpha (lpf_gyro)",
          value: _lpfGyro, min: 0.05, max: 1.0, divisions: 19, unit: "",
          onChanged: (val) => setState(() => _lpfGyro = val),
          onChangeEnd: (val) => UsbService.sendCommand("lpf_gyro ${val.toStringAsFixed(2)}"),
        ),
        _buildSliderCard(
          title: "Accel LPF Alpha (lpf_accel)",
          value: _lpfAccel, min: 0.01, max: 1.0, divisions: 99, unit: "",
          onChanged: (val) => setState(() => _lpfAccel = val),
          onChangeEnd: (val) => UsbService.sendCommand("lpf_accel ${val.toStringAsFixed(2)}"),
        ),
        _buildSliderCard(
          title: "Notch Center Freq (notch_freq)",
          value: _notchFreq, min: 20.0, max: 200.0, divisions: 36, unit: "Hz",
          onChanged: (val) => setState(() => _notchFreq = val),
          onChangeEnd: (val) => UsbService.sendCommand("notch_freq ${val.round()}"),
        ),
        _buildSliderCard(
          title: "Dyn Notch Min Hz",
          value: _dynNotchMin, min: 20.0, max: 100.0, divisions: 16, unit: "Hz",
          onChanged: (val) => setState(() => _dynNotchMin = val),
          onChangeEnd: (val) => UsbService.sendCommand("dyn_notch $val $_dynNotchMax"),
        ),
        _buildSliderCard(
          title: "Dyn Notch Max Hz",
          value: _dynNotchMax, min: 60.0, max: 200.0, divisions: 28, unit: "Hz",
          onChanged: (val) => setState(() => _dynNotchMax = val),
          onChangeEnd: (val) => UsbService.sendCommand("dyn_notch $_dynNotchMin $val"),
        ),

        // --- 4. POWER & SAFETY ---
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text("POWER & SAFETY", style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
        _buildSliderCard(
          title: "Battery Cells (0: Auto, 2-6)",
          value: _cells, min: 0, max: 6, divisions: 6, unit: "S",
          onChanged: (val) => setState(() => _cells = val),
          onChangeEnd: (val) => UsbService.sendCommand("cells ${val.round()}"),
        ),
        _buildSliderCard(
          title: "Failsafe Voltage (fs_batt)",
          value: _fsBatt, min: 6.0, max: 25.0, divisions: 38, unit: "V",
          onChanged: (val) => setState(() => _fsBatt = val),
          onChangeEnd: (val) => UsbService.sendCommand("fs_batt ${val.toStringAsFixed(1)}"),
        ),
        _buildSliderCard(
          title: "Failsafe Descent Speed (fs_speed)",
          value: _fsSpeed, min: 0.2, max: 3.0, divisions: 28, unit: "m/s",
          onChanged: (val) => setState(() => _fsSpeed = val),
          onChangeEnd: (val) => UsbService.sendCommand("fs_speed ${val.toStringAsFixed(1)}"),
        ),

        // --- 5. PID TUNING ---
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text("PID TUNING (ROLL)", style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
        _buildSliderCard(
          title: "Roll P Gain", value: _rollP, min: 0.0, max: 2.0, divisions: 40, unit: "",
          onChanged: (val) => setState(() => _rollP = val),
          onChangeEnd: (val) => UsbService.sendCommand("pid_roll $val $_rollI $_rollD"),
        ),
        _buildSliderCard(
          title: "Roll I Gain", value: _rollI, min: 0.0, max: 0.1, divisions: 50, unit: "",
          onChanged: (val) => setState(() => _rollI = val),
          onChangeEnd: (val) => UsbService.sendCommand("pid_roll $_rollP $val $_rollD"),
        ),
        _buildSliderCard(
          title: "Roll D Gain", value: _rollD, min: 0.0, max: 0.1, divisions: 50, unit: "",
          onChanged: (val) => setState(() => _rollD = val),
          onChangeEnd: (val) => UsbService.sendCommand("pid_roll $_rollP $_rollI $val"),
        ),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text("PID TUNING (PITCH)", style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
        _buildSliderCard(
          title: "Pitch P Gain", value: _pitchP, min: 0.0, max: 2.0, divisions: 40, unit: "",
          onChanged: (val) => setState(() => _pitchP = val),
          onChangeEnd: (val) => UsbService.sendCommand("pid_pitch $val $_pitchI $_pitchD"),
        ),
        _buildSliderCard(
          title: "Pitch I Gain", value: _pitchI, min: 0.0, max: 0.1, divisions: 50, unit: "",
          onChanged: (val) => setState(() => _pitchI = val),
          onChangeEnd: (val) => UsbService.sendCommand("pid_pitch $_pitchP $val $_pitchD"),
        ),
        _buildSliderCard(
          title: "Pitch D Gain", value: _pitchD, min: 0.0, max: 0.1, divisions: 50, unit: "",
          onChanged: (val) => setState(() => _pitchD = val),
          onChangeEnd: (val) => UsbService.sendCommand("pid_pitch $_pitchP $_pitchI $val"),
        ),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text("PID TUNING (YAW)", style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
        _buildSliderCard(
          title: "Yaw P Gain", value: _yawP, min: 0.0, max: 2.0, divisions: 40, unit: "",
          onChanged: (val) => setState(() => _yawP = val),
          onChangeEnd: (val) => UsbService.sendCommand("pid_yaw $val $_yawI $_yawD"),
        ),
        _buildSliderCard(
          title: "Yaw I Gain", value: _yawI, min: 0.0, max: 0.1, divisions: 50, unit: "",
          onChanged: (val) => setState(() => _yawI = val),
          onChangeEnd: (val) => UsbService.sendCommand("pid_yaw $_yawP $val $_yawD"),
        ),
        _buildSliderCard(
          title: "Yaw D Gain", value: _yawD, min: 0.0, max: 0.1, divisions: 50, unit: "",
          onChanged: (val) => setState(() => _yawD = val),
          onChangeEnd: (val) => UsbService.sendCommand("pid_yaw $_yawP $_yawI $val"),
        ),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text("PID TUNING (THROTTLE VZ)", style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
        _buildSliderCard(
          title: "Vz P Gain", value: _vzP, min: 1.0, max: 20.0, divisions: 38, unit: "",
          onChanged: (val) => setState(() => _vzP = val),
          onChangeEnd: (val) => UsbService.sendCommand("pid_vz $val $_vzI $_vzD"),
        ),
        _buildSliderCard(
          title: "Vz I Gain", value: _vzI, min: 0.0, max: 5.0, divisions: 50, unit: "",
          onChanged: (val) => setState(() => _vzI = val),
          onChangeEnd: (val) => UsbService.sendCommand("pid_vz $_vzP $val $_vzD"),
        ),
        _buildSliderCard(
          title: "Vz D Gain", value: _vzD, min: 0.0, max: 2.0, divisions: 40, unit: "",
          onChanged: (val) => setState(() => _vzD = val),
          onChangeEnd: (val) => UsbService.sendCommand("pid_vz $_vzP $_vzI $val"),
        ),
      ],
    );
  }
}

// ==========================================
// РАЗДЕЛ 3: Команды и тесты
// ==========================================
class CommandsTab extends StatelessWidget {
  const CommandsTab({super.key});

  Widget _buildActionCard(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Material(
      color: const Color(0xFF1E1E1E),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color ?? Colors.blueAccent, size: 28),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
        children: [
          _buildActionCard(
            context,
            title: "Calibrate Gyro",
            subtitle: "Calib sensors (calib)",
            icon: Icons.explore_outlined,
            onTap: () => UsbService.sendCommand("calib"),
          ),
          _buildActionCard(
            context,
            title: "Test Motors",
            subtitle: "Spin motors (test_motor)",
            icon: Icons.bolt,
            color: Colors.amberAccent,
            onTap: () => UsbService.sendCommand("test_motor"),
          ),
          _buildActionCard(
            context,
            title: "Test ESC",
            subtitle: "ESC range (test_esc)",
            icon: Icons.settings_input_component,
            onTap: () => UsbService.sendCommand("test_esc"),
          ),
          _buildActionCard(
            context,
            title: "Test PID Loop",
            subtitle: "Table test (test_pid)",
            icon: Icons.show_chart,
            onTap: () => UsbService.sendCommand("test_pid"),
          ),
          _buildActionCard(
            context,
            title: "Auto Takeoff",
            subtitle: "Demo flight (auto)",
            icon: Icons.flight_takeoff,
            color: Colors.greenAccent,
            onTap: () => UsbService.sendCommand("auto"),
          ),
          _buildActionCard(
            context,
            title: "Factory Reset",
            subtitle: "Clear EEPROM (reset)",
            icon: Icons.warning_amber_rounded,
            color: Colors.redAccent,
            onTap: () => UsbService.sendCommand("reset"),
          ),
        ],
      ),
    );
  }
}
