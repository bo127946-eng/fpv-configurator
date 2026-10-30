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
      title: 'FPV CLI Configurator',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blueAccent,
        colorScheme: const ColorScheme.dark(secondary: Colors.amberAccent),
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
    const ConfigTab(),
    const TerminalTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.tune), label: 'Configurator'),
          BottomNavigationBarItem(icon: Icon(Icons.terminal), label: 'Terminal'),
        ],
      ),
    );
  }
}

class UsbService {
  static UsbPort? port;
  static String terminalLog = "";
  static StreamController<String> logController = StreamController.broadcast();

  static Future<void> sendCommand(String cmd) async {
    if (port != null) {
      await port!.write(Uint8List.fromList('$cmd\n'.codeUnits));
      terminalLog += ">> $cmd\n";
      logController.add(terminalLog);
    }
  }
}

class ConfigTab extends StatefulWidget {
  const ConfigTab({super.key});

  @override
  State<ConfigTab> createState() => _ConfigTabState();
}

class _ConfigTabState extends State<ConfigTab> {
  String _statusMessage = "Disconnected";
  List<UsbDevice> _devices = [];
  bool _isConnected = false;

  double _deadbandVal = 20.0;
  double _lpfGyroVal = 0.4;
  double _fsBattVal = 14.0;

  @override
  void initState() {
    super.initState();
    _scanDevices();
  }

  Future<void> _scanDevices() async {
    _devices = await UsbSerial.listDevices();
    setState(() {
      _statusMessage = _devices.isNotEmpty ? "Found: ${_devices[0].deviceName}" : "No USB devices found";
    });
  }

  Future<void> _toggleConnection() async {
    if (_isConnected) {
      await UsbService.port?.close();
      UsbService.port = null;
      setState(() {
        _isConnected = false;
        _statusMessage = "Disconnected";
      });
    } else {
      if (_devices.isEmpty) return;
      UsbService.port = await _devices[0].create();
      bool openResult = await UsbService.port!.open();
      if (!openResult) {
        setState(() { _statusMessage = "Failed to open port"; });
        return;
      }
      await UsbService.port!.setPortParameters(115200, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);
      
      setState(() {
        _isConnected = true;
        _statusMessage = "Connected to ${_devices[0].deviceName}";
      });

      UsbService.port!.inputStream!.listen((Uint8List data) {
        String incoming = String.fromCharCodes(data);
        UsbService.terminalLog += incoming;
        UsbService.logController.add(UsbService.terminalLog);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FPV Configurator (v1.06)'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _scanDevices),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            color: _isConnected ? Colors.green.shade900 : Colors.grey.shade900,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(_statusMessage, overflow: TextOverflow.ellipsis)),
                  ElevatedButton(
                    onPressed: _devices.isNotEmpty ? _toggleConnection : null,
                    style: ElevatedButton.styleFrom(backgroundColor: _isConnected ? Colors.red : Colors.blue),
                    child: Text(_isConnected ? "Disconnect" : "Connect"),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          const Text("RC & Deadband", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber)),
          ListTile(
            title: Text("Deadband: ${_deadbandVal.round()} us"),
            subtitle: Slider(
              value: _deadbandVal,
              min: 0,
              max: 100,
              divisions: 100,
              onChanged: (val) => setState(() => _deadbandVal = val),
              onChangeEnd: (val) => UsbService.sendCommand("deadband ${val.round()}"),
            ),
          ),

          const Divider(),

          const Text("Filters Tuning", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber)),
          ListTile(
            title: Text("Gyro LPF Alpha: ${_lpfGyroVal.toStringAsFixed(2)}"),
            subtitle: Slider(
              value: _lpfGyroVal,
              min: 0.05,
              max: 1.0,
              divisions: 19,
              onChanged: (val) => setState(() => _lpfGyroVal = val),
              onChangeEnd: (val) => UsbService.sendCommand("lpf_gyro ${val.toStringAsFixed(2)}"),
            ),
          ),

          const Divider(),

          const Text("Failsafe & Battery", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber)),
          ListTile(
            title: Text("Failsafe Voltage: ${_fsBattVal.toStringAsFixed(1)} V"),
            subtitle: Slider(
              value: _fsBattVal,
              min: 6.0,
              max: 25.0,
              divisions: 38,
              onChanged: (val) => setState(() => _fsBattVal = val),
              onChangeEnd: (val) => UsbService.sendCommand("fs_batt ${val.toStringAsFixed(1)}"),
            ),
          ),

          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => UsbService.sendCommand("calib_sticks"),
                icon: const Icon(Icons.gamepad),
                label: const Text("Calib Sticks"),
              ),
              ElevatedButton.icon(
                onPressed: () => UsbService.sendCommand("calib"),
                icon: const Icon(Icons.explore),
                label: const Text("Calib Gyro"),
              ),
              ElevatedButton.icon(
                onPressed: () => UsbService.sendCommand("info"),
                icon: const Icon(Icons.info),
                label: const Text("Read Info"),
              ),
              ElevatedButton.icon(
                onPressed: () => UsbService.sendCommand("reset"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                icon: const Icon(Icons.warning),
                label: const Text("Reset Factory"),
              ),
            ],
          ),
        ],
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
      setState(() {
        _displayLog = log;
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
    return Scaffold(
      appBar: AppBar(title: const Text('CLI Terminal')),
      body: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.black,
              child: SingleChildScrollView(
                reverse: true,
                child: Text(
                  _displayLog,
                  style: const TextStyle(fontFamily: 'monospace', color: Colors.greenAccent, fontSize: 12),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cmdController,
                    decoration: const InputDecoration(
                      hintText: "Enter CLI command (e.g. info)",
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (val) {
                      if (val.isNotEmpty) {
                        UsbService.sendCommand(val);
                        _cmdController.clear();
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    if (_cmdController.text.isNotEmpty) {
                      UsbService.sendCommand(_cmdController.text);
                      _cmdController.clear();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
