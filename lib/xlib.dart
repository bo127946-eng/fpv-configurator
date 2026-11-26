import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:usb_serial/usb_serial.dart';

class SerialService {
  static bool isConnected = false;
  static bool isBusy = false;
  static UsbDevice? activeDevice;
  static UsbPort? usbPort;
  static StreamSubscription<Uint8List>? usbSubscription;

  static Future<void> _queue = Future.value();

  static String lastResponse = "Ready. Connect via USB OTG.";
  static String terminalLog = "";
  static final StreamController<String> logController =
      StreamController<String>.broadcast();
  static final StreamController<void> telemetryController =
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
    terminalLog += text;
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
        final StringBuffer sb = StringBuffer()..writeln('config')..write('"');
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
}

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

  static Future findDfuDevice() async {
    _ensureInitialized();
    final dynamic res = await _channel.invokeMethod('findDfuDevice');
    if (res is Map) {
      return Map.from(res);
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
    String assetPath = 'assets/firmware_f401.bin',
    int startAddress = 0x08000000,
    void Function(String status, double progress)? onProgress,
  }) async {
    _ensureInitialized();

    onProgress?.call("Поиск STM32F401 в режиме DFU...", 0.02);
    final Map? dev = await findDfuDevice();
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

    final StreamSubscription<DfuProgressEvent> sub = progressStream.listen((ev) {
      onProgress?.call(ev.status, ev.progress);
    });

    try {
      await _channel.invokeMethod('flashF401', {
        'firmware': firmware,
        'startAddress': startAddress,
      });
    } finally {
      await sub.cancel();
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
          _statusState = "Прошивка F401 по DFU завершена!";
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
    final double range = maxVal - minVal;

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
    final double range = maxVal - minVal;

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
    final radius = math.min(size.width, size.height) / 2 - 1;

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
