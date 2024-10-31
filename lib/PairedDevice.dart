import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'BLEManager.dart';

class PairedDevicesPage extends StatefulWidget {

  const PairedDevicesPage({super.key});

  @override
  State<PairedDevicesPage> createState() => _PairedDevicesPageState();
}

class _PairedDevicesPageState extends State<PairedDevicesPage>{
  Color selectedColor = Colors.blue;
  bool isSwitchedOn = true;
  double sliderValue = 0.0;
  double _ledGlowSliderValue = 0.0; // Default to 50%
  bool _isLedGlowSwitched = false;
  Color _ledColor = Colors.orange;
  bool isSwitchedOn1 = false;
  Color selectedColor1 = Colors.blue;
  double sliderValue1 = 0.5;

  Color _borderColor1 = Colors.transparent;
  Color _borderColor2 = Colors.transparent;

  String? newDeviceName;


  double _tintSliderValue = 0.0;

  BleManager? _bleManager; // Store a reference to the BleManager
  String? _deviceId; // To store the connected device's ID
  String? _deviceName; // To store the device name
  bool _connectionAlertShown = false; // Track if connection alert has been shown
  int _retryCount = 0; // Track the number of retries
  final int _maxRetries = 3; // Maximum number of retries


  @override
  void initState() {
    super.initState();
    requestBluetoothPermissions().then((_) {
      _setupBLEConnection();
    });
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Fetch BleManager reference safely in didChangeDependencies
    _bleManager = Provider.of<BleManager>(context, listen: false);
  }
  @override
  void dispose() {
    _executeBleCommands();
    super.dispose();
  }

  Future<void> requestBluetoothPermissions() async {
    if (await Permission.bluetooth.isDenied) {
      await Permission.bluetooth.request();
    }

    // For BLE scan, you may also need location permission on Android 6.0 to Android 11
    if (await Permission.location.isDenied) {
      await Permission.location.request();
    }

    // For Android 12 (API level 31) and above:
    if (await Permission.bluetoothScan.isDenied) {
      await Permission.bluetoothScan.request();
    }

    if (await Permission.bluetoothConnect.isDenied) {
      await Permission.bluetoothConnect.request();
    }

    if (await Permission.bluetoothAdvertise.isDenied) {
      await Permission.bluetoothAdvertise.request();
    }
  }


  // Setup BLE connection and listeners
  void _setupBLEConnection() {
    final bleManager = Provider.of<BleManager>(context, listen: false);
    bleManager.addListener(_bleManagerListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBLEConnection();
    });
  }

  // Check BLE connection and initiate connection if not connected
  void _checkBLEConnection() async {
    final bleManager = Provider.of<BleManager>(context, listen: false);

    if (bleManager.connectedDevice != null) {
      _deviceId = bleManager.connectedDevice!.id.toString();
      await _fetchDeviceName();
      //_checkFirstTimeDialog(); // Show first-time dialog
    } else {
      _startBLEConnection();
    }
  }

  // Start BLE connection process
  void _startBLEConnection() {
    final bleManager = Provider.of<BleManager>(context, listen: false);
    bleManager.startScan(); // Start BLE scan
  }

  // Listener to handle BLEManager state changes
  void _bleManagerListener() {
    final bleManager = Provider.of<BleManager>(context, listen: false);

    // Handle connection
    if (bleManager.connectedDevice != null &&
        !bleManager.isConnecting &&
        !_connectionAlertShown) {
      _deviceId = bleManager.connectedDevice!.id.toString();
      _fetchDeviceName().then((_) {
        //_checkFirstTimeDialog(); // Show first-time dialog after fetching device name
        setState(() {}); // Update UI
      });
    }

    // Handle disconnection
    if (bleManager.connectedDevice == null && _deviceName != null) {
      // Device was previously connected and now disconnected
      setState(() {
        _deviceId = null;
        _deviceName = null;
      });
    }

    // Existing code for no device found
    if (bleManager.noDeviceFound && !_connectionAlertShown) {
      if (_retryCount < _maxRetries) {
        _retryCount++;
        print("Retrying scan ($_retryCount/$_maxRetries)...");
        _startBLEConnection(); // Restart the scan
      } else {
        _showConnectionFailedDialog();
      }
    }
  }



  // Implement the missing _fetchDeviceName method
  Future<void> _fetchDeviceName() async {
    if (_deviceId != null) {
      setState(() {
        _deviceName = 'SleepSanity';
      });
    }
  }

  // Show a dialog if no device is found after maximum retries
  void _showConnectionFailedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Failed to Connect to Device"),
        content: const Text("Would you like to try connecting again?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _retryCount = 0; // Reset retry count
              _startBLEConnection(); // Retry connection
            },
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  // Function to send BLE commands
  void _executeBleCommands() {
    if (_bleManager != null) {
      _bleManager!.sendBleCommand('5c0601000000000000');
      _bleManager!.sendBleCommand('5c0701000000000000');
      _bleManager!.updateTintLevel(0);
    }
  }


  // Update LED glow brightness with increment or decrement
  void _updateLedGlow(BleManager bleManager, double newValue) {
    setState(() {
      _ledGlowSliderValue = newValue.clamp(0.0, 1.0);
    });
    bleManager.updateLedGlow(_ledGlowSliderValue, _ledColor == Colors.orange);
    print('Glow Level: ${_ledGlowSliderValue * 100}%');
  }

  @override
  Widget build(BuildContext context) {
    final bleManager = Provider.of<BleManager>(context);
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
            backgroundColor: Colors.blueAccent,
            title: const Text(
              'SleepSanity Device Test',
              style: TextStyle(color: Colors.white, fontSize: 19),
            ),
            ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromRGBO(50, 18, 122, 1.0),
                Color(0xFF0D1241),
                Color(0xFF0D1241),
              ],
              stops: [0.0, 0.66, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Transform.scale(
                  scale: 1.6,
                  child: const Image(
                    image: AssetImage('assets/images/Device.png'),
                    height: 250,
                  ),
                ),
                const SizedBox(height: 20),
                // TextField to rename the device
                // Rest of the UI remains the same
                // Tint Control with Correct Mapping
                Container(
                  width: 360,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(224, 228, 240, 1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Darkness level',
                        style: TextStyle(fontSize: 20, color: Colors.black87),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${(_tintSliderValue * 100).toInt()}%',
                        style: const TextStyle(fontSize: 20, color: Colors.black87),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _tintSliderValue = (_tintSliderValue - 0.1).clamp(0.0, 1.0);
                              });
                              bleManager.updateTintLevel(_tintSliderValue);
                              print('Tint Level: ${_tintSliderValue * 100}%');
                            },
                            child: Image.asset(
                              'assets/images/slider2.png',
                              height: 27,
                              width: 27,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 35,
                                activeTrackColor: Color.fromRGBO(50, 18, 122, 1.0),
                                thumbColor: Colors.white,
                                overlayColor: Colors.white.withOpacity(0.3),
                                valueIndicatorColor: Colors.blue,
                                inactiveTrackColor: Colors.grey,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 20,
                                ),
                              ),
                              child: Slider(
                                value: _tintSliderValue,
                                onChanged: (newValue) {
                                  setState(() {
                                    _tintSliderValue = newValue;
                                  });
                                  bleManager.updateTintLevel(_tintSliderValue);
                                  print('Tint Level: ${_tintSliderValue * 100}%');
                                },
                                min: 0,
                                max: 1,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _tintSliderValue = (_tintSliderValue + 0.1).clamp(0.0, 1.0);
                              });
                              bleManager.updateTintLevel(_tintSliderValue);
                              print('Tint Level: ${_tintSliderValue * 100}%');
                            },
                            child: Image.asset(
                              'assets/images/slider.png',
                              height: 27,
                              width: 27,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(20),
                  width: 360,
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(224, 228, 240, 1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Glow',
                        style: TextStyle(fontSize: 20, color: Colors.black87),
                      ),

                      const SizedBox(height: 10),
                      Transform.scale(
                        scale: 1.2,
                        child: Switch(
                          value: _isLedGlowSwitched,
                          onChanged: (value) {
                            setState(() {
                              _isLedGlowSwitched = value;
                              if (_isLedGlowSwitched) {
                                _ledColor = Colors.orange;
                                _borderColor1 = Colors.orange;
                                _borderColor2 = Colors.transparent;
                                _updateLedGlow(bleManager, 0.5); // Reset to 50% brightness
                              } else {
                                _ledColor = Colors.transparent;
                                _borderColor1 = Colors.transparent;
                                _borderColor2 = Colors.transparent;
                                bleManager.toggleLed(false);  // Turn off LED
                                bleManager.sendBleCommand('5c0601000000000000');
                                _ledGlowSliderValue=0;
                              }
                            });
                          },
                          activeColor: Colors.white,
                          activeTrackColor: _ledColor,
                          //inactiveThumbColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${(_ledGlowSliderValue * 100).toInt()}%',
                        style: const TextStyle(fontSize: 20, color: Colors.black87),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: GestureDetector(
                              onTap: _isLedGlowSwitched
                                  ? () {
                                setState(() {
                                  _ledColor = Colors.orange;
                                  _borderColor1 = Colors.orange;
                                  _borderColor2 = Colors.transparent;
                                });
                                bleManager.updateLedGlow(1.0, true);  // Orange light
                                bleManager.sendBleCommand('5c0601000000000000'); // Turn off blue light
                              }
                                  : null,
                              child: Container(
                                padding: EdgeInsets.only(top: 13.0),
                                height: 150,
                                width: 150,
                                margin: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _borderColor1,
                                    width: 3,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Center(
                                      child: Image.asset(
                                        'assets/images/Sunset.png',
                                        height: 90,
                                        width: 90,
                                      ),
                                    ),
                                    SizedBox(height: 8.0,),
                                    const Text('Orange'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Flexible(
                            child: GestureDetector(
                              onTap: _isLedGlowSwitched
                                  ? () {
                                setState(() {
                                  _ledColor = Colors.blue;
                                  _borderColor1 = Colors.transparent;
                                  _borderColor2 = Colors.blue;
                                });
                                bleManager.updateLedGlow(1.0, false);  // Blue light
                                bleManager.sendBleCommand('5c0701000000000000'); //Orange off
                              }
                                  : null,
                              child: Container(
                                height: 150,
                                width: 150,
                                margin: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _borderColor2,
                                    width: 3,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    const Center(
                                      child: Icon(Icons.circle, color: Colors.blueAccent, size: 110),
                                    ),
                                    const Text('Blue'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: _isLedGlowSwitched
                                ? () {
                              _updateLedGlow(bleManager, _ledGlowSliderValue - 0.05);
                            }
                                : null,  // Disable slider if LED glow is off
                            child: Image.asset('assets/images/slider2.png', height: 27, width: 27),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 40,
                                activeTrackColor: _isLedGlowSwitched ? _ledColor : Colors.grey,  // Disable if off
                                thumbColor: Colors.white,
                                overlayColor: _ledColor.withOpacity(0.2),
                                valueIndicatorColor: _ledColor,
                                inactiveTrackColor: Colors.grey,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 20,
                                ),
                              ),
                              child: Slider(
                                value: _ledGlowSliderValue,
                                onChanged: _isLedGlowSwitched
                                    ? (newValue) {
                                  _updateLedGlow(bleManager, newValue);
                                }
                                    : null,
                                min: 0,
                                max: 1,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _isLedGlowSwitched
                                ? () {
                              _updateLedGlow(bleManager, _ledGlowSliderValue + 0.05);
                            }
                                : null,  // Disable slider if LED glow is off
                            child: Image.asset('assets/images/slider.png', height: 30, width: 30),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (Provider.of<BleManager>(context).isConnecting)
                  const Center(
                    child: CircularProgressIndicator(), // Show progress indicator while connecting
                  ),
                if (_deviceName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.circle, color: Colors.green, size: 12),
                          const SizedBox(width: 8),
                          Text(
                            "Connected to $_deviceName",
                            style: const TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.circle, color: Colors.red, size: 12),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: (){
                              _retryCount = 0; // Reset retry count
                              _checkBLEConnection();
                            },
                            child: const Text(
                              "Not connected, Tap to retry",
                              style: TextStyle(fontSize: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }

}