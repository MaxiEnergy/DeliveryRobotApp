import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color.fromARGB(255, 255, 255, 255),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.white,
          foregroundColor: Color.fromRGBO(255, 53, 63, 1),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            primary: Colors.white,
            onPrimary: Color.fromRGBO(255, 53, 63, 1),
            shadowColor: Colors.grey,
            elevation: 4,
          ),
        ),
        appBarTheme: AppBarTheme(
          color: Color.fromRGBO(255, 53, 63, 1),
          centerTitle: true,
          foregroundColor: Colors.white,
        ),
      ),
      home: FindDevicesScreen(),
    );
  }
}

class FindDevicesScreen extends StatefulWidget {
  @override
  _FindDevicesScreenState createState() => _FindDevicesScreenState();
}

class _FindDevicesScreenState extends State<FindDevicesScreen> {
  @override
  void initState() {
    super.initState();
    requestPermissions();
    startDeviceScan();
  }

  Future<void> requestPermissions() async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.bluetooth.request();
  }

  void startDeviceScan() {
    FlutterBlue.instance.startScan(timeout: Duration(seconds: 4));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Подключение'),
      ),
      body: RefreshIndicator(
        onRefresh: () {
          return FlutterBlue.instance.startScan(timeout: Duration(seconds: 4));
        },
        child: StreamBuilder<List<ScanResult>>(
          stream: FlutterBlue.instance.scanResults,
          initialData: [],
          builder: (c, snapshot) {
            final devices = snapshot.data!.where((result) {
              return result.device.name.startsWith('Rover Toy ') &&
                  RegExp(r'^Rover Toy \d{3}$').hasMatch(result.device.name);
            }).toList();

            if (devices.isEmpty) {
              return Center(child: CircularProgressIndicator());
            } else {
              return Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: devices.map((device) {
                      final roverNumber =
                      int.parse(device.device.name.split(' ')[2]);
                      final formattedNumber =
                      roverNumber.toString().padLeft(3, '0');
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) => RoverDeviceScreen(
                                device: device.device,
                                roverNumber: roverNumber,
                              ),
                            ));
                          },
                          child: Container(
                            width: 200,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.5),
                                  spreadRadius: 3,
                                  blurRadius: 5,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                'Ровер $formattedNumber',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Color.fromRGBO(255, 53, 63, 1),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );
            }
          },
        ),
      ),
      floatingActionButton: StreamBuilder<bool>(
        stream: FlutterBlue.instance.isScanning,
        initialData: false,
        builder: (c, snapshot) {
          if (snapshot.data!) {
            return FloatingActionButton(
              child: Icon(Icons.stop),
              onPressed: () => FlutterBlue.instance.stopScan(),
            );
          } else {
            return FloatingActionButton(
              child: Icon(Icons.search),
              onPressed: () {
                FlutterBlue.instance.startScan(timeout: Duration(seconds: 4));
              },
            );
          }
        },
      ),
    );
  }
}

class RoverDeviceScreen extends StatefulWidget {
  final BluetoothDevice device;
  final int roverNumber;

  RoverDeviceScreen({required this.device, required this.roverNumber});

  @override
  _RoverDeviceScreenState createState() => _RoverDeviceScreenState();
}

class _RoverDeviceScreenState extends State<RoverDeviceScreen> {
  bool isDeviceConnected = false;
  bool toggleState = true;
  Alignment begin = Alignment.bottomCenter;
  Alignment end = Alignment.topCenter;
  double gradientOpacity = 1.0;

  @override
  void initState() {
    super.initState();
    connectToDevice();
  }

  @override
  void dispose() {
    disconnectFromDevice(); // Отключаемся от устройства при выходе
    super.dispose();
  }

  Future<void> connectToDevice() async {
    try {
      await widget.device.connect();
      setState(() {
        isDeviceConnected = true;
      });
    } catch (e) {
      print("Error connecting to device: $e");
    }
  }

  Future<void> disconnectFromDevice() async {
    try {
      await widget.device.disconnect();
      setState(() {
        isDeviceConnected = false;
      });
    } catch (e) {
      print("Error disconnecting from device: $e");
    }
  }

  Future<bool> onWillPop() async {
    await disconnectFromDevice();
    return true;
  }

  Future<void> sendCommand(int command) async {
    List<int> value = [command];
    try {
      List<BluetoothService> services = await widget.device.discoverServices();
      var targetService = services.firstWhere((service) =>
      service.uuid ==
          Guid(
              '0000170D-${widget.roverNumber.toString().padLeft(4, '0')}-1000-8000-00805f9b34fb'));
      var targetCharacteristic = targetService.characteristics.firstWhere(
              (characteristic) =>
          characteristic.uuid ==
              Guid(
                  '00002A60-${widget.roverNumber.toString().padLeft(4, '0')}-1000-8000-00805f9b34fb'));
      await targetCharacteristic.write(value);

      setState(() {
        switch (command) {
          case 0x01:
            begin = Alignment.centerRight;
            end = Alignment.centerLeft;
            gradientOpacity = 1.0;
            break;
          case 0x02:
            begin = Alignment.centerLeft;
            end = Alignment.centerRight;
            gradientOpacity = 1.0;
            break;
          case 0x05:
            begin = Alignment.bottomCenter;
            end = Alignment.topCenter;
            gradientOpacity = 1.0;
            break;
          case 0x04:
            begin = Alignment.topCenter;
            end = Alignment.bottomCenter;
            gradientOpacity = 1.0;
            break;
          default:
            begin = Alignment.center;
            end = Alignment.center;
            gradientOpacity = 0.0;
            break;
        }
      });
    } catch (e) {
      print("Error sending command: $e");
    }

    if (command == 0) {
      Future.delayed(Duration(milliseconds: 100), () {
        setState(() {
          gradientOpacity = 0.0;
          begin = Alignment.center;
          end = Alignment.center;
        });
      });
    }
  }

  void animateLightEffect() {
    setState(() {
      gradientOpacity = 0.5;
      begin = Alignment.center;
      end = Alignment.topRight;
    });

    Future.delayed(Duration(milliseconds: 500), () {
      setState(() {
        gradientOpacity = 0.0;
        begin = Alignment.center;
        end = Alignment.center;
      });
    });
  }

  Widget controlButton(IconData icon, int command, String tooltip) {
    return Listener(
      onPointerDown: (_) => sendCommand(command),
      onPointerUp: (_) => sendCommand(0),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border:
            Border.all(color: Color.fromRGBO(255, 53, 63, 1), width: 4)),
        child: Icon(icon, color: Color.fromRGBO(255, 53, 63, 1), size: 28),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedNumber = widget.roverNumber.toString().padLeft(3, '0');
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Управление ровером $formattedNumber'),
        ),
        body: Stack(
          children: [
            Center(
              child: AnimatedContainer(
                duration: Duration(milliseconds: 800),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: begin,
                    end: end,
                    colors: [
                      Color.fromRGBO(255, 53, 63, gradientOpacity * 0.5),
                      Color.fromRGBO(255, 53, 63, gradientOpacity * 0.1),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              right: 20,
              child: FloatingActionButton(
                onPressed: () {
                  animateLightEffect();
                  toggleState = !toggleState;
                  sendCommand(toggleState ? 3 : 6);
                },
                child: Icon(
                  toggleState ? Icons.lightbulb_outline : Icons.lightbulb,
                  color: Color.fromRGBO(255, 53, 63, 1),
                ),
                backgroundColor: Colors.white,
              ),
            ),
            Positioned(
              bottom: 160,
              left: 80,
              child: controlButton(Icons.arrow_back, 0x02, "Right"),
            ),
            Positioned(
              bottom: 160,
              right: 80,
              child: controlButton(Icons.arrow_forward, 0x01, "Left"),
            ),
            Positioned(
              bottom: 240,
              left: MediaQuery.of(context).size.width / 2 - 28,
              child: controlButton(Icons.arrow_upward, 0x04, "Forward"),
            ),
            Positioned(
              bottom: 80,
              left: MediaQuery.of(context).size.width / 2 - 28,
              child: controlButton(Icons.arrow_downward, 0x05, "Backward"),
            ),
          ],
        ),
      ),
    );
  }
}
