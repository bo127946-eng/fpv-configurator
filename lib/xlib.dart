// xlib.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:usb_serial/usb_serial.dart';

// ==========================================
// СЕРВИС СВЯЗИ И УТИЛИТЫ (СТРОГО 1 ПОРТ)
// ==========================================
class SerialService {
  static bool isConnected = false;
  static bool isBusy = false;
  static UsbDevice? activeDevice;
  static UsbPort? usbPort;
  static StreamSubscription<Uint8List>? usbSubscription;

  static Future<void> _queue = Future.value();

  static String lastResponse = "Ready. Connect via USB OTG.";
  static String terminalLog = "";
  static StreamController<String> logController =
      StreamController<String>.broadcast();
  static StreamController<void> telemetryController =
      StreamController<void>.broadcast();

  static double gyroRoll = 0.0, gyroPitch = 0.0, gyroYaw = 0.0;
  static double accelX = 0.0, accelY = 0.0, accelZ = 1.0;

  static Future<T> _enqueue<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      isBusy = true;
      try {
        final result = await action();
        if (!completer.isCompleted) completer.complete(result);
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      } finally {
        isBusy = false;
      }
    });
    return completer.future;
  }

  static void appendLog(String text) {
    if (text.isNotEmpty) {
      terminalLog += text;
    }
    if (!logController.isClosed) {
      logController.add(terminalLog);
    }
  }

  static void _notifyTelemetry() {
    if (!telemetryController.isClosed) {
      telemetryController.add(null);
    }
  }

  static Future<bool> connectDevice(
    UsbDevice device, {
    int baudRate = 115200,
    bool autoDisconnectIfSame = false,
  }) {
    return _enqueue<bool>(() async {
      final bool isSameDevice = isConnected &&
          activeDevice != null &&
          usbPort != null &&
          ((device.deviceId != null && activeDevice!.deviceId == device.deviceId) ||
              activeDevice!.deviceName == device.deviceName);

      if (isSameDevice && autoDisconnectIfSame) {
        await _closeInternal(statusMessage: "USB Disconnected");
        return false;
      }

      await _closeInternal(statusMessage: "Reconnecting USB...");

      UsbPort? port;
      try {
        port = await device.create();
        if (port == null) {
          lastResponse = "Failed to create USB port";
          appendLog(">> ERROR: Cannot create port for ${device.deviceName}\n");
          _notifyTelemetry();
          return false;
        }

        final bool opened = await port.open();
        if (!opened) {
          try {
            await port.close();
          } catch (_) {}
          lastResponse = "Failed to open serial device";
          appendLog(">> ERROR: Failed to open serial device (${device.deviceName})\n");
          _notifyTelemetry();
          return false;
        }

        await port.setDTR(true);
        await port.setRTS(true);
        await port.setPortParameters(
          baudRate,
          UsbPort.DATABITS_8,
          UsbPort.STOPBITS_1,
          UsbPort.PARITY_NONE,
        );

        final Stream<Uint8List>? stream = port.inputStream;
        if (stream == null) {
          try {
            await port.close();
          } catch (_) {}
          lastResponse = "Input stream unavailable";
          appendLog(">> ERROR: USB input stream is null\n");
          _notifyTelemetry();
          return false;
        }

        usbPort = port;
        activeDevice = device;
        isConnected = true;
        lastResponse = "Connected: ${device.deviceName}";
        appendLog(">> CONNECTED: ${device.deviceName} @ $baudRate baud\n");

        usbSubscription = stream.listen(
          (Uint8List data) => handleIncomingData(data),
          onError: (Object error) {
            appendLog(">> USB STREAM ERROR: $error\n");
            unawaited(disconnect());
          },
          onDone: () {
            appendLog(">> USB STREAM CLOSED\n");
            unawaited(disconnect());
          },
          cancelOnError: true,
        );

        _notifyTelemetry();
        return true;
      } catch (e) {
        try {
          await port?.close();
        } catch (_) {}
        usbPort = null;
        activeDevice = null;
        isConnected = false;
        lastResponse = "Serial connection error: $e";
        appendLog(">> ERROR: Serial connect failed: $e\n");
        _notifyTelemetry();
        return false;
      }
    });
  }

  static Future<bool> sendCommand(String cmd) {
    return _enqueue<bool>(() async {
      if (!isConnected || usbPort == null) {
        appendLog(">> ERROR: USB Device not connected (cmd: $cmd)\n");
        return false;
      }
      try {
        final bytes = Uint8List.fromList(utf8.encode('$cmd\n'));
        await usbPort!.write(bytes);
        appendLog(">> $cmd\n");
        return true;
      } catch (e) {
        appendLog(">> WRITE ERROR ($cmd): $e\n");
        await _closeInternal(statusMessage: "USB Write Error");
        return false;
      }
    });
  }

  static Future<bool> sendBatchConfig(List<String> params) {
    return _enqueue<bool>(() async {
      if (!isConnected || usbPort == null) {
        appendLog(">> ERROR: USB Device not connected (batch config)\n");
        return false;
      }
      try {
        final StringBuffer sb = StringBuffer()
          ..writeln('config')
          ..write('"');
        for (final p in params) {
          sb.write('\n$p');
        }
        sb.writeln('"');
        final String payload = sb.toString();
        await usbPort!.write(Uint8List.fromList(utf8.encode(payload)));
        appendLog(">> $payload");
        return true;
      } catch (e) {
        appendLog(">> BATCH WRITE ERROR: $e\n");
        await _closeInternal(statusMessage: "USB Write Error");
        return false;
      }
    });
  }

  static void handleIncomingData(Uint8List data) {
    if (data.isEmpty) return;
    final String incoming = utf8.decode(data, allowMalformed: true);
    terminalLog += incoming;

    final List<String> lines = incoming
        .split(RegExp(r'[\r\n]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (lines.isNotEmpty) {
      lastResponse = lines.last;
    }

    appendLog("");
    _notifyTelemetry();
  }

  static Future<void> _closeInternal({String statusMessage = "USB Disconnected"}) async {
    final sub = usbSubscription;
    final port = usbPort;

    usbSubscription = null;
    usbPort = null;
    activeDevice = null;
    isConnected = false;

    if (sub != null) {
      try {
        await sub.cancel();
      } catch (_) {}
    }

    if (port != null) {
      try {
        await port.setDTR(false);
      } catch (_) {}
      try {
        await port.setRTS(false);
      } catch (_) {}
      try {
        await port.close();
      } catch (_) {}
    }

    lastResponse = statusMessage;
    appendLog(">> $statusMessage\n");
    _notifyTelemetry();
  }

  static Future<void> disconnect() {
    return _enqueue<void>(() async {
      await _closeInternal(statusMessage: "USB Disconnected");
    });
  }

  static Future<void> dispose() async {
    await disconnect();
    if (!logController.isClosed) await logController.close();
    if (!telemetryController.isClosed) await telemetryController.close();
  }
}

// ==========================================
// СЕРВИС ПРОШИВКИ ПО DFU (METHOD CHANNEL)
// ==========================================
class DfuService {
  static const MethodChannel _channel = MethodChannel('xfire/dfu');
  static final StreamController<DfuProgressEvent> _progressController =
      StreamController<DfuProgressEvent>.broadcast();

  static Stream<DfuProgressEvent> get progressStream => _progressController.stream;
  static bool _initialized = false;

  static void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDfuProgress') {
        final rawArgs = call.arguments;
        final Map args = rawArgs is Map ? rawArgs : const {};
        final status = (args['status'] as String?) ?? 'Прошивка DFU...';
        final progress = ((args['progress'] as num?) ?? 0.0).toDouble();
        if (!_progressController.isClosed) {
          _progressController.add(DfuProgressEvent(status: status, progress: progress));
        }
      }
    });
  }

  static Future?> findDfuDevice() async {
    _ensureInitialized();
    final dynamic res = await _channel.invokeMethod('findDfuDevice');
    if (res is Map) {
      return Map<dynamic, dynamic>.from(res);
    }
    return null;
  }

  static Future<bool> requestPermission() async {
    _ensureInitialized();
    final dynamic granted = await _channel.invokeMethod('requestDfuPermission');
    return granted == true;
  }

  static Future<void> flashF401({
    Uint8List? bytes,
    String assetPath = 'assets/fc401.bin',
    int startAddress = 0x08000000,
    void Function(String status, double progress)? onProgress,
  }) async {
    _ensureInitialized();

    final StreamSubscription<DfuProgressEvent>? sub = onProgress == null
        ? null
        : progressStream.listen((ev) => onProgress(ev.status, ev.progress));

    try {
      onProgress?.call("Поиск STM32F401 в режиме DFU...", 0.02);
      final Map<dynamic, dynamic>? dev = await findDfuDevice();
      if (dev == null) {
        throw Exception(
          "DFU-устройство не найдено.\nПереведите F401 в DFU (BOOT0=1 + RESET).",
        );
      }

      onProgress?.call("Запрос USB-разрешения для DFU...", 0.04);
      final bool granted = await requestPermission();
      if (!granted) {
        throw Exception("Доступ к USB DFU не предоставлен.");
      }

      Uint8List firmware = bytes ?? Uint8List(0);
      if (firmware.isEmpty) {
        final ByteData data = await rootBundle.load(assetPath);
        firmware = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      }
      if (firmware.isEmpty) {
        throw Exception("Файл прошивки ($assetPath) пуст.");
      }

      await _channel.invokeMethod('flashF401', {
        'firmware': firmware,
        'startAddress': startAddress,
      });
    } finally {
      if (sub != null) {
        await sub.cancel();
      }
    }
  }
}

class DfuProgressEvent {
  final String status;
  final double progress;
  const DfuProgressEvent({required this.status, required this.progress});
}

void showAppDialog(
  BuildContext context,
  String title,
  String message, {
  bool isError = false,
}) {
  if (!context.mounted) return;
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        title,
        style: TextStyle(
          color: isError ? Colors.redAccent : Colors.amberAccent,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        softWrap: true,
      ),
      content: Text(
        message,
        style: const TextStyle(fontSize: 17, color: Colors.white70, height: 1.4),
        softWrap: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text(
            "ОК",
            style: TextStyle(
              color: Colors.blueAccent,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
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

    final Paint activePaint = Paint()
      ..color = sliderTheme.activeTrackColor ?? Colors.blueAccent
      ..style = PaintingStyle.fill;
    final Paint inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? Colors.white12
      ..style = PaintingStyle.fill;
    final Paint dividerPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    final Radius radius = Radius.circular(trackRect.height / 2);

    final Rect inactiveRect =
        Rect.fromLTRB(thumbCenter.dx, trackRect.top, trackRect.right, trackRect.bottom);
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(inactiveRect, radius),
      inactivePaint,
    );

    const double dividerWidth = 3.0;
    final double activeRight = math.max(trackRect.left, thumbCenter.dx - dividerWidth);
    final Rect activeRect =
        Rect.fromLTRB(trackRect.left, trackRect.top, activeRight, trackRect.bottom);
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(activeRect, radius),
      activePaint,
    );

    final Rect dividerRect =
        Rect.fromLTRB(activeRight, trackRect.top, thumbCenter.dx, trackRect.bottom);
    context.canvas.drawRect(dividerRect, dividerPaint);
  }
}

// ==========================================
// УНИВЕРСАЛЬНЫЕ КОМПОНЕНТЫ СТИЛЯ
// ==========================================
class XFireCard extends StatelessWidget {
  final Widget child;
  const XFireCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13.0, vertical: 6.0),
      child: Container(
        padding: const EdgeInsets.all(15.0),
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

class XFireExpansionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  const XFireExpansionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11.0, vertical: 6.0),
      child: Card(
        margin: EdgeInsets.zero,
        child: ExpansionTile(
          leading: Icon(icon, color: Colors.amberAccent, size: 25),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.amberAccent,
              height: 1.25,
            ),
            softWrap: true,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              subtitle,
              style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.3),
              softWrap: true,
            ),
          ),
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
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Colors.white,
                      height: 1.25,
                    ),
                    softWrap: true,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    commandName,
                    style: TextStyle(
                      color: Colors.amberAccent.withOpacity(0.9),
                      fontSize: 14,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                    softWrap: true,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 17, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

class XFireResetCard extends StatelessWidget {
  final String hint;
  final VoidCallback onReset;

  const XFireResetCard({
    super.key,
    required this.hint,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return XFireCard(
      child: InkWell(
        onTap: onReset,
        borderRadius: BorderRadius.circular(10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Сбросить настройки",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hint,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    softWrap: true,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.refresh_rounded, size: 22, color: Colors.amberAccent),
          ],
        ),
      ),
    );
  }
}

class XFireBatchApplyCard extends StatefulWidget {
  final String hint;
  final List<String> parameters;
  final VoidCallback? onApplied;

  const XFireBatchApplyCard({
    super.key,
    required this.hint,
    required this.parameters,
    this.onApplied,
  });

  @override
  State<XFireBatchApplyCard> createState() => _XFireBatchApplyCardState();
}

class _XFireBatchApplyCardState extends State<XFireBatchApplyCard> {
  bool _isSending = false;

  Future<void> _handleTap() async {
    if (_isSending) return;
    if (!SerialService.isConnected || SerialService.usbPort == null) {
      showAppDialog(
        context,
        "Ошибка соединения",
        "Устройство не подключено\nпо USB!",
        isError: true,
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      final bool ok = await SerialService.sendBatchConfig(widget.parameters);
      if (!mounted) return;
      if (ok) {
        widget.onApplied?.call();
        showAppDialog(
          context,
          "Пакет настроек",
          "Конфигурация успешно\nотправлена!",
        );
      } else {
        showAppDialog(
          context,
          "Ошибка отправки",
          "Не удалось отправить пакет\nнастроек по USB.",
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return XFireCard(
      child: InkWell(
        onTap: _isSending ? null : _handleTap,
        borderRadius: BorderRadius.circular(10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Применить настройки",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.hint,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    softWrap: true,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 17, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

class XFireTextHexCard extends StatefulWidget {
  final String title;
  final String commandName;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitEnd;

  const XFireTextHexCard({
    super.key,
    required this.title,
    required this.commandName,
    required this.initialValue,
    required this.onChanged,
    required this.onSubmitEnd,
  });

  @override
  State<XFireTextHexCard> createState() => _XFireTextHexCardState();
}

class _XFireTextHexCardState extends State<XFireTextHexCard> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant XFireTextHexCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue && _controller.text != widget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return XFireCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white, height: 1.25),
            softWrap: true,
          ),
          const SizedBox(height: 4),
          Text(
            widget.commandName,
            style: TextStyle(
              color: Colors.amberAccent.withOpacity(0.9),
              fontSize: 14,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
            softWrap: true,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-FxX]'))],
            style: const TextStyle(fontFamily: 'monospace', fontSize: 17),
            decoration: const InputDecoration(
              hintText: "например, 0x1424",
              hintStyle: TextStyle(fontSize: 15),
              isDense: true,
            ),
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitEnd,
          ),
        ],
      ),
    );
  }
}

class XFireFlashCard extends StatefulWidget {
  final String title;
  final String targetName;
  final Future<void> Function(void Function(String status, double progress) onProgress) onFlash;

  const XFireFlashCard({
    super.key,
    required this.title,
    required this.targetName,
    required this.onFlash,
  });

  @override
  State<XFireFlashCard> createState() => _XFireFlashCardState();
}

class _XFireFlashCardState extends State<XFireFlashCard> {
  bool _isFlashing = false;
  double _progress = 0.0;
  String _statusState = "Нажмите для запуска прошивки DFU";
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  Future<void> _startFlashing() async {
    if (_isFlashing) return;

    _resetTimer?.cancel();
    setState(() {
      _isFlashing = true;
      _progress = 0.0;
      _statusState = "Подготовка к прошивке DFU...";
    });

    try {
      await widget.onFlash((status, prog) {
        if (mounted) {
          setState(() {
            _statusState = status;
            _progress = prog.isFinite ? prog.clamp(0.0, 1.0).toDouble() : 0.0;
          });
        }
      });
      if (mounted) {
        setState(() {
          _statusState = "Прошивка F401 по DFU завершена\n(v3.27)!";
          _progress = 1.0;
        });
        showAppDialog(context, "Успех", "${widget.targetName}\nуспешно прошит по DFU!");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusState = "Ошибка прошивки DFU:\n$e";
          _progress = 0.0;
        });
        showAppDialog(
          context,
          "Ошибка DFU",
          "Сбой прошивки\n${widget.targetName}:\n$e",
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        _resetTimer?.cancel();
        _resetTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _isFlashing = false;
              _statusState = "Нажмите для запуска прошивки DFU";
              _progress = 0.0;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13.0, vertical: 6.0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isFlashing ? Colors.amberAccent.withOpacity(0.5) : Colors.white12,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isFlashing ? null : _startFlashing,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(15.0),
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
                            Text(
                              widget.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: Colors.white,
                                height: 1.25,
                              ),
                              softWrap: true,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _statusState,
                              style: TextStyle(
                                color: _isFlashing ? Colors.amberAccent : Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                              softWrap: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _isFlashing ? Icons.hourglass_top_rounded : Icons.arrow_forward_ios,
                        size: _isFlashing ? 24 : 17,
                        color: _isFlashing ? Colors.amberAccent : Colors.white54,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _isFlashing ? (_progress > 0 ? _progress : null) : 0.0,
                    color: Colors.amberAccent,
                    backgroundColor: Colors.white12,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class XFireSliderCard extends StatefulWidget {
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
  State<XFireSliderCard> createState() => _XFireSliderCardState();
}

class _XFireSliderCardState extends State<XFireSliderCard> {
  bool _isEditing = false;
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

  bool get _isIntegerRange =>
      widget.min % 1 == 0 &&
      widget.max % 1 == 0 &&
      widget.divisions > 0 &&
      ((widget.max - widget.min) / widget.divisions) % 1 == 0;

  String _formatValue(double v) {
    if (_isIntegerRange) {
      return v.round().toString();
    }
    return v.toStringAsFixed(v.truncate() == v ? 0 : 2);
  }

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: _formatValue(widget.value));
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _isEditing) {
        _commitInput();
      }
    });
  }

  @override
  void didUpdateWidget(covariant XFireSliderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && oldWidget.value != widget.value) {
      _textController.text = _formatValue(widget.value);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _textController.text = _formatValue(widget.value);
      _textController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _textController.text.length,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_focusNode.hasFocus) _focusNode.requestFocus();
    });
  }

  void _commitInput() {
    if (!_isEditing) return;
    final normalized = _textController.text.trim().replaceAll(',', '.');
    final parsed = double.tryParse(normalized);
    setState(() => _isEditing = false);

    if (parsed == null || !parsed.isFinite) {
      _textController.text = _formatValue(widget.value);
      return;
    }

    double clamped = parsed.clamp(widget.min, widget.max).toDouble();
    if (_isIntegerRange) {
      clamped = clamped.roundToDouble();
    } else if (widget.divisions > 0) {
      final step = (widget.max - widget.min) / widget.divisions;
      clamped = (widget.min + ((clamped - widget.min) / step).round() * step)
          .clamp(widget.min, widget.max)
          .toDouble();
    }

    _textController.text = _formatValue(clamped);
    widget.onChanged(clamped);
    widget.onChangeEnd(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final clampedValue = widget.value.clamp(widget.min, widget.max).toDouble();
    final formatted = _formatValue(clampedValue);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13.0, vertical: 6.0),
      child: Container(
        padding: const EdgeInsets.all(15.0),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: Colors.white,
                          height: 1.25,
                        ),
                        softWrap: true,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.commandName,
                        style: TextStyle(
                          color: Colors.amberAccent.withOpacity(0.9),
                          fontSize: 14,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _isEditing
                    ? SizedBox(
                        width: 118,
                        child: TextField(
                          controller: _textController,
                          focusNode: _focusNode,
                          autofocus: true,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            fontFamily: 'monospace',
                          ),
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: !_isIntegerRange,
                            signed: widget.min < 0,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(_isIntegerRange ? r'^-?\d*' : r'^-?\d*[.,]?\d*'),
                            ),
                          ],
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                            filled: true,
                            fillColor: const Color(0xFF242428),
                            suffixText: widget.unit.isEmpty ? null : widget.unit,
                            suffixStyle: const TextStyle(
                              fontSize: 12,
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.bold,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(9),
                              borderSide: const BorderSide(color: Colors.blueAccent),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(9),
                              borderSide: const BorderSide(color: Colors.blueAccent),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(9),
                              borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
                            ),
                          ),
                          onSubmitted: (_) => _commitInput(),
                        ),
                      )
                    : InkWell(
                        onTap: _startEditing,
                        borderRadius: BorderRadius.circular(9),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: Colors.blueAccent.withOpacity(0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "$formatted ${widget.unit}".trim(),
                                style: const TextStyle(
                                  color: Colors.blueAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                softWrap: true,
                              ),
                              const SizedBox(width: 5),
                              const Icon(Icons.edit, size: 13, color: Colors.blueAccent),
                            ],
                          ),
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
                    trackHeight: 7.0,
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 21.0),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11.0),
                  ),
                  child: Slider(
                    value: clampedValue,
                    min: widget.min,
                    max: widget.max,
                    divisions: widget.divisions > 0 ? widget.divisions : 1,
                    onChanged: widget.onChanged,
                    onChangeEnd: widget.onChangeEnd,
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
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Colors.white,
                    height: 1.25,
                  ),
                  softWrap: true,
                ),
                const SizedBox(height: 4),
                Text(
                  commandName,
                  style: TextStyle(
                    color: Colors.amberAccent.withOpacity(0.9),
                    fontSize: 14,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                  softWrap: true,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(value: value, onChanged: onChanged, activeTrackColor: Colors.blueAccent),
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
    final int count = options.isEmpty ? 1 : options.length;
    return XFireCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: Colors.white,
              height: 1.25,
            ),
            softWrap: true,
          ),
          const SizedBox(height: 4),
          Text(
            commandName,
            style: TextStyle(
              color: Colors.amberAccent.withOpacity(0.9),
              fontSize: 14,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
            softWrap: true,
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              return ToggleButtons(
                isSelected: List.generate(options.length, (i) => i == selectedIndex),
                onPressed: onSelected,
                borderRadius: BorderRadius.circular(10),
                selectedColor: Colors.white,
                fillColor: Colors.blueAccent,
                color: Colors.white70,
                constraints: BoxConstraints(
                  minHeight: 44,
                  minWidth: math.max(0.0, (constraints.maxWidth - (count - 1)) / count),
                ),
                children: options
                    .map(
                      (opt) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        child: Text(
                          opt,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, height: 1.2),
                          softWrap: true,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ==========================================
// ПИД ВИДЖЕТ
// ==========================================
class PidAxisCardWidget extends StatefulWidget {
  final String axisName;
  final String kpCmd, kiCmd, kdCmd;
  final double kp, ki, kd;
  final double kpMin, kpMax;
  final double kiMin, kiMax;
  final double kdMin, kdMax;
  final int kpDecimals, kiDecimals, kdDecimals;
  final void Function(double, double, double) onUpdate;

  const PidAxisCardWidget({
    super.key,
    required this.axisName,
    required this.kpCmd,
    required this.kiCmd,
    required this.kdCmd,
    required this.kp,
    required this.ki,
    required this.kd,
    this.kpMin = 0.0,
    this.kpMax = 10.0,
    this.kiMin = 0.0,
    this.kiMax = 5.0,
    this.kdMin = 0.0,
    this.kdMax = 2.0,
    this.kpDecimals = 3,
    this.kiDecimals = 3,
    this.kdDecimals = 3,
    required this.onUpdate,
  });

  @override
  State<PidAxisCardWidget> createState() => _PidAxisCardWidgetState();
}

class _PidAxisCardWidgetState extends State<PidAxisCardWidget> {
  late TextEditingController _kpController;
  late TextEditingController _kiController;
  late TextEditingController _kdController;
  late FocusNode _kpFocus;
  late FocusNode _kiFocus;
  late FocusNode _kdFocus;

  double _normalize(double val, double minVal, double maxVal, int decimals) {
    final clamped = val.clamp(minVal, maxVal).toDouble();
    final factor = math.pow(10, decimals).toDouble();
    return (clamped * factor).round() / factor;
  }

  String _format(double val, double minVal, double maxVal, int decimals) {
    return _normalize(val, minVal, maxVal, decimals).toStringAsFixed(decimals);
  }

  @override
  void initState() {
    super.initState();
    _kpController = TextEditingController(
      text: _format(widget.kp, widget.kpMin, widget.kpMax, widget.kpDecimals),
    );
    _kiController = TextEditingController(
      text: _format(widget.ki, widget.kiMin, widget.kiMax, widget.kiDecimals),
    );
    _kdController = TextEditingController(
      text: _format(widget.kd, widget.kdMin, widget.kdMax, widget.kdDecimals),
    );
    _kpFocus = FocusNode();
    _kiFocus = FocusNode();
    _kdFocus = FocusNode();

    _kpFocus.addListener(() {
      if (!_kpFocus.hasFocus) _applyValues(kpText: _kpController.text);
    });
    _kiFocus.addListener(() {
      if (!_kiFocus.hasFocus) _applyValues(kiText: _kiController.text);
    });
    _kdFocus.addListener(() {
      if (!_kdFocus.hasFocus) _applyValues(kdText: _kdController.text);
    });
  }

  @override
  void didUpdateWidget(covariant PidAxisCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_kpFocus.hasFocus && oldWidget.kp != widget.kp) {
      _kpController.text = _format(widget.kp, widget.kpMin, widget.kpMax, widget.kpDecimals);
    }
    if (!_kiFocus.hasFocus && oldWidget.ki != widget.ki) {
      _kiController.text = _format(widget.ki, widget.kiMin, widget.kiMax, widget.kiDecimals);
    }
    if (!_kdFocus.hasFocus && oldWidget.kd != widget.kd) {
      _kdController.text = _format(widget.kd, widget.kdMin, widget.kdMax, widget.kdDecimals);
    }
  }

  @override
  void dispose() {
    _kpFocus.dispose();
    _kiFocus.dispose();
    _kdFocus.dispose();
    _kpController.dispose();
    _kiController.dispose();
    _kdController.dispose();
    super.dispose();
  }

  void _applyValues({String? kpText, String? kiText, String? kdText}) {
    final parsedKp =
        double.tryParse((kpText ?? _kpController.text).trim().replaceAll(',', '.')) ?? widget.kp;
    final parsedKi =
        double.tryParse((kiText ?? _kiController.text).trim().replaceAll(',', '.')) ?? widget.ki;
    final parsedKd =
        double.tryParse((kdText ?? _kdController.text).trim().replaceAll(',', '.')) ?? widget.kd;

    final nextKp = _normalize(parsedKp, widget.kpMin, widget.kpMax, widget.kpDecimals);
    final nextKi = _normalize(parsedKi, widget.kiMin, widget.kiMax, widget.kiDecimals);
    final nextKd = _normalize(parsedKd, widget.kdMin, widget.kdMax, widget.kdDecimals);

    _kpController.text = nextKp.toStringAsFixed(widget.kpDecimals);
    _kiController.text = nextKi.toStringAsFixed(widget.kiDecimals);
    _kdController.text = nextKd.toStringAsFixed(widget.kdDecimals);

    if (nextKp != widget.kp || nextKi != widget.ki || nextKd != widget.kd) {
      widget.onUpdate(nextKp, nextKi, nextKd);
    }
  }

  Widget _buildCoeffField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required double minVal,
    required double maxVal,
    required int decimals,
    required VoidCallback onCommit,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            focusNode: focusNode,
            style: const TextStyle(fontSize: 16, fontFamily: 'monospace'),
            decoration: InputDecoration(
              labelText: '$label (.$decimals)',
              labelStyle: const TextStyle(fontSize: 13),
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            onSubmitted: (_) => onCommit(),
          ),
          const SizedBox(height: 4),
          Text(
            "${minVal.toStringAsFixed(decimals)}..${maxVal.toStringAsFixed(decimals)}",
            style: const TextStyle(fontSize: 11, color: Colors.white54, fontFamily: 'monospace'),
            softWrap: true,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return XFireCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.axisName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
            softWrap: true,
          ),
          const SizedBox(height: 4),
          Text(
            "${widget.kpCmd} / ${widget.kiCmd} / ${widget.kdCmd}",
            style: TextStyle(
              color: Colors.amberAccent.withOpacity(0.9),
              fontSize: 13,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
            softWrap: true,
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCoeffField(
                label: 'Kp',
                controller: _kpController,
                focusNode: _kpFocus,
                minVal: widget.kpMin,
                maxVal: widget.kpMax,
                decimals: widget.kpDecimals,
                onCommit: () => _applyValues(kpText: _kpController.text),
              ),
              const SizedBox(width: 8),
              _buildCoeffField(
                label: 'Ki',
                controller: _kiController,
                focusNode: _kiFocus,
                minVal: widget.kiMin,
                maxVal: widget.kiMax,
                decimals: widget.kiDecimals,
                onCommit: () => _applyValues(kiText: _kiController.text),
              ),
              const SizedBox(width: 8),
              _buildCoeffField(
                label: 'Kd',
                controller: _kdController,
                focusNode: _kdFocus,
                minVal: widget.kdMin,
                maxVal: widget.kdMax,
                decimals: widget.kdDecimals,
                onCommit: () => _applyValues(kdText: _kdController.text),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==========================================
// УНИВЕРСАЛЬНЫЙ КАЛЬКУЛЯТОР ЛИНКА
// ==========================================
class RtxLinkCalculatorCard extends StatelessWidget {
  final String title;
  final Color themeColor;
  final double currentFreqMhz,
      sensitivity,
      distKm,
      bitRate,
      sensitivityProgress,
      bitRateProgress;

  const RtxLinkCalculatorCard({
    super.key,
    required this.title,
    required this.themeColor,
    required this.currentFreqMhz,
    required this.sensitivity,
    required this.distKm,
    required this.bitRate,
    required this.sensitivityProgress,
    required this.bitRateProgress,
  });

  @override
  Widget build(BuildContext context) {
    final String distFormatted =
        distKm >= 1.0 ? "${distKm.toStringAsFixed(2)} км" : "${(distKm * 1000).toStringAsFixed(0)} м";
    final String bitRateStr =
        bitRate >= 1000 ? "${(bitRate / 1000).toStringAsFixed(1)} kbps" : "${bitRate.toStringAsFixed(0)} bps";

    return Container(
      padding: const EdgeInsets.all(15.0),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: themeColor.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text(
            "$title\nЧАСТОТА: ${currentFreqMhz.toStringAsFixed(0)} МГц",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: themeColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              height: 1.3,
            ),
            softWrap: true,
          ),
          const SizedBox(height: 8),
          Text(
            distFormatted,
            style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: themeColor),
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Text(
                      "Чувствительность приемника\n(Sensitivity):",
                      style: TextStyle(fontSize: 15, color: Colors.white70, height: 1.25),
                      softWrap: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${sensitivity.toStringAsFixed(1)} dBm",
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              LinearProgressIndicator(
                value: sensitivityProgress.clamp(0.0, 1.0),
                color: Colors.cyanAccent,
                backgroundColor: Colors.white12,
                minHeight: 7,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Text(
                      "Скорость по воздуху\n(Air Data Rate):",
                      style: TextStyle(fontSize: 15, color: Colors.white70, height: 1.25),
                      softWrap: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    bitRateStr,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              LinearProgressIndicator(
                value: bitRateProgress.clamp(0.0, 1.0),
                color: Colors.blueAccent,
                backgroundColor: Colors.white12,
                minHeight: 7,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==========================================
// БЛОКИ ГЕОМЕТРИИ АНТЕНН
// ==========================================
class DipoleAntennaBlock extends StatelessWidget {
  final bool hasProtectiveSleeve;
  final double sleeveThicknessMm, dipoleTubeDiameterMm, dipoleTopWireSqMm;
  final Map<String, dynamic> antResults;
  final ValueChanged<bool> onSleeveToggle;
  final ValueChanged<double> onSleeveThickChanged, onTubeDiamChanged, onTopWireChanged;
  final ValueChanged<double>? onSleeveThickEnd, onTubeDiamEnd, onTopWireEnd;

  const DipoleAntennaBlock({
    super.key,
    required this.hasProtectiveSleeve,
    required this.sleeveThicknessMm,
    required this.dipoleTubeDiameterMm,
    required this.dipoleTopWireSqMm,
    required this.antResults,
    required this.onSleeveToggle,
    required this.onSleeveThickChanged,
    required this.onTubeDiamChanged,
    required this.onTopWireChanged,
    this.onSleeveThickEnd,
    this.onTubeDiamEnd,
    this.onTopWireEnd,
  });

  @override
  Widget build(BuildContext context) {
    return XFireExpansionCard(
      title: "Дипольная антенна\n(Расчет и геометрия)",
      subtitle: "Расчет плеч штыревого диполя\nи диэлектрической усадки",
      icon: Icons.wifi_tethering,
      children: [
        XFireCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Графический расчет плеч диполя",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.cyanAccent),
                softWrap: true,
              ),
              const SizedBox(height: 12),
              Center(
                child: SizedBox(
                  width: 250,
                  child: Column(
                    children: [
                      const Text(
                        "Штыревой диполь",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
                        softWrap: true,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 125,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: CustomPaint(
                          painter: DipoleSchematicPainter(hasSleeve: hasProtectiveSleeve),
                          size: const Size(double.infinity, 125),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Верхнее плечо: ${(antResults['dipoleArmTopMm'] as double).toStringAsFixed(1)} мм",
                        style: const TextStyle(fontSize: 15, color: Colors.white70),
                        softWrap: true,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Нижнее плечо: ${(antResults['dipoleArmBotMm'] as double).toStringAsFixed(1)} мм",
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        XFireSwitchCard(
          title: "Защитная трубка / термоусадка\nна диполе",
          commandName: "ant_sleeve_en",
          value: hasProtectiveSleeve,
          onChanged: onSleeveToggle,
        ),
        if (hasProtectiveSleeve)
          XFireSliderCard(
            title: "Толщина стенки трубки\n(чехла)",
            commandName: "ant_sleeve_thick",
            value: sleeveThicknessMm,
            min: 0.5,
            max: 3.0,
            divisions: 25,
            unit: "мм",
            onChanged: onSleeveThickChanged,
            onChangeEnd: onSleeveThickEnd ?? (_) {},
          ),
        XFireSliderCard(
          title: "Диаметр трубки диполя\n(нижн.)",
          commandName: "ant_tube_diam",
          value: dipoleTubeDiameterMm,
          min: 2.0,
          max: 5.0,
          divisions: 6,
          unit: "мм",
          onChanged: onTubeDiamChanged,
          onChangeEnd: onTubeDiamEnd ?? (_) {},
        ),
        XFireSliderCard(
          title: "Сечение провода диполя\n(верхн.)",
          commandName: "ant_top_wire",
          value: dipoleTopWireSqMm,
          min: 0.5,
          max: 2.5,
          divisions: 20,
          unit: "мм²",
          onChanged: onTopWireChanged,
          onChangeEnd: onTopWireEnd ?? (_) {},
        ),
        XFireResetCard(
          hint: "Сброс геометрии диполя\nпо умолчанию",
          onReset: () {
            onSleeveToggle(true);
            onSleeveThickChanged(1.0);
            onTubeDiamChanged(3.0);
            onTopWireChanged(1.0);
            SerialService.sendCommand("default dipole");
          },
        ),
        XFireBatchApplyCard(
          hint: "Пакетная отправка геометрии\nштыревого диполя",
          parameters: [
            "ant_sleeve_en ${hasProtectiveSleeve ? 1 : 0}",
            "ant_sleeve_thick $sleeveThicknessMm",
            "ant_tube_diam $dipoleTubeDiameterMm",
            "ant_top_wire $dipoleTopWireSqMm",
          ],
        ),
      ],
    );
  }
}

class KharchenkoAntennaBlock extends StatelessWidget {
  final double kharchenkoWireSqMm;
  final Map<String, dynamic> antResults;
  final ValueChanged<double> onKharcChanged;
  final ValueChanged<double>? onKharcChangeEnd;

  const KharchenkoAntennaBlock({
    super.key,
    required this.kharchenkoWireSqMm,
    required this.antResults,
    required this.onKharcChanged,
    this.onKharcChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return XFireExpansionCard(
      title: "Антенна Харченко\n(Расчет и геометрия)",
      subtitle: "Расчет стороны ромба\nи геометрии биквадрата",
      icon: Icons.hub,
      children: [
        XFireCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Графический расчет антенны Харченко",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.amberAccent),
                softWrap: true,
              ),
              const SizedBox(height: 12),
              Center(
                child: SizedBox(
                  width: 250,
                  child: Column(
                    children: [
                      const Text(
                        "Антенна Харченко",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                        softWrap: true,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 125,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: CustomPaint(
                          painter: KharchenkoSchematicPainter(),
                          size: const Size(double.infinity, 125),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Сторона ромба",
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                        softWrap: true,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Сторона: ${(antResults['kharchenkoSideMm'] as double).toStringAsFixed(1)} мм",
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
          onChangeEnd: onKharcChangeEnd ?? (_) {},
        ),
        XFireResetCard(
          hint: "Сброс геометрии антенны\nХарченко по умолчанию",
          onReset: () {
            onKharcChanged(2.0);
            SerialService.sendCommand("default kharchenko");
          },
        ),
        XFireBatchApplyCard(
          hint: "Пакетная отправка геометрии\nантенны Харченко",
          parameters: ["ant_kharc_wire $kharchenkoWireSqMm"],
        ),
      ],
    );
  }
}

// ==========================================
// ХУДОЖНИКИ HUD И АВИАГОРИЗОНТ
// ==========================================
class DipoleSchematicPainter extends CustomPainter {
  final bool hasSleeve;
  DipoleSchematicPainter({required this.hasSleeve});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final cx = size.width / 2;

    if (hasSleeve) {
      final sleevePaint = Paint()
        ..color = Colors.blueAccent.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, size.height / 2), width: 14, height: size.height - 10),
          const Radius.circular(6),
        ),
        sleevePaint,
      );
    }

    canvas.drawLine(Offset(cx, 15), Offset(cx, size.height / 2 - 5), paint);
    canvas.drawLine(
      Offset(cx, size.height / 2 + 5),
      Offset(cx, size.height - 15),
      paint
        ..color = Colors.blueAccent
        ..strokeWidth = 5.0,
    );
    canvas.drawCircle(Offset(cx, size.height / 2), 3, Paint()..color = Colors.redAccent);

    textPainter.text = const TextSpan(
      text: "Верхнее\nплечо",
      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.15),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(cx + 12, 18));

    textPainter.text = const TextSpan(
      text: "Нижнее\nплечо",
      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.15),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(cx + 12, size.height - 46));
  }

  @override
  bool shouldRepaint(covariant DipoleSchematicPainter oldDelegate) => oldDelegate.hasSleeve != hasSleeve;
}

class KharchenkoSchematicPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.amberAccent
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
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
    textPainter.text = const TextSpan(
      text: "λ/4",
      style: TextStyle(color: Colors.cyanAccent, fontSize: 14, fontWeight: FontWeight.bold),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(cx + 8, cy - 28));
  }

  @override
  bool shouldRepaint(covariant KharchenkoSchematicPainter oldDelegate) => false;
}

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
    final double rawRange = maxVal - minVal;
    final double range = rawRange.abs() < 1e-6 ? 1.0 : rawRange;

    for (int i = 0; i <= 6; i++) {
      final double v = minVal + (range / 6) * i;
      final double y = size.height - 14 - ((v - minVal) / range) * (size.height - 28);
      canvas.drawLine(Offset(x, y), Offset(isLeftSide ? x - 6 : x + 6, y), paintLine);

      paintText.text = TextSpan(
        text: "${v.toInt()}°",
        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
      );
      paintText.layout();
      paintText.paint(canvas, Offset(isLeftSide ? x - 38 : x + 10, y - 7));
    }

    final double clampedVal = value.clamp(minVal, maxVal);
    final double currentY =
        size.height - 14 - ((clampedVal - minVal) / range) * (size.height - 28);

    final path = Path();
    if (isLeftSide) {
      final double cursorX = x - 6;
      path.moveTo(cursorX + 10, currentY);
      path.lineTo(cursorX, currentY - 5);
      path.lineTo(cursorX, currentY + 5);
    } else {
      final double cursorX = x + 6;
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

  YawHudScalePainter({
    required this.value,
    required this.minVal,
    required this.maxVal,
    required this.isTop,
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
    const double margin = 36.0;
    final double y = isTop ? 14.0 : size.height - 14.0;

    canvas.drawLine(Offset(margin, y), Offset(size.width - margin, y), paintLine);
    final double rawRange = maxVal - minVal;
    final double range = rawRange.abs() < 1e-6 ? 1.0 : rawRange;

    for (int i = 0; i <= 4; i++) {
      final double v = minVal + (range / 4) * i;
      final double x = margin + ((v - minVal) / range) * (size.width - (margin * 2));
      canvas.drawLine(Offset(x, y), Offset(x, y + (isTop ? -5 : 5)), paintLine);
      paintText.text = TextSpan(
        text: "${v.toInt()}°",
        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
      );
      paintText.layout();
      paintText.paint(canvas, Offset(x - 14, y + (isTop ? -20 : 6)));
    }

    final double currentX =
        margin + ((value.clamp(minVal, maxVal) - minVal) / range) * (size.width - (margin * 2));

    final path = Path();
    if (isTop) {
      final double cursorY = y + 6;
      path.moveTo(currentX, cursorY + 10);
      path.lineTo(currentX - 5, cursorY);
      path.lineTo(currentX + 5, cursorY);
    } else {
      final double cursorY = y - 6;
      path.moveTo(currentX, cursorY - 10);
      path.lineTo(currentX - 5, cursorY);
      path.lineTo(currentX + 5, cursorY);
    }
    path.close();
    canvas.drawPath(path, indicatorPaint);
  }

  @override
  bool shouldRepaint(covariant YawHudScalePainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.minVal != minVal ||
      oldDelegate.maxVal != maxVal ||
      oldDelegate.isTop != isTop;
}

class ArtificialHorizonPainter extends CustomPainter {
  final double roll, pitch;
  ArtificialHorizonPainter({required this.roll, required this.pitch});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.max(1.0, math.min(size.width, size.height) / 2 - 1);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: radius)));
    canvas.rotate(-roll);

    final double pitchOffset = pitch * 40.0;
    canvas.drawRect(
      Rect.fromLTWH(-radius * 2, -radius * 3 + pitchOffset, radius * 4, radius * 3),
      Paint()..color = const Color(0xFF1E6091),
    );
    canvas.drawRect(
      Rect.fromLTWH(-radius * 2, pitchOffset, radius * 4, radius * 3),
      Paint()..color = const Color(0xFF6A4A3A),
    );
    canvas.drawLine(
      Offset(-radius * 2, pitchOffset),
      Offset(radius * 2, pitchOffset),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2.0,
    );

    for (int p = -3; p <= 3; p++) {
      if (p == 0) continue;
      canvas.drawLine(
        Offset(-(p.abs() % 2 == 0 ? 20.0 : 10.0) / 2, pitchOffset - (p * 20.0)),
        Offset((p.abs() % 2 == 0 ? 20.0 : 10.0) / 2, pitchOffset - (p * 20.0)),
        Paint()
          ..color = Colors.white70
          ..strokeWidth = 1.5,
      );
    }
    canvas.restore();
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
    );
  }

  @override
  bool shouldRepaint(covariant ArtificialHorizonPainter oldDelegate) =>
      oldDelegate.roll != roll || oldDelegate.pitch != pitch;
}
