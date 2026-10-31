import 'package:flutter/material.dart';
import 'package:usb_serial/usb_serial.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
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
    const TestsTab(),
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
            icon: Icon(Icons.science_outlined),
            selectedIcon: Icon(Icons.science),
            label: 'Tests',
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

// ==========================================
// УНИВЕРСАЛЬНЫЙ СЕРВИС СВЯЗИ (SERIAL SERVICE)
// ==========================================
enum ConnectionType { usb, bluetooth }

class SerialService {
  static ConnectionType? activeConnectionType;
  
  static UsbPort? usbPort;
  static StreamSubscription<Uint8List>? _usbSubscription;

  static BluetoothDevice? bleDevice;
  static BluetoothCharacteristic? bleWriteCharacteristic;
  static StreamSubscription<List<int>>? _bleSubscription;

  static String lastResponse = ">> Ready. Connect device.";
  static String terminalLog = "";
  static StreamController<String> logController = StreamController.broadcast();
  static StreamController<void> telemetryController = StreamController.broadcast();

  static double gyroRoll = 0.0, gyroPitch = 0.0, gyroYaw = 0.0;
  static double accelX = 0.0, accelY = 0.0, accelZ = 1.0;
  static double motor1 = 0.0, motor2 = 0.0, motor3 = 0.0, motor4 = 0.0;
  static double batteryVoltage = 16.2;

  static Future<void> sendCommand(String cmd) async {
    if (activeConnectionType == ConnectionType.usb && usbPort != null) {
      await usbPort!.write(Uint8List.fromList('$cmd\n'.codeUnits));
      appendLog(">> $cmd\n");
    } else if (activeConnectionType == ConnectionType.bluetooth && bleWriteCharacteristic != null) {
      await bleWriteCharacteristic!.write(Uint8List.fromList('$cmd\n'.codeUnits), withoutResponse: true);
      appendLog(">> $cmd\n");
    } else {
      appendLog(">> ERROR: Device not connected\n");
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
    if (activeConnectionType == ConnectionType.usb) {
      await _usbSubscription?.cancel();
      await usbPort?.close();
      usbPort = null;
    } else if (activeConnectionType == ConnectionType.bluetooth) {
      await _bleSubscription?.cancel();
      await bleDevice?.disconnect();
      bleDevice = null;
      bleWriteCharacteristic = null;
    }
    activeConnectionType = null;
    lastResponse = ">> Disconnected";
    logController.add(terminalLog);
  }
}

// ==========================================
// ШАПКА СТАТУСА И УПРАВЛЕНИЯ ПОДКЛЮЧЕНИЕМ
// ==========================================
class DroneStatusHeader extends StatefulWidget {
  const DroneStatusHeader({super.key});

  @override
  State<DroneStatusHeader> createState() => _DroneStatusHeaderState();
}

class _DroneStatusHeaderState extends State<DroneStatusHeader> {
  String _displayResponse = SerialService.lastResponse;
  bool _isConnected = false;
  late StreamSubscription<String> _sub;

  @override
  void initState() {
    super.initState();
    _sub = SerialService.logController.stream.listen((_) {
      setState(() {
        _displayResponse = SerialService.lastResponse;
        _isConnected = SerialService.activeConnectionType != null;
      });
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  void _showConnectionDialog() {
    if (_isConnected) {
      SerialService.disconnect();
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Select Connection Type",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _connectUsb();
                },
                icon: const Icon(Icons.usb),
                label: const Text("Connect via USB OTG"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.all(12)),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showBluetoothScanDialog();
                },
                icon: const Icon(Icons.bluetooth),
                label: const Text("Connect via Bluetooth (BLE)"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent, padding: const EdgeInsets.all(12)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _connectUsb() async {
    List<UsbDevice> devices = await UsbSerial.listDevices();
    if (devices.isEmpty) {
      setState(() => SerialService.lastResponse = ">> No USB devices found");
      return;
    }
    SerialService.usbPort = await devices[0].create();
    bool openResult = await SerialService.usbPort!.open();
    if (!openResult) {
      setState(() => SerialService.lastResponse = ">> Failed to open USB port");
      return;
    }
    await SerialService.usbPort!.setPortParameters(115200, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);
    SerialService.activeConnectionType = ConnectionType.usb;
    setState(() {
      _isConnected = true;
      SerialService.lastResponse = ">> Connected via USB to ${devices[0].deviceName}";
    });
    SerialService._usbSubscription = SerialService.usbPort!.inputStream!.listen((data) {
      SerialService.handleIncomingData(data);
    });
  }

  void _showBluetoothScanDialog() {
    showDialog(
      context: context,
      builder: (context) => const BluetoothScanDialog(),
    );
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
            Icon(
              SerialService.activeConnectionType == ConnectionType.bluetooth 
                  ? Icons.bluetooth_connected 
                  : Icons.sensors, 
              color: _isConnected ? Colors.greenAccent : Colors.amberAccent, 
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _displayResponse, 
                style: const TextStyle(fontFamily: 'monospace', color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w500), 
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 32,
              child: ElevatedButton.icon(
                onPressed: _showConnectionDialog,
                icon: Icon(_isConnected ? Icons.link_off : Icons.link, size: 14),
                label: Text(_isConnected ? "Disconnect" : "Connect", style: const TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isConnected ? Colors.red.shade900 : Colors.blueAccent, 
                  padding: const EdgeInsets.symmetric(horizontal: 10),
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
// ДИАЛОГ СКАНИРОВАНИЯ BLUETOOTH УСТРОЙСТВ
// ==========================================
class BluetoothScanDialog extends StatefulWidget {
  const BluetoothScanDialog({super.key});

  @override
  State<BluetoothScanDialog> createState() => _BluetoothScanDialogState();
}

class _BluetoothScanDialogState extends State<BluetoothScanDialog> {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanSub;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() => _isScanning = true);
    try {
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        if (mounted) setState(() => _scanResults = results);
      });
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
    } catch (e) {
      SerialService.appendLog(">> BLE Scan Error: $e\n");
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    Navigator.pop(context);
    try {
      await device.connect(timeout: const Duration(seconds: 5));
      SerialService.bleDevice = device;
      SerialService.activeConnectionType = ConnectionType.bluetooth;

      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
            SerialService.bleWriteCharacteristic = characteristic;
          }
          if (characteristic.properties.notify || characteristic.properties.indicate) {
            await characteristic.setNotifyValue(true);
            SerialService._bleSubscription = characteristic.lastValueStream.listen((data) {
              SerialService.handleIncomingData(Uint8List.fromList(data));
            });
          }
        }
      }

      String devName = device.platformName.isNotEmpty ? device.platformName : "Drone BLE";
      SerialService.lastResponse = ">> Connected to BLE: $devName";
      SerialService.logController.add(SerialService.terminalLog);
    } catch (e) {
      SerialService.lastResponse = ">> BLE Error: $e";
      SerialService.logController.add(SerialService.terminalLog);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Select BLE Device", style: TextStyle(fontSize: 16)),
          if (_isScanning) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ),
      content: SizedBox(
        width: 300,
        height: 300,
        child: ListView.builder(
          itemCount: _scanResults.length,
          itemBuilder: (context, index) {
            final data = _scanResults[index];
            String name = data.device.platformName.isNotEmpty 
                ? data.device.platformName 
                : (data.advertisementData.advName.isNotEmpty ? data.advertisementData.advName : "Unknown Device");
            return ListTile(
              title: Text(name, style: const TextStyle(fontSize: 14)),
              subtitle: Text(data.device.remoteId.toString(), style: const TextStyle(fontSize: 11)),
              onTap: () => _connectToDevice(data.device),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
      ],
    );
  }
}

// ==========================================
// ВКЛАДКА 1: НАСТРОЙКИ (SettingsTab)
// ==========================================
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  double _flightMode = 0;
  double _filterMode = 1;
  double _dynamicNotchEnabled = 1;

  double _fsRcEn = 1;
  double _fsBattEn = 1;
  double _batteryCells = 0;
  double _battFsV = 14.0;
  double _fsSpeed = 0.8;

  double _gyroLpfAlpha = 0.40;
  double _accelLpfAlpha = 0.15;
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
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.amberAccent),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
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
      margin: const EdgeInsets.only(bottom: 8),
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
                      Text("($commandName)", style: TextStyle(color: Colors.amberAccent.withOpacity(0.8), fontSize: 10, fontFamily: 'monospace')),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text("${value.toStringAsFixed(value.truncate() == value ? 0 : 2)} $unit", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged, onChangeEnd: onChangeEnd),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownCard({
    required String title,
    required String commandName,
    required double value,
    required List<DropdownMenuItem<double>> items,
    required ValueChanged<double?> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text("($commandName)", style: TextStyle(color: Colors.amberAccent.withOpacity(0.8), fontSize: 10, fontFamily: 'monospace')),
              ],
            ),
            DropdownButton<double>(
              value: value,
              items: items,
              onChanged: onChanged,
              dropdownColor: const Color(0xFF1E1E1E),
              style: const TextStyle(fontSize: 13, color: Colors.white),
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
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text("($commandName)", style: TextStyle(color: Colors.amberAccent.withOpacity(0.8), fontSize: 10, fontFamily: 'monospace')),
              ],
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.blueAccent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPidCard({
    required String title,
    required String commandName,
    required double p,
    required double i,
    required double d,
    required Function(double, double, double) onUpdate,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text("($commandName)", style: TextStyle(color: Colors.amberAccent.withOpacity(0.8), fontSize: 10, fontFamily: 'monospace')),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: p.toString()),
                    decoration: const InputDecoration(labelText: 'P', isDense: true),
                    keyboardType: TextInputType.number,
                    onSubmitted: (val) {
                      double? np = double.tryParse(val);
                      if (np != null) onUpdate(np, i, d);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: i.toString()),
                    decoration: const InputDecoration(labelText: 'I', isDense: true),
                    keyboardType: TextInputType.number,
                    onSubmitted: (val) {
                      double? ni = double.tryParse(val);
                      if (ni != null) onUpdate(p, ni, d);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: d.toString()),
                    decoration: const InputDecoration(labelText: 'D', isDense: true),
                    keyboardType: TextInputType.number,
                    onSubmitted: (val) {
                      double? nd = double.tryParse(val);
                      if (nd != null) onUpdate(p, i, nd);
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

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12.0),
      children: [
        _buildSectionHeader("ОСНОВНЫЕ РЕЖИМЫ", Icons.flight),
        _buildDropdownCard(
          title: "Полетный режим",
          commandName: "flight_mode",
          value: _flightMode,
          items: const [
            DropdownMenuItem(value: 0, child: Text("0: Angle")),
            DropdownMenuItem(value: 1, child: Text("1: Rate-Acro")),
            DropdownMenuItem(value: 2, child: Text("2: Horizon")),
          ],
          onChanged: (v) {
            if (v != null) {
              setState(() => _flightMode = v);
              SerialService.sendCommand("flight_mode ${v.round()}");
            }
          },
        ),
        _buildDropdownCard(
          title: "Режим фильтрации",
          commandName: "filter_mode",
          value: _filterMode,
          items: const [
            DropdownMenuItem(value: 0, child: Text("0: Выкл")),
            DropdownMenuItem(value: 1, child: Text("1: Уровень 1")),
            DropdownMenuItem(value: 2, child: Text("2: Уровень 2")),
            DropdownMenuItem(value: 3, child: Text("3: Уровень 3")),
          ],
          onChanged: (v) {
            if (v != null) {
              setState(() => _filterMode = v);
              SerialService.sendCommand("filter_mode ${v.round()}");
            }
          },
        ),
        _buildSwitchCard(
          title: "Динамический Notch фильтр",
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
        _buildDropdownCard(
          title: "Количество ячеек батареи",
          commandName: "battery_cells",
          value: _batteryCells,
          items: const [
            DropdownMenuItem(value: 0, child: Text("Авто")),
            DropdownMenuItem(value: 2, child: Text("2S")),
            DropdownMenuItem(value: 3, child: Text("3S")),
            DropdownMenuItem(value: 4, child: Text("4S")),
            DropdownMenuItem(value: 5, child: Text("5S")),
            DropdownMenuItem(value: 6, child: Text("6S")),
          ],
          onChanged: (v) {
            if (v != null) {
              setState(() => _batteryCells = v);
              SerialService.sendCommand("battery_cells ${v.round()}");
            }
          },
        ),
        _buildSliderCard(title: "Порог разряда батареи", commandName: "batt_fs_v", value: _battFsV, min: 6.0, max: 25.0, divisions: 190, unit: "В", onChanged: (v) => setState(() => _battFsV = v), onChangeEnd: (v) => SerialService.sendCommand("batt_fs_v $v")),
        _buildSliderCard(title: "Скорость снижения при Failsafe", commandName: "fs_speed", value: _fsSpeed, min: 0.2, max: 2.0, divisions: 18, unit: "м/с", onChanged: (v) => setState(() => _fsSpeed = v), onChangeEnd: (v) => SerialService.sendCommand("fs_speed $v")),

        _buildSectionHeader("ФИЛЬТРЫ СЕНСОРОВ", Icons.waves),
        _buildSliderCard(title: "Фильтр гироскопа LPF", commandName: "gyro_lpf_alpha", value: _gyroLpfAlpha, min: 0.05, max: 1.0, divisions: 19, unit: "", onChanged: (v) => setState(() => _gyroLpfAlpha = v), onChangeEnd: (v) => SerialService.sendCommand("gyro_lpf_alpha $v")),
        _buildSliderCard(title: "Фильтр акселерометра LPF", commandName: "accel_lpf_alpha", value: _accelLpfAlpha, min: 0.01, max: 1.0, divisions: 99, unit: "", onChanged: (v) => setState(() => _accelLpfAlpha = v), onChangeEnd: (v) => SerialService.sendCommand("accel_lpf_alpha $v")),
        _buildSliderCard(title: "Notch: Центр", commandName: "notch_center_freq", value: _notchCenterFreq, min: 30, max: 150, divisions: 120, unit: "Гц", onChanged: (v) => setState(() => _notchCenterFreq = v), onChangeEnd: (v) => SerialService.sendCommand("notch_center_freq $v")),
        _buildSliderCard(title: "Notch: Ширина полосы", commandName: "notch_bandwidth", value: _notchBandwidth, min: 5, max: 50, divisions: 45, unit: "Гц", onChanged: (v) => setState(() => _notchBandwidth = v), onChangeEnd: (v) => SerialService.sendCommand("notch_bandwidth $v")),
        _buildSliderCard(title: "Dyn Notch Мин", commandName: "dyn_notch_min_hz", value: _dynNotchMinHz, min: 20, max: 100, divisions: 16, unit: "Гц", onChanged: (v) => setState(() => _dynNotchMinHz = v), onChangeEnd: (v) => SerialService.sendCommand("dyn_notch_min_hz $v")),
        _buildSliderCard(title: "Dyn Notch Макс", commandName: "dyn_notch_max_hz", value: _dynNotchMaxHz, min: 80, max: 200, divisions: 24, unit: "Гц", onChanged: (v) => setState(() => _dynNotchMaxHz = v), onChangeEnd: (v) => SerialService.sendCommand("dyn_notch_max_hz $v")),

        _buildSectionHeader("РЕЖИМ HORIZON", Icons.threesixty),
        _buildSliderCard(title: "Порог перехода Horizon", commandName: "horizon_transition", value: _horizonTransition, min: 0.0, max: 1.0, divisions: 20, unit: "", onChanged: (v) => setState(() => _horizonTransition = v), onChangeEnd: (v) => SerialService.sendCommand("horizon_transition $v")),
        _buildSliderCard(title: "Усиление Horizon Trainer", commandName: "horizon_trainer_gain", value: _horizonTrainerGain, min: 0.0, max: 1.0, divisions: 20, unit: "", onChanged: (v) => setState(() => _horizonTrainerGain = v), onChangeEnd: (v) => SerialService.sendCommand("horizon_trainer_gain $v")),
        _buildSliderCard(title: "Мертвая зона Horizon", commandName: "horizon_trainer_dead", value: _horizonTrainerDead, min: 0.0, max: 0.5, divisions: 25, unit: "", onChanged: (v) => setState(() => _horizonTrainerDead = v), onChangeEnd: (v) => SerialService.sendCommand("horizon_trainer_dead $v")),

        _buildSectionHeader("УПРАВЛЕНИЕ И ЭКСПОНЕНТЫ", Icons.gamepad),
        _buildSliderCard(title: "Крен/Тангаж: Rate", commandName: "rc_rate", value: _rcRate, min: 0.1, max: 2.0, divisions: 19, unit: "", onChanged: (v) => setState(() => _rcRate = v), onChangeEnd: (v) => SerialService.sendCommand("rc_rate $v")),
        _buildSliderCard(title: "Крен/Тангаж: Super Expo", commandName: "super_expo", value: _superExpo, min: 0.0, max: 0.9, divisions: 18, unit: "", onChanged: (v) => setState(() => _superExpo = v), onChangeEnd: (v) => SerialService.sendCommand("super_expo $v")),
        _buildSliderCard(title: "Крен/Тангаж: Stick Expo", commandName: "stick_expo", value: _stickExpo, min: 0.0, max: 1.0, divisions: 20, unit: "", onChanged: (v) => setState(() => _stickExpo = v), onChangeEnd: (v) => SerialService.sendCommand("stick_expo $v")),
        _buildSliderCard(title: "Рыскание (Yaw): Rate", commandName: "yaw_rc_rate", value: _yawRcRate, min: 0.1, max: 2.0, divisions: 19, unit: "", onChanged: (v) => setState(() => _yawRcRate = v), onChangeEnd: (v) => SerialService.sendCommand("yaw_rc_rate $v")),
        _buildSliderCard(title: "Рыскание (Yaw): Super Expo", commandName: "yaw_super_expo", value: _yawSuperExpo, min: 0.
