import 'package:flutter/material.dart';
import 'package:usb_serial/usb_serial.dart';
import 'package:flutter_cube/flutter_cube.dart';
import 'dart:async';
import 'dart:typed_data';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FPV Drone Configurator (CD v.2.0)',
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
    const ThreeDViewTab(),
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
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
          NavigationDestination(
            icon: Icon(Icons.threed_rotation),
            selectedIcon: Icon(Icons.view_in_ar),
            label: '3D View',
          ),
        ],
      ),
    );
  }
}

class UsbService {
  static UsbPort? port;
  static String lastResponse = ">> Ready. Connect USB device.";
  static String terminalLog = "";
  static StreamController<String> logController = StreamController.broadcast();
  static StreamSubscription<Uint8List>? _subscription;

  static double gyroRoll = 0.0, gyroPitch = 0.0, gyroYaw = 0.0;
  static double accelX = 0.0, accelY = 0.0, accelZ = 1.0;
  static double motor1 = 0.0, motor2 = 0.0, motor3 = 0.0, motor4 = 0.0;
  static double batteryVoltage = 16.2;

  static StreamController<void> telemetryController = StreamController.broadcast();

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

  static void handleIncomingData(Uint8List data) {
    String incoming = String.fromCharCodes(data);
    terminalLog += incoming;
    List<String> lines = incoming.trim().split('\n');
    if (lines.isNotEmpty) lastResponse = lines.last.trim();
    logController.add(terminalLog);
    telemetryController.add(null);
  }
}

class DroneStatusHeader extends StatefulWidget {
  const DroneStatusHeader({super.key});

  @override
  State<DroneStatusHeader> createState() => _DroneStatusHeaderState();
}

class _DroneStatusHeaderState extends State<DroneStatusHeader> {
  String _displayResponse = UsbService.lastResponse;
  bool _isConnected = false;
  List<UsbDevice> _devices = [];
  late StreamSubscription<String> _sub;

  @override
  void initState() {
    super.initState();
    _scanDevices();
    _sub = UsbService.logController.stream.listen((_) => setState(() => _displayResponse = UsbService.lastResponse));
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  Future<void> _scanDevices() async {
    _devices = await UsbSerial.listDevices();
    setState(() {});
  }

  Future<void> _toggleConnection() async {
    if (_isConnected) {
      await UsbService._subscription?.cancel();
      await UsbService.port?.close();
      UsbService.port = null;
      setState(() {
        _isConnected = false;
        UsbService.lastResponse = ">> Disconnected";
      });
    } else {
      await _scanDevices();
      if (_devices.isEmpty) {
        setState(() => UsbService.lastResponse = ">> No USB devices found");
        return;
      }
      UsbService.port = await _devices[0].create();
      bool openResult = await UsbService.port!.open();
      if (!openResult) {
        setState(() => UsbService.lastResponse = ">> Failed to open USB port");
        return;
      }
      await UsbService.port!.setPortParameters(115200, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);
      setState(() {
        _isConnected = true;
        UsbService.lastResponse = ">> Connected to ${_devices[0].deviceName}";
      });
      UsbService._subscription = UsbService.port!.inputStream!.listen((data) => UsbService.handleIncomingData(data));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFF161616), border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05)))),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(Icons.sensors, color: _isConnected ? Colors.greenAccent : Colors.amberAccent, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(_displayResponse, style: const TextStyle(fontFamily: 'monospace', color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            SizedBox(
              height: 32,
              child: ElevatedButton.icon(
                onPressed: _toggleConnection,
                icon: Icon(_isConnected ? Icons.link_off : Icons.link, size: 14),
                label: Text(_isConnected ? "Disconnect" : "Connect", style: const TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(backgroundColor: _isConnected ? Colors.red.shade900 : Colors.blueAccent, padding: const EdgeInsets.symmetric(horizontal: 10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ThreeDViewTab extends StatefulWidget {
  const ThreeDViewTab({super.key});

  @override
  State<ThreeDViewTab> createState() => _ThreeDViewTabState();
}

class _ThreeDViewTabState extends State<ThreeDViewTab> {
  Object? droneModel;
  late StreamSubscription<void> _telemetrySub;

  @override
  void initState() {
    super.initState();
    _telemetrySub = UsbService.telemetryController.stream.listen((_) {
      if (droneModel != null) {
        droneModel!.rotation.x = UsbService.gyroPitch;
        droneModel!.rotation.y = UsbService.gyroYaw;
        droneModel!.rotation.z = UsbService.gyroRoll;
        droneModel!.updateTransform();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _telemetrySub.cancel();
    super.dispose();
  }

  Widget _buildSensorBar(String label, double value, double min, double max, String unit, Color color) {
    double percent = ((value - min) / (max - min)).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
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
          const SizedBox(height: 3),
          LinearProgressIndicator(value: percent, color: color, backgroundColor: Colors.white12, minHeight: 6, borderRadius: BorderRadius.circular(3)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.08))),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Cube(onSceneCreated: (Scene scene) {
                scene.world.add(Object(fileName: 'assets/drone.obj', lighting: true));
                if (scene.world.children.isNotEmpty) {
                  droneModel = scene.world.children.first;
                  droneModel!.scale.setValues(1.5, 1.5, 1.5);
                }
                scene.camera.zoom = 5.0;
              }),
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const Text("GYROSCOPE", style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                const SizedBox(height: 4),
                _buildSensorBar("Gyro Roll", UsbService.gyroRoll, -3.14, 3.14, "rad/s", Colors.blueAccent),
                _buildSensorBar("Gyro Pitch", UsbService.gyroPitch, -3.14, 3.14, "rad/s", Colors.blueAccent),
                _buildSensorBar("Gyro Yaw", UsbService.gyroYaw, -3.14, 3.14, "rad/s", Colors.blueAccent),
                
                const SizedBox(height: 8),
                const Text("ACCELEROMETER", style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                const SizedBox(height: 4),
                _buildSensorBar("Accel X", UsbService.accelX, -2.0, 2.0, "G", Colors.cyanAccent),
                _buildSensorBar("Accel Y", UsbService.accelY, -2.0, 2.0, "G", Colors.cyanAccent),
                _buildSensorBar("Accel Z", UsbService.accelZ, -2.0, 2.0, "G", Colors.cyanAccent),

                const SizedBox(height: 8),
                const Text("MOTORS OUTPUTS", style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                const SizedBox(height: 4),
                _buildSensorBar("Motor 1 (Front-Left)", UsbService.motor1, 0, 100, "%", Colors.orangeAccent),
                _buildSensorBar("Motor 2 (Front-Right)", UsbService.motor2, 0, 100, "%", Colors.orangeAccent),
                _buildSensorBar("Motor 3 (Back-Right)", UsbService.motor3, 0, 100, "%", Colors.orangeAccent),
                _buildSensorBar("Motor 4 (Back-Left)", UsbService.motor4, 0, 100, "%", Colors.orangeAccent),

                const SizedBox(height: 8),
                const Text("POWER SYSTEM", style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                const SizedBox(height: 4),
                _buildSensorBar("Battery Voltage", UsbService.batteryVoltage, 10.0, 25.2, "V", Colors.greenAccent),
              ],
            ),
          ),
        ),
      ],
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
    _sub = UsbService.logController.stream.listen((log) => setState(() => _displayLog = log));
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
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.08))),
            child: SingleChildScrollView(
              reverse: true,
              child: Text(_displayLog, style: const TextStyle(fontFamily: 'monospace', color: Colors.greenAccent, fontSize: 12)),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
                style: IconButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.all(14)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ==========================================
// ВКЛАДКА НАСТРОЕК (Полная карта параметров EEPROM)
// ==========================================
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  // 1. Gyro Biases
  double _gyroBiasX = 0.0, _gyroBiasY = 0.0, _gyroBiasZ = 0.0;
  // 2. Temp Coefficients
  double _tempCoeffX = 0.5, _tempCoeffY = 0.5, _tempCoeffZ = 0.2;
  // 3. Accel Biases
  double _accelBiasX = 0.0, _accelBiasY = 0.0, _accelBiasZ = 0.0;
  // 4. Flight & System Modes
  double _flightMode = 0;
  double _filterMode = 3;
  double _dynamicNotchEnabled = 1;
  // 5. Failsafe & Battery Flags/Configs
  double _fsRcEn = 1;
  double _fsBattEn = 1;
  double _batteryCells = 4.0;
  double _battFsV = 14.0;
  // 6. Filters (LPF & Notch)
  double _lpfGyro = 0.40;
  double _lpfAccel = 0.15;
  double _notchCenterFreq = 65.0;
  double _notchBandwidth = 18.0;
  double _dynNotchMinHz = 45.0;
  double _dynNotchMaxHz = 120.0;
  // 7. Horizon Trainer & Transition
  double _horizonTransition = 0.75;
  double _horizonTrainerGain = 0.15;
  double _horizonTrainerDead = 0.05;
  // 8. RC Rates & Expo
  double _rcRate = 0.40, _superExpo = 0.05, _stickExpo = 0.50;
  double _yawRcRate = 0.35, _yawSuperExpo = 0.05, _yawExpo = 0.40;
  double _deadband = 20.0;
  double _rcSmoothingAlpha = 0.30;
  // 9. Limits & Speeds
  double _maxAngleDeg = 20.0;
  double _maxVz = 1.2;
  double _fsSpeed = 0.8;
  // 10. PIDs (Roll, Pitch, Yaw, VZ -> Kp, Ki, Kd)
  double _rollKp = 0.50, _rollKi = 0.015, _rollKd = 0.02;
  double _pitchKp = 0.50, _pitchKi = 0.015, _pitchKd = 0.02;
  double _yawKp = 0.65, _yawKi = 0.010, _yawKd = 0.0;
  double _vzKp = 7.5, _vzKi = 1.3, _vzKd = 0.35;

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.amberAccent),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.amberAccent,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderCard({
    required String title,
    required String subtitleCommand,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String unit,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(subtitleCommand, style: TextStyle(color: Colors.amberAccent.withOpacity(0.8), fontSize: 11, fontFamily: 'monospace')),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text("${value.toStringAsFixed(value.truncate() == value ? 0 : 3)} $unit", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged, onChangeEnd: onChangeEnd),
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
        _buildSectionHeader("GYRO BIASES", Icons.explore),
        _buildSliderCard(title: "Gyro Bias X", subtitleCommand: "(gyro_bias_x)", value: _gyroBiasX, min: -500, max: 500, divisions: 100, unit: "raw", onChanged: (v) => setState(() => _gyroBiasX = v), onChangeEnd: (v) => UsbService.sendCommand("gyro_bias_x $v")),
        _buildSliderCard(title: "Gyro Bias Y", subtitleCommand: "(gyro_bias_y)", value: _gyroBiasY, min: -500, max: 500, divisions: 100, unit: "raw", onChanged: (v) => setState(() => _gyroBiasY = v), onChangeEnd: (v) => UsbService.sendCommand("gyro_bias_y $v")),
        _buildSliderCard(title: "Gyro Bias Z", subtitleCommand: "(gyro_bias_z)", value: _gyroBiasZ, min: -500, max: 500, divisions: 100, unit: "raw", onChanged: (v) => setState(() => _gyroBiasZ = v), onChangeEnd: (v) => UsbService.sendCommand("gyro_bias_z $v")),

        _buildSectionHeader("TEMP COEFFICIENTS", Icons.thermostat),
        _buildSliderCard(title: "Temp Coeff X", subtitleCommand: "(temp_coeff_x)", value: _tempCoeffX, min: 0.0, max: 2.0, divisions: 20, unit: "", onChanged: (v) => setState(() => _tempCoeffX = v), onChangeEnd: (v) => UsbService.sendCommand("temp_coeff_x $v")),
        _buildSliderCard(title: "Temp Coeff Y", subtitleCommand: "(temp_coeff_y)", value: _tempCoeffY, min: 0.0, max: 2.0, divisions: 20, unit: "", onChanged: (v) => setState(() => _tempCoeffY = v), onChangeEnd: (v) => UsbService.sendCommand("temp_coeff_y $v")),
        _buildSliderCard(title: "Temp Coeff Z", subtitleCommand: "(temp_coeff_z)", value: _tempCoeffZ, min: 0.0, max: 2.0, divisions: 20, unit: "", onChanged: (v) => setState(() => _tempCoeffZ = v), onChangeEnd: (v) => UsbService.sendCommand("temp_coeff_z $v")),

        _buildSectionHeader("ACCEL BIASES", Icons.speed),
        _buildSliderCard(title: "Accel Bias X", subtitleCommand: "(accel_bias_x)", value: _accelBiasX, min: -1000, max: 1000, divisions: 100, unit: "raw", onChanged: (v) => setState(() => _accelBiasX = v), onChangeEnd: (v) => UsbService.sendCommand("accel_bias_x $v")),
        _buildSliderCard(title: "Accel Bias Y", subtitleCommand: "(accel_bias_y)", value: _accelBiasY, min: -1000, max: 1000, divisions: 100, unit: "raw", onChanged: (v) => setState(() => _accelBiasY = v), onChangeEnd: (v) => UsbService.sendCommand("accel_bias_y $v")),
        _buildSliderCard(title: "Accel Bias Z", subtitleCommand: "(accel_bias_z)", value: _accelBiasZ, min: -1000, max: 1000, divisions: 100, unit: "raw", onChanged: (v) => setState(() => _accelBiasZ = v), onChangeEnd: (v) => UsbService.sendCommand("accel_bias_z $v")),

        _buildSectionHeader("FLIGHT & SYSTEM MODES", Icons.flight),
        _buildSliderCard(title: "Flight Mode", subtitleCommand: "(mode)", value: _flightMode, min: 0, max: 2, divisions: 2, unit: "", onChanged: (v) => setState(() => _flightMode = v), onChangeEnd: (v) => UsbService.sendCommand("mode ${v.round()}")),
        _buildSliderCard(title: "Filter Mode", subtitleCommand: "(filter)", value: _filterMode, min: 0, max: 3, divisions: 3, unit: "", onChanged: (v) => setState(() => _filterMode = v), onChangeEnd: (v) => UsbService.sendCommand("filter ${v.round()}")),
        _buildSliderCard(title: "Dynamic Notch Enabled", subtitleCommand: "(dyn_notch_en)", value: _dynamicNotchEnabled, min: 0, max: 1, divisions: 1, unit: "", onChanged: (v) => setState(() => _dynamicNotchEnabled = v), onChangeEnd: (v) => UsbService.sendCommand("dyn_notch_en ${v.round()}")),

        _buildSectionHeader("FAILSAFE & BATTERY", Icons.battery_charging_full),
        _buildSliderCard(title: "FS RC Enable", subtitleCommand: "(fs_rc_en)", value: _fsRcEn, min: 0, max: 1, divisions: 1, unit: "", onChanged: (v) => setState(() => _fsRcEn = v), onChangeEnd: (v) => UsbService.sendCommand("fs_rc_en ${v.round()}")),
        _buildSliderCard(title: "FS Batt Enable", subtitleCommand: "(fs_batt_en)", value: _fsBattEn, min: 0, max: 1, divisions: 1, unit: "", onChanged: (v) => setState(() => _fsBattEn = v), onChangeEnd: (v) => UsbService.sendCommand("fs_batt_en ${v.round()}")),
        _buildSliderCard(title: "Battery Cells", subtitleCommand: "(cells)", value: _batteryCells, min: 2, max: 6, divisions: 4, unit: "S", onChanged: (v) => setState(() => _batteryCells = v), onChangeEnd: (v) => UsbService.sendCommand("cells ${v.round()}")),
        _buildSliderCard(title: "Failsafe Battery V", subtitleCommand: "(fs_batt)", value: _battFsV, min: 6.0, max: 25.0, divisions: 19, unit: "V", onChanged: (v) => setState(() => _battFsV = v), onChangeEnd: (v) => UsbService.sendCommand("fs_batt $v")),

        _buildSectionHeader("SENSORS & FILTERS (LPF / NOTCH)", Icons.waves),
        _buildSliderCard(title: "Gyro LPF Alpha", subtitleCommand: "(lpf_gyro)", value: _lpfGyro, min: 0.05, max: 1.0, divisions: 19, unit: "", onChanged: (v) => setState(() => _lpfGyro = v), onChangeEnd: (v) => UsbService.sendCommand("lpf_gyro $v")),
        _buildSliderCard(title: "Accel LPF Alpha", subtitleCommand: "(lpf_accel)", value: _lpfAccel, min: 0.01, max: 1.0, divisions: 19, unit: "", onChanged: (v) => setState(() => _lpfAccel = v), onChangeEnd: (v) => UsbService.sendCommand("lpf_accel $v")),
        _buildSliderCard(title: "Notch Center Frequency", subtitleCommand: "(notch_freq)", value: _notchCenterFreq, min: 20.0, max: 200.0, divisions: 36, unit: "Hz", onChanged: (v) => setState(() => _notchCenterFreq = v), onChangeEnd: (v) => UsbService.sendCommand("notch_freq $v")),
        _buildSliderCard(title: "Notch Bandwidth", subtitleCommand: "(notch_bw)", value: _notchBandwidth, min: 5.0, max: 50.0, divisions: 45, unit: "Hz", onChanged: (v) => setState(() => _notchBandwidth = v), onChangeEnd: (v) => UsbService.sendCommand("notch_bw $v")),
        _buildSliderCard(title: "Dyn Notch Min Hz", subtitleCommand: "(dyn_notch_min)", value: _dynNotchMinHz, min: 20.0, max: 100.0, divisions: 16, unit: "Hz", onChanged: (v) => setState(() => _dynNotchMinHz = v), onChangeEnd: (v) => UsbService.sendCommand("dyn_notch_min $v")),
        _buildSliderCard(title: "Dyn Notch Max Hz", subtitleCommand: "(dyn_notch_max)", value: _dynNotchMaxHz, min: 80.0, max: 200.0, divisions: 24, unit: "Hz", onChanged: (v) => setState(() => _dynNotchMaxHz = v), onChangeEnd: (v) => UsbService.sendCommand("dyn_notch_max $v")),

        _buildSectionHeader("HORIZON TRAINER & TRANSITION", Icons.threesixty),
        _buildSliderCard(title: "Horizon Transition", subtitleCommand: "(horizon_trans)", value: _horizonTransition, min: 0.0, max: 1.0, divisions: 20, unit: "", onChanged: (v) => setState(() => _horizonTransition = v), onChangeEnd: (v) => UsbService.sendCommand("horizon_trans $v")),
        _buildSliderCard(title: "Horizon Trainer Gain", subtitleCommand: "(horizon_gain)", value: _horizonTrainerGain, min: 0.0, max: 1.0, divisions: 20, unit: "", onChanged: (v) => setState(() => _horizonTrainerGain = v), onChangeEnd: (v) => UsbService.sendCommand("horizon_gain $v")),
        _buildSliderCard(title: "Horizon Trainer Dead", subtitleCommand: "(horizon_dead)", value: _horizonTrainerDead, min: 0.0, max: 0.5, divisions: 25, unit: "", onChanged: (v) => setState(() => _horizonTrainerDead = v), onChangeEnd: (v) => UsbService.sendCommand("horizon_dead $v")),

        _buildSectionHeader("RC RATES & STICKS", Icons.gamepad),
        _buildSliderCard(title: "Roll/Pitch RC Rate", subtitleCommand: "(rates)", value: _rcRate, min: 0.1, max: 2.0, divisions: 19, unit: "", onChanged: (v) => setState(() => _rcRate = v), onChangeEnd: (v) => UsbService.sendCommand("rates $v $_superExpo $_stickExpo")),
        _buildSliderCard(title: "Roll/Pitch Super Expo", subtitleCommand: "(rates)", value: _superExpo, min: 0.0, max: 1.0, divisions: 20, unit: "", onChanged: (v) => setState(() => _superExpo = v), onChangeEnd: (v) => UsbService.sendCommand("rates $_rcRate $v $_stickExpo")),
        _buildSliderCard(title: "Roll/Pitch Stick Expo", subtitleCommand: "(rates)", value: _stickExpo, min: 0.0, max: 1.0, divisions: 20, unit: "", onChanged: (v) => setState(() => _stickExpo = v), onChangeEnd: (v) => UsbService.sendCommand("rates $_rcRate $_superExpo $v")),
        _buildSliderCard(title: "Yaw RC Rate", subtitleCommand: "(yaw_rates)", value: _yawRcRate, min: 0.1, max: 2.0, divisions: 19, unit: "", onChanged: (v) => setState(() => _yawRcRate = v), onChangeEnd: (v) => UsbService.sendCommand("yaw_rates $v $_yawSuperExpo $_yawExpo")),
        _buildSliderCard(title: "Yaw Super Expo", subtitleCommand: "(yaw_rates)", value: _yawSuperExpo, min: 0.0, max: 1.0, divisions: 20, unit: "", onChanged: (v) => setState(() => _yawSuperExpo = v), onChangeEnd: (v) => UsbService.sendCommand("yaw_rates $_yawRcRate $v $_yawExpo")),
        _buildSliderCard(title: "Yaw Expo", subtitleCommand: "(yaw_rates)", value: _yawExpo, min: 0.0, max: 1.0, divisions: 20, unit: "", onChanged: (v) => setState(() => _yawExpo = v), onChangeEnd: (v) => UsbService.sendCommand("yaw_rates $_yawRcRate $_yawSuperExpo $v")),
        _buildSliderCard(title: "Stick Deadband", subtitleCommand: "(deadband)", value: _deadband, min: 0, max: 100, divisions: 20, unit: "us", onChanged: (v) => setState(() => _deadband = v), onChangeEnd: (v) => UsbService.sendCommand("deadband $v")),
        _buildSliderCard(title: "RC Smoothing Alpha", subtitleCommand: "(rc_smooth)", value: _rcSmoothingAlpha, min: 0.05, max: 1.0, divisions: 19, unit: "", onChanged: (v) => setState(() => _rcSmoothingAlpha = v), onChangeEnd: (v) => UsbService.sendCommand("rc_smooth $v")),

        _buildSectionHeader("FLIGHT LIMITS", Icons.speed_outlined),
        _buildSliderCard(title: "Max Angle", subtitleCommand: "(angle_max)", value: _maxAngleDeg, min: 10, max: 80, divisions: 14, unit: "deg", onChanged: (v) => setState(() => _maxAngleDeg = v), onChangeEnd: (v) => UsbService.sendCommand("angle_max ${v.round()}")),
        _buildSliderCard(title: "Max Vertical Speed", subtitleCommand: "(vz_max)", value: _maxVz, min: 0.5, max: 5.0, divisions: 9, unit: "m/s", onChanged: (v) => setState(() => _maxVz = v), onChangeEnd: (v) => UsbService.sendCommand("vz_max $v")),
        _buildSliderCard(title: "Failsafe Descent Speed", subtitleCommand: "(fs_speed)", value: _fsSpeed, min: 0.2, max: 3.0, divisions: 14, unit: "m/s", onChanged: (v) => setState(() => _fsSpeed = v), onChangeEnd: (v) => UsbService.sendCommand("fs_speed $v")),

        _buildSectionHeader("PID CONTROLLERS (ROLL, PITCH, YAW, VZ)", Icons.tune),
        _buildSliderCard(title: "Roll P Gain", subtitleCommand: "(pid_roll)", value: _rollKp, min: 0, max: 2, divisions: 40, unit: "P", onChanged: (v) => setState(() => _rollKp = v), onChangeEnd: (v) => UsbService.sendCommand("pid_roll $v $_rollKi $_rollKd")),
        _buildSliderCard(title: "Roll I Gain", subtitleCommand: "(pid_roll)", value: _rollKi, min: 0, max: 0.1, divisions: 20, unit: "I", onChanged: (v) => setState(() => _rollKi = v), onChangeEnd: (v) => UsbService.sendCommand("pid_roll $_rollKp $v $_rollKd")),
        _buildSliderCard(title: "Roll D Gain", subtitleCommand: "(pid_roll)", value: _rollKd, min: 0, max: 0.1, divisions: 20, unit: "D", onChanged: (v) => setState(() => _rollKd = v), onChangeEnd: (v) => UsbService.sendCommand("pid_roll $_rollKp $_rollKi $v")),

        _buildSliderCard(title: "Pitch P Gain", subtitleCommand: "(pid_pitch)", value: _pitchKp, min: 0, max: 2, divisions: 40, unit: "P", onChanged: (v) => setState(() => _pitchKp = v), onChangeEnd: (v) => UsbService.sendCommand("pid_pitch $v $_pitchKi $_pitchKd")),
        _buildSliderCard(title: "Pitch I Gain", subtitleCommand: "(pid_pitch)", value: _pitchKi, min: 0, max: 0.1, divisions: 20, unit: "I", onChanged: (v) => setState(() => _pitchKi = v), onChangeEnd: (v) => UsbService.sendCommand("pid_pitch $_pitchKp $v $_pitchKd")),
        _buildSliderCard(title: "Pitch D Gain", subtitleCommand: "(pid_pitch)", value: _pitchKd, min: 0, max: 0.1, divisions: 20, unit: "D", onChanged: (v) => setState(() => _pitchKd = v), onChangeEnd: (v) => UsbService.sendCommand("pid_pitch $_pitchKp $_pitchKi $v")),

        _buildSliderCard(title: "Yaw P Gain", subtitleCommand: "(pid_yaw)", value: _yawKp, min: 0, max: 2, divisions: 40, unit: "P", onChanged: (v) => setState(() => _yawKp = v), onChangeEnd: (v) => UsbService.sendCommand("pid_yaw $v $_yawKi $_yawKd")),
        _buildSliderCard(title: "Yaw I Gain", subtitleCommand: "(pid_yaw)", value: _yawKi, min: 0, max: 0.1, divisions: 20, unit: "I", onChanged: (v) => setState(() => _yawKi = v), onChangeEnd: (v) => UsbService.sendCommand("pid_yaw $_yawKp $v $_yawKd")),
        _buildSliderCard(title: "Yaw D Gain", subtitleCommand: "(pid_yaw)", value: _yawKd, min: 0, max: 0.1, divisions: 20, unit: "D", onChanged: (v) => setState(() => _yawKd = v), onChangeEnd: (v) => UsbService.sendCommand("pid_yaw $_yawKp $_yawKi $v")),

        _buildSliderCard(title: "VZ P Gain", subtitleCommand: "(pid_vz)", value: _vzKp, min: 1.0, max: 20.0, divisions: 38, unit: "P", onChanged: (v) => setState(() => _vzKp = v), onChangeEnd: (v) => UsbService.sendCommand("pid_vz $v $_vzKi $_vzKd")),
        _buildSliderCard(title: "VZ I Gain", subtitleCommand: "(pid_vz)", value: _vzKi, min: 0.0, max: 5.0, divisions: 25, unit: "I", onChanged: (v) => setState(() => _vzKi = v), onChangeEnd: (v) => UsbService.sendCommand("pid_vz $_vzKp $v $_vzKd")),
        _buildSliderCard(title: "VZ D Gain", subtitleCommand: "(pid_vz)", value: _vzKd, min: 0.0, max: 2.0, divisions: 20, unit: "D", onChanged: (v) => setState(() => _vzKd = v), onChangeEnd: (v) => UsbService.sendCommand("pid_vz $_vzKp $_vzKi $v")),
      ],
    );
  }
}

class CommandsTab extends StatelessWidget {
  const CommandsTab({super.key});

  Widget _buildActionCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required VoidCallback onTap, Color? color}) {
    return Card(
      color: const Color(0xFF1E1E1E),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color ?? Colors.blueAccent, size: 26),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
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
        childAspectRatio: 1.35,
        children: [
          _buildActionCard(context, title: "Calibrate Gyro", subtitle: "calib", icon: Icons.explore_outlined, onTap: () => UsbService.sendCommand("calib")),
          _buildActionCard(context, title: "Test Motors", subtitle: "test_motor", icon: Icons.bolt, color: Colors.amberAccent, onTap: () => UsbService.sendCommand("test_motor")),
          _buildActionCard(context, title: "Test ESC", subtitle: "test_esc", icon: Icons.settings_input_component, onTap: () => UsbService.sendCommand("test_esc")),
          _buildActionCard(context, title: "Table PID Test", subtitle: "test_pid", icon: Icons.science_outlined, color: Colors.cyanAccent, onTap: () => UsbService.sendCommand("test_pid")),
          _buildActionCard(context, title: "Auto Takeoff", subtitle: "auto", icon: Icons.flight_takeoff, color: Colors.greenAccent, onTap: () => UsbService.sendCommand("auto")),
          _buildActionCard(context, title: "Factory Reset", subtitle: "reset", icon: Icons.warning_amber_rounded, color: Colors.redAccent, onTap: () => UsbService.sendCommand("reset")),
        ],
      ),
    );
  }
}
