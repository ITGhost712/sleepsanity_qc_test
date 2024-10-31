import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/material.dart';

class BleManager with ChangeNotifier {
  BluetoothDevice? connectedDevice;
  List<BluetoothDevice> scannedDevices = [];
  bool isScanning = false;
  bool isDeviceFound = false;
  bool noDeviceFound = false;
  bool isConnecting = false;
  bool renameDialogShown = false;
  bool isCharacteristicDiscovered = false; // New flag to track discovery of characteristic
  String? deviceName;
  Timer? _reconnectTimer;
  bool isReconnecting = false; // Flag to track reconnection status

  static final BleManager _instance = BleManager._internal();
  factory BleManager() => _instance;

  BleManager._internal();

  //final String UUID_SERVICE = "0000FEE0-0000-1000-8000-00805F9B34FB";

  //final String UUID_CHAR_WRITE = "0000FEE1-0000-1000-8000-00805F9B34FB";
 // final String UUID_CHAR_NOTIFY = "0000FEE2-0000-1000-8000-00805F9B34FB";
  // Update these with the correct UUIDs from nRF Connect
  final String UUID_SERVICE = "FEE0";  // Primary Service UUID
  final String UUID_CHAR_WRITE = "FEE1";  // Write Without Response Characteristic UUID
  final String UUID_CHAR_NOTIFY = "FEE2";  // Notify Characteristic UUID


  BluetoothCharacteristic? _writeCharacteristic;
  bool isLedOn = false;

  BluetoothCharacteristic? get writeCharacteristic => _writeCharacteristic;

  void startScan() async {
    isScanning = true;
    isDeviceFound = false;
    noDeviceFound = false;
    scannedDevices.clear();
    renameDialogShown = false;
    notifyListeners();

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult result in results) {
        final deviceName = result.device.name;
        if (deviceName.isNotEmpty && deviceName.toLowerCase().contains("ssanity")) {
          if (!scannedDevices.contains(result.device)) {
            scannedDevices.add(result.device);
          }
          if (!isDeviceFound) {
            isDeviceFound = true;
            isScanning = false;
            FlutterBluePlus.stopScan();
            notifyListeners();
            await connectToDevice(result.device);
          }
        }
      }
    });

    await Future.delayed(const Duration(seconds: 3));
    if (!isDeviceFound) {
      noDeviceFound = true;
      isScanning = false;
      notifyListeners();
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    connectedDevice = device;
    isConnecting = true;
    await connectedDevice!.connect();
    notifyListeners();

    //await connectedDevice!.connect();
    // Listen to connection state changes
    device.connectionState.listen((event) {
      if (event == BluetoothConnectionState.disconnected) {
        _handleDisconnection(); // Call handle disconnection when the device is disconnected
      }
    });

    // Discover services and characteristics
    List<BluetoothService> services = await connectedDevice!.discoverServices();
    print("Discovered ${services.length} services");

    for (BluetoothService service in services) {
      print('Service UUID: ${service.uuid}');
      if (service.uuid.toString().toUpperCase() == UUID_SERVICE) {
        // Try to find the write characteristic
        final characteristic = service.characteristics.firstWhere(
              (c) => c.uuid.toString().toUpperCase() == UUID_CHAR_WRITE,
          //orElse: () => null,
        );

        if (characteristic != null) {
          _writeCharacteristic = characteristic;
          isCharacteristicDiscovered = true;
          print('Write Characteristic found');
        } else {
          print('Write Characteristic not found');
        }

        // Enable notifications if needed
        final notifyCharacteristic = service.characteristics.firstWhere(
              (c) => c.uuid.toString().toUpperCase() == UUID_CHAR_NOTIFY,
          //orElse: () => null,
        );

        if (notifyCharacteristic != null) {
          await notifyCharacteristic.setNotifyValue(true);
          print('Notify characteristic subscribed');
        }

        notifyListeners();
        break;
      }
    }

    isConnecting = false;
    notifyListeners();
  }

  void _startReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      try {
        // Await connectedDevices future and retrieve the list of connected devices
        //List<BluetoothDevice> devices = await FlutterBluePlus.instance.connectedDevices;
        if (connectedDevice != null && FlutterBluePlus.connectedDevices.contains(connectedDevice)) {
          connectToDevice(connectedDevice!);
        }
      } catch (e) {
        print("Error retrieving connected devices: $e");
      }
    });
  }

  void _listenToConnectionState() {
    connectedDevice?.state.listen((state) {
      if (state == BluetoothDeviceState.disconnected) {
        print("Device disconnected");
        _attemptReconnect();
      } else if (state == BluetoothDeviceState.connected) {
        print("Device connected");
        isReconnecting = false;
        notifyListeners(); // Notify UI to update
      }
    });
  }


  // Attempt reconnection if the device is disconnected
  void _attemptReconnect() {
    isReconnecting = true;
    notifyListeners(); // Notify UI to show loader or reconnecting state

    _reconnectTimer = Timer.periodic(Duration(seconds: 4), (timer) async {
      print("Attempting to reconnect...");
      List<BluetoothDevice> devices = await FlutterBluePlus.connectedDevices;

      if (connectedDevice != null && FlutterBluePlus.connectedDevices.contains(connectedDevice)) {
        await connectToDevice(connectedDevice!); // Reconnect to the device
        isReconnecting = false;
        timer.cancel(); // Stop reconnection attempts once reconnected
      }
    });
  }

  // Stop reconnecting and clean up resources
  void stopReconnect() {
    _reconnectTimer?.cancel();
    isReconnecting = false;
    notifyListeners();
  }


  Future<void> sendBleCommand(String command) async {
    if (_writeCharacteristic == null) {
      print('Write characteristic not available');
      return;
    }

    var buffer = Uint8List.fromList(command.codeUnits);
    await _writeCharacteristic!.write(buffer, withoutResponse: true);
    print('Command sent: $command');
  }


  Future<void> toggleLed(bool isOn) async {
    String command = isOn ? '5c0701500000000000' : '5c0701000000000000';
    await sendBleCommand(command);
  }

  void updateLedGlow(double glowValue, bool isSunset) {
    int brightness = (glowValue * 99).toInt();
    String brightnessHex = brightness.toRadixString(16).padLeft(2, '0');
    String command = isSunset ? '5c0701${brightnessHex}0000000000' : '5c0601${brightnessHex}0000000000';
    sendBleCommand(command);
  }

  void updateTintLevel(double tintValue) {
    int tint = (tintValue * 99).toInt();
    String tintHex = tint.toRadixString(16).padLeft(2, '0');
    String command = '5c0401${tintHex}0000000000';
    sendBleCommand(command);
  }

  void updateVolumeLevel(double volumeValue) {
    int volume = (volumeValue * 100).toInt();
    String volumeHex = volume.toRadixString(16).padLeft(2, '0');
    String command = '5c0101${volumeHex}0000000000';
    sendBleCommand(command);
  }
  void updateZeroVolumeLevel() {
    //int volume = (volumeValue * 100).toInt();
    //String volumeHex = volume.toRadixString(16).padLeft(2, '0');
    String command = '5c0201000000000000';
    sendBleCommand(command);
  }

  void setLedColor(Color color) {
    bool isSunset = (color == Colors.orange);
    updateLedGlow(1.0, isSunset);
  }

  // In BleManager class
  void _handleDisconnection() {
    connectedDevice = null;
    notifyListeners(); // Notify listeners that the device has disconnected
  }

}
