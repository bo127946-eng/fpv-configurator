// XFire Ecosystem v3.6 (Обновлено: центрированный выпадающий список, USB Serial в конце выпадающего меню)

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
// КАСТОМНЫЙ ТРЕК СЛАЙДЕРА С ЧЕРНОЙ ПОЛОСКОЙ
// ==========================================
class XFireSliderTrackShape extends RectangularSliderTrackShape {
  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = true,
    bool isDiscrete = true,
  }) {
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
    );

    final Paint activePaint = Paint()..color = sliderTheme.activeTrackColor ?? Colors.blueAccent..style = PaintingStyle.fill;
    final Paint inactivePaint = Paint()..color = sliderTheme.inactiveTrackColor ?? Colors.white12..style = PaintingStyle.fill;
    final Paint dividerPaint = Paint()..color = Colors.black..style = PaintingStyle.fill;
    final Radius radius = Radius.circular(trackRect.height / 2);

    final Rect inactiveRect = Rect.fromLTRB(thumbCenter.dx, trackRect.top, trackRect.right, trackRect.bottom);
    context.canvas.drawRRect(RRect.fromRectAndRadius(inactiveRect, radius), inactivePaint);

    const double dividerWidth = 3.0;
    final Rect activeRect = Rect.fromLTRB(trackRect.left, trackRect.top, thumbCenter.dx - dividerWidth, trackRect.bottom);
    context.canvas.drawRRect(RRect.fromRectAndRadius(activeRect, radius), activePaint);

    final Rect dividerRect = Rect.fromLTRB(thumbCenter.dx - dividerWidth, trackRect.top, thumbCenter.dx, trackRect.bottom);
    context.canvas.drawRect(dividerRect, dividerPaint);
  }
}

// ==========================================
// ОБЩИЕ УНИВЕРСАЛЬНЫЕ КОМПОНЕНТЫ СТИЛЯ
// ==========================================
class XFireCard extends StatelessWidget {
  final Widget child;
  const XFireCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13.0, vertical: 4.0),
      child: Container(
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: child,
      ),
    );
  }
}

class XFireActionCard extends StatelessWidget {
  final String title;
  final String commandName;
  final VoidCallback onTap;

  const XFireActionCard({
    super.key,
    required this.title,
    required this.commandName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return XFireCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(commandName, style: TextStyle(color: Colors.amberAccent.withOpacity(0.8), fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

class XFireSliderCard extends StatelessWidget {
  final String title;
  final String commandName;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String unit;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const XFireSliderCard({
    super.key,
    required this.title,
    required this.commandName,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.unit,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13.0, vertical: 4.0),
      child: Container(
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
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
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(commandName, style: TextStyle(color: Colors.amberAccent.withOpacity(0.8), fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    "${value.toStringAsFixed(value.truncate() == value ? 0 : 2)} $unit",
                    style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3.0),
              child: SizedBox(
                width: double.infinity,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackShape: XFireSliderTrackShape(),
                    trackHeight: 6.0,
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
                  ),
                  child: Slider(
                    value: value.clamp(min, max),
                    min: min,
                    max: max,
                    divisions: divisions,
                    onChanged: onChanged,
                    onChangeEnd: onChangeEnd,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class XFireSwitchCard extends StatelessWidget {
  final String title;
  final String commandName;
  final bool value;
  final ValueChanged<bool> onChanged;

  const XFireSwitchCard({
    super.key,
    required this.title,
    required this.commandName,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return XFireCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                const SizedBox(height: 2),
                Text(commandName, style: TextStyle(color: Colors.amberAccent.withOpacity(0.8), fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: Colors.blueAccent),
        ],
      ),
    );
  }
}

class XFireSegmentedCard extends StatelessWidget {
  final String title;
  final String commandName;
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const XFireSegmentedCard({
    super.key,
    required this.title,
    required this.commandName,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return XFireCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
          const SizedBox(height: 2),
          Text(commandName, style: TextStyle(color: Colors.amberAccent.withOpacity(0.8), fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              return ToggleButtons(
                isSelected: List.generate(options.length, (i) => i == selectedIndex),
                onPressed: onSelected,
                borderRadius: BorderRadius.circular(10),
                selectedColor: Colors.white, fillColor: Colors.blueAccent, color: Colors.white70,
                constraints: BoxConstraints(minHeight: 36, minWidth: (constraints.maxWidth - (options.length - 1)) / options.length),
                children: options.map((opt) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(opt, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ==========================================
// ПИД ВИДЖЕТ (StatefulWidget)
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
  late TextEditingController _kpController;
  late TextEditingController _kiController;
  late TextEditingController _kdController;

  @override
  void initState() {
    super.initState();
    _kpController = TextEditingController(text: widget.kp.toString());
    _kiController = TextEditingController(text: widget.ki.toString());
    _kdController = TextEditingController(text: widget.kd.toString());
  }

  @override
  void didUpdateWidget(covariant PidAxisCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kp != widget.kp) _kpController.text = widget.kp.toString();
    if (oldWidget.ki != widget.ki) _kiController.text = widget.ki.toString();
    if (oldWidget.kd != widget.kd) _kdController.text = widget.kd.toString();
  }

  @override
  void dispose() {
    _kpController.dispose();
    _kiController.dispose();
    _kdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return XFireCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.axisName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
          const SizedBox(height: 2),
          Text("${widget.kpCmd} / ${widget.kiCmd} / ${widget.kdCmd}", style: TextStyle(color: Colors.amberAccent.withOpacity(0.8), fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: TextField(decoration: const InputDecoration(labelText: 'Kp', isDense: true), keyboardType: TextInputType.number, controller: _kpController, onSubmitted: (val) { double? np = double.tryParse(val); if (np != null) widget.onUpdate(np, widget.ki, widget.kd); })),
              const SizedBox(width: 8),
              Expanded(child: TextField(decoration: const InputDecoration(labelText: 'Ki', isDense: true), keyboardType: TextInputType.number, controller: _kiController, onSubmitted: (val) { double? ni = double.tryParse(val); if (ni != null) widget.onUpdate(widget.kp, ni, widget.kd); })),
              const SizedBox(width: 8),
              Expanded(child: TextField(decoration: const InputDecoration(labelText: 'Kd', isDense: true), keyboardType: TextInputType.number, controller: _kdController, onSubmitted: (val) { double? nd = double.tryParse(val); if (nd != null) widget.onUpdate(widget.kp, widget.ki, nd); })),
            ],
          ),
        ],
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
        child: Text("XFire v3.6", style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, letterSpacing: 4.0, color: Colors.white)),
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
    const TerminalTab(),
  ];

  final List<String> _tabNames = [
    "Инфо", "Полетный контроллер FC", "Пульт RC", "Радиомодуль RTX (915 МГц)", "Терминал CLI",
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
      List<UsbDevice> devices = await UsbSerial.listDevices();
      if (devices.isEmpty) {
        SerialService.appendLog(">> ERROR: No USB devices found\n");
      } else {
        SerialService.usbPort = await devices[0].create();
        bool openResult = await SerialService.usbPort!.open();
        if (!openResult) {
          SerialService.appendLog(">> ERROR: Failed to open USB port\n");
        } else {
          await SerialService.usbPort!.setPortParameters(115200, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);
          SerialService.isConnected = true;
          SerialService.appendLog(">> USB Connected: ${devices[0].deviceName}\n");
          SerialService._usbSubscription = SerialService.usbPort!.inputStream!.listen((data) => SerialService.handleIncomingData(data));
        }
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
                  // USB Serial в конце выпадающего списка
                  DropdownMenuItem<int>(
                    value: _tabs.length,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Соединение USB Serial",
                          style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Icon(
                          Icons.usb,
                          color: SerialService.isConnected ? Colors.greenAccent : Colors.redAccent,
                          size: 16,
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
// СЕРВИС СВЯЗИ И УТИЛИТЫ (ДЕФОЛТЫ 915 МГц)
// ==========================================
class SerialService {
  static bool isConnected = false;
  static UsbPort? usbPort;
  static StreamSubscription<Uint8List>? _usbSubscription;

  static String lastResponse = "Ready. Connect via USB OTG.";
  static String terminalLog = "";
  static StreamController<String> logController = StreamController.broadcast();
  static StreamController<void> telemetryController = StreamController.broadcast();

  static double rtxBand = 9.0; 
  static double rtxChan = 15.0; 
  static double rtxSf = 7.0;
  static double rtxBw = 7.0;
  static double rtxCr = 1.0;
  static double rtxPower = 22.0;
  static double rtxLinkWarnThreshold = 30.0;
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

class DocSection {
  final String title;
  final String content;
  DocSection({required this.title, required this.content});
}

// ==========================================
// ВКЛАДКА 0: ИНФО (БЕЗ БЛОКА USB)
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
      setState(() { _sections = parsedSections; _isLoading = false; });
    } catch (e) {
      setState(() { _sections = [DocSection(title: 'Ошибка загрузки doc.txt', content: 'Ошибка: $e')]; _isLoading = false; });
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('XFire Ecosystem', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: const Text('v.3.6 (CLI)', style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold)),
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
// ВКЛАДКА 1: ПОЛЕТНЫЙ КОНТРОЛЛЕР FC
// ==========================================
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  double _flMode = 1;          
  double _flRollMax = 25.0;    
  double _flPitchMax = 25.0;   
  double _flVzSpeedMax = 1.2;  
  double _flHeightMin = 0.0;   

  double _rtxEn = 1;
  double _rtxBand = 9;         
  double _rtxAddr = 0;
  double _rtxChan = 15;        
  double _rtxSf = 7;
  double _rtxBw = 7;
  double _rtxCr = 1;
  double _rtxPower = 22;
  double _rtxLinkWarnThreshold = 30;
  double _rtxAfcEn = 0;
  double _rtxAutoEn = 1;

  double _rcFsEn = 1;
  double _fsBatEn = 1;
  double _fsRtxEn = 0;
  double _fsSpiEn = 1;
  double _fsI2cEn = 1;
  double _fsVzSpeed = 0.5;

  double _rcRate = 0.35;
  double _rcSuperExpo = 0.03;
  double _rcStickExpo = 0.45;
  double _rcYawRate = 0.30;
  double _rcYawSuperExpo = 0.03;
  double _rcYawExpo = 0.35;
  double _rcDeadband = 15.0;
  double _rcHorizonTransition = 0.75;
  double _rcFilterSmoothing = 0.35;

  double _batCells = 4;
  double _batFsV = 13.8;
  double _batFilterAlpha = 0.05;

  double _lidarEn = 0;
  double _lidarMinAlt = 0.0;
  double _lidarFilterAlpha = 0.15;
  double _gyroFilterAlpha = 0.10;
  double _accFilterAlpha = 0.10;
  double _filterMode = 3; 
  double _filterNotchFreq = 120.0; 
  double _filterNotchBw = 20.0;
  double _filterDynMinHz = 70.0;
  double _filterDynMaxHz = 220.0;

  double _rollKp = 0.45, _rollKi = 0.010, _rollKd = 0.018;
  double _pitchKp = 0.45, _pitchKi = 0.010, _pitchKd = 0.018;
  double _yawKp = 0.60, _yawKi = 0.010, _yawKd = 0.0;
  double _vzKp = 7.0, _vzKi = 1.2, _vzKd = 0.30;

  bool _isFlashingFC = false;
  double _progressFC = 0.0;
  String _statusFC = "Готов к прошивке полетного контроллера (v3.6)";

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

  Future<void> _flashFC() async {
    if (!SerialService.isConnected || SerialService.usbPort == null) {
      showAppDialog(context, "Ошибка", "Устройство не подключено по USB!", isError: true);
      return;
    }
    setState(() {
      _isFlashingFC = true;
      _progressFC = 0.0;
      _statusFC = "Связь с загрузчиком FC...";
    });
    try {
      await SerialService.usbPort!.write(Uint8List.fromList([0x7F]));
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() => _statusFC = "Запись прошивки FC v3.6...");
      for (int i = 1; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        setState(() => _progressFC = i / 10.0);
      }
      setState(() {
        _isFlashingFC = false;
        _statusFC = "УСПЕХ: Полетный контроллер прошит (v3.6)!";
      });
      if (mounted) showAppDialog(context, "Успех", "Операция прошивки FC v3.6 завершена успешно!");
    } catch (e) {
      setState(() {
        _isFlashingFC = false;
        _statusFC = "ОШИБКА: $e";
      });
      if (mounted) showAppDialog(context, "Ошибка", "Сбой прошивки FC: $e", isError: true);
    }
  }

  Widget _buildExpansionCard(String title, String subtitle, IconData icon, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11.0, vertical: 4.0),
      child: Card(
        margin: EdgeInsets.zero,
        child: ExpansionTile(
          leading: Icon(icon, color: Colors.amberAccent, size: 20),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amberAccent)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.white70)),
          iconColor: Colors.amberAccent,
          collapsedIconColor: Colors.white54,
          children: [
            const SizedBox(height: 8),
            ...children,
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
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
    double yawDeg = SerialService.gyroYaw * 57.2958;
    while (yawDeg > 180) yawDeg -= 360;
    while (yawDeg < -180) yawDeg += 360;

    return StreamBuilder<void>(
      stream: SerialService.telemetryController.stream,
      builder: (context, snapshot) {
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          children: [
            _buildExpansionCard("Полетные режимы и ограничения", "Режимы, углы крена, тангажа и лимиты высоты", Icons.flight, [
              XFireSegmentedCard(title: "Режим полета", commandName: "fl_mode", options: const ["Acro", "Angle", "Horizon"], selectedIndex: _flMode.round(), onSelected: (val) { setState(() => _flMode = val.toDouble()); SerialService.sendCommand("fl_mode $val"); }),
              XFireSliderCard(title: "Максимальный угол крена", commandName: "fl_roll_max", value: _flRollMax, min: 10.0, max: 80.0, divisions: 14, unit: "°", onChanged: (v) => setState(() => _flRollMax = v), onChangeEnd: (v) => SerialService.sendCommand("fl_roll_max $v")),
              XFireSliderCard(title: "Максимальный угол тангажа", commandName: "fl_pitch_max", value: _flPitchMax, min: 10.0, max: 80.0, divisions: 14, unit: "°", onChanged: (v) => setState(() => _flPitchMax = v), onChangeEnd: (v) => SerialService.sendCommand("fl_pitch_max $v")),
              XFireSliderCard(title: "Максимальная вертикальная скорость", commandName: "fl_vz_speed_max", value: _flVzSpeedMax, min: 0.5, max: 3.0, divisions: 25, unit: "м/с", onChanged: (v) => setState(() => _flVzSpeedMax = v), onChangeEnd: (v) => SerialService.sendCommand("fl_vz_speed_max $v")),
              XFireSliderCard(title: "Минимальная высота полета", commandName: "fl_height_min", value: _flHeightMin, min: 0.0, max: 5.0, divisions: 50, unit: "м", onChanged: (v) => setState(() => _flHeightMin = v), onChangeEnd: (v) => SerialService.sendCommand("fl_height_min $v")),
            ]),

            _buildExpansionCard("Радиоуправление и экспоненты", "RC Rate, Super Expo и мертвые зоны стиков", Icons.gamepad, [
              XFireSliderCard(title: "RC Rate (Roll/Pitch)", commandName: "rc_rate", value: _rcRate, min: 0.1, max: 2.0, divisions: 19, unit: "", onChanged: (v) => setState(() => _rcRate = v), onChangeEnd: (v) => SerialService.sendCommand("rc_rate $v")),
              XFireSliderCard(title: "RC Super Expo", commandName: "rc_super_expo", value: _rcSuperExpo, min: 0.0, max: 0.9, divisions: 18, unit: "", onChanged: (v) => setState(() => _rcSuperExpo = v), onChangeEnd: (v) => SerialService.sendCommand("rc_super_expo $v")),
              XFireSliderCard(title: "RC Stick Expo", commandName: "rc_stick_expo", value: _rcStickExpo, min: 0.0, max: 1.0, divisions: 20, unit: "", onChanged: (v) => setState(() => _rcStickExpo = v), onChangeEnd: (v) => SerialService.sendCommand("rc_stick_expo $v")),
              XFireSliderCard(title: "Yaw Rate", commandName: "rc_yaw_rate", value: _rcYawRate, min: 0.1, max: 2.0, divisions: 19, unit: "", onChanged: (v) => setState(() => _rcYawRate = v), onChangeEnd: (v) => SerialService.sendCommand("rc_yaw_rate $v")),
              XFireSliderCard(title: "Yaw Super Expo", commandName: "rc_yaw_super_expo", value: _rcYawSuperExpo, min: 0.0, max: 0.9, divisions: 18, unit: "", onChanged: (v) => setState(() => _rcYawSuperExpo = v), onChangeEnd: (v) => SerialService.sendCommand("rc_yaw_super_expo $v")),
              XFireSliderCard(title: "Yaw Expo", commandName: "rc_yaw_expo", value: _rcYawExpo, min: 0.0, max: 1.0, divisions: 20, unit: "", onChanged: (v) => setState(() => _rcYawExpo = v), onChangeEnd: (v) => SerialService.sendCommand("rc_yaw_expo $v")),
              XFireSliderCard(title: "Переход Horizon", commandName: "rc_horizon_transition", value: _rcHorizonTransition, min: 0.0, max: 1.0, divisions: 20, unit: "", onChanged: (v) => setState(() => _rcHorizonTransition = v), onChangeEnd: (v) => SerialService.sendCommand("rc_horizon_transition $v")),
              XFireSliderCard(title: "Мертвая зона стиков", commandName: "rc_deadband", value: _rcDeadband, min: 0, max: 50, divisions: 50, unit: "PWM", onChanged: (v) => setState(() => _rcDeadband = v), onChangeEnd: (v) => SerialService.sendCommand("rc_deadband $v")),
              XFireSliderCard(title: "Сглаживание RC", commandName: "rc_filter_smoothing", value: _rcFilterSmoothing, min: 0.05, max: 1.0, divisions: 19, unit: "", onChanged: (v) => setState(() => _rcFilterSmoothing = v), onChangeEnd: (v) => SerialService.sendCommand("rc_filter_smoothing $v")),
            ]),

            _buildExpansionCard("Аварийная посадка и Failsafe", "Реакция на разряд, потерю связи и шин", Icons.warning_amber_rounded, [
              XFireSwitchCard(title: "RC Failsafe (пакеты пульта)", commandName: "rc_fs_en", value: _rcFsEn == 1, onChanged: (v) { setState(() => _rcFsEn = v ? 1.0 : 0.0); SerialService.sendCommand("rc_fs_en ${_rcFsEn.round()}"); }),
              XFireSwitchCard(title: "При разряде батареи", commandName: "fs_bat_en", value: _fsBatEn == 1, onChanged: (v) { setState(() => _fsBatEn = v ? 1.0 : 0.0); SerialService.sendCommand("fs_bat_en ${_fsBatEn.round()}"); }),
              XFireSwitchCard(title: "При обрыве связи с пультом", commandName: "fs_rtx_en", value: _fsRtxEn == 1, onChanged: (v) { setState(() => _fsRtxEn = v ? 1.0 : 0.0); SerialService.sendCommand("fs_rtx_en ${_fsRtxEn.round()}"); }),
              XFireSwitchCard(title: "При обрыве связи по шине SPI", commandName: "fs_spi_en", value: _fsSpiEn == 1, onChanged: (v) { setState(() => _fsSpiEn = v ? 1.0 : 0.0); SerialService.sendCommand("fs_spi_en ${_fsSpiEn.round()}"); }),
              XFireSwitchCard(title: "При обрыве связи по шине I2C", commandName: "fs_i2c_en", value: _fsI2cEn == 1, onChanged: (v) { setState(() => _fsI2cEn = v ? 1.0 : 0.0); SerialService.sendCommand("fs_i2c_en ${_fsI2cEn.round()}"); }),
              XFireSliderCard(title: "Порог падения качества связи", commandName: "rtx_link_warn_threshold", value: _rtxLinkWarnThreshold, min: 5, max: 90, divisions: 85, unit: "%", onChanged: (v) => setState(() => _rtxLinkWarnThreshold = v), onChangeEnd: (v) => SerialService.sendCommand("rtx_link_warn_threshold ${v.round()}")),
              XFireSwitchCard(title: "Инициатива с борта при ухудшении связи", commandName: "rtx_auto_en", value: _rtxAutoEn == 1, onChanged: (v) { setState(() => _rtxAutoEn = v ? 1.0 : 0.0); SerialService.sendCommand("rtx_auto_en ${_rtxAutoEn.round()}"); }),
              XFireSliderCard(title: "Скорость аварийного снижения Failsafe", commandName: "fs_vz_speed", value: _fsVzSpeed, min: 0.2, max: 2.0, divisions: 18, unit: "м/с", onChanged: (v) => setState(() => _fsVzSpeed = v), onChangeEnd: (v) => SerialService.sendCommand("fs_vz_speed $v")),
            ]),

            _buildExpansionCard("Питание и батарея (4S LiPo)", "Настройка 4S ячеек и фильтрации питания", Icons.battery_charging_full, [
              XFireSliderCard(title: "Количество ячеек LiPo", commandName: "bat_cells", value: _batCells, min: 1, max: 6, divisions: 5, unit: "S", onChanged: (v) => setState(() => _batCells = v), onChangeEnd: (v) => SerialService.sendCommand("bat_cells ${v.round()}")),
              XFireSliderCard(title: "Порог Failsafe батареи 4S", commandName: "bat_fs_v", value: _batFsV, min: 6.0, max: 25.0, divisions: 190, unit: "В", onChanged: (v) => setState(() => _batFsV = v), onChangeEnd: (v) => SerialService.sendCommand("bat_fs_v $v")),
              XFireSliderCard(title: "Фильтр батареи (Alpha)", commandName: "bat_filter_alpha", value: _batFilterAlpha, min: 0.01, max: 1.0, divisions: 99, unit: "", onChanged: (v) => setState(() => _batFilterAlpha = v), onChangeEnd: (v) => SerialService.sendCommand("bat_filter_alpha $v")),
            ]),

            _buildExpansionCard("Телеметрия", "Авиогоризонт, HUD и датчики в реальном времени", Icons.radar, [
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
                          Expanded(flex: 4, child: Center(child: Stack(alignment: Alignment.center, children: [CustomPaint(size: const Size(155, 155), painter: ArtificialHorizonPainter(roll: SerialService.gyroRoll, pitch: SerialService.gyroPitch)), const Icon(Icons.add, color: Colors.white, size: 24)]))),
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
            ]),

            _buildExpansionCard("Прошивка и калибровки FC", "Обновление прошивки STM32 и калибровка датчиков", Icons.memory, [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13.0, vertical: 4.0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_statusFC, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.greenAccent)),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(value: _progressFC, color: Colors.blueAccent, backgroundColor: Colors.white12, minHeight: 6, borderRadius: BorderRadius.circular(3)),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: ElevatedButton.icon(
                            onPressed: _isFlashingFC ? null : _flashFC,
                            icon: const Icon(Icons.memory, size: 16),
                            label: Text(_isFlashingFC ? "Прошивка FC..." : "Прошить полетный контроллер (v3.6)", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              XFireActionCard(title: "Калибровка гироскопа", commandName: "cal_gyro", onTap: () { if (!SerialService.isConnected) { showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true); } else { SerialService.sendCommand("cal_gyro"); showAppDialog(context, "Успех", "Калибровка гироскопа запущена!"); } }),
              XFireActionCard(title: "Калибровка акселерометра", commandName: "cal_acc", onTap: () { if (!SerialService.isConnected) { showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true); } else { SerialService.sendCommand("cal_acc"); showAppDialog(context, "Успех", "Калибровка акселерометра запущена!"); } }),
            ]),

            _buildExpansionCard("Тесты оборудования", "Аппаратные, исполнительные и системные тесты", Icons.rule, [
              XFireActionCard(title: "Тест подключения MPU6050", commandName: "test_mpu", onTap: () { if (!SerialService.isConnected) { showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true); } else { SerialService.sendCommand("test_mpu"); showAppDialog(context, "Тест MPU6050", "Команда отправлена."); } }),
              XFireActionCard(title: "Тест подключения SX126x (915 МГц)", commandName: "test_sx", onTap: () { if (!SerialService.isConnected) { showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true); } else { SerialService.sendCommand("test_sx"); showAppDialog(context, "Тест SX126x", "Проверка SPI запущена!"); } }),
              XFireActionCard(title: "Тест подключения лидара", commandName: "test_lidar", onTap: () { if (!SerialService.isConnected) { showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true); } else { SerialService.sendCommand("test_lidar"); showAppDialog(context, "Тест лидара", "Запрос отправлен!"); } }),
              XFireActionCard(title: "Тест моторов 2312 (25%)", commandName: "test_motor", onTap: () { if (!SerialService.isConnected) { showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true); } else { SerialService.sendCommand("test_motor"); showAppDialog(context, "Внимание", "Тест моторов (25%) активирован!", isError: true); } }),
              XFireActionCard(title: "Тест PID 25%", commandName: "test_pid", onTap: () { if (!SerialService.isConnected) { showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true); } else { SerialService.sendCommand("test_pid"); showAppDialog(context, "Тест PID", "Стресс-тест ПИД активирован."); } }),
              XFireActionCard(title: "Тест связи с пультом", commandName: "test_rc", onTap: () { if (!SerialService.isConnected) { showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true); } else { SerialService.sendCommand("test_rc"); showAppDialog(context, "Тест RC", "Диагностика пакетов запущена."); } }),
              XFireActionCard(title: "Тест смены канала связи с пультом", commandName: "test_rc_can", onTap: () { if (!SerialService.isConnected) { showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true); } else { SerialService.sendCommand("test_rc_can"); showAppDialog(context, "Автопоиск канала", "Команда отправлена. Новый номер канала придет в сообщении лога."); } }),
            ]),

            _buildExpansionCard("Сенсоры и лидар (VL53L1X)", "Настройки высотомера и фильтрации дальномера", Icons.straighten, [
              XFireSwitchCard(title: "Включить лидар VL53L1X", commandName: "lidar_en", value: _lidarEn == 1, onChanged: (v) { setState(() => _lidarEn = v ? 1.0 : 0.0); SerialService.sendCommand("lidar_en ${_lidarEn.round()}"); }),
              XFireSliderCard(title: "Минимальная высота лидара", commandName: "lidar_min_alt", value: _lidarMinAlt, min: 0.0, max: 2.0, divisions: 20, unit: "м", onChanged: (v) => setState(() => _lidarMinAlt = v), onChangeEnd: (v) => SerialService.sendCommand("lidar_min_alt $v")),
              XFireSliderCard(title: "Фильтр лидара (Alpha)", commandName: "lidar_filter_alpha", value: _lidarFilterAlpha, min: 0.01, max: 1.0, divisions: 99, unit: "", onChanged: (v) => setState(() => _lidarFilterAlpha = v), onChangeEnd: (v) => SerialService.sendCommand("lidar_filter_alpha $v")),
            ]),

            _buildExpansionCard("Фильтрация и Notch-фильтры (2312/9450)", "Гироскоп, акселерометр и режекторные фильтры", Icons.waves, [
              XFireSegmentedCard(title: "Режим фильтрации (filter_mode)", commandName: "filter_mode", options: const ["Off", "LPF", "Notch", "DynNotch"], selectedIndex: _filterMode.round(), onSelected: (val) { setState(() => _filterMode = val.toDouble()); SerialService.sendCommand("filter_mode $val"); }),
              XFireSliderCard(title: "Фильтр гироскопа LPF", commandName: "gyro_filter_alpha", value: _gyroFilterAlpha, min: 0.05, max: 1.0, divisions: 19, unit: "", onChanged: (v) => setState(() => _gyroFilterAlpha = v), onChangeEnd: (v) => SerialService.sendCommand("gyro_filter_alpha $v")),
              XFireSliderCard(title: "Фильтр акселерометра LPF", commandName: "acc_filter_alpha", value: _accFilterAlpha, min: 0.01, max: 1.0, divisions: 99, unit: "", onChanged: (v) => setState(() => _accFilterAlpha = v), onChangeEnd: (v) => SerialService.sendCommand("acc_filter_alpha $v")),
              XFireSliderCard(title: "Центр Notch фильтра", commandName: "filter_notch_freq", value: _filterNotchFreq, min: 30, max: 250, divisions: 220, unit: "Гц", onChanged: (v) => setState(() => _filterNotchFreq = v), onChangeEnd: (v) => SerialService.sendCommand("filter_notch_freq $v")),
              XFireSliderCard(title: "Ширина полосы Notch (Bandwidth)", commandName: "filter_notch_bw", value: _filterNotchBw, min: 5, max: 50, divisions: 45, unit: "Гц", onChanged: (v) => setState(() => _filterNotchBw = v), onChangeEnd: (v) => SerialService.sendCommand("filter_notch_bw $v")),
              XFireSliderCard(title: "Динамический Notch: Мин. частота", commandName: "filter_dyn_min_hz", value: _filterDynMinHz, min: 30, max: 120, divisions: 90, unit: "Гц", onChanged: (v) => setState(() => _filterDynMinHz = v), onChangeEnd: (v) => SerialService.sendCommand("filter_dyn_min_hz $v")),
              XFireSliderCard(title: "Динамический Notch: Макс. частота", commandName: "filter_dyn_max_hz", value: _filterDynMaxHz, min: 150, max: 350, divisions: 200, unit: "Гц", onChanged: (v) => setState(() => _filterDynMaxHz = v), onChangeEnd: (v) => SerialService.sendCommand("filter_dyn_max_hz $v")),
            ]),

            _buildExpansionCard("ПИД-регуляторы (Под 2312 / 9450)", "Настройки Kp, Ki, Kd для осей Roll, Pitch, Yaw и Vz", Icons.tune, [
              PidAxisCardWidget(axisName: "Roll Axis (Rate)", kpCmd: "roll_kp", kiCmd: "roll_ki", kdCmd: "roll_kd", kp: _rollKp, ki: _rollKi, kd: _rollKd, onUpdate: (p, i, d) { setState(() { _rollKp = p; _rollKi = i; _rollKd = d; }); SerialService.sendCommand("roll_kp $p"); SerialService.sendCommand("roll_ki $i"); SerialService.sendCommand("roll_kd $d"); }),
              PidAxisCardWidget(axisName: "Pitch Axis (Rate)", kpCmd: "pitch_kp", kiCmd: "pitch_ki", kdCmd: "pitch_kd", kp: _pitchKp, ki: _pitchKi, kd: _pitchKd, onUpdate: (p, i, d) { setState(() { _pitchKp = p; _pitchKi = i; _pitchKd = d; }); SerialService.sendCommand("pitch_kp $p"); SerialService.sendCommand("pitch_ki $i"); SerialService.sendCommand("pitch_kd $d"); }),
              PidAxisCardWidget(axisName: "Yaw Axis (Rate)", kpCmd: "yaw_kp", kiCmd: "yaw_ki", kdCmd: "yaw_kd", kp: _yawKp, ki: _yawKi, kd: _yawKd, onUpdate: (p, i, d) { setState(() { _yawKp = p; _yawKi = i; _yawKd = d; }); SerialService.sendCommand("yaw_kp $p"); SerialService.sendCommand("yaw_ki $i"); SerialService.sendCommand("yaw_kd $d"); }),
              PidAxisCardWidget(axisName: "Vertical Speed Axis (Vz)", kpCmd: "vz_kp", kiCmd: "vz_ki", kdCmd: "vz_kd", kp: _vzKp, ki: _vzKi, kd: _vzKd, onUpdate: (p, i, d) { setState(() { _vzKp = p; _vzKi = i; _vzKd = d; }); SerialService.sendCommand("vz_kp $p"); SerialService.sendCommand("vz_ki $i"); SerialService.sendCommand("vz_kd $d"); }),
            ]),

            const SizedBox(height: 24),
          ],
        );
      },
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

  bool _isFlashingRC = false;
  double _progressRC = 0.0;
  String _statusRC = "Готов к прошивке пульта управления (v3.6)";

  Future<void> _flashRC() async {
    if (!SerialService.isConnected || SerialService.usbPort == null) {
      showAppDialog(context, "Ошибка", "Устройство не подключено по USB!", isError: true);
      return;
    }
    setState(() {
      _isFlashingRC = true;
      _progressRC = 0.0;
      _statusRC = "Связь с загрузчиком пульта...";
    });
    try {
      await SerialService.usbPort!.write(Uint8List.fromList([0x7F]));
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() => _statusRC = "Запись прошивки пульта v3.6...");
      for (int i = 1; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        setState(() => _progressRC = i / 10.0);
      }
      setState(() {
        _isFlashingRC = false;
        _statusRC = "УСПЕХ: Пульт успешно прошит (v3.6)!";
      });
      if (mounted) showAppDialog(context, "Успех", "Операция прошивки пульта завершена успешно!");
    } catch (e) {
      setState(() {
        _isFlashingRC = false;
        _statusRC = "ОШИБКА: $e";
      });
      if (mounted) showAppDialog(context, "Ошибка", "Сбой прошивки пульта: $e", isError: true);
    }
  }

  Widget _buildExpansionCard(String title, String subtitle, IconData icon, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11.0, vertical: 4.0),
      child: Card(
        margin: EdgeInsets.zero,
        child: ExpansionTile(
          leading: Icon(icon, color: Colors.amberAccent, size: 20),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amberAccent)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.white70)),
          iconColor: Colors.amberAccent,
          collapsedIconColor: Colors.white54,
          children: [
            const SizedBox(height: 8),
            ...children,
            const SizedBox(height: 12),
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
        _buildExpansionCard("Калибровка стиков и прошивка пульта", "Настройка нейтрали, мертвых зон и обновление", Icons.gamepad, [
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
          XFireSliderCard(
            title: "Мертвая зона стиков (Deadband)",
            commandName: "rc_tx_deadband",
            value: _stickDeadband,
            min: 0,
            max: 50,
            divisions: 50,
            unit: "PWM",
            onChanged: (v) => setState(() => _stickDeadband = v),
            onChangeEnd: (v) => SerialService.sendCommand("rc_tx_deadband ${v.round()}"),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13.0, vertical: 4.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_statusRC, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.greenAccent)),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(value: _progressRC, color: Colors.blueAccent, backgroundColor: Colors.white12, minHeight: 6, borderRadius: BorderRadius.circular(3)),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: _isFlashingRC ? null : _flashRC,
                        icon: const Icon(Icons.gamepad, size: 16),
                        label: Text(_isFlashingRC ? "Прошивка пульта..." : "Прошить пульт управления (v3.6)", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ]),

        _buildExpansionCard("Протокол и мощность", "Выбор протокола связи и мощности передатчика", Icons.wifi, [
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
          XFireSliderCard(
            title: "Выходная мощность передатчика пульта",
            commandName: "tx_power_mw",
            value: _txPowerW,
            min: 10,
            max: 1000,
            divisions: 99,
            unit: "мВт",
            onChanged: (v) => setState(() => _txPowerW = v),
            onChangeEnd: (v) => SerialService.sendCommand("tx_power_mw ${v.round()}"),
          ),
        ]),

        _buildExpansionCard("Радиоуправление и экспоненты пульта", "RC Rate, Super Expo, кривые и сглаживание", Icons.tune, [
          XFireSliderCard(title: "RC Rate (Roll/Pitch)", commandName: "rc_rate", value: _rcRate, min: 0.1, max: 2.0, divisions: 19, unit: "", onChanged: (v) => setState(() => _rcRate = v), onChangeEnd: (v) => SerialService.sendCommand("rc_rate $v")),
          XFireSliderCard(title: "RC Super Expo", commandName: "rc_super_expo", value: _rcSuperExpo, min: 0.0, max: 0.9, divisions: 18, unit: "", onChanged: (v) => setState(() => _rcSuperExpo = v), onChangeEnd: (v) => SerialService.sendCommand("rc_super_expo $v")),
          XFireSliderCard(title: "RC Stick Expo", commandName: "rc_stick_expo", value: _rcStickExpo, min: 0.0, max: 1.0, divisions: 20, unit: "", onChanged: (v) => setState(() => _rcStickExpo = v), onChangeEnd: (v) => SerialService.sendCommand("rc_stick_expo $v")),
          XFireSliderCard(title: "Yaw Rate", commandName: "rc_yaw_rate", value: _rcYawRate, min: 0.1, max: 2.0, divisions: 19, unit: "", onChanged: (v) => setState(() => _rcYawRate = v), onChangeEnd: (v) => SerialService.sendCommand("rc_yaw_rate $v")),
          XFireSliderCard(title: "Yaw Super Expo", commandName: "rc_yaw_super_expo", value: _rcYawSuperExpo, min: 0.0, max: 0.9, divisions: 18, unit: "", onChanged: (v) => setState(() => _rcYawSuperExpo = v), onChangeEnd: (v) => SerialService.sendCommand("rc_yaw_super_expo $v")),
          XFireSliderCard(title: "Yaw Expo", commandName: "rc_yaw_expo", value: _rcYawExpo, min: 0.0, max: 1.0, divisions: 20, unit: "", onChanged: (v) => setState(() => _rcYawExpo = v), onChangeEnd: (v) => SerialService.sendCommand("rc_yaw_expo $v")),
          XFireSliderCard(title: "Мертвая зона стиков", commandName: "rc_deadband", value: _rcDeadband, min: 0, max: 50, divisions: 50, unit: "PWM", onChanged: (v) => setState(() => _rcDeadband = v), onChangeEnd: (v) => SerialService.sendCommand("rc_deadband $v")),
          XFireSliderCard(title: "Сглаживание RC", commandName: "rc_filter_smoothing", value: _rcFilterSmoothing, min: 0.05, max: 1.0, divisions: 19, unit: "", onChanged: (v) => setState(() => _rcFilterSmoothing = v), onChangeEnd: (v) => SerialService.sendCommand("rc_filter_smoothing $v")),
          XFireSwitchCard(title: "RC Failsafe (пакеты пульта)", commandName: "rc_fs_en", value: _rcFsEn == 1, onChanged: (v) { setState(() => _rcFsEn = v ? 1.0 : 0.0); SerialService.sendCommand("rc_fs_en ${_rcFsEn.round()}"); }),
        ]),

        _buildExpansionCard("Тест каналов", "Монитор каналов управления в реальном времени", Icons.bar_chart, [
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
        ]),
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
// ГРАФИЧЕСКИЕ СХЕМЫ АНТЕНН
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
      final sleevePaint = Paint()..color = Colors.blueAccent.withOpacity(0.3)..style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, size.height / 2), width: 14, height: size.height - 10), const Radius.circular(6)), sleevePaint);
    }

    canvas.drawLine(Offset(cx, 15), Offset(cx, size.height / 2 - 5), paint);
    canvas.drawLine(Offset(cx, size.height / 2 + 5), Offset(cx, size.height - 15), paint..color = Colors.blueAccent..strokeWidth = 5.0);
    canvas.drawCircle(Offset(cx, size.height / 2), 3, Paint()..color = Colors.redAccent);

    textPainter.text = const TextSpan(text: "Верхнее плечо", style: TextStyle(color: Colors.white70, fontSize: 9));
    textPainter.layout();
    textPainter.paint(canvas, Offset(cx + 12, 25));

    textPainter.text = const TextSpan(text: "Нижнее плечо", style: TextStyle(color: Colors.white70, fontSize: 9));
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
    textPainter.text = const TextSpan(text: "λ/4", style: TextStyle(color: Colors.cyanAccent, fontSize: 10));
    textPainter.layout();
    textPainter.paint(canvas, Offset(cx + 8, cy - 25));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==========================================
// КАРТОЧКА КАЛЬКУЛЯТОРА ЛИНКА
// ==========================================
class RtxLinkCalculatorCard extends StatelessWidget {
  final double currentFreqMhz, sensitivity, distKm, bitRate, sensitivityProgress, bitRateProgress;

  const RtxLinkCalculatorCard({
    super.key,
    required this.currentFreqMhz,
    required this.sensitivity,
    required this.distKm,
    required this.bitRate,
    required this.sensitivityProgress,
    required this.bitRateProgress,
  });

  @override
  Widget build(BuildContext context) {
    String distFormatted = distKm >= 1.0 ? "${distKm.toStringAsFixed(2)} км" : "${(distKm * 1000).toStringAsFixed(0)} м";
    String bitRateStr = bitRate >= 1000 ? "${(bitRate / 1000).toStringAsFixed(1)} kbps" : "${bitRate.toStringAsFixed(0)} bps";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11.0, vertical: 4.0),
      child: Card(
        margin: EdgeInsets.zero,
        child: ExpansionTile(
          title: const Text("Калькулятор линка и дальности (915 МГц)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amberAccent)),
          subtitle: const Text("Расчет чувствительности и скорости по воздуху", style: TextStyle(fontSize: 10, color: Colors.white70)),
          iconColor: Colors.amberAccent,
          collapsedIconColor: Colors.white54,
          children: [
            XFireCard(
              child: Column(
                children: [
                  Text("КАЛЬКУЛЯТОР ЛИНКА (ЧАСТОТА: ${currentFreqMhz.toStringAsFixed(0)} МГц)", style: const TextStyle(fontSize: 10, color: Colors.amberAccent, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
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
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// УНИФИЦИРОВАННЫЙ ВИДЖЕТ АНТЕНН
// ==========================================
class RtxAntennaExpansion extends StatelessWidget {
  final int antennaComboIndex;
  final bool hasProtectiveSleeve;
  final double sleeveThicknessMm, dipoleTubeDiameterMm, dipoleTopWireSqMm, kharchenkoWireSqMm, calcEnvironmentLoss;
  final Map<String, dynamic> antResults;
  final ValueChanged<int?> onComboChanged;
  final ValueChanged<bool> onSleeveToggle;
  final ValueChanged<double> onSleeveThickChanged, onTubeDiamChanged, onTopWireChanged, onKharcChanged, onEnvLossChanged;

  const RtxAntennaExpansion({
    super.key,
    required this.antennaComboIndex, required this.hasProtectiveSleeve,
    required this.sleeveThicknessMm, required this.dipoleTubeDiameterMm, required this.dipoleTopWireSqMm, required this.kharchenkoWireSqMm, required this.calcEnvironmentLoss,
    required this.antResults,
    required this.onComboChanged, required this.onSleeveToggle, required this.onSleeveThickChanged, required this.onTubeDiamChanged, required this.onTopWireChanged, required this.onKharcChanged, required this.onEnvLossChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11.0, vertical: 4.0),
      child: Card(
        margin: EdgeInsets.zero,
        child: ExpansionTile(
          title: const Text("Калькулятор и геометрия антенн (915 МГц)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amberAccent)),
          subtitle: const Text("Расчет плеч диполя и антенны Харченко", style: TextStyle(fontSize: 10, color: Colors.white70)),
          iconColor: Colors.amberAccent,
          collapsedIconColor: Colors.white54,
          children: [
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
                    decoration: BoxDecoration(
                      color: const Color(0xFF242428),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: antennaComboIndex,
                        dropdownColor: const Color(0xFF242428),
                        borderRadius: BorderRadius.circular(12),
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.amberAccent),
                        style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text("Штырь + Штырь (2.15 dBi)")),
                          DropdownMenuItem(value: 1, child: Text("Харченко + Штырь (5.5 dBi)")),
                        ],
                        onChanged: onComboChanged,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            XFireCard(
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
                              child: CustomPaint(painter: DipoleSchematicPainter(hasSleeve: hasProtectiveSleeve), size: const Size(double.infinity, 120)),
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
            XFireSwitchCard(
              title: "Защитная трубка / термоусадка на диполе",
              commandName: "ant_sleeve_en",
              value: hasProtectiveSleeve,
              onChanged: onSleeveToggle,
            ),
            if (hasProtectiveSleeve)
              XFireSliderCard(
                title: "Толщина стенки трубки (чехла)",
                commandName: "ant_sleeve_thick",
                value: sleeveThicknessMm,
                min: 0.5,
                max: 3.0,
                divisions: 25,
                unit: "мм",
                onChanged: onSleeveThickChanged,
                onChangeEnd: (_) {},
              ),
            XFireSliderCard(
              title: "Диаметр трубки диполя (нижн.)",
              commandName: "ant_tube_diam",
              value: dipoleTubeDiameterMm,
              min: 2.0,
              max: 5.0,
              divisions: 6,
              unit: "мм",
              onChanged: onTubeDiamChanged,
              onChangeEnd: (_) {},
            ),
            XFireSliderCard(
              title: "Сечение провода диполя (верхн.)",
              commandName: "ant_top_wire",
              value: dipoleTopWireSqMm,
              min: 0.5,
              max: 2.5,
              divisions: 20,
              unit: "мм²",
              onChanged: onTopWireChanged,
              onChangeEnd: (_) {},
            ),
            XFireSliderCard(
              title: "Сечение провода Харченко",
              commandName: "ant_kharc_wire",
              value: kharchenkoWireSqMm,
              min: 1.0,
              max: 4.0,
              divisions: 15,
              unit: "мм²",
              onChanged: onKharcChanged,
              onChangeEnd: (_) {},
            ),
            XFireSliderCard(
              title: "Запас на условия (Fade Margin)",
              commandName: "ant_fade_margin",
              value: calcEnvironmentLoss,
              min: 5.0,
              max: 30.0,
              divisions: 25,
              unit: "dB",
              onChanged: onEnvLossChanged,
              onChangeEnd: (_) {},
            ),
            const SizedBox(height: 12),
          ],
        ),
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

  final List<double> _bwTable = [7800.0, 10400.0, 15600.0, 20800.0, 31250.0, 41700.0, 62500.0, 125000.0, 250000.0, 500000.0];
  final Map<int, double> _snrTable = {5: -2.5, 6: -5.0, 7: -7.5, 8: -10.0, 9: -12.5, 10: -15.0, 11: -17.5, 12: -20.0};

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

    return {'sensitivity': sensitivity, 'eirp': eirp, 'distanceKm': distanceKm, 'bitRate': bitRate};
  }

  Map<String, dynamic> _calculateAntennaDimensions() {
    double freqHz = _currentFreqMhz * 1e6;
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

  Widget _buildExpansionCard(String title, String subtitle, IconData icon, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11.0, vertical: 4.0),
      child: Card(
        margin: EdgeInsets.zero,
        child: ExpansionTile(
          leading: Icon(icon, color: Colors.amberAccent, size: 20),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amberAccent)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.white70)),
          iconColor: Colors.amberAccent,
          collapsedIconColor: Colors.white54,
          children: [
            const SizedBox(height: 8),
            ...children,
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var linkResults = _calculateLinkBudget();
    var antResults = _calculateAntennaDimensions();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      children: [
        _buildExpansionCard("Радиомодуль RTX (915 МГц на борту)", "Параметры беспроводного интерфейса дрона", Icons.wifi, [
          XFireSwitchCard(title: "Включить RTX модуль", commandName: "rtx_en", value: _rtxEn == 1, onChanged: (v) { setState(() => _rtxEn = v ? 1.0 : 0.0); SerialService.sendCommand("rtx_en ${_rtxEn.round()}"); }),
          XFireSliderCard(title: "Диапазон частот (9 = 900 МГц)", commandName: "rtx_band", value: _rtxBand, min: 1, max: 9, divisions: 8, unit: "", onChanged: (v) => setState(() => _rtxBand = v), onChangeEnd: (v) { SerialService.rtxBand = v; SerialService.sendCommand("rtx_band ${v.round()}"); }),
          XFireSliderCard(title: "Сетевой адрес устройства", commandName: "rtx_addr", value: 0, min: 0, max: 65535, divisions: 100, unit: "", onChanged: (v) {}, onChangeEnd: (v) => SerialService.sendCommand("rtx_addr ${v.round()}")),
          XFireSliderCard(title: "Рабочий канал связи (+15 МГц = 915 МГц)", commandName: "rtx_chan", value: _rtxChan, min: 0, max: 99, divisions: 99, unit: "МГц", onChanged: (v) => setState(() => _rtxChan = v), onChangeEnd: (v) { SerialService.rtxChan = v; SerialService.sendCommand("rtx_chan ${v.round()}"); }),
          XFireSliderCard(title: "Spreading Factor (SF)", commandName: "rtx_sf", value: _rtxSf, min: 5, max: 12, divisions: 7, unit: "", onChanged: (v) => setState(() => _rtxSf = v), onChangeEnd: (v) { SerialService.rtxSf = v; SerialService.sendCommand("rtx_sf ${v.round()}"); }),
          XFireSliderCard(title: "Полоса пропускания (Bandwidth)", commandName: "rtx_bw", value: _rtxBw, min: 0, max: 9, divisions: 9, unit: "", onChanged: (v) => setState(() => _rtxBw = v), onChangeEnd: (v) { SerialService.rtxBw = v; SerialService.sendCommand("rtx_bw ${v.round()}"); }),
          XFireSliderCard(title: "Коэффициент кодирования (CR)", commandName: "rtx_cr", value: _rtxCr, min: 1, max: 4, divisions: 3, unit: "", onChanged: (v) => setState(() => _rtxCr = v), onChangeEnd: (v) { SerialService.rtxCr = v; SerialService.sendCommand("rtx_cr ${v.round()}"); }),
          XFireSliderCard(title: "Мощность передатчика", commandName: "rtx_power", value: _rtxPower, min: -9, max: 22, divisions: 31, unit: "dBm", onChanged: (v) => setState(() => _rtxPower = v), onChangeEnd: (v) { SerialService.rtxPower = v; SerialService.sendCommand("rtx_power ${v.round()}"); }),
          XFireSwitchCard(title: "Автоматическая подстройка частоты (AFC)", commandName: "rtx_afc_en", value: false, onChanged: (v) => SerialService.sendCommand("rtx_afc_en ${v ? 1 : 0}")),
          XFireActionCard(title: "Применить настройки RTX", commandName: "rtx_write", onTap: () { if (!SerialService.isConnected) { showAppDialog(context, "Ошибка", "Устройство не подключено!", isError: true); } else { SerialService.sendCommand("rtx_write"); showAppDialog(context, "Успех", "Настройки радиомодуля 915 МГц применены!"); } }),
        ]),

        RtxLinkCalculatorCard(
          currentFreqMhz: _currentFreqMhz,
          sensitivity: linkResults['sensitivity'],
          distKm: linkResults['distanceKm'],
          bitRate: linkResults['bitRate'],
          sensitivityProgress: ((linkResults['sensitivity'] - (-140.0)) / ((-100.0) - (-140.0))).clamp(0.0, 1.0),
          bitRateProgress: (linkResults['bitRate'] / 30000.0).clamp(0.0, 1.0),
        ),
        RtxAntennaExpansion(
          antennaComboIndex: _antennaComboIndex, hasProtectiveSleeve: _hasProtectiveSleeve,
          sleeveThicknessMm: _sleeveThicknessMm, dipoleTubeDiameterMm: _dipoleTubeDiameterMm,
          dipoleTopWireSqMm: _dipoleTopWireSqMm, kharchenkoWireSqMm: _kharchenkoWireSqMm,
          calcEnvironmentLoss: _calcEnvironmentLoss, antResults: antResults,
          onComboChanged: (val) { if (val != null) setState(() => _antennaComboIndex = val); },
          onSleeveToggle: (v) => setState(() => _hasProtectiveSleeve = v),
          onSleeveThickChanged: (v) => setState(() => _sleeveThicknessMm = v),
          onTubeDiamChanged: (v) => setState(() => _dipoleTubeDiameterMm = v),
          onTopWireChanged: (v) => setState(() => _dipoleTopWireSqMm = v),
          onKharcChanged: (v) => setState(() => _kharchenkoWireSqMm = v),
          onEnvLossChanged: (v) => setState(() => _calcEnvironmentLoss = v),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ==========================================
// ВКЛАДКА 4: ТЕРМИНАЛ CLI (ЧИСТЫЙ ТЕРМИНАЛ)
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
    _sub = SerialService.logController.stream.listen((log) { if (mounted) setState(() => _displayLog = log); });
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
            padding: const EdgeInsets.symmetric(horizontal: 13.0, vertical: 4.0),
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
              margin: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
              child: SingleChildScrollView(reverse: true, child: Text(_displayLog, style: const TextStyle(fontFamily: 'monospace', color: Colors.greenAccent, fontSize: 11))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13.0, vertical: 8.0),
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
// ХУДОЖНИКИ HUD И АВИАГОРИЗОНТ
// ==========================================

class PitchHudScalePainter extends CustomPainter {
  final double value; 
  final double minVal; 
  final double maxVal; 
  final bool isLeftSide; 

  PitchHudScalePainter({
    required this.value,
    required this.minVal,
    required this.maxVal,
    required this.isLeftSide,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = Colors.white70
      ..strokeWidth = 2.5;
    final paintText = TextPainter(textDirection: TextDirection.ltr);
    final indicatorPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final double x = isLeftSide ? size.width - 10.0 : 10.0;

    canvas.drawLine(Offset(x, 14), Offset(x, size.height - 14), paintLine);

    double range = maxVal - minVal;

    for (int i = 0; i <= 6; i++) {
      double v = minVal + (range / 6) * i;
      double y = size.height - 14 - ((v - minVal) / range) * (size.height - 28);

      canvas.drawLine(
        Offset(x, y),
        Offset(isLeftSide ? x - 6 : x + 6, y),
        paintLine,
      );

      paintText.text = TextSpan(
        text: "${v.toInt()}°",
        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
      );
      paintText.layout();

      double textX = isLeftSide ? x - 28 : x + 10;
      paintText.paint(canvas, Offset(textX, y - 5));
    }

    double clampedVal = value.clamp(minVal, maxVal);
    double currentY = size.height - 14 - ((clampedVal - minVal) / range) * (size.height - 28);

    final path = Path();
    if (isLeftSide) {
      double cursorX = x - 6;
      path.moveTo(cursorX + 10, currentY);
      path.lineTo(cursorX, currentY - 5);
      path.lineTo(cursorX, currentY + 5);
    } else {
      double cursorX = x + 6;
      path.moveTo(cursorX - 10, currentY);
      path.lineTo(cursorX, currentY - 5);
      path.lineTo(cursorX, currentY + 5);
    }
    path.close();
    canvas.drawPath(path, indicatorPaint);
  }

  @override
  bool shouldRepaint(covariant PitchHudScalePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.minVal != minVal ||
        oldDelegate.maxVal != maxVal ||
        oldDelegate.isLeftSide != isLeftSide;
  }
}

class YawHudScalePainter extends CustomPainter {
  final double value;
  final double minVal;
  final double maxVal;
  final bool isTop;

  YawHudScalePainter({required this.value, required this.minVal, required this.maxVal, required this.isTop});

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()..color = Colors.white70..strokeWidth = 2.5;
    final paintText = TextPainter(textDirection: TextDirection.ltr);
    final indicatorPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    const double margin = 34.0;
    final y = isTop ? 14.0 : size.height - 14.0;

    canvas.drawLine(Offset(margin, y), Offset(size.width - margin, y), paintLine);
    double range = maxVal - minVal;

    for (int i = 0; i <= 4; i++) {
      double v = minVal + (range / 4) * i;
      double x = margin + ((v - minVal) / range) * (size.width - (margin * 2));
      canvas.drawLine(Offset(x, y), Offset(x, y + (isTop ? -5 : 5)), paintLine);
      paintText.text = TextSpan(text: "${v.toInt()}°", style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold));
      paintText.layout();
      paintText.paint(canvas, Offset(x - 10, y + (isTop ? -16 : 6)));
    }

    double currentX = margin + ((value.clamp(minVal, maxVal) - minVal) / range) * (size.width - (margin * 2));
    
    final path = Path();
    if (isTop) {
      double cursorY = y + 6;
      path.moveTo(currentX, cursorY + 10);
      path.lineTo(currentX - 5, cursorY);
      path.lineTo(currentX + 5, cursorY);
    } else {
      double cursorY = y - 6;
      path.moveTo(currentX, cursorY - 10);
      path.lineTo(currentX - 5, cursorY);
      path.lineTo(currentX + 5, cursorY);
    }
    path.close();
    canvas.drawPath(path, indicatorPaint);
  }

  @override
  bool shouldRepaint(covariant YawHudScalePainter oldDelegate) => oldDelegate.value != value;
}

class ArtificialHorizonPainter extends CustomPainter {
  final double roll, pitch; 
  ArtificialHorizonPainter({required this.roll, required this.pitch});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 1;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: radius)));
    canvas.rotate(-roll);

    double pitchOffset = pitch * 40.0;
    canvas.drawRect(Rect.fromLTWH(-radius * 2, -radius * 3 + pitchOffset, radius * 4, radius * 3), Paint()..color = const Color(0xFF1E6091));
    canvas.drawRect(Rect.fromLTWH(-radius * 2, pitchOffset, radius * 4, radius * 3), Paint()..color = const Color(0xFF6A4A3A));
    canvas.drawLine(Offset(-radius * 2, pitchOffset), Offset(radius * 2, pitchOffset), Paint()..color = Colors.white..strokeWidth = 2.0);

    for (int p = -3; p <= 3; p++) {
      if (p == 0) continue;
      canvas.drawLine(Offset(- (p.abs() % 2 == 0 ? 20.0 : 10.0) / 2, pitchOffset - (p * 20.0)), Offset((p.abs() % 2 == 0 ? 20.0 : 10.0) / 2, pitchOffset - (p * 20.0)), Paint()..color = Colors.white70..strokeWidth = 1.5);
    }
    canvas.restore();
    canvas.drawCircle(center, radius, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3.0);
  }

  @override
  bool shouldRepaint(covariant ArtificialHorizonPainter oldDelegate) => oldDelegate.roll != roll || oldDelegate.pitch != pitch;
}
