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
        cardTheme: CardThemeData(
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
        onDestinationSelected: (index) => setState(() => _currentIndex = index,
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

// Глобальный сервис для связи с дроном
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

// Стильная верхняя плашка телеметрии/ответа
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

// ==========================================
// РАЗДЕЛ 1: Терминал
// ==========================================
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
        // Быстрая кнопка Info
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
        // Черное поле терминала
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
        // Поле ввода
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
// РАЗДЕЛ 2: Настройки (Minimalist Cards & Sliders)
// ==========================================
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  double _deadbandVal = 20.0;
  double _lpfGyroVal = 0.4;
  double _lpfAccelVal = 0.15;
  double _fsBattVal = 14.0;
  double _rollPVal = 0.5;

  Widget _buildSliderCard({
    required String title,
    required String commandPrefix,
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
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text("RC & DEADBAND", style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
        _buildSliderCard(
          title: "Stick Deadband",
          commandPrefix: "deadband",
          value: _deadbandVal,
          min: 0,
          max: 100,
          divisions: 100,
          unit: "us",
          onChanged: (val) => setState(() => _deadbandVal = val),
          onChangeEnd: (val) => UsbService.sendCommand("deadband ${val.round()}"),
        ),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text("SENSORS & FILTERS", style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
        _buildSliderCard(
          title: "Gyro LPF Alpha (lpf_gyro)",
          commandPrefix: "lpf_gyro",
          value: _lpfGyroVal,
          min: 0.05,
          max: 1.0,
          divisions: 19,
          unit: "",
          onChanged: (val) => setState(() => _lpfGyroVal = val),
          onChangeEnd: (val) => UsbService.sendCommand("lpf_gyro ${val.toStringAsFixed(2)}"),
        ),
        _buildSliderCard(
          title: "Accel LPF Alpha (lpf_accel)",
          commandPrefix: "lpf_accel",
          value: _lpfAccelVal,
          min: 0.01,
          max: 1.0,
          divisions: 99,
          unit: "",
          onChanged: (val) => setState(() => _lpfAccelVal = val),
          onChangeEnd: (val) => UsbService.sendCommand("lpf_accel ${val.toStringAsFixed(2)}"),
        ),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text("PID TUNING", style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
        _buildSliderCard(
          title: "Roll P Gain",
          commandPrefix: "pid_roll",
          value: _rollPVal,
          min: 0.0,
          max: 2.0,
          divisions: 40,
          unit: "",
          onChanged: (val) => setState(() => _rollPVal = val),
          onChangeEnd: (val) => UsbService.sendCommand("pid_roll $val 0.015 0.02"),
        ),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text("POWER & SAFETY", style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
        _buildSliderCard(
          title: "Failsafe Voltage (fs_batt)",
          commandPrefix: "fs_batt",
          value: _fsBattVal,
          min: 6.0,
          max: 25.0,
          divisions: 38,
          unit: "V",
          onChanged: (val) => setState(() => _fsBattVal = val),
          onChangeEnd: (val) => UsbService.sendCommand("fs_batt ${val.toStringAsFixed(1)}"),
        ),
      ],
    );
  }
}

// ==========================================
// РАЗДЕЛ 3: Команды и тесты (Grid Buttons)
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

