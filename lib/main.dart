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
          centerTitle: true, // Центрирование заголовков
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
  }

  Future<void> requestPermissions() async {
    if (await Permission.bluetoothScan.request().isGranted &&
        await Permission.bluetoothConnect.request().isGranted &&
        await Permission.bluetooth.request().isGranted &&
        await Permission.locationWhenInUse.request().isGranted) {
      // Все разрешения предоставлены
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Разрешение на использование Bluetooth и местоположения не предоставлено'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Подключение'),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            FlutterBlue.instance.startScan(timeout: Duration(seconds: 4)),
        child: StreamBuilder<List<ScanResult>>(
          stream: FlutterBlue.instance.scanResults,
          initialData: [],
          builder: (c, snapshot) {
            final devices = snapshot.data!
                .where((result) => result.device.name == 'Yandex Delivery Robot');

            if (devices.isEmpty) {
              return Center(child: CircularProgressIndicator());
            } else {
              final device = devices.first;
              return Center(
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => YandexDeliveryRobotDeviceScreen(
                          device: device.device),
                    ));
                  },
                  child: Container(
                    width: 200,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        'Робот доставщик 001',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
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
              onPressed: () =>
                  FlutterBlue.instance.startScan(timeout: Duration(seconds: 4)),
            );
          }
        },
      ),
    );
  }
}

class YandexDeliveryRobotDeviceScreen extends StatefulWidget {
  final BluetoothDevice device;

  YandexDeliveryRobotDeviceScreen({required this.device});

  @override
  _YandexDeliveryRobotDeviceScreenState createState() =>
      _YandexDeliveryRobotDeviceScreenState();
}

class _YandexDeliveryRobotDeviceScreenState
    extends State<YandexDeliveryRobotDeviceScreen> {
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

  Future<void> sendCommand(int command) async {
    List<int> value = [command];
    try {
      List<BluetoothService> services = await widget.device.discoverServices();
      var targetService = services.firstWhere((service) =>
      service.uuid == Guid('0000170D-0000-1000-8000-00805f9b34fb'));
      var targetCharacteristic = targetService.characteristics.firstWhere(
              (characteristic) =>
          characteristic.uuid ==
              Guid('00002A60-0000-1000-8000-00805f9b34fb'));
      await targetCharacteristic.write(value);

      setState(() {
        switch (command) {
          case 0x01:
            begin = Alignment.centerLeft;
            end = Alignment.centerRight;
            gradientOpacity = 1.0;
            break;
          case 0x02:
            begin = Alignment.centerRight;
            end = Alignment.centerLeft;
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

    // Если отпустили кнопку, плавно убираем градиент
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
            border: Border.all(color: Color.fromRGBO(255, 53, 63, 1), width: 4)),
        child: Icon(icon, color: Color.fromRGBO(255, 53, 63, 1), size: 28),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Управление ровером'),
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
    );
  }
}
