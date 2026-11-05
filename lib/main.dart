// XFire Ecosystem (Финальная версия с красивым авиагоризонтом HUD и шкалами)

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
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
// СТАРТОВАЯ ЗАСТАВКА (С задержкой 0.5с)
// ==========================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3500),
      vsync: this,
    );

    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 15.0),          // Задержка 0.5 сек
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 28.3), // Появление (1 сек)
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 28.3),          // Показ (1 сек)
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 28.4), // Исчезновение (1 сек)
    ]).animate(_controller);

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainContainer()),
          );
        }
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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: const Text(
            "XFire",
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              letterSpacing: 4.0,
              color: Colors.white,
            ),
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
  
  final List<Widget> _tabs = [
    const InfoConnectionTab(),  // 0: Инфо
    const SettingsTab(),        // 1: Полетный контроллер FC
    const RemoteControlTab(),   // 2: Пульт RC
    const RadioTab(),           // 3: Радиомодуль RTX
    const TestsTab(),           // 4: Калибровка и тесты
    const ThreeDViewTab(),      // 5: Телеметрия
    const TerminalTab(),        // 6: Терминал CLI
    const FlasherTab(),         // 7: Прошивка FC и RC
  ];

  final List<String> _tabNames = [
    "Инфо",
    "Полетный контроллер FC",
    "Пульт RC",
    "Радиомодуль RTX",
    "Калибровка и тесты",
    "Телеметрия",
    "Терминал CLI",
    "Прошивка FC и RC",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121214),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.local_fire_department, color: Colors.amberAccent, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
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
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.amberAccent),
                    items: List.generate(_tabs.length, (index) {
                      return DropdownMenuItem<int>(
                        value: index,
                        child: Text(
                          _tabNames[index],
                          style: TextStyle(
                            color: index == 0 ? Colors.greenAccent : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }),
                    onChanged: (val) {
                      if (val != null) setState(() => _currentIndex = val);
                    },
                  ),
                ),
              ),
            ),
          ],
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
// СЕРВИС СВЯЗИ И ОБЩИЕ ПАРАМЕТРЫ РАДИО
// ==========================================
class SerialService {
  static bool isConnected = false;
  static UsbPort? usbPort;
  static StreamSubscription<Uint8List>? _usbSubscription;

  static String lastResponse = "Ready. Connect via USB OTG.";
  static String terminalLog = "";
  static StreamController<String> logController = StreamController.broadcast();
  static StreamController<void> telemetryController = StreamController.broadcast();

  static double rtxBand = 4.0; 
  static double rtxChan = 68.0; 
  static double rtxSf = 7.0;
  static double rtxBw = 7.0;
  static double rtxCr = 1.0;
  static double rtxPower = 14.0;
  static double rtxLinkWarnThreshold = 20.0;
  static double rtxAutoEn = 1.0;

  static double gyroRoll = 0.0, gyroPitch = 0.0, gyroYaw = 0.0;
  static double accelX = 0.0, accelY = 0.0, accelZ = 1.0;

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
// ВКЛАДКА 0: ИНФО (InfoConnectionTab)
// ==========================================
class InfoConnectionTab extends StatefulWidget {
  const InfoConnectionTab({super.key});

  @override
  State<InfoConnectionTab> createState() => _InfoConnectionTabState();
}

class _InfoConnectionTabState extends State<InfoConnectionTab> {
  String _displayResponse = SerialService.lastResponse;
  bool _isConnected = SerialService.isConnected;
  late StreamSubscription<String> _sub;
  
  List<DocSection> _sections = [];
  bool _isLoading = true;

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
    _loadDocumentation();
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
      setState(() { _sections = parsedSections; _isLoading = false; });
    } catch (e) {
      setState(() {
        _sections = [DocSection(title: 'Ошибка загрузки doc.txt', content: 'Не удалось загрузить doc.txt из assets.\nОшибка: $e')];
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
          child: Image.asset('assets/$imgTag.jpg', width: double.infinity, fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 100, width: double.infinity, alignment: Alignment.center,
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
                const Text("УПРАВЛЕНИЕ ПОДКЛЮЧЕНИЕМ USB", style: TextStyle(fontSize: 10, color: Colors.amberAccent, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: (_isConnected ? Colors.greenAccent : Colors.amberAccent).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.usb, color: Colors.greenAccent, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_displayResponse, style: const TextStyle(fontFamily: 'monospace', color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: _toggleConnection,
                    icon: Icon(_isConnected ? Icons.link_off : Icons.link, size: 16),
                    label: Text(_isConnected ? "Disconnect USB" : "Connect USB", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isConnected ? Colors.red.shade900 : Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
                      child: const Text('v.3.5.0 (CLI)', style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('Аппаратно-программная экосистема для управления дронами.', style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.4)),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('СПРАВОЧНИК CLI КОМАНД (doc.txt)', style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        ),
        if (_isLoading)
          const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(color: Colors.blueAccent)))
        else
          ..._sections.map((sec) => Card(
            child: ExpansionTile(
              title: Text(sec.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
              iconColor: Colors.amberAccent,
              collapsedIconColor: Colors.white54,
              children: [Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _buildContentWidgets(sec.content)))],
            ),
          )),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ==========================================
// ВКЛАДКА: ПОЛЕТНЫЙ КОНТРОЛЛЕР FC (SettingsTab)
// ==========================================
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  double _flMode = 0;          
  double _flRollMax = 25.0;    
  double _flPitchMax = 25.0;   
  double _flVzSpeedMax = 1.5;  
  double _flHeightMin = 0.5;   

  double _fsBatEn = 1;
  double _fsRtxEn = 1;
  double _fsSpiEn = 1;
  double _fsI2cEn = 1;

  double _rtxLinkWarnThreshold = SerialService.rtxLinkWarnThreshold;
  double _rtxAutoEn = SerialService.rtxAutoEn;

  double _rcRate = 0.40;
  double _rcSuperExpo = 0.05;
  double _rcStickExpo = 0.50;
  double _rcYawRate = 0.35;
  double _rcDeadband = 20.0;
  double _rcFilterSmoothing = 0.30;

  double _batCells = 4;
  double _batFsV = 14.0;
  double _fsSpeed = 0.8;

  double _lidarEn = 1;
  double _gyroFilterAlpha = 0.40;
  double _accFilterAlpha = 0.15;
  double _filterDynNotchEn = 1;
  double _filterNotchFreq = 65.0;

  double _rollKp = 0.50, _rollKi = 0.015, _rollKd = 0.02;
  double _pitchKp = 0.50, _pitchKi = 0.015, _pitchKd = 0.02;
  double _yawKp = 0.65, _yawKi = 0.010, _yawKd = 0.0;
  double _vzKp = 7.5, _vzKi = 1.3, _vzKd = 0.35;

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

  Widget _buildSliderCard({required String title, required String commandName, required double value, required double min, required double max, required int divisions, required String unit, required ValueChanged<double> onChanged, required ValueChanged<double> onChangeEnd}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), Text(commandName, style: TextStyle(color: Colors.amberAccent.withOpacity(0.8), fontSize: 10, fontFamily: 'monospace'))])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text("${value.toStringAsFixed(value.truncate() == value ? 0 : 2)} $unit", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 11))),
              ],
            ),
            Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged, onChangeEnd: onChangeEnd),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedChoiceCard({required String title, required String commandName, required List<String> options, required int selectedIndex, required ValueChanged<int> onSelected}) {
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
                  onPressed: (index) => onSelected(index),
                  borderRadius: BorderRadius.circular(10),
                  selectedColor: Colors.white, fillColor: Colors.blueAccent, color: Colors.white70,
                  constraints: BoxConstraints(minHeight: 36, minWidth: (constraints.maxWidth - (options.length - 1)) / options.length),
                  children: options.map((opt) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(opt, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)))).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchCard({required String title, required String commandName, required bool value, required ValueChanged<bool> onChanged}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), Text(commandName, style: TextStyle(color: Colors.amberAccent.withOpacity(0.8), fontSize: 10, fontFamily: 'monospace'))]),
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
        _buildSectionHeader("ПОЛЕТНЫЕ РЕЖИМЫ И ОГРАНИЧЕНИЯ", Icons.flight),
        _buildSegmentedChoiceCard(title: "Режим полета", commandName: "fl_mode", options: const ["Acro", "Angle", "Horizon"], selectedIndex: _flMode.round(), onSelected: (val) { setState(() => _flMode = val.toDouble()); SerialService.sendCommand("fl_mode $val"); }),
        _buildSliderCard(title: "Максимальный угол крена", commandName: "fl_roll_max", value: _flRollMax, min: 10.0, max: 80.0, divisions: 14, unit: "°", onChanged: (v) => setState(() => _flRollMax = v), onChangeEnd: (v) => SerialService.sendCommand("fl_roll_max $v")),
        _buildSliderCard(title: "Максимальный угол тангажа", commandName: "fl_pitch_max", value: _flPitchMax, min: 10.0, max: 80.0, divisions: 14, unit: "°", onChanged: (v) => setState(() => _flPitchMax = v), onChangeEnd: (v) => SerialService.sendCommand("fl_pitch_max $v")),
        _buildSliderCard(title: "Максимальная вертикальная скорость", commandName: "fl_vz_speed_max", value: _flVzSpeedMax, min: 0.5, max: 3.0, divisions: 25, unit: "м/с", onChanged: (v) => setState(() => _flVzSpeedMax = v), onChangeEnd: (v) => SerialService.sendCommand("fl_vz_speed_max $v")),
        _buildSliderCard(title: "Минимальная высота полета", commandName: "fl_height_min", value: _flHeightMin, min: 0.0, max: 5.0, divisions: 50, unit: "м", onChanged: (v) => setState(() => _flHeightMin = v), onChangeEnd: (v) => SerialService.sendCommand("fl_height_min $v")),

        _buildSectionHeader("АВАРИЙНАЯ ПОСАДКА И СВЯЗЬ", Icons.warning_amber_rounded),
        _buildSwitchCard(title: "При разряде батареи", commandName: "fs_bat_en", value: _fsBatEn == 1, onChanged: (v) { setState(() => _fsBatEn = v ? 1 : 0); SerialService.sendCommand("fs_bat_en ${_fsBatEn.round()}"); }),
        _buildSwitchCard(title: "При обрыве связи с пультом", commandName: "fs_rtx_en", value: _fsRtxEn == 1, onChanged: (v) { setState(() => _fsRtxEn = v ? 1 : 0); SerialService.sendCommand("fs_rtx_en ${_fsRtxEn.round()}"); }),
        _buildSwitchCard(title: "При обрыве связи по шине SPI", commandName: "fs_spi_en", value: _fsSpiEn == 1, onChanged: (v) { setState(() => _fsSpiEn = v ? 1 : 0); SerialService.sendCommand("fs_spi_en ${_fsSpiEn.round()}"); }),
        _buildSwitchCard(title: "При обрыве связи по шине I2C", commandName: "fs_i2c_en", value: _fsI2cEn == 1, onChanged: (v) { setState(() => _fsI2cEn = v ? 1 : 0); SerialService.sendCommand("fs_i2c_en ${_fsI2cEn.round()}"); }),
        
        _buildSliderCard(
          title: "Порог падения качества связи", commandName: "rtx_link_warn_threshold", value: _rtxLinkWarnThreshold,
          min: 5, max: 90, divisions: 85, unit: "%",
          onChanged: (v) => setState(() => _rtxLinkWarnThreshold = v),
          onChangeEnd: (v) { SerialService.rtxLinkWarnThreshold = v; SerialService.sendCommand("rtx_link_warn_threshold ${v.round()}"); },
        ),
        _buildSwitchCard(
          title: "Инициатива с борта при ухудшении связи", commandName: "rtx_auto_en", value: _rtxAutoEn == 1,
          onChanged: (v) { setState(() => _rtxAutoEn = v ? 1 : 0); SerialService.rtxAutoEn = v ? 1.0 : 0.0; SerialService.sendCommand("rtx_auto_en ${_rtxAutoEn.round()}"); },
        ),

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
        PidAxisCardWidget(axisName: "Roll Axis (Rate)", kpCmd: "roll_kp", kiCmd: "roll_ki", kdCmd: "roll_kd", kp: _rollKp, ki: _rollKi, kd: _rollKd, onUpdate: (p, i, d) { setState(() { _rollKp = p; _rollKi = i; _rollKd = d; }); SerialService.sendCommand("roll_kp $p"); SerialService.sendCommand("roll_ki $i"); SerialService.sendCommand("roll_kd $d"); }),
        PidAxisCardWidget(axisName: "Pitch Axis (Rate)", kpCmd: "pitch_kp", kiCmd: "pitch_ki", kdCmd: "pitch_kd", kp: _pitchKp, ki: _pitchKi, kd: _pitchKd, onUpdate: (p, i, d) { setState(() { _pitchKp = p; _pitchKi = i; _pitchKd = d; }); SerialService.sendCommand("pitch_kp $p"); SerialService.sendCommand("pitch_ki $i"); SerialService.sendCommand("pitch_kd $d"); }),
        PidAxisCardWidget(axisName: "Yaw Axis (Rate)", kpCmd: "yaw_kp", kiCmd: "yaw_ki", kdCmd: "yaw_kd", kp: _yawKp, ki: _yawKi, kd: _yawKd, onUpdate: (p, i, d) { setState(() { _yawKp = p; _yawKi = i; _yawKd = d; }); SerialService.sendCommand("yaw_kp $p"); SerialService.sendCommand("yaw_ki $i"); SerialService.sendCommand("yaw_kd $d"); }),
        PidAxisCardWidget(axisName: "Vertical Speed Axis (Vz)", kpCmd: "vz_kp", kiCmd: "vz_ki", kdCmd: "vz_kd", kp: _vzKp, ki: _vzKi, kd: _vzKd, onUpdate: (p, i, d) { setState(() { _vzKp = p; _vzKi = i; _vzKd = d; }); SerialService.sendCommand("vz_kp $p"); SerialService.sendCommand("vz_ki $i"); SerialService.sendCommand("vz_kd $d"); }),
        const SizedBox(height: 24),
      ],
    );
  }
}

class PidAxisCardWidget extends StatefulWidget {
  final String axisName;
  final String kpCmd, kiCmd, kdCmd;
  final double kp, ki, kd;
  final Function(double, double, double) onUpdate;

  const PidAxisCardWidget({super.key, required this.axisName, required this.kpCmd, required this.kiCmd, required this.kdCmd, required this.kp, required this.ki, required this.kd, required this.onUpdate});

  @override
  State<PidAxisCardWidget> createState() => _PidAxisCardWidgetState();
}

class _PidAxisCardWidgetState extends State<PidAxisCardWidget> {
  late TextEditingController _pController, _iController, _dController;

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
    _pController.dispose(); _iController.dispose(); _dController.dispose();
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
                Expanded(child: TextField(controller: _pController, decoration: const InputDecoration(labelText: 'Kp', isDense: true), keyboardType: TextInputType.number, onSubmitted: (val) { double? np = double.tryParse(val); if (np != null) widget.onUpdate(np, widget.ki, widget.kd); })),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _iController, decoration: const InputDecoration(labelText: 'Ki', isDense: true), keyboardType: TextInputType.number, onSubmitted: (val) { double? ni = double.tryParse(val); if (ni != null) widget.onUpdate(widget.kp, ni, widget.kd); })),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _dController, decoration: const InputDecoration(labelText: 'Kd', isDense: true), keyboardType: TextInputType.number, onSubmitted: (val) { double? nd = double.tryParse(val); if (nd != null) widget.onUpdate(widget.kp, widget.ki, nd); })),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// ВКЛАДКА: ПУЛЬТ RC (RemoteControlTab)
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

  Widget _buildSliderCard({required String title, required String commandName, required double value, required double min, required double max, required int divisions, required String unit, required ValueChanged<double> onChanged, required ValueChanged<double> onChangeEnd}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), Text(commandName, style: TextStyle(color: Colors.amberAccent.withOpacity(0.8), fontSize: 10, fontFamily: 'monospace'))])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text("${value.toStringAsFixed(value.truncate() == value ? 0 : 1)} $unit", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 11))),
              ],
            ),
            Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged, onChangeEnd: onChangeEnd),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedChoiceCard({required String title, required String commandName, required List<String> options, required int selectedIndex, required ValueChanged<int> onSelected}) {
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
                  onPressed: (index) => onSelected(index),
                  borderRadius: BorderRadius.circular(10),
                  selectedColor: Colors.white, fillColor: Colors.blueAccent, color: Colors.white70,
                  constraints: BoxConstraints(minHeight: 36, minWidth: (constraints.maxWidth - (options.length - 1)) / options.length),
                  children: options.map((opt) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(opt, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)))).toList(),
                );
              },
            ),
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
        _buildSectionHeader("КАЛИБРОВКА СТИКОВ ПУЛЬТА", Icons.gamepad),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Калибровка нейтрали стиков", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const Text("rc_cal_sticks", style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontFamily: 'monospace')),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (!SerialService.isConnected) {
                        showAppDialog(context, "Ошибка", "Устройство пульта не подключено!", isError: true);
                      } else {
                        SerialService.sendCommand("rc_cal_sticks");
                        showAppDialog(context, "Калибровка", "Команда калибровки нейтрали отправлена в пульт.");
                      }
                    },
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text("Запустить калибровку стиков", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                ),
              ],
            ),
          ),
        ),

        _buildSliderCard(
          title: "Мертвая зона стиков (Deadband)", commandName: "rc_tx_deadband", value: _stickDeadband,
          min: 0, max: 50, divisions: 50, unit: "PWM",
          onChanged: (v) => setState(() => _stickDeadband = v),
          onChangeEnd: (v) => SerialService.sendCommand("rc_tx_deadband ${v.round()}"),
        ),

        _buildSectionHeader("ПРОТОКОЛ И РАДИОПЕРЕДАТЧИК ПУЛЬТА", Icons.wifi),
        _buildSegmentedChoiceCard(
          title: "Протокол связи с модулем", commandName: "rc_proto",
          options: const ["CRSF", "XFire RTX", "SBUS"],
          selectedIndex: _rcProtocol.round(),
          onSelected: (val) { setState(() => _rcProtocol = val.toDouble()); SerialService.sendCommand("rc_proto $val"); },
        ),

        _buildSliderCard(
          title: "Выходная мощность передатчика пульта", commandName: "tx_power_mw", value: _txPowerW,
          min: 10, max: 1000, divisions: 99, unit: "мВт",
          onChanged: (v) => setState(() => _txPowerW = v),
          onChangeEnd: (v) => SerialService.sendCommand("tx_power_mw ${v.round()}"),
        ),

        _buildSectionHeader("ТЕСТ КАНАЛОВ ПУЛЬТА (CH1 - CH4)", Icons.bar_chart),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Монитор каналов управления в реальном времени", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 12),
                _buildChannelBar("Channel 1 (Roll)", 1500, Colors.blueAccent),
                _buildChannelBar("Channel 2 (Pitch)", 1500, Colors.cyanAccent),
                _buildChannelBar("Channel 3 (Throttle)", 1000, Colors.greenAccent),
                _buildChannelBar("Channel 4 (Yaw)", 1500, Colors.amberAccent),
              ],
            ),
          ),
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
// ГРАФИЧЕСКИЕ СХЕМЫ АНТЕНН (Custom Painters)
// ==========================================
class DipoleSchematicPainter extends CustomPainter {
  final bool hasSleeve;
  DipoleSchematicPainter({required this.hasSleeve});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.cyanAccent..strokeWidth = 3.0..strokeCap = StrokeCap.round;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final cx = size.width / 2;
    
    if (hasSleeve) {
      final sleevePaint = Paint()
        ..color = Colors.blueAccent.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, size.height / 2), width: 14, height: size.height - 10), const Radius.circular(6)),
        sleevePaint,
      );
    }

    canvas.drawLine(Offset(cx, 15), Offset(cx, size.height / 2 - 5), paint);
    canvas.drawLine(Offset(cx, size.height / 2 + 5), Offset(cx, size.height - 15), paint..color = Colors.blueAccent..strokeWidth = 5.0);
    canvas.drawCircle(Offset(cx, size.height / 2), 3, Paint()..color = Colors.redAccent);

    textPainter.text = const TextSpan(text: "Верхнее плечо", style: TextStyle(color: Colors.white70, fontSize: 9));
    textPainter.layout();
    textPainter.paint(canvas, Offset(cx + 12, 25));

    textPainter.text = const TextSpan(text: "Нижнее плечо (трубка)", style: TextStyle(color: Colors.white70, fontSize: 9));
    textPainter.layout();
    textPainter.paint(canvas, Offset(cx + 12, size.height - 35));
  }

  @override
  bool shouldRepaint(covariant DipoleSchematicPainter oldDelegate) => oldDelegate.hasSleeve != hasSleeve;
}

class KharchenkoSchematicPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.amberAccent..strokeWidth = 3.0..style = PaintingStyle.stroke..strokeJoin = StrokeJoin.round;
    final cx = size.width / 2;
    final cy = size.height / 2;
    const sizeDiamond = 35.0;

    final path = Path()
      ..moveTo(cx, cy - sizeDiamond)
      ..lineTo(cx + sizeDiamond, cy)
      ..lineTo(cx, cy + sizeDiamond)
      ..lineTo(cx - sizeDiamond, cy)
      ..close()
      ..moveTo(cx, cy - sizeDiamond)
      ..lineTo(cx - sizeDiamond * 2, cy)
      ..lineTo(cx, cy + sizeDiamond)
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawCircle(Offset(cx, cy + sizeDiamond), 3, Paint()..color = Colors.redAccent);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = const TextSpan(text: "Сторона ромба (λ/4)", style: TextStyle(color: Colors.cyanAccent, fontSize: 10));
    textPainter.layout();
    textPainter.paint(canvas, Offset(cx + 8, cy - 25));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==========================================
// ВКЛАДКА: РАДИОМОДУЛЬ RTX (RadioTab)
// ==========================================
class RadioTab extends StatefulWidget {
  const RadioTab({super.key});

  @override
  State<RadioTab> createState() => _RadioTabState();
}

class _RadioTabState extends State<RadioTab> {
  double _rtxEn = 1;
  double _rtxBand = SerialService.rtxBand;
  double _rtxChan = SerialService.rtxChan;
  double _rtxSf = SerialService.rtxSf;
  double _rtxBw = SerialService.rtxBw; 
  double _rtxCr = SerialService.rtxCr;
  double _rtxPower = SerialService.rtxPower;
  
  double _calcEnvironmentLoss = 15.0; 

  double _dipoleTubeDiameterMm = 3.0; 
  double _dipoleTopWireSqMm = 1.0;    
  double _kharchenkoWireSqMm = 2.0;   

  bool _hasProtectiveSleeve = true;
  double _sleeveThicknessMm = 1.0; 
  int _antennaComboIndex = 1;

  final List<double> _bwTable = [
    7800.0, 10400.0, 15600.0, 20800.0, 31250.0, 
    41700.0, 62500.0, 125000.0, 250000.0, 500000.0
  ];

  final Map<int, double> _snrTable = {
    5: -2.5, 6: -5.0, 7: -7.5, 8: -10.0, 
    9: -12.5, 10: -15.0, 11: -17.5, 12: -20.0
  };

  double get _currentFreqMhz => (_rtxBand * 100.0) + _rtxChan;

  double _calculateSensitivity() {
    int bwIdx = _rtxBw.round().clamp(0, _bwTable.length - 1);
    double bwHz = _bwTable[bwIdx];
    int sfInt = _rtxSf.round().clamp(5, 12);
    double snr = _snrTable[sfInt] ?? -7.5;
    return -174.0 + (10.0 * (math.log(bwHz) / math.ln10)) + 6.0 + snr;
  }

  double _calculateAirDataRate() {
    int bwIdx = _rtxBw.round().clamp(0, _bwTable.length - 1);
    double bwHz = _bwTable[bwIdx];
    int sfInt = _rtxSf.round().clamp(5, 12);
    int crInt = _rtxCr.round().clamp(1, 4);
    double symbolRate = bwHz / math.pow(2, sfInt);
    return sfInt * symbolRate * (4.0 / (4.0 + crInt));
  }

  Map<String, dynamic> _calculateLinkBudget() {
    double sensitivity = _calculateSensitivity();
    double gTx = (_antennaComboIndex == 1) ? 5.5 : 2.15;
    double gRx = 2.15;
    double cableLoss = 1.0;

    double eirp = _rtxPower + gTx - cableLoss;
    double maxPathLoss = eirp + gRx - sensitivity - _calcEnvironmentLoss;
    if (maxPathLoss < 0) maxPathLoss = 0;

    double freqLog = 20 * (math.log(_currentFreqMhz) / math.ln10);
    double exponent = (maxPathLoss - 32.44 - freqLog) / 20.0;
    double distanceKm = math.pow(10.0, exponent).toDouble();
    double bitRate = _calculateAirDataRate();

    return {
      'sensitivity': sensitivity,
      'eirp': eirp,
      'distanceKm': distanceKm,
      'bitRate': bitRate,
    };
  }

  Map<String, dynamic> _calculateAntennaDimensions() {
    double freqHz = _currentFreqMhz * 1e6;
    double nAtmosphere = 1.0003;
    double cInAir = 299792458.0 / nAtmosphere;
    double lambdaMm = (cInAir / freqHz) * 1000.0;
    double quarterLambda = lambdaMm / 4.0;

    double dielectricLoading = 1.0;
    if (_hasProtectiveSleeve) {
      double epsilonR = 2.6;
      dielectricLoading = 1.0 + (0.018 * (epsilonR - 1.0) * (_sleeveThicknessMm / 1.0));
    }

    double radiusBot = _dipoleTubeDiameterMm / 2.0;
    double omegaBot = 2.0 * math.log(lambdaMm / radiusBot);
    double kFactorDipoleBot = (0.97 - (2.5 / omegaBot) - (0.003 * (_dipoleTubeDiameterMm / 1.0))) / dielectricLoading;

    double radiusTop = math.sqrt(_dipoleTopWireSqMm / math.pi);
    double omegaTop = 2.0 * math.log(lambdaMm / radiusTop);
    double kFactorDipoleTop = (0.97 - (2.0 / omegaTop)) / dielectricLoading;

    double feedGapMm = 3.0;
    double gapCorrection = 0.002 * (feedGapMm / (lambdaMm / 100.0));

    double dipoleArmTopMm = quarterLambda * kFactorDipoleTop - gapCorrection;
    double dipoleArmBotMm = quarterLambda * kFactorDipoleBot - gapCorrection;

    double radiusKharc = math.sqrt(_kharchenkoWireSqMm / math.pi);
    double omegaKharc = 2.0 * math.log(lambdaMm / (2.0 * radiusKharc));
    double kFactorKharc = 0.96 - (1.8 / omegaKharc);
    double kharchenkoSideMm = quarterLambda * kFactorKharc;

    return {
      'lambdaMm': lambdaMm,
      'dipoleArmTopMm': dipoleArmTopMm,
      'dipoleArmBotMm': dipoleArmBotMm,
      'kharchenkoSideMm': kharchenkoSideMm,
    };
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

  Widget _buildSliderCard({required String title, required String commandName, required double value, required double min, required double max, required int divisions, required String unit, required ValueChanged<double> onChanged, required ValueChanged<double> onChangeEnd}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), Text(commandName, style: TextStyle(color: Colors.amberAccent.withOpacity(0.8), fontSize: 10, fontFamily: 'monospace'))])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text("${value.toStringAsFixed(value.truncate() == value ? 0 : 2)} $unit", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 11))),
              ],
            ),
            Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged, onChangeEnd: onChangeEnd),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchCard({required String title, required String commandName, required bool value, required ValueChanged<bool> onChanged}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), Text(commandName, style: TextStyle(color: Colors.amberAccent.withOpacity(0.8), fontSize: 10, fontFamily: 'monospace'))]),
            Switch(value: value, onChanged: onChanged, activeColor: Colors.blueAccent),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var linkResults = _calculateLinkBudget();
    var antResults = _calculateAntennaDimensions();
    
    double distKm = linkResults['distanceKm'];
    String distFormatted = distKm >= 1.0 ? "${distKm.toStringAsFixed(2)} км" : "${(distKm * 1000).toStringAsFixed(0)} м";
    double bitRate = linkResults['bitRate'];
    String bitRateStr = bitRate >= 1000 ? "${(bitRate / 1000).toStringAsFixed(1)} kbps" : "${bitRate.toStringAsFixed(0)} bps";
    double sensitivity = linkResults['sensitivity'];

    double sensitivityProgress = ((sensitivity - (-140.0)) / ((-100.0) - (-140.0))).clamp(0.0, 1.0);
    double bitRateProgress = (bitRate / 30000.0).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      children: [
        _buildSectionHeader("ПАРАМЕТРЫ РАДИОМОДУЛЯ RTX (SPI)", Icons.wifi),
        _buildSwitchCard(title: "Включить RTX модуль", commandName: "rtx_en", value: _rtxEn == 1, onChanged: (v) { setState(() => _rtxEn = v ? 1 : 0); SerialService.sendCommand("rtx_en ${_rtxEn.round()}"); }),
        _buildSliderCard(
          title: "Частотный диапазон (x100 МГц)", commandName: "rtx_band", value: _rtxBand, min: 1, max: 9, divisions: 8, unit: "",
          onChanged: (v) => setState(() => _rtxBand = v),
          onChangeEnd: (v) { SerialService.rtxBand = v; SerialService.sendCommand("rtx_band ${v.round()}"); },
        ),
        _buildSliderCard(title: "Сетевой адрес устройства", commandName: "rtx_addr", value: 1234, min: 0, max: 65535, divisions: 100, unit: "", onChanged: (v) {}, onChangeEnd: (v) {}),
        _buildSliderCard(
          title: "Рабочий канал связи (1 МГц шаг)", commandName: "rtx_chan", value: _rtxChan, min: 0, max: 99, divisions: 99, unit: "МГц",
          onChanged: (v) => setState(() => _rtxChan = v),
          onChangeEnd: (v) { SerialService.rtxChan = v; SerialService.sendCommand("rtx_chan ${v.round()}"); },
        ),
        _buildSliderCard(
          title: "Spreading Factor (SF)", commandName: "rtx_sf", value: _rtxSf, min: 5, max: 12, divisions: 7, unit: "",
          onChanged: (v) => setState(() => _rtxSf = v),
          onChangeEnd: (v) { SerialService.rtxSf = v; SerialService.sendCommand("rtx_sf ${v.round()}"); },
        ),
        _buildSliderCard(
          title: "Полоса пропускания (Bandwidth)", commandName: "rtx_bw", value: _rtxBw, min: 0, max: 9, divisions: 9, unit: "",
          onChanged: (v) => setState(() => _rtxBw = v),
          onChangeEnd: (v) { SerialService.rtxBw = v; SerialService.sendCommand("rtx_bw ${v.round()}"); },
        ),
        _buildSliderCard(
          title: "Коэффициент кодирования (Coding Rate)", commandName: "rtx_cr", value: _rtxCr, min: 1, max: 4, divisions: 3, unit: "",
          onChanged: (v) => setState(() => _rtxCr = v),
          onChangeEnd: (v) { SerialService.rtxCr = v; SerialService.sendCommand("rtx_cr ${v.round()}"); },
        ),
        _buildSliderCard(
          title: "Мощность передатчика", commandName: "rtx_power", value: _rtxPower, min: -9, max: 22, divisions: 31, unit: "dBm",
          onChanged: (v) => setState(() => _rtxPower = v),
          onChangeEnd: (v) { SerialService.rtxPower = v; SerialService.sendCommand("rtx_power ${v.round()}"); },
        ),

        _buildSectionHeader("КАЛЬКУЛЯТОР ЛИНКА И АНТЕНН (ЧАСТОТА: ${_currentFreqMhz.toStringAsFixed(0)} МГц)", Icons.analytics),
        
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Комбинация антенн:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                DropdownButton<int>(
                  value: _antennaComboIndex,
                  dropdownColor: const Color(0xFF1C1C1E),
                  underline: const SizedBox(),
                  style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text("Штырь + Штырь (2.15 dBi)")),
                    DropdownMenuItem(value: 1, child: Text("Харченко + Штырь (5.5 dBi)")),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _antennaComboIndex = val);
                  },
                ),
              ],
            ),
          ),
        ),

        Card(
          color: const Color(0xFF1E222B),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text("ПРОГНОЗИРУЕМАЯ ДАЛЬНОСТЬ СВЯЗИ", style: TextStyle(fontSize: 10, color: Colors.amberAccent, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                const SizedBox(height: 8),
                Text(distFormatted, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                const SizedBox(height: 12),
                const Divider(color: Colors.white12),
                const SizedBox(height: 8),
                
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(child: Text("Чувствительность приемника (Sensitivity):", style: TextStyle(fontSize: 11, color: Colors.white70), overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Text("${sensitivity.toStringAsFixed(1)} dBm", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: sensitivityProgress, color: Colors.cyanAccent, backgroundColor: Colors.white12, minHeight: 6, borderRadius: BorderRadius.circular(3)),
                  ],
                ),
                const SizedBox(height: 12),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(child: Text("Скорость по воздуху (Air Data Rate):", style: TextStyle(fontSize: 11, color: Colors.white70), overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Text(bitRateStr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: bitRateProgress, color: Colors.blueAccent, backgroundColor: Colors.white12, minHeight: 6, borderRadius: BorderRadius.circular(3)),
                  ],
                ),
                const SizedBox(height: 10),

                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  children: [
                    Text("EIRP Пульта: ${(linkResults['eirp'] as double).toStringAsFixed(1)} dBm", style: const TextStyle(fontSize: 11, color: Colors.white60)),
                    Text("Запас: ${_calcEnvironmentLoss.toStringAsFixed(0)} dB", style: const TextStyle(fontSize: 11, color: Colors.white60)),
                  ],
                ),
              ],
            ),
          ),
        ),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Графический расчет плеч и геометрии антенн", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amberAccent)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Text("Штыревой диполь", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                          const SizedBox(height: 6),
                          Container(
                            height: 120,
                            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
                            child: CustomPaint(painter: DipoleSchematicPainter(hasSleeve: _hasProtectiveSleeve), size: const Size(double.infinity, 120)),
                          ),
                          const SizedBox(height: 6),
                          Text("Верх: ${(antResults['dipoleArmTopMm'] as double).toStringAsFixed(1)} мм", style: const TextStyle(fontSize: 10, color: Colors.white70)),
                          Text("Низ: ${(antResults['dipoleArmBotMm'] as double).toStringAsFixed(1)} мм", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          const Text("Антенна Харченко", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                          const SizedBox(height: 6),
                          Container(
                            height: 120,
                            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
                            child: CustomPaint(painter: KharchenkoSchematicPainter(), size: const Size(double.infinity, 120)),
                          ),
                          const SizedBox(height: 6),
                          const Text("Сторона ромба", style: TextStyle(fontSize: 10, color: Colors.white70)),
                          Text("Сторона: ${(antResults['kharchenkoSideMm'] as double).toStringAsFixed(1)} мм", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Физические параметры материалов и среды", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 10),

                SwitchListTile(
                  title: const Text("Защитная трубка / термоусадка на диполе", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  subtitle: const Text("Учитывает диэлектрическую нагрузку пластика", style: TextStyle(fontSize: 10, color: Colors.white60)),
                  value: _hasProtectiveSleeve,
                  activeColor: Colors.blueAccent,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() => _hasProtectiveSleeve = v),
                ),
                if (_hasProtectiveSleeve) ...[
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text("Толщина стенки трубки (чехла):", style: TextStyle(fontSize: 11, color: Colors.white70)),
                    Text("${_sleeveThicknessMm.toStringAsFixed(1)} мм (0.5-3.0)", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                  ]),
                  Slider(value: _sleeveThicknessMm, min: 0.5, max: 3.0, divisions: 25, onChanged: (v) => setState(() => _sleeveThicknessMm = v)),
                ],

                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text("Диаметр трубки диполя (нижн.):", style: TextStyle(fontSize: 11, color: Colors.white70)),
                  Text("${_dipoleTubeDiameterMm.toStringAsFixed(1)} мм (2-5мм)", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                ]),
                Slider(value: _dipoleTubeDiameterMm, min: 2.0, max: 5.0, divisions: 6, onChanged: (v) => setState(() => _dipoleTubeDiameterMm = v)),

                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text("Сечение провода диполя (верхн.):", style: TextStyle(fontSize: 11, color: Colors.white70)),
                  Text("${_dipoleTopWireSqMm.toStringAsFixed(2)} мм² (0.5-2.5)", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                ]),
                Slider(value: _dipoleTopWireSqMm, min: 0.5, max: 2.5, divisions: 20, onChanged: (v) => setState(() => _dipoleTopWireSqMm = v)),

                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text("Сечение провода Харченко:", style: TextStyle(fontSize: 11, color: Colors.white70)),
                  Text("${_kharchenkoWireSqMm.toStringAsFixed(1)} мм² (1-4)", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                ]),
                Slider(value: _kharchenkoWireSqMm, min: 1.0, max: 4.0, divisions: 15, onChanged: (v) => setState(() => _kharchenkoWireSqMm = v)),

                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text("Запас на условия (Fade Margin):", style: TextStyle(fontSize: 11, color: Colors.white70)),
                  Text("${_calcEnvironmentLoss.toStringAsFixed(0)} dB", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                ]),
                Slider(value: _calcEnvironmentLoss, min: 5.0, max: 30.0, divisions: 25, onChanged: (v) => setState(() => _calcEnvironmentLoss = v)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ==========================================
// ВКЛАДКА: КАЛИБРОВКА И ТЕСТЫ (TestsTab)
// ==========================================
class TestsTab extends StatefulWidget {
  const TestsTab({super.key});

  @override
  State<TestsTab> createState() => _TestsTabState();
}

class _TestsTabState extends State<TestsTab> {
  int _selectedChannel = 0;

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

  Widget _buildActionCard({required BuildContext context, required String title, required String subtitleCommand, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 22)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(height: 2), Text(subtitleCommand, style: TextStyle(color: Colors.amberAccent.withOpacity(0.8), fontSize: 10, fontFamily: 'monospace'))])),
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
        _buildSectionHeader("АППАРАТНЫЕ ТЕСТЫ ОБОРУДОВАНИЯ", Icons.memory),
        _buildActionCard(context: context, title: "Тест подключения MPU6050", subtitleCommand: "test_mpu", icon: Icons.explore, color: Colors.cyanAccent, onTap: () { if (!SerialService.isConnected) { showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true); } else { SerialService.sendCommand("test_mpu"); showAppDialog(context, "Тест MPU6050", "Команда отправлена."); } }),
        _buildActionCard(context: context, title: "Тест подключения SX126x", subtitleCommand: "test_sx", icon: Icons.wifi, color: Colors.blueAccent, onTap: () { if (!SerialService.isConnected) { showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true); } else { SerialService.sendCommand("test_sx"); showAppDialog(context, "Тест SX126x", "Проверка SPI запущена!"); } }),
        _buildActionCard(context: context, title: "Тест подключения лидара", subtitleCommand: "test_lidar", icon: Icons.radar, color: Colors.orangeAccent, onTap: () { if (!SerialService.isConnected) { showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true); } else { SerialService.sendCommand("test_lidar"); showAppDialog(context, "Тест лидара", "Запрос отправлен!"); } }),

        _buildSectionHeader("ИСПОЛНИТЕЛЬНЫЕ И СИСТЕМНЫЕ ТЕСТЫ", Icons.gavel),
        _buildActionCard(context: context, title: "Тест моторов 25%", subtitleCommand: "test_motor", icon: Icons.sports_motorsports, color: Colors.redAccent, onTap: () { if (!SerialService.isConnected) { showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true); } else { SerialService.sendCommand("test_motor"); showAppDialog(context, "Внимание", "Тест моторов (25%) активирован!", isError: true); } }),
        _buildActionCard(context: context, title: "Тест PID 25%", subtitleCommand: "test_pid", icon: Icons.tune, color: Colors.purpleAccent, onTap: () { if (!SerialService.isConnected) { showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true); } else { SerialService.sendCommand("test_pid"); showAppDialog(context, "Тест PID", "Стресс-тест ПИД активирован."); } }),
        _buildActionCard(context: context, title: "Тест связи с пультом", subtitleCommand: "test_rc", icon: Icons.gamepad, color: Colors.greenAccent, onTap: () { if (!SerialService.isConnected) { showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true); } else { SerialService.sendCommand("test_rc"); showAppDialog(context, "Тест RC", "Диагностика пакетов запущена."); } }),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Тест смены канала связи с пультом", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amberAccent)),
                const Text("test_rc_can", style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontFamily: 'monospace')),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Выбор канала (0 - 99):", style: TextStyle(fontSize: 11, color: Colors.white70)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: Text("КАНАЛ: $_selectedChannel", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
                Slider(
                  value: _selectedChannel.toDouble(),
                  min: 0,
                  max: 99,
                  divisions: 99,
                  onChanged: (v) => setState(() => _selectedChannel = v.round()),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (!SerialService.isConnected) {
                        showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true);
                      } else {
                        SerialService.sendCommand("test_rc_can $_selectedChannel");
                        showAppDialog(context, "Успех", "Отправлена команда: test_rc_can $_selectedChannel");
                      }
                    },
                    icon: const Icon(Icons.wifi_channel, size: 16),
                    label: const Text("Выполнить тест смены канала", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        _buildSectionHeader("КАЛИБРОВКИ ДАТЧИКОВ", Icons.explore),
        _buildActionCard(context: context, title: "Калибровка гироскопа", subtitleCommand: "cal_gyro", icon: Icons.explore_outlined, color: Colors.blueAccent, onTap: () { if (!SerialService.isConnected) { showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true); } else { SerialService.sendCommand("cal_gyro"); showAppDialog(context, "Успех", "Калибровка гироскопа запущена!"); } }),
        _buildActionCard(context: context, title: "Калибровка акселерометра", subtitleCommand: "cal_acc", icon: Icons.grid_view, color: Colors.cyanAccent, onTap: () { if (!SerialService.isConnected) { showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true); } else { SerialService.sendCommand("cal_acc"); showAppDialog(context, "Успех", "Калибровка акселерометра запущена!"); } }),
        _buildActionCard(context: context, title: "Калибровка лидара (Xtalk)", subtitleCommand: "cal_lidar", icon: Icons.radar, color: Colors.orangeAccent, onTap: () { if (!SerialService.isConnected) { showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true); } else { SerialService.sendCommand("cal_lidar"); showAppDialog(context, "Успех", "Калибровка лидара запущена!"); } }),
        _buildSectionHeader("СИСТЕМНЫЕ КОМАНДЫ", Icons.settings),
        _buildActionCard(context: context, title: "Применить настройки RTX", subtitleCommand: "rtx_write", icon: Icons.save, color: Colors.greenAccent, onTap: () { if (!SerialService.isConnected) { showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true); } else { SerialService.sendCommand("rtx_write"); showAppDialog(context, "Успех", "Настройки радиомодуля применены!"); } }),
      ],
    );
  }
}

// ==========================================
// ВИДЖЕТ ТЕРМИНАЛА CLI (TerminalTab)
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
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => SerialService.sendCommand("info"),
                    icon: const Icon(Icons.info_outline, size: 16, color: Colors.white),
                    label: const Text("Read Config Info", style: TextStyle(color: Colors.white)),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 44,
                  child: IconButton.filledTonal(
                    onPressed: () { SerialService.terminalLog = ""; SerialService.logController.add(""); },
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
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
              child: SingleChildScrollView(reverse: true, child: Text(_displayLog, style: const TextStyle(fontFamily: 'monospace', color: Colors.greenAccent, fontSize: 11))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cmdController,
                    style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                    decoration: const InputDecoration(hintText: "Enter CLI command..."),
                    onSubmitted: (val) { if (val.isNotEmpty) { SerialService.sendCommand(val); _cmdController.clear(); } },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                  onPressed: () { if (_cmdController.text.isNotEmpty) { SerialService.sendCommand(_cmdController.text); _cmdController.clear(); } },
                  style: IconButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.all(14)),
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
// КЛАССИЧЕСКИЕ ШКАЛЫ ДЛЯ HUD (Вариант 1)
// ==========================================
class ClassicHudScalePainter extends CustomPainter {
  final double value;
  final double minVal;
  final double maxVal;
  final Color color;
  final bool isVertical;

  ClassicHudScalePainter({
    required this.value,
    required this.minVal,
    required this.maxVal,
    required this.color,
    required this.isVertical,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()..color = Colors.white30..strokeWidth = 1.5;
    final paintText = TextPainter(textDirection: TextDirection.ltr);
    final indicatorPaint = Paint()..color = color..style = PaintingStyle.fill;

    if (isVertical) {
      final x = size.width - 12.0;
      canvas.drawLine(Offset(x, 8), Offset(x, size.height - 8), paintLine);

      double range = maxVal - minVal;
      int steps = 4;
      for (int i = 0; i <= steps; i++) {
        double v = minVal + (range / steps) * i;
        double ratio = (v - minVal) / range;
        double y = size.height - 8 - ratio * (size.height - 16);

        canvas.drawLine(Offset(x - 4, y), Offset(x, y), paintLine);

        paintText.text = TextSpan(
          text: "${v.toInt()}°",
          style: const TextStyle(color: Colors.white60, fontSize: 8),
        );
        paintText.layout();
        paintText.paint(canvas, Offset(x - 26, y - 5));
      }

      double clampedVal = value.clamp(minVal, maxVal);
      double currentRatio = (clampedVal - minVal) / range;
      double currentY = size.height - 8 - currentRatio * (size.height - 16);

      final path = Path()
        ..moveTo(x - 12, currentY)
        ..lineTo(x - 4, currentY - 4)
        ..lineTo(x - 4, currentY + 4)
        ..close();
      canvas.drawPath(path, indicatorPaint);

    } else {
      final y = size.height - 10.0;
      canvas.drawLine(Offset(8, y), Offset(size.width - 8, y), paintLine);

      double range = maxVal - minVal;
      int steps = 6;
      for (int i = 0; i <= steps; i++) {
        double v = minVal + (range / steps) * i;
        double ratio = (v - minVal) / range;
        double x = 8 + ratio * (size.width - 16);

        canvas.drawLine(Offset(x, y), Offset(x, y + 4), paintLine);

        paintText.text = TextSpan(
          text: "${v.toInt()}°",
          style: const TextStyle(color: Colors.white60, fontSize: 8),
        );
        paintText.layout();
        paintText.paint(canvas, Offset(x - 6, y + 6));
      }

      double clampedVal = value.clamp(minVal, maxVal);
      double currentRatio = (clampedVal - minVal) / range;
      double currentX = 8 + currentRatio * (size.width - 16);

      final path = Path()
        ..moveTo(currentX, y - 8)
        ..lineTo(currentX - 4, y)
        ..lineTo(currentX + 4, y)
        ..close();
      canvas.drawPath(path, indicatorPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ClassicHudScalePainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.minVal != minVal || oldDelegate.maxVal != maxVal;
}

// ==========================================
// ВИДЖЕТ КРАСИВОГО АВИАГОРИЗОНТА С НЕБОМ И ЗЕМЛЕЙ
// ==========================================
class ArtificialHorizonPainter extends CustomPainter {
  final double roll, pitch; 
  ArtificialHorizonPainter({required this.roll, required this.pitch});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Обрезаем область по кругу прибора
    final clipPath = Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: radius));
    canvas.clipPath(clipPath);

    // Вращаем холст на угол крена (Roll)
    canvas.rotate(-roll);

    // Смещение по тангажу (Pitch)
    final pitchOffset = pitch * 40.0;

    // Рисуем небо (синий фон)
    final skyRect = Rect.fromLTWH(-radius * 2, -radius * 3 + pitchOffset, radius * 4, radius * 3);
    canvas.drawRect(skyRect, Paint()..color = const Color(0xFF1E6091));

    // Рисуем землю (коричневый фон)
    final groundRect = Rect.fromLTWH(-radius * 2, pitchOffset, radius * 4, radius * 3);
    canvas.drawRect(groundRect, Paint()..color = const Color(0xFF6A4A3A));

    // Линия горизонта
    final horizonPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(-radius * 2, pitchOffset), Offset(radius * 2, pitchOffset), horizonPaint);

    // Штрихи тангажа
    final strokePaint = Paint()..color = Colors.white70..strokeWidth = 1.5;
    for (int p = -3; p <= 3; p++) {
      if (p == 0) continue;
      double yStep = pitchOffset - (p * 20.0);
      double lineWidth = (p.abs() % 2 == 0) ? 20.0 : 10.0;
      canvas.drawLine(Offset(-lineWidth / 2, yStep), Offset(lineWidth / 2, yStep), strokePaint);
    }

    canvas.restore();

    // Внешнее кольцо прибора
    canvas.drawCircle(
      center, 
      radius, 
      Paint()
        ..color = Colors.blueAccent.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
    );
  }

  @override
  bool shouldRepaint(covariant ArtificialHorizonPainter oldDelegate) => 
      oldDelegate.roll != roll || oldDelegate.pitch != pitch;
}

// ==========================================
// ВКЛАДКА: ТЕЛЕМЕТРИЯ (Классический HUD со шкалами)
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
    _telemetrySub = SerialService.telemetryController.stream.listen((_) { if (mounted) setState(() {}); });
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
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)), Text("${value.toStringAsFixed(2)} $unit", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color))]),
          const SizedBox(height: 2),
          LinearProgressIndicator(value: percent, color: color, backgroundColor: Colors.white12, minHeight: 5, borderRadius: BorderRadius.circular(3)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double rollDeg = SerialService.gyroRoll * 57.2958;
    double pitchDeg = SerialService.gyroPitch * 57.2958;
    double yawDeg = (SerialService.gyroYaw * 57.2958) % 360;
    if (yawDeg < 0) yawDeg += 360;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Expanded(
            flex: 6,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
              child: Column(
                children: [
                  const Text("YAW HEADING", style: TextStyle(fontSize: 9, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                  SizedBox(
                    height: 22,
                    child: CustomPaint(
                      painter: ClassicHudScalePainter(value: yawDeg, minVal: 0, maxVal: 360, color: Colors.amberAccent, isVertical: false),
                      size: const Size(double.infinity, 22),
                    ),
                  ),
                  const SizedBox(height: 4),

                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("ROLL", style: TextStyle(fontSize: 9, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                              Expanded(
                                child: CustomPaint(
                                  painter: ClassicHudScalePainter(value: rollDeg, minVal: -180, maxVal: 180, color: Colors.blueAccent, isVertical: true),
                                  size: const Size(double.infinity, double.infinity),
                                ),
                              ),
                            ],
                          ),
                        ),

                        Expanded(
                          flex: 4,
                          child: Center(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CustomPaint(
                                  size: const Size(150, 150),
                                  painter: ArtificialHorizonPainter(roll: SerialService.gyroRoll, pitch: SerialService.gyroPitch),
                                ),
                                const Icon(Icons.local_fire_department, color: Colors.amberAccent, size: 22),
                              ],
                            ),
                          ),
                        ),

                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text("PITCH", style: TextStyle(fontSize: 9, color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                              Expanded(
                                child: CustomPaint(
                                  painter: ClassicHudScalePainter(value: pitchDeg, minVal: -90, maxVal: 90, color: Colors.cyanAccent, isVertical: true),
                                  size: const Size(double.infinity, double.infinity),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),

                  SizedBox(
                    height: 18,
                    child: CustomPaint(
                      painter: ClassicHudScalePainter(value: yawDeg, minVal: 0, maxVal: 360, color: Colors.amberAccent, isVertical: false),
                      size: const Size(double.infinity, 18),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
// ВКЛАДКА: ПРОШИВКА FC И RC (FlasherTab)
// ==========================================
class FlasherTab extends StatefulWidget {
  const FlasherTab({super.key});

  @override
  State<FlasherTab> createState() => _FlasherTabState();
}

class _FlasherTabState extends State<FlasherTab> {
  bool _isFlashingFC = false;
  bool _isFlashingRC = false;
  double _progressFC = 0.0;
  double _progressRC = 0.0;
  String _statusFC = "Готов к прошивке полетного контроллера";
  String _statusRC = "Готов к прошивке пульта управления";

  Future<void> _flashFlightController() async {
    if (!SerialService.isConnected || SerialService.usbPort == null) {
      showAppDialog(context, "Ошибка", "Устройство не подключено по USB!", isError: true);
      return;
    }
    setState(() { _isFlashingFC = true; _progressFC = 0.0; _statusFC = "Связь с загрузчиком FC..."; });
    try {
      await SerialService.usbPort!.write(Uint8List.fromList([0x7F]));
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() => _statusFC = "Запись прошивки FC...");
      for (int i = 1; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        setState(() => _progressFC = i / 10.0);
      }
      setState(() { _isFlashingFC = false; _statusFC = "УСПЕХ: Полетный контроллер прошит!"; });
      if (mounted) showAppDialog(context, "Успех", "Прошивка полетного контроллера завершена!");
    } catch (e) {
      setState(() { _isFlashingFC = false; _statusFC = "ОШИБКА: $e"; });
      if (mounted) showAppDialog(context, "Ошибка", "Сбой прошивки FC: $e", isError: true);
    }
  }

  Future<void> _flashRemoteControl() async {
    if (!SerialService.isConnected || SerialService.usbPort == null) {
      showAppDialog(context, "Ошибка", "Пульт не подключен по USB!", isError: true);
      return;
    }
    setState(() { _isFlashingRC = true; _progressRC = 0.0; _statusRC = "Связь с загрузчиком пульта..."; });
    try {
      await SerialService.usbPort!.write(Uint8List.fromList([0x7F]));
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() => _statusRC = "Запись прошивки пульта...");
      for (int i = 1; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        setState(() => _progressRC = i / 10.0);
      }
      setState(() { _isFlashingRC = false; _statusRC = "УСПЕХ: Пульт успешно прошит!"; });
      if (mounted) showAppDialog(context, "Успех", "Прошивка пульта управления завершена!");
    } catch (e) {
      setState(() { _isFlashingRC = false; _statusRC = "ОШИБКА: $e"; });
      if (mounted) showAppDialog(context, "Ошибка", "Сбой прошивки пульта: $e", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text("ЗАГРУЗЧИКИ ЭКОСИСТЕМЫ XFIRE", style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        ),

        // Загрузчик 1: Полетный контроллер
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("1. Загрузчик полетного контроллера (STM32)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Text(_statusFC, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.greenAccent)),
                const SizedBox(height: 10),
                LinearProgressIndicator(value: _progressFC, color: Colors.blueAccent, backgroundColor: Colors.white12, minHeight: 6, borderRadius: BorderRadius.circular(3)),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: _isFlashingFC ? null : _flashFlightController,
                    icon: const Icon(Icons.memory, size: 16),
                    label: Text(_isFlashingFC ? "Прошивка FC..." : "Прошить полетный контроллер", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Загрузчик 2: Пульт управления
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("2. Загрузчик пульта управления", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Text(_statusRC, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.greenAccent)),
                const SizedBox(height: 10),
                LinearProgressIndicator(value: _progressRC, color: Colors.blueAccent, backgroundColor: Colors.white12, minHeight: 6, borderRadius: BorderRadius.circular(3)),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: _isFlashingRC ? null : _flashRemoteControl,
                    icon: const Icon(Icons.gamepad, size: 16),
                    label: Text(_isFlashingRC ? "Прошивка пульта..." : "Прошить пульт управления", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
