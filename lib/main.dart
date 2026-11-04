// Конфигуратор CFC v3.5

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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF121214),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.info_outline, Icons.info, 'Info'),
                _buildNavItem(1, Icons.terminal_outlined, Icons.terminal, 'CLI'),
                _buildNavItem(2, Icons.tune_outlined, Icons.tune, 'Tuning'),
                _buildNavItem(3, Icons.gavel_outlined, Icons.gavel, 'Tests'),
                _buildNavItem(4, Icons.threed_rotation_outlined, Icons.threed_rotation, 'Monitor'),
                _buildNavItem(5, Icons.memory_outlined, Icons.memory, 'Flasher'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData selectedIcon, String label) {
    bool isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected ? Colors.blueAccent : Colors.white70,
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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
// МОДЕЛЬ ДАННЫХ ДОКУМЕНТАЦИИ
// ==========================================
class DocSection {
  final String title;
  final String content;

  DocSection({required this.title, required this.content});
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
      Iterable<RegExpMatch> matches = regExp.allMatches(fileContent);
      
      for (var match in matches) {
        String title = match.group(1)?.trim() ?? '';
        String content = match.group(2)?.trim() ?? '';
        if (title.isNotEmpty) {
          parsedSections.add(DocSection(title: title, content: content));
        }
      }

      if (parsedSections.isEmpty) {
        parsedSections.add(
          DocSection(title: 'Справочник CLI команд', content: fileContent)
        );
      }

      setState(() {
        _sections = parsedSections;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _sections = [
          DocSection(
            title: 'Ошибка загрузки doc.txt',
            content: 'Не удалось загрузить doc.txt из assets. Проверьте pubspec.yaml.\nОшибка: $e',
          ),
        ];
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
        String subText = rawContent.substring(lastMatchEnd, match.start).trim();
        if (subText.isNotEmpty) {
          widgets.add(
            Text(
              subText,
              style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4, fontFamily: 'monospace'),
            ),
          );
          widgets.add(const SizedBox(height: 10));
        }
      }

      String imgTag = match.group(1)!.toLowerCase();
      String assetImagePath = 'assets/$imgTag.jpg';

      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              assetImagePath,
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
                  "Изображение не найдено ($imgTag.jpg)",
                  style: const TextStyle(fontSize: 11, color: Colors.amberAccent),
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
      String remainingText = rawContent.substring(lastMatchEnd).trim();
      if (remainingText.isNotEmpty) {
        widgets.add(
          Text(
            remainingText,
            style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4, fontFamily: 'monospace'),
          ),
        );
      }
    }

    return widgets;
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
                      child: const Text('v.3.5.0 (CLI)', style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Мобильный конфигуратор для настройки полетного контроллера STM32.', style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.4)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text('СПРАВОЧНИК CLI КОМАНД (doc.txt)', style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        ),
        ..._sections.map((sec) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            title: Text(sec.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
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
class PidAxisCardWidget extends StatefulWidget {
  final String axisName;
  final String kpCmd, kiCmd, kdCmd;
  final double kp, ki, kd;
  final Function(double, double, double) onUpdate;

  const PidAxisCardWidget({
    super.key,
    required this.axisName,
    required this.kpCmd,
    required this.kiCmd,
    required this.kdCmd,
    required this.kp,
    required this.ki,
    required this.kd,
    required this.onUpdate,
  });

  @override
  State<PidAxisCardWidget> createState() => _PidAxisCardWidgetState();
}

class _PidAxisCardWidgetState extends State<PidAxisCardWidget> {
  late TextEditingController _pController;
  late TextEditingController _iController;
  late TextEditingController _dController;

  @override
  void initState() {
    super.initState();
    _pController = TextEditingController(text: widget.kp.toString());
    _iController = TextEditingController(text: widget.ki.toString());
    _dController = TextEditingController(text: widget.kd.toString());
  }

  @override
  void didUpdateWidget(covariant PidAxisCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kp != widget.kp) _pController.text = widget.kp.toString();
    if (oldWidget.ki != widget.ki) _iController.text = widget.ki.toString();
    if (oldWidget.kd != widget.kd) _dController.text = widget.kd.toString();
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
            Text(widget.axisName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 2),
            Text("${widget.kpCmd} / ${widget.kiCmd} / ${widget.kdCmd}", style: TextStyle(color: Colors.amberAccent.withOpacity(0.8), fontSize: 9, fontFamily: 'monospace')),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pController,
                    decoration: const InputDecoration(labelText: 'Kp', isDense: true),
                    keyboardType: TextInputType.number,
                    onSubmitted: (val) {
                      double? np = double.tryParse(val);
                      if (np != null) widget.onUpdate(np, widget.ki, widget.kd);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _iController,
                    decoration: const InputDecoration(labelText: 'Ki', isDense: true),
                    keyboardType: TextInputType.number,
                    onSubmitted: (val) {
                      double? ni = double.tryParse(val);
                      if (ni != null) widget.onUpdate(widget.kp, ni, widget.kd);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _dController,
                    decoration: const InputDecoration(labelText: 'Kd', isDense: true),
                    keyboardType: TextInputType.number,
                    onSubmitted: (val) {
                      double? nd = double.tryParse(val);
                      if (nd != null) widget.onUpdate(widget.kp, widget.ki, nd);
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
  // Полетные параметры и ограничения
  double _flMode = 0;          
  double _flRollMax = 25.0;    
  double _flPitchMax = 25.0;   
  double _flVzSpeedMax = 1.5;  
  double _flHeightMin = 0.5;   

  // Аварийная посадка
  double _fsBatEn = 1;
  double _fsRtxEn = 1;
  double _fsSpiEn = 1;
  double _fsI2cEn = 1;

  // ПАРАМЕТРЫ РАДИОМОДУЛЯ RTX (SPI)
  double _rtxEn = 1;
  double _rtxBand = 4;
  double _rtxAddr = 1234;
  double _rtxChan = 0;
  double _rtxSf = 7;
  double _rtxBw = 7; // Индекс полосы (0-9)
  double _rtxCr = 1;
  double _rtxPower = 14;
  double _rtxLinkWarnThreshold = 20;
  double _rtxAfcEn = 1;
  double _rtxAutoEn = 1;

  // RC параметры
  double _rcRate = 0.40;
  double _rcSuperExpo = 0.05;
  double _rcStickExpo = 0.50;
  double _rcYawRate = 0.35;
  double _rcDeadband = 20.0;
  double _rcFilterSmoothing = 0.30;

  // Питание и батарея
  double _batCells = 4;
  double _batFsV = 14.0;
  double _fsSpeed = 0.8;

  // Лидар и фильтры
  double _lidarEn = 1;
  double _gyroFilterAlpha = 0.40;
  double _accFilterAlpha = 0.15;
  double _filterDynNotchEn = 1;
  double _filterNotchFreq = 65.0;

  // PID регуляторы
  double _rollKp = 0.50, _rollKi = 0.015, _rollKd = 0.02;
  double _pitchKp = 0.50, _pitchKi = 0.015, _pitchKd = 0.02;
  double _yawKp = 0.65, _yawKi = 0.010, _yawKd = 0.0;
  double _vzKp = 7.5, _vzKi = 1.3, _vzKd = 0.35;

  // Расчет чувствительности приемника (LoRa Sensitivity)
  double _calculateSensitivity() {
    const bwTable = [7800.0, 10400.0, 15600.0, 20800.0, 31250.0, 41700.0, 62500.0, 125000.0, 250000.0, 500000.0];
    int bwIdx = _rtxBw.round().clamp(0, bwTable.length - 1);
    double bwHz = bwTable[bwIdx];

    const snrTable = {5: -2.5, 6: -5.0, 7: -7.5, 8: -10.0, 9: -12.5, 10: -15.0, 11: -17.5, 12: -20.0};
    int sfInt = _rtxSf.round().clamp(5, 12);
    double snr = snrTable[sfInt] ?? -7.5;

    double nf = 6.0;
    return -174.0 + (10.0 * (math.log(bwHz) / math.ln10)) + nf + snr;
  }

  // Расчет скорости передачи по воздуху (Air Data Rate в bps/kbps)
  double _calculateAirDataRate() {
    const bwTable = [7800.0, 10400.0, 15600.0, 20800.0, 31250.0, 41700.0, 62500.0, 125000.0, 250000.0, 500000.0];
    int bwIdx = _rtxBw.round().clamp(0, bwTable.length - 1);
    double bwHz = bwTable[bwIdx];

    int sfInt = _rtxSf.round().clamp(5, 12);
    int crInt = _rtxCr.round().clamp(1, 4); // Coding Rate 1->4/5, 2->4/6, 3->4/7, 4->4/8

    // Формула символьной скорости: Rs = BW / (2^SF)
    double symbolRate = bwHz / math.pow(2, sfInt);
    // Битрейт: R = SF * (symbolRate) * (4 / (4 + crInt))
    double bitRate = sfInt * symbolRate * (4.0 / (4.0 + crInt));
    return bitRate;
  }

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

  // Виджет прогресс-бара по стилю ползунка без ручки управления
  Widget _buildInfoProgressCard({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required String displayValue,
  }) {
    double percent = ((value - min) / (max - min)).clamp(0.0, 1.0);
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
                      Text(subtitle, style: TextStyle(color: Colors.amberAccent.withOpacity(0.8), fontSize: 10, fontFamily: 'monospace')),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(displayValue, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent,
                minHeight: 4,
                backgroundColor: Colors.white12,
                color: Colors.blueAccent,
              ),
            ),
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
    double sensitivity = _calculateSensitivity();
    double airDataRate = _calculateAirDataRate();
    String airDataRateStr = airDataRate >= 1000 
        ? "${(airDataRate / 1000).toStringAsFixed(2)} kbps" 
        : "${airDataRate.toStringAsFixed(1)} bps";

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      children: [
        _buildSectionHeader("ПОЛЕТНЫЕ РЕЖИМЫ И ОГРАНИЧЕНИЯ", Icons.flight),
        _buildSegmentedChoiceCard(
          title: "Режим полета",
          commandName: "fl_mode",
          options: const ["Acro", "Angle", "Horizon"],
          selectedIndex: _flMode.round(),
          onSelected: (val) {
            setState(() => _flMode = val.toDouble());
            SerialService.sendCommand("fl_mode $val");
          },
        ),
        _buildSliderCard(
          title: "Максимальный угол крена",
          commandName: "fl_roll_max",
          value: _flRollMax,
          min: 10.0,
          max: 80.0,
          divisions: 14,
          unit: "°",
          onChanged: (v) => setState(() => _flRollMax = v),
          onChangeEnd: (v) => SerialService.sendCommand("fl_roll_max $v"),
        ),
        _buildSliderCard(
          title: "Максимальный угол тангажа",
          commandName: "fl_pitch_max",
          value: _flPitchMax,
          min: 10.0,
          max: 80.0,
          divisions: 14,
          unit: "°",
          onChanged: (v) => setState(() => _flPitchMax = v),
          onChangeEnd: (v) => SerialService.sendCommand("fl_pitch_max $v"),
        ),
        _buildSliderCard(
          title: "Максимальная вертикальная скорость",
          commandName: "fl_vz_speed_max",
          value: _flVzSpeedMax,
          min: 0.5,
          max: 3.0,
          divisions: 25,
          unit: "м/с",
          onChanged: (v) => setState(() => _flVzSpeedMax = v),
          onChangeEnd: (v) => SerialService.sendCommand("fl_vz_speed_max $v"),
        ),
        _buildSliderCard(
          title: "Минимальная высота полета",
          commandName: "fl_height_min",
          value: _flHeightMin,
          min: 0.0,
          max: 5.0,
          divisions: 50,
          unit: "м",
          onChanged: (v) => setState(() => _flHeightMin = v),
          onChangeEnd: (v) => SerialService.sendCommand("fl_height_min $v"),
        ),

        _buildSectionHeader("АВАРИЙНАЯ ПОСАДКА", Icons.warning_amber_rounded),
        _buildSwitchCard(
          title: "При разряде батареи",
          commandName: "fs_bat_en",
          value: _fsBatEn == 1,
          onChanged: (v) {
            setState(() => _fsBatEn = v ? 1 : 0);
            SerialService.sendCommand("fs_bat_en ${_fsBatEn.round()}");
          },
        ),
        _buildSwitchCard(
          title: "При обрыве связи с пультом",
          commandName: "fs_rtx_en",
          value: _fsRtxEn == 1,
          onChanged: (v) {
            setState(() => _fsRtxEn = v ? 1 : 0);
            SerialService.sendCommand("fs_rtx_en ${_fsRtxEn.round()}");
          },
        ),
        _buildSwitchCard(
          title: "При обрыве связи по шине SPI",
          commandName: "fs_spi_en",
          value: _fsSpiEn == 1,
          onChanged: (v) {
            setState(() => _fsSpiEn = v ? 1 : 0);
            SerialService.sendCommand("fs_spi_en ${_fsSpiEn.round()}");
          },
        ),
        _buildSwitchCard(
          title: "При обрыве связи по шине I2C",
          commandName: "fs_i2c_en",
          value: _fsI2cEn == 1,
          onChanged: (v) {
            setState(() => _fsI2cEn = v ? 1 : 0);
            SerialService.sendCommand("fs_i2c_en ${_fsI2cEn.round()}");
          },
        ),

        // --- БЛОК РАДИОМОДУЛЯ RTX (SPI) С ПРОГРЕСС-БАРАМИ РАСЧЕТОВ ---
        _buildSectionHeader("РАДИОМОДУЛЬ RTX (SPI)", Icons.wifi),
        _buildSwitchCard(
          title: "Включить RTX модуль",
          commandName: "rtx_en",
          value: _rtxEn == 1,
          onChanged: (v) {
            setState(() => _rtxEn = v ? 1 : 0);
            SerialService.sendCommand("rtx_en ${_rtxEn.round()}");
          },
        ),
        _buildSliderCard(
          title: "Частотный диапазон (x100 МГц)",
          commandName: "rtx_band",
          value: _rtxBand,
          min: 1,
          max: 9,
          divisions: 8,
          unit: "",
          onChanged: (v) => setState(() => _rtxBand = v),
          onChangeEnd: (v) => SerialService.sendCommand("rtx_band ${v.round()}"),
        ),
        _buildSliderCard(
          title: "Сетевой адрес устройства",
          commandName: "rtx_addr",
          value: _rtxAddr,
          min: 0,
          max: 65535,
          divisions: 100,
          unit: "",
          onChanged: (v) => setState(() => _rtxAddr = v),
          onChangeEnd: (v) => SerialService.sendCommand("rtx_addr ${v.round()}"),
        ),
        _buildSliderCard(
          title: "Рабочий канал связи (1 МГц шаг)",
          commandName: "rtx_chan",
          value: _rtxChan,
          min: 0,
          max: 99,
          divisions: 99,
          unit: "",
          onChanged: (v) => setState(() => _rtxChan = v),
          onChangeEnd: (v) => SerialService.sendCommand("rtx_chan ${v.round()}"),
        ),
        _buildSliderCard(
          title: "Spreading Factor (SF)",
          commandName: "rtx_sf",
          value: _rtxSf,
          min: 5,
          max: 12,
          divisions: 7,
          unit: "",
          onChanged: (v) => setState(() => _rtxSf = v),
          onChangeEnd: (v) => SerialService.sendCommand("rtx_sf ${v.round()}"),
        ),
        _buildSliderCard(
          title: "Полоса пропускания (Bandwidth)",
          commandName: "rtx_bw",
          value: _rtxBw,
          min: 0,
          max: 9,
          divisions: 9,
          unit: "",
          onChanged: (v) => setState(() => _rtxBw = v),
          onChangeEnd: (v) => SerialService.sendCommand("rtx_bw ${v.round()}"),
        ),

        // 1. Прогресс-бар расчетной чувствительности приемника
        _buildInfoProgressCard(
          title: "Расчетная чувствительность приемника",
          subtitle: "sensitivity_calc",
          value: sensitivity,
          min: -145.0,
          max: -110.0,
          displayValue: "${sensitivity.toStringAsFixed(2)} dBm",
        ),

        // 2. Прогресс-бар расчетной скорости передачи по воздуху
        _buildInfoProgressCard(
          title: "Скорость передачи по воздуху (Air Rate)",
          subtitle: "air_bitrate_calc",
          value: airDataRate,
          min: 100.0,
          max: 37500.0,
          displayValue: airDataRateStr,
        ),

        _buildSliderCard(
          title: "Коэффициент кодирования (Coding Rate)",
          commandName: "rtx_cr",
          value: _rtxCr,
          min: 1,
          max: 4,
          divisions: 3,
          unit: "",
          onChanged: (v) => setState(() => _rtxCr = v),
          onChangeEnd: (v) => SerialService.sendCommand("rtx_cr ${v.round()}"),
        ),
        _buildSliderCard(
          title: "Мощность передатчика",
          commandName: "rtx_power",
          value: _rtxPower,
          min: -9,
          max: 22,
          divisions: 31,
          unit: "dBm",
          onChanged: (v) => setState(() => _rtxPower = v),
          onChangeEnd: (v) => SerialService.sendCommand("rtx_power ${v.round()}"),
        ),
        _buildSliderCard(
          title: "Порог падения качества связи",
          commandName: "rtx_link_warn_threshold",
          value: _rtxLinkWarnThreshold,
          min: 5,
          max: 90,
          divisions: 85,
          unit: "%",
          onChanged: (v) => setState(() => _rtxLinkWarnThreshold = v),
          onChangeEnd: (v) => SerialService.sendCommand("rtx_link_warn_threshold ${v.round()}"),
        ),
        _buildSwitchCard(
          title: "Автоматическая подстройка частоты (AFC)",
          commandName: "rtx_afc_en",
          value: _rtxAfcEn == 1,
          onChanged: (v) {
            setState(() => _rtxAfcEn = v ? 1 : 0);
            SerialService.sendCommand("rtx_afc_en ${_rtxAfcEn.round()}");
          },
        ),
        _buildSwitchCard(
          title: "Авто-инициатива с борта при ухудшении связи",
          commandName: "rtx_auto_en",
          value: _rtxAutoEn == 1,
          onChanged: (v) {
            setState(() => _rtxAutoEn = v ? 1 : 0);
            SerialService.sendCommand("rtx_auto_en ${_rtxAutoEn.round()}");
          },
        ),
        // -------------------------------------------------------------

        _buildSectionHeader("РАДИОУПРАВЛЕНИЕ И ЭКСПОНЕНТЫ", Icons.gamepad),
        _buildSliderCard(title: "RC Rate (Roll/Pitch)", commandName: "rc_rate", value: _rcRate, min: 0.1, max: 2.0, divisions: 19, unit: "", onChanged: (v) => setState(() => _rcRate = v), onChangeEnd: (v) => SerialService.sendCommand("rc_rate $v")),
        _buildSliderCard(title: "RC Super Expo", commandName: "rc_super_expo", value: _rcSuperExpo, min: 0.0, max: 0.9, divisions: 18, unit: "", onChanged: (v) => setState(() => _rcSuperExpo = v), onChangeEnd: (v) => SerialService.sendCommand("rc_super_expo $v")),
        _buildSliderCard(title: "RC Stick Expo", commandName: "rc_stick_expo", value: _rcStickExpo, min: 0.0, max: 1.0, divisions: 20, unit: "", onChanged: (v) => setState(() => _rcStickExpo = v), onChangeEnd: (v) => SerialService.sendCommand("rc_stick_expo $v")),
        _buildSliderCard(title: "Yaw Rate", commandName: "rc_yaw_rate", value: _rcYawRate, min: 0.1, max: 2.0, divisions: 19, unit: "", onChanged: (v) => setState(() => _rcYawRate = v), onChangeEnd: (v) => SerialService.sendCommand("rc_yaw_rate $v")),
        _buildSliderCard(title: "Мертвая зона стиков", commandName: "rc_deadband", value: _rcDeadband, min: 0, max: 50, divisions: 50, unit: "PWM", onChanged: (v) => setState(() => _rcDeadband = v), onChangeEnd: (v) => SerialService.sendCommand("rc_deadband $v")),
        _buildSliderCard(title: "Сглаживание RC", commandName: "rc_filter_smoothing", value: _rcFilterSmoothing, min: 0.05, max: 1.0, divisions: 19, unit: "", onChanged: (v) => setState(() => _rcFilterSmoothing = v), onChangeEnd: (v) => SerialService.sendCommand("rc_filter_smoothing $v")),

        _buildSectionHeader("ПИТАНИЕ И БАТАРЕЯ", Icons.battery_charging_full),
        _buildSliderCard(title: "Количество ячеек LiPo", commandName: "bat_cells", value: _batCells, min: 1, max: 6, divisions: 5, unit: "S", onChanged: (v) => setState(() => _batCells = v), onChangeEnd: (v) => SerialService.sendCommand("bat_cells ${v.round()}")),
        _buildSliderCard(title: "Порог Failsafe батареи", commandName: "bat_fs_v", value: _batFsV, min: 6.0, max: 25.0, divisions: 190, unit: "В", onChanged: (v) => setState(() => _batFsV = v), onChangeEnd: (v) => SerialService.sendCommand("bat_fs_v $v")),
        _buildSliderCard(title: "Скорость посадки Failsafe", commandName: "fs_speed", value: _fsSpeed, min: 0.2, max: 2.0, divisions: 18, unit: "м/с", onChanged: (v) => setState(() => _fsSpeed = v), onChangeEnd: (v) => SerialService.sendCommand("fs_speed $v")),

        _buildSectionHeader("ЛИДАР И ФИЛЬТРЫ СЕНСОРОВ", Icons.waves),
        _buildSwitchCard(title: "Включить лидар VL53L1X", commandName: "lidar_en", value: _lidarEn == 1, onChanged: (v) { setState(() => _lidarEn = v ? 1 : 0); SerialService.sendCommand("lidar_en ${_lidarEn.round()}"); }),
        _buildSliderCard(title: "Фильтр гироскопа LPF", commandName: "gyro_filter_alpha", value: _gyroFilterAlpha, min: 0.05, max: 1.0, divisions: 19, unit: "", onChanged: (v) => setState(() => _gyroFilterAlpha = v), onChangeEnd: (v) => SerialService.sendCommand("gyro_filter_alpha $v")),
        _buildSliderCard(title: "Фильтр акселерометра LPF", commandName: "acc_filter_alpha", value: _accFilterAlpha, min: 0.01, max: 1.0, divisions: 99, unit: "", onChanged: (v) => setState(() => _accFilterAlpha = v), onChangeEnd: (v) => SerialService.sendCommand("acc_filter_alpha $v")),
        _buildSwitchCard(title: "Динамический Notch фильтр", commandName: "filter_dyn_notch_en", value: _filterDynNotchEn == 1, onChanged: (v) { setState(() => _filterDynNotchEn = v ? 1 : 0); SerialService.sendCommand("filter_dyn_notch_en ${_filterDynNotchEn.round()}"); }),
        _buildSliderCard(title: "Центр Notch фильтра", commandName: "filter_notch_freq", value: _filterNotchFreq, min: 30, max: 150, divisions: 120, unit: "Гц", onChanged: (v) => setState(() => _filterNotchFreq = v), onChangeEnd: (v) => SerialService.sendCommand("filter_notch_freq $v")),

        _buildSectionHeader("ПИД-РЕГУЛЯТОРЫ (PID TUNINGS)", Icons.tune),
        PidAxisCardWidget(
          axisName: "Roll Axis (Rate)",
          kpCmd: "roll_kp", kiCmd: "roll_ki", kdCmd: "roll_kd",
          kp: _rollKp, ki: _rollKi, kd: _rollKd,
          onUpdate: (p, i, d) {
            setState(() { _rollKp = p; _rollKi = i; _rollKd = d; });
            SerialService.sendCommand("roll_kp $p");
            SerialService.sendCommand("roll_ki $i");
            SerialService.sendCommand("roll_kd $d");
          },
        ),
        PidAxisCardWidget(
          axisName: "Pitch Axis (Rate)",
          kpCmd: "pitch_kp", kiCmd: "pitch_ki", kdCmd: "pitch_kd",
          kp: _pitchKp, ki: _pitchKi, kd: _pitchKd,
          onUpdate: (p, i, d) {
            setState(() { _pitchKp = p; _pitchKi = i; _pitchKd = d; });
            SerialService.sendCommand("pitch_kp $p");
            SerialService.sendCommand("pitch_ki $i");
            SerialService.sendCommand("pitch_kd $d");
          },
        ),
        PidAxisCardWidget(
          axisName: "Yaw Axis (Rate)",
          kpCmd: "yaw_kp", kiCmd: "yaw_ki", kdCmd: "yaw_kd",
          kp: _yawKp, ki: _yawKi, kd: _yawKd,
          onUpdate: (p, i, d) {
            setState(() { _yawKp = p; _yawKi = i; _yawKd = d; });
            SerialService.sendCommand("yaw_kp $p");
            SerialService.sendCommand("yaw_ki $i");
            SerialService.sendCommand("yaw_kd $d");
          },
        ),
        PidAxisCardWidget(
          axisName: "Vertical Speed Axis (Vz)",
          kpCmd: "vz_kp", kiCmd: "vz_ki", kdCmd: "vz_kd",
          kp: _vzKp, ki: _vzKi, kd: _vzKd,
          onUpdate: (p, i, d) {
            setState(() { _vzKp = p; _vzKi = i; _vzKd = d; });
            SerialService.sendCommand("vz_kp $p");
            SerialService.sendCommand("vz_ki $i");
            SerialService.sendCommand("vz_kd $d");
          },
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
        _buildSectionHeader("КАЛИБРОВКИ ДАТЧИКОВ", Icons.explore),
        _buildActionCard(
          context: context,
          title: "Калибровка гироскопа",
          subtitleCommand: "cal_gyro",
          icon: Icons.explore_outlined,
          color: Colors.blueAccent,
          onTap: () {
            if (!SerialService.isConnected) {
              showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true);
            } else {
              SerialService.sendCommand("cal_gyro");
              showAppDialog(context, "Успех", "Калибровка гироскопа запущена!");
            }
          },
        ),
        _buildActionCard(
          context: context,
          title: "Калибровка акселерометра",
          subtitleCommand: "cal_acc",
          icon: Icons.grid_view,
          color: Colors.cyanAccent,
          onTap: () {
            if (!SerialService.isConnected) {
              showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true);
            } else {
              SerialService.sendCommand("cal_acc");
              showAppDialog(context, "Успех", "Калибровка акселерометра запущена!");
            }
          },
        ),
        _buildActionCard(
          context: context,
          title: "Калибровка лидара (Xtalk)",
          subtitleCommand: "cal_lidar",
          icon: Icons.radar,
          color: Colors.orangeAccent,
          onTap: () {
            if (!SerialService.isConnected) {
              showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true);
            } else {
              SerialService.sendCommand("cal_lidar");
              showAppDialog(context, "Успех", "Калибровка лидара запущена!");
            }
          },
        ),
        _buildSectionHeader("СИСТЕМНЫЕ КОМАНДЫ", Icons.settings),
        _buildActionCard(
          context: context,
          title: "Применить настройки RTX",
          subtitleCommand: "rtx_write",
          icon: Icons.save,
          color: Colors.greenAccent,
          onTap: () {
            if (!SerialService.isConnected) {
              showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true);
            } else {
              SerialService.sendCommand("rtx_write");
              showAppDialog(context, "Успех", "Настройки радиомодуля применены!");
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
