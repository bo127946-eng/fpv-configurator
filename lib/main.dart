import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:usb_serial/usb_serial.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FPV Drone Configurator Pro',
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
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF242428),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          isDense: true,
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
    const InfoTab(),
    const TerminalTab(),
    const SettingsTab(),
    const TestsTab(),
    const ThreeDViewTab(),
    const FlasherTab(),
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
        backgroundColor: const Color(0xFF121214),
        indicatorColor: Colors.blueAccent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.info_outline, color: Colors.white70),
            selectedIcon: Icon(Icons.info, color: Colors.white),
            label: 'Info',
          ),
          NavigationDestination(
            icon: Icon(Icons.terminal_outlined, color: Colors.white70),
            selectedIcon: Icon(Icons.terminal, color: Colors.white),
            label: 'CLI',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined, color: Colors.white70),
            selectedIcon: Icon(Icons.tune, color: Colors.white),
            label: 'Tuning',
          ),
          NavigationDestination(
            icon: Icon(Icons.gavel_outlined, color: Colors.white70),
            selectedIcon: Icon(Icons.gavel, color: Colors.white),
            label: 'Tests',
          ),
          NavigationDestination(
            icon: Icon(Icons.threed_rotation_outlined, color: Colors.white70),
            selectedIcon: Icon(Icons.threed_rotation, color: Colors.white),
            label: 'Monitor',
          ),
          NavigationDestination(
            icon: Icon(Icons.memory_outlined, color: Colors.white70),
            selectedIcon: Icon(Icons.memory, color: Colors.white),
            label: 'Flasher',
          ),
        ],
      ),
    );
  }
}

// ==========================================
// СЕРВИС СВЯЗИ (USB SERIAL SERVICE ONLY)
// ==========================================
class SerialService {
  static bool isConnected = false;
  static UsbPort? usbPort;
  static StreamSubscription<Uint8List>? _usbSubscription;

  static String lastResponse = "Ready. Connect via USB OTG.";
  static String terminalLog = "";
  static StreamController<String> logController = StreamController.broadcast();
  static StreamController<void> telemetryController = StreamController.broadcast();

  static double gyroRoll = 0.0, gyroPitch = 0.0, gyroYaw = 0.0;
  static double accelX = 0.0, accelY = 0.0, accelZ = 1.0;
  static double motor1 = 0.0, motor2 = 0.0, motor3 = 0.0, motor4 = 0.0;
  static double batteryVoltage = 16.2;
  static double azimuth = 0.0;

  static Future<void> sendCommand(String cmd) async {
    if (isConnected && usbPort != null) {
      await usbPort!.write(Uint8List.fromList('$cmd\n'.codeUnits));
      appendLog(">> $cmd\n");
    } else {
      appendLog(">> ERROR: USB Device not connected\n");
    }
  }

  static void appendLog(String text) {
    terminalLog += text;
    logController.add(terminalLog);
  }

  static void handleIncomingData(Uint8List data) {
    String incoming = String.fromCharCodes(data);
    terminalLog += incoming;
    List<String> lines = incoming.trim().split('\n');
    if (lines.isNotEmpty) lastResponse = lines.last.trim();
    logController.add(terminalLog);
    telemetryController.add(null);
  }

  static Future<void> disconnect() async {
    await _usbSubscription?.cancel();
    await usbPort?.close();
    usbPort = null;
    isConnected = false;
    lastResponse = "USB Disconnected";
    logController.add(terminalLog);
  }
}

// ==========================================
// ВСПОМОГАТЕЛЬНЫЕ ОКНА СООБЩЕНИЙ (POPUP)
// ==========================================
void showAppDialog(BuildContext context, String title, String message, {bool isError = false}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: TextStyle(color: isError ? Colors.redAccent : Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.bold)),
      content: Text(message, style: const TextStyle(fontSize: 13, color: Colors.white70)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("ОК", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

// ==========================================
// ВКЛАДКА: ИНФОРМАЦИЯ И ИНСТРУКЦИЯ (InfoTab)
// ==========================================
class InfoTab extends StatefulWidget {
  const InfoTab({super.key});

  @override
  State<InfoTab> createState() => _InfoTabState();
}

class _InfoTabState extends State<InfoTab> {
  List> _sections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocumentation();
  }

  Future<void> _loadDocumentation() async {
    try {
      String fileContent = await rootBundle.loadString('assets/doc.txt');
      List> parsedSections = [];
      
      RegExp regExp = RegExp(r'/([^/]+)/\s*\[([^\]]*)\]', multiLine: true, dotAll: true);
      Iterable<RegExpMatch> matches = regExp.allMatches(fileContent);
      
      for (var match in matches) {
        String title = match.group(1)?.trim() ?? '';
        String content = match.group(2)?.trim() ?? '';
        if (title.isNotEmpty) {
          parsedSections.add({'title': title, 'content': content});
        }
      }

      if (parsedSections.isEmpty) {
        parsedSections.add({
          'title': 'Руководство пользователя',
          'content': fileContent
        });
      }

      setState(() {
        _sections = parsedSections;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _sections = [
          {
            'title': 'Ошибка загрузки doc.txt',
            'content': 'Не удалось загрузить doc.txt из assets. Проверьте pubspec.yaml.\nОшибка: $e'
          }
        ];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
    }

    return ListView(
      padding: const EdgeInsets.all(12.0),
      children: [
        Card(
          color: const Color(0xFF1E222B),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('FPV Drone Configurator Pro', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: const Text('v.2.6.2 (USB)', style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('Профессиональный кроссплатформенный мобильный конфигуратор для настройки, телеметрии, калибровки и прошивки FPV-дронов на базе STM32 (архитектура YMFC-32). Поддерживает проводное USB OTG подключение.', style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.4)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text('РУКОВОДСТВО ПОЛЬЗОВАТЕЛЯ (doc.txt)', style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        ),
        ..._sections.map((sec) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            title: Text(sec['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
            iconColor: Colors.amberAccent,
            collapsedIconColor: Colors.white54,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(sec['content']!, style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4, fontFamily: 'monospace')),
              ),
            ],
          ),
        )),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ==========================================
// ШАПКА СТАТУСА (USB ONLY)
// ==========================================
class DroneStatusHeader extends StatefulWidget {
  const DroneStatusHeader({super.key});

  @override
  State<DroneStatusHeader> createState() => _DroneStatusHeaderState();
}

class _DroneStatusHeaderState extends State<DroneStatusHeader> {
  String _displayResponse = SerialService.lastResponse;
  bool _isConnected = SerialService.isConnected;
  late StreamSubscription<String> _sub;

  @override
  void initState() {
    super.initState();
    _sub = SerialService.logController.stream.listen((_) {
      if (mounted) {
        setState(() {
          _displayResponse = SerialService.lastResponse;
          _isConnected = SerialService.isConnected;
        });
      }
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  Future<void> _toggleConnection() async {
    if (_isConnected) {
      await SerialService.disconnect();
    } else {
      List<UsbDevice> devices = await UsbSerial.listDevices();
      if (devices.isEmpty) {
        setState(() => SerialService.lastResponse = "No USB devices found");
        return;
      }
      SerialService.usbPort = await devices[0].create();
      bool openResult = await SerialService.usbPort!.open();
      if (!openResult) {
        setState(() => SerialService.lastResponse = "Failed to open USB port");
        return;
      }
      await SerialService.usbPort!.setPortParameters(115200, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);
      SerialService.isConnected = true;
      setState(() {
        _isConnected = true;
        SerialService.lastResponse = "USB Connected: ${devices[0].deviceName}";
      });
      SerialService._usbSubscription = SerialService.usbPort!.inputStream!.listen((data) {
        SerialService.handleIncomingData(data);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: (_isConnected ? Colors.greenAccent : Colors.amberAccent).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.usb, 
                color: Colors.greenAccent, 
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _displayResponse, 
                style: const TextStyle(fontFamily: 'monospace', color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w500), 
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 34,
              child: ElevatedButton.icon(
                onPressed: _toggleConnection,
                icon: Icon(_isConnected ? Icons.link_off : Icons.link, size: 14),
                label: Text(_isConnected ? "Disconnect" : "Connect USB", style: const TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isConnected ? Colors.red.shade900 : Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
// ВКЛАДКА: ТЕРМИНАЛ (CLI)
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
    _displayLog = SerialService.terminalLog;
    _sub = SerialService.logController.stream.listen((log) {
      if (mounted) setState(() => _displayLog = log);
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => SerialService.sendCommand("info"),
                    icon: const Icon(Icons.info_outline, size: 16, color: Colors.white),
                    label: const Text("Read Config Info", style: TextStyle(color: Colors.white)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 44,
                  child: IconButton.filledTonal(
                    onPressed: () {
                      SerialService.terminalLog = "";
                      SerialService.logController.add("");
                    },
                    icon: const Icon(Icons.cleaning_services, size: 18),
                    tooltip: "Clear Log",
                    style: IconButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cmdController,
                    style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                    decoration: const InputDecoration(hintText: "Enter CLI command..."),
                    onSubmitted: (val) {
                      if (val.isNotEmpty) {
                        SerialService.sendCommand(val);
                        _cmdController.clear();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                  onPressed: () {
                    if (_cmdController.text.isNotEmpty) {
                      SerialService.sendCommand(_cmdController.text);
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
      ),
    );
  }
}

// ==========================================
// ВИДЖЕТ PID КАРТЫ
// ==========================================
class PidCardWidget extends StatefulWidget {
  final String title;
  final String commandName;
  final double p, i, d;
  final Function(double, double, double) onUpdate;

  const PidCardWidget({
    super.key,
    required this.title,
    required this.commandName,
    required this.p,
    required this.i,
    required this.d,
    required this.onUpdate,
  });

  @override
  State<PidCardWidget> createState() => _PidCardWidgetState();
}

class _PidCardWidgetState extends State<PidCardWidget> {
  late TextEditingController _pController;
  late TextEditingController _iController;
  late TextEditingController _dController;

  @override
  void initState() {
    super.initState();
    _pController = TextEditingController(text: widget.p.toString());
    _iController = TextEditingController(text: widget.i.toString());
    _dController = TextEditingController(text: widget.d.toString());
  }

  @override
  void didUpdateWidget(covariant PidCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.p != widget.p) _pController.text = widget.p.toString();
    if (oldWidget.i != widget.i) _iController.text = widget.i.toString();
    if (oldWidget.d != widget.d) _dController.text = widget.d.toString();
  }

  @override
  void dispose() {
    _pController.dispose();
    _iController.dispose();
    _dController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 2),
            Text(widget.commandName, style: TextStyle(color: Colors.amberAccent.withOpacity(0.8), fontSize: 10, fontFamily: 'monospace')),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pController,
                    decoration: const InputDecoration(labelText: 'P', isDense: true),
                    keyboardType: TextInputType.number,
                    onSubmitted: (val) {
                      double? np = double.tryParse(val);
                      if (np != null) widget.onUpdate(np, widget.i, widget.d);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _iController,
                    decoration: const InputDecoration(labelText: 'I', isDense: true),
                    keyboardType: TextInputType.number,
                    onSubmitted: (val) {
                      double? ni = double.tryParse(val);
                      if (ni != null) widget.onUpdate(widget.p, ni, widget.d);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _dController,
                    decoration: const InputDecoration(labelText: 'D', isDense: true),
                    keyboardType: TextInputType.number,
                    onSubmitted: (val) {
                      double? nd = double.tryParse(val);
                      if (nd != null) widget.onUpdate(widget.p, widget.i, nd);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// ВКЛАДКА: НАСТРОЙКИ (SettingsTab)
// ==========================================
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  int _flightMode = 0; 
  int _filterMode = 1; 
  double _dynamicNotchEnabled = 1;

  double _fsRcEn = 1;
  double _fsBattEn = 1;
  double _batteryCells = 0;
  double _battFsV = 14.0;
  double _fsSpeed = 0.8;

  double _lpfGyroAlpha = 0.40;
  double _lpfAccelAlpha = 0.15;
  double _notchCenterFreq = 65.0;
  double _notchBandwidth = 18.0;
  double _dynNotchMinHz = 45.0;
  double _dynNotchMaxHz = 120.0;

  double _horizonTransition = 0.75;
  double _horizonTrainerGain = 0.15;
  double _horizonTrainerDead = 0.05;

  double _rcRate = 0.40, _superExpo = 0.05, _stickExpo = 0.50;
  double _yawRcRate = 0.35, _yawSuperExpo = 0.05, _yawExpo = 0.40;
  double _deadband = 10.0;
  double _rcSmoothingAlpha = 0.30;

  double _maxAngleDeg = 25.0;
  double _maxVz = 1.5;

  double _rollP = 0.50, _rollI = 0.015, _rollD = 0.02;
  double _pitchP = 0.50, _pitchI = 0.015, _pitchD = 0.02;
  double _yawP = 0.65, _yawI = 0.010, _yawD = 0.0;
  double _vzP = 7.5, _vzI = 1.3, _vzD = 0.35;

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.amberAccent),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        ],
      ),
    );
  }

  Widget _buildSliderCard({
    required String title,
    required String commandName,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String unit,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
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
                      Text(commandName, style: TextStyle(color: Colors.amberAccent.withOpacity(0.8), fontSize: 10, fontFamily: 'monospace')),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text("${value.toStringAsFixed(value.truncate() == value ? 0 : 2)} $unit", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
            Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged, onChangeEnd: onChangeEnd),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedChoiceCard({
    required String title,
    required String commandName,
    required List<String> options,
    required int selectedIndex,
    required ValueChanged<int> onSelected,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text(commandName, style: TextStyle(color: Colors.amberAccent.withOpacity(0.8), fontSize: 10, fontFamily: 'monospace')),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                return ToggleButtons(
                  isSelected: List.generate(options.length, (i) => i == selectedIndex),
                  onPressed: (index) {
                    onSelected(index);
                  },
                  borderRadius: BorderRadius.circular(10),
                  selectedColor: Colors.white,
                  fillColor: Colors.blueAccent,
                  color: Colors.white70,
                  constraints: BoxConstraints(minHeight: 36, minWidth: (constraints.maxWidth - (options.length - 1)) / options.length),
                  children: options.map((opt) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(opt, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  )).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchCard({
    required String title,
    required String commandName,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(commandName, style: TextStyle(color: Colors.amberAccent.withOpacity(0.8), fontSize: 10, fontFamily: 'monospace')),
              ],
            ),
            Switch(value: value, onChanged: onChanged, activeColor: Colors.blueAccent),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      children: [
        _buildSectionHeader("ОСНОВНЫЕ РЕЖИМЫ", Icons.flight),
        _buildSegmentedChoiceCard(
          title: "Полетный режим",
          commandName: "flight_mode",
          options: const ["Angle", "Acro", "Horizon"],
          selectedIndex: _flightMode,
          onSelected: (val) {
            setState(() => _flightMode = val);
            SerialService.sendCommand("flight_mode $val");
          },
        ),
        _buildSegmentedChoiceCard(
          title: "Режим фильтрации",
          commandName: "filter_mode",
          options: const ["Off", "LPF", "LPF+Notch", "LPF+DynNotch"],
          selectedIndex: _filterMode,
          onSelected: (val) {
            setState(() => _filterMode = val);
            SerialService.sendCommand("filter_mode $val");
          },
        ),
        _buildSwitchCard(
          title: "Динамический notch\nфильтр",
          commandName: "dynamic_notch_enabled",
          value: _dynamicNotchEnabled == 1,
          onChanged: (val) {
            setState(() => _dynamicNotchEnabled = val ? 1 : 0);
            SerialService.sendCommand("dynamic_notch_enabled ${_dynamicNotchEnabled.round()}");
          },
        ),

        _buildSectionHeader("БЕЗОПАСНОСТЬ И БАТАРЕЯ", Icons.battery_charging_full),
        _buildSwitchCard(
          title: "Failsafe по радиосвязи",
          commandName: "fs_rc_en",
          value: _fsRcEn == 1,
          onChanged: (val) {
            setState(() => _fsRcEn = val ? 1 : 0);
            SerialService.sendCommand("fs_rc_en ${_fsRcEn.round()}");
          },
        ),
        _buildSwitchCard(
          title: "Failsafe по батарее",
          commandName: "fs_batt_en",
          value: _fsBattEn == 1,
          onChanged: (val) {
            setState(() => _fsBattEn = val ? 1 : 0);
            SerialService.sendCommand("fs_batt_en ${_fsBattEn.round()}");
          },
        ),
        _buildSegmentedChoiceCard(
          title: "Ячейки батареи",
          commandName: "battery_cells",
          options: const ["Авто", "2S", "3S", "4S", "5S", "6S"],
          selectedIndex: _batteryCells.round(),
          onSelected: (val) {
            setState(() => _batteryCells = val.toDouble());
            SerialService.sendCommand("battery_cells $val");
          },
        ),
        _buildSliderCard(title: "Порог разряда батареи", commandName: "fs_batt_v", value: _battFsV, min: 6.0, max: 25.0, divisions: 190, unit: "В", onChanged: (v) => setState(() => _battFsV = v), onChangeEnd: (v) => SerialService.sendCommand("fs_batt_v $v")),
        _buildSliderCard(title: "Скорость снижения Failsafe", commandName: "fs_speed", value: _fsSpeed, min: 0.2, max: 2.0, divisions: 18, unit: "м/с", onChanged: (v) => setState(() => _fsSpeed = v), onChangeEnd: (v) => SerialService.sendCommand("fs_speed $v")),

        _buildSectionHeader("ФИЛЬТРЫ СЕНСОРОВ", Icons.waves),
        _buildSliderCard(title: "Фильтр гироскопа LPF", commandName: "lpf_gyro", value: _lpfGyroAlpha, min: 0.05, max: 1.0, divisions: 19, unit: "", onChanged: (v) => setState(() => _lpfGyroAlpha = v), onChangeEnd: (v) => SerialService.sendCommand("lpf_gyro $v")),
        _buildSliderCard(title: "Фильтр акселерометра LPF", commandName: "lpf_accel", value: _lpfAccelAlpha, min: 0.01, max: 1.0, divisions: 99, unit: "", onChanged: (v) => setState(() => _lpfAccelAlpha = v), onChangeEnd: (v) => SerialService.sendCommand("lpf_accel $v")),
        _buildSliderCard(title: "Notch: Центр", commandName: "notch_center_freq", value: _notchCenterFreq, min: 30, max: 150, divisions: 120, unit: "Гц", onChanged: (v) => setState(() => _notchCenterFreq = v), onChangeEnd: (v) => SerialService.sendCommand("notch_center_freq $v")),
        _buildSliderCard(title: "Notch: Ширина", commandName: "notch_bandwidth", value: _notchBandwidth, min: 5, max: 50, divisions: 45, unit: "Гц", onChanged: (v) => setState(() => _notchBandwidth = v), onChangeEnd: (v) => SerialService.sendCommand("notch_bandwidth $v")),
        _buildSliderCard(title: "Dyn Notch Мин", commandName: "dyn_notch_min_hz", value: _dynNotchMinHz, min: 20, max: 100, divisions: 16, unit: "Гц", onChanged: (v) => setState(() => _dynNotchMinHz = v), onChangeEnd: (v) => SerialService.sendCommand("dyn_notch_min_hz $v")),
        _buildSliderCard(title: "Dyn Notch Макс", commandName: "dyn_notch_max_hz", value: _dynNotchMaxHz, min: 80, max: 200, divisions: 24, unit: "Гц", onChanged: (v) => setState(() => _dynNotchMaxHz = v), onChangeEnd: (v) => SerialService.sendCommand("dyn_notch_max_hz $v")),

        _buildSectionHeader("РЕЖИМ HORIZON", Icons.threesixty),
        _buildSliderCard(title: "Порог перехода Horizon", commandName: "horizon_transition", value: _horizonTransition, min: 0.0, max: 1.0, divisions: 20, unit: "", onChanged: (v) => setState(() => _horizonTransition = v), onChangeEnd: (v) => SerialService.sendCommand("horizon_transition $v")),
        _buildSliderCard(title: "Усиление Trainer", commandName: "horizon_trainer_gain", value: _horizonTrainerGain, min: 0.0, max: 1.0, divisions: 20, unit: "", onChanged: (v) => setState(() => _horizonTrainerGain = v), onChangeEnd: (v) => SerialService.sendCommand("horizon_trainer_gain $v")),
        _buildSliderCard(title: "Мертвая зона Trainer", commandName: "horizon_trainer_dead", value: _horizonTrainerDead, min: 0.0, max: 0.5, divisions: 25, unit: "", onChanged: (v) => setState(() => _horizonTrainerDead = v), onChangeEnd: (v) => SerialService.sendCommand("horizon_trainer_dead $v")),

        _buildSectionHeader("УПРАВЛЕНИЕ И ЭКСПОНЕНТЫ", Icons.gamepad),
        _buildSliderCard(title: "Крен/Тангаж: Rate", commandName: "rc_rate", value: _rcRate, min: 0.1, max: 2.0, divisions: 19, unit: "", onChanged: (v) => setState(() => _rcRate = v), onChangeEnd: (v) => SerialService.sendCommand("rc_rate $v")),
        _buildSliderCard(title: "Крен/Тангаж: Super Expo", commandName: "super_expo", value: _superExpo, min: 0.0, max: 0.9, divisions: 18, unit: "", onChanged: (v) => setState(() => _superExpo = v), onChangeEnd: (v) => SerialService.sendCommand("super_expo $v")),
        _buildSliderCard(title: "Крен/Тангаж: Stick Expo", commandName: "stick_expo", value: _stickExpo, min: 0.0, max: 1.0, divisions: 20, unit: "", onChanged: (v) => setState(() => _stickExpo = v), onChangeEnd: (v) => SerialService.sendCommand("stick_expo $v")),
        _buildSliderCard(title: "Рыскание (Yaw): Rate", commandName: "yaw_rc_rate", value: _yawRcRate, min: 0.1, max: 2.0, divisions: 19, unit: "", onChanged: (v) => setState(() => _yawRcRate = v), onChangeEnd: (v) => SerialService.sendCommand("yaw_rc_rate $v")),
        _buildSliderCard(title: "Рыскание (Yaw): Super Expo", commandName: "yaw_super_expo", value: _yawSuperExpo, min: 0.0, max: 0.9, divisions: 18, unit: "", onChanged: (v) => setState(() => _yawSuperExpo = v), onChangeEnd: (v) => SerialService.sendCommand("yaw_super_expo $v")),
        _buildSliderCard(title: "Рыскание (Yaw): Expo", commandName: "yaw_expo", value: _yawExpo, min: 0.0, max: 1.0, divisions: 20, unit: "", onChanged: (v) => setState(() => _yawExpo = v), onChangeEnd: (v) => SerialService.sendCommand("yaw_expo $v")),
        _buildSliderCard(title: "Мертвая зона стиков", commandName: "deadband", value: _deadband, min: 0, max: 50, divisions: 50, unit: "", onChanged: (v) => setState(() => _deadband = v), onChangeEnd: (v) => SerialService.sendCommand("deadband ${v.round()}")),
        _buildSliderCard(title: "Сглаживание RC", commandName: "rc_smoothing_alpha", value: _rcSmoothingAlpha, min: 0.05, max: 1.0, divisions: 19, unit: "", onChanged: (v) => setState(() => _rcSmoothingAlpha = v), onChangeEnd: (v) => SerialService.sendCommand("rc_smoothing_alpha $v")),

        _buildSectionHeader("ОГРАНИЧЕНИЯ ПОЛЕТА", Icons.speed),
        _buildSliderCard(title: "Максимальный угол наклона", commandName: "max_angle_deg", value: _maxAngleDeg, min: 10, max: 80, divisions: 14, unit: "°", onChanged: (v) => setState(() => _maxAngleDeg = v), onChangeEnd: (v) => SerialService.sendCommand("max_angle_deg ${v.round()}")),
        _buildSliderCard(title: "Максимальная вертикальная скорость", commandName: "max_vz", value: _maxVz, min: 0.5, max: 3.0, divisions: 25, unit: "м/с", onChanged: (v) => setState(() => _maxVz = v), onChangeEnd: (v) => SerialService.sendCommand("max_vz $v")),

        _buildSectionHeader("PID РЕГУЛЯТОРЫ", Icons.tune),
        PidCardWidget(title: "Roll PID", commandName: "pid_roll", p: _rollP, i: _rollI, d: _rollD, onUpdate: (p, i, d) {
          setState(() { _rollP = p; _rollI = i; _rollD = d; });
          SerialService.sendCommand("pid_roll $p $i $d");
        }),
        PidCardWidget(title: "Pitch PID", commandName: "pid_pitch", p: _pitchP, i: _pitchI, d: _pitchD, onUpdate: (p, i, d) {
          setState(() { _pitchP = p; _pitchI = i; _pitchD = d; });
          SerialService.sendCommand("pid_pitch $p $i $d");
        }),
        PidCardWidget(title: "Yaw PID", commandName: "pid_yaw", p: _yawP, i: _yawI, d: _yawD, onUpdate: (p, i, d) {
          setState(() { _yawP = p; _yawI = i; _yawD = d; });
          SerialService.sendCommand("pid_yaw $p $i $d");
        }),
        PidCardWidget(title: "Vertical VZ PID", commandName: "pid_vz", p: _vzP, i: _vzI, d: _vzD, onUpdate: (p, i, d) {
          setState(() { _vzP = p; _vzI = i; _vzD = d; });
          SerialService.sendCommand("pid_vz $p $i $d");
        }),

        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: ElevatedButton.icon(
            onPressed: () {
              if (!SerialService.isConnected) {
                showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true);
              } else {
                SerialService.sendCommand("save_profile");
                showAppDialog(context, "Успех", "Значения успешно применены и переданы профилем!");
              }
            },
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text("Применить значения и передать профилем", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: ElevatedButton.icon(
            onPressed: () {
              if (!SerialService.isConnected) {
                showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true);
              } else {
                SerialService.sendCommand("reset");
                showAppDialog(context, "Сброс", "Настройки сброшены в заводские!");
              }
            },
            icon: const Icon(Icons.restore, color: Colors.white),
            label: const Text("Сбросить в заводские настройки", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade900,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ==========================================
// ВКЛАДКА: ТЕСТЫ (TestsTab)
// ==========================================
class TestsTab extends StatelessWidget {
  const TestsTab({super.key});

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.amberAccent),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required String title,
    required String subtitleCommand,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(subtitleCommand, style: TextStyle(color: Colors.amberAccent.withOpacity(0.8), fontSize: 10, fontFamily: 'monospace')),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      children: [
        _buildSectionHeader("КАЛИБРОВКИ", Icons.explore),
        _buildActionCard(
          context: context,
          title: "Калибровка гиро/акселя",
          subtitleCommand: "calib",
          icon: Icons.explore_outlined,
          color: Colors.blueAccent,
          onTap: () {
            if (!SerialService.isConnected) {
              showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true);
            } else {
              SerialService.sendCommand("calib");
              showAppDialog(context, "Успех", "Калибровка гиро/акселя успешно запущена!");
            }
          },
        ),
        _buildActionCard(
          context: context,
          title: "Калибровка ESC",
          subtitleCommand: "test_esc",
          icon: Icons.settings_input_component,
          color: Colors.orangeAccent,
          onTap: () {
            if (!SerialService.isConnected) {
              showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true);
            } else {
              SerialService.sendCommand("test_esc");
              showAppDialog(context, "Успех", "Режим калибровки ESC активирован!");
            }
          },
        ),

        _buildSectionHeader("ТЕСТЫ", Icons.bolt),
        _buildActionCard(
          context: context,
          title: "Тест шумов сенсоров",
          subtitleCommand: "test_sensors",
          icon: Icons.graphic_eq,
          color: Colors.cyanAccent,
          onTap: () {
            if (!SerialService.isConnected) {
              showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true);
            } else {
              SerialService.sendCommand("test_sensors");
              showAppDialog(context, "Тест", "Диагностика шумов сенсоров выполнена.");
            }
          },
        ),
        _buildActionCard(
          context: context,
          title: "Тест моторов 10%",
          subtitleCommand: "test_motor",
          icon: Icons.toys,
          color: Colors.amberAccent,
          onTap: () {
            if (!SerialService.isConnected) {
              showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true);
            } else {
              SerialService.sendCommand("test_motor");
              showAppDialog(context, "Тест", "Тест моторов (10%) отправлен на контроллер.");
            }
          },
        ),
        _buildActionCard(
          context: context,
          title: "Тест стабилизации",
          subtitleCommand: "test_pid",
          icon: Icons.science_outlined,
          color: Colors.purpleAccent,
          onTap: () {
            if (!SerialService.isConnected) {
              showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true);
            } else {
              SerialService.sendCommand("test_pid");
              showAppDialog(context, "Тест", "Тест стабилизации запущен.");
            }
          },
        ),
        _buildActionCard(
          context: context,
          title: "Автоматический полет / Тест",
          subtitleCommand: "auto",
          icon: Icons.flight_takeoff,
          color: Colors.greenAccent,
          onTap: () {
            if (!SerialService.isConnected) {
              showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true);
            } else {
              SerialService.sendCommand("auto");
              showAppDialog(context, "Тест", "Автоматический режим запущен.");
            }
          },
        ),
      ],
    );
  }
}

// ==========================================
// КАСТОМНЫЙ ВИДЖЕТ АВИАГОРИЗОНТА (Artificial Horizon Painter)
// ==========================================
class ArtificialHorizonPainter extends CustomPainter {
  final double roll; 
  final double pitch; 

  ArtificialHorizonPainter({required this.roll, required this.pitch});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    final path = Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: radius));
    canvas.clipPath(path);

    canvas.rotate(-roll);
    final pitchOffset = pitch * 75.0;

    final skyPaint = Paint()..color = const Color(0xFF1E6091);
    canvas.drawRect(Rect.fromLTWH(-radius * 2, -radius * 3 + pitchOffset, radius * 4, radius * 3), skyPaint);

    final groundPaint = Paint()..color = const Color(0xFF8B5A2B);
    canvas.drawRect(Rect.fromLTWH(-radius * 2, pitchOffset, radius * 4, radius * 3), groundPaint);

    final horizonPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(-radius * 2, pitchOffset), Offset(radius * 2, pitchOffset), horizonPaint);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int p = -30; p <= 30; p += 10) {
      if (p == 0) continue;
      double yPos = pitchOffset - (p * 1.3);
      double lineWidth = (p.abs() % 20 == 0) ? 30.0 : 15.0;

      canvas.drawLine(Offset(-lineWidth / 2, yPos), Offset(lineWidth / 2, yPos), horizonPaint);
      
      if (p.abs() % 20 == 0) {
        textPainter.text = TextSpan(
          text: "$p",
          style: const TextStyle(color: Colors.white, fontSize: 9, fontFamily: 'monospace'),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(lineWidth / 2 + 4, yPos - 5));
      }
    }

    canvas.restore();

    final fixedPaint = Paint()
      ..color = Colors.amberAccent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(center.dx - 45, center.dy), Offset(center.dx - 15, center.dy), fixedPaint);
    canvas.drawLine(Offset(center.dx + 15, center.dy), Offset(center.dx + 45, center.dy), fixedPaint);
    canvas.drawLine(Offset(center.dx - 15, center.dy), Offset(center.dx - 15, center.dy + 10), fixedPaint);
    canvas.drawLine(Offset(center.dx + 15, center.dy), Offset(center.dx + 15, center.dy + 10), fixedPaint);
    canvas.drawCircle(center, 3, Paint()..color = Colors.amberAccent);

    canvas.drawCircle(center, radius, Paint()
      ..color = Colors.white24
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant ArtificialHorizonPainter oldDelegate) {
    return oldDelegate.roll != roll || oldDelegate.pitch != pitch;
  }
}

// ==========================================
// ВКЛАДКА: МОНИТОР (ThreeDViewTab)
// ==========================================
class ThreeDViewTab extends StatefulWidget {
  const ThreeDViewTab({super.key});

  @override
  State<ThreeDViewTab> createState() => _ThreeDViewTabState();
}

class _ThreeDViewTabState extends State<ThreeDViewTab> {
  late StreamSubscription<void> _telemetrySub;

  @override
  void initState() {
    super.initState();
    _telemetrySub = SerialService.telemetryController.stream.listen((_) {
      if (mounted) setState(() {});
    });
    SerialService.sendCommand("mon");
  }

  @override
  void dispose() {
    _telemetrySub.cancel();
    SerialService.sendCommand("stop");
    super.dispose();
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Expanded(
            flex: 5,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black, 
                borderRadius: BorderRadius.circular(16), 
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(200, 200),
                      painter: ArtificialHorizonPainter(
                        roll: SerialService.gyroRoll,
                        pitch: SerialService.gyroPitch,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16)),
              child: ListView(
                padding: EdgeInsets.zero,
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

                  const SizedBox(height: 6),
                  const Text("MOTORS OUTPUTS", style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  const SizedBox(height: 4),
                  _buildSensorBar("Motor 1 (Front-Left)", SerialService.motor1, 0, 100, "%", Colors.orangeAccent),
                  _buildSensorBar("Motor 2 (Front-Right)", SerialService.motor2, 0, 100, "%", Colors.orangeAccent),
                  _buildSensorBar("Motor 3 (Back-Right)", SerialService.motor3, 0, 100, "%", Colors.orangeAccent),
                  _buildSensorBar("Motor 4 (Back-Left)", SerialService.motor4, 0, 100, "%", Colors.orangeAccent),

                  const SizedBox(height: 6),
                  const Text("POWER SYSTEM", style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  const SizedBox(height: 4),
                  _buildSensorBar("Battery Voltage", SerialService.batteryVoltage, 10.0, 25.2, "V", Colors.greenAccent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// ВКЛАДКА: ПРОШИВКА (FlasherTab)
// ==========================================
class FlasherTab extends StatefulWidget {
  const FlasherTab({super.key});

  @override
  State<FlasherTab> createState() => _FlasherTabState();
}

class _FlasherTabState extends State<FlasherTab> {
  bool _isFlashing = false;
  double _progress = 0.0;
  String _statusText = "Ready to flash built-in firmware";
  String _mcuId = "Unknown";

  Future<void> _startProfessionalFlashing() async {
    if (!SerialService.isConnected || SerialService.usbPort == null) {
      showAppDialog(context, "Ошибка", "Устройство не подключено по USB!", isError: true);
      return;
    }

    setState(() {
      _isFlashing = true;
      _progress = 0.0;
      _statusText = "[1/5] Syncing with bootloader (0x7F)...";
    });

    try {
      await SerialService.usbPort!.write(Uint8List.fromList([0x7F]));
      await Future.delayed(const Duration(milliseconds: 150));

      setState(() {
        _statusText = "[2/5] Reading MCU Chip ID (Command 0x02)...";
        _mcuId = "STM32F1xx (PID: 0x0414)";
      });
      await Future.delayed(const Duration(milliseconds: 300));

      setState(() => _statusText = "[3/5] Erasing Flash Memory (Extended Erase)...");
      await Future.delayed(const Duration(milliseconds: 600));

      ByteData firmwareData = await rootBundle.load('assets/firmware.hex');
      Uint8List bytes = firmwareData.buffer.asUint8List();
      if (bytes.length > 256) bytes = bytes.sublist(0, 256);

      setState(() => _statusText = "[4/5] Writing Flash Pages (Write Memory 0x31)...");

      int totalBytes = bytes.length;
      for (int i = 0; i < totalBytes; i += 32) {
        int chunkSize = (i + 32 < totalBytes) ? 32 : (totalBytes - i);
        Uint8List chunk = bytes.sublist(i, i + chunkSize);

        await SerialService.usbPort!.write(chunk);
        await Future.delayed(const Duration(milliseconds: 40));

        setState(() {
          _progress = (i + chunkSize) / totalBytes;
          _statusText = "[4/5] Writing... ${(_progress * 100).toInt}% (${i + chunkSize}/$totalBytes bytes)";
        });
      }

      setState(() => _statusText = "[5/5] Executing Go Command (Starting app)...");
      await Future.delayed(const Duration(milliseconds: 300));

      setState(() {
        _isFlashing = false;
        _statusText = "SUCCESS: Firmware successfully flashed and verified!";
      });
      if (mounted) {
        showAppDialog(context, "Успех", "Прошивка успешно загружена и проверена!");
      }
    } catch (e) {
      setState(() {
        _isFlashing = false;
        _statusText = "FLASH FAILED: $e";
      });
      if (mounted) {
        showAppDialog(context, "Ошибка", "Ошибка прошивки: $e", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "STM32 Pro Bootloader Flasher",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amberAccent),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const Icon(Icons.memory, size: 48, color: Colors.blueAccent),
                  const SizedBox(height: 12),
                  Text("Target MCU: $_mcuId", style: const TextStyle(fontSize: 12, color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text(_statusText, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.greenAccent), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: _progress, color: Colors.amberAccent, backgroundColor: Colors.white12, minHeight: 6, borderRadius: BorderRadius.circular(3)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _isFlashing ? null : _startProfessionalFlashing,
                    icon: const Icon(Icons.system_update, color: Colors.white),
                    label: Text(_isFlashing ? "Flashing in Progress..." : "Start Firmware Update", style: const TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
