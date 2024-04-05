import 'dart:async'; // Импортируем dart:async библиотеку
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Color(0xFF0B0C10), // Устанавливаем цвет фона
      ),
      home: FindDevicesScreen(),
    );
  }
}

class FindDevicesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Поиск устройств'),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            FlutterBlue.instance.startScan(timeout: Duration(seconds: 4)),
        child: StreamBuilder<List<ScanResult>>(
          stream: FlutterBlue.instance.scanResults,
          initialData: [],
          builder: (c, snapshot) {
            final devices = snapshot.data!.where(
                (result) => result.device.name == 'Yandex Delivery Robot');

            return ListView.builder(
              itemCount: devices.length,
              itemBuilder: (c, index) {
                final device = devices.elementAt(index);
                return ListTile(
                  title: Center(
                    child: Container(
                      width: 364,
                      height: 156,
                      decoration: BoxDecoration(
                        color: Color(0xFF1F2833),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          device.device.name,
                          style:
                              TextStyle(color: Color(0xFFC5C6C7), fontSize: 30),
                        ),
                      ),
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => YandexDeliveryRobotDeviceScreen(
                          device: device.device),
                    ));
                  },
                );
              },
            );
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
              backgroundColor: Color(0xFF45A29E),
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
  bool toggleState = true; // Переменная для отслеживания состояния кнопки

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

  Future<void> disconnectDevice() async {
    try {
      await widget.device.disconnect();
      setState(() {
        isDeviceConnected = false;
      });
    } catch (e) {
      print("Error disconnecting from device: $e");
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
    } catch (e) {
      print("Error sending command: $e");
    }
  }

  Widget controlButton(IconData icon, int command) {
    return Listener(
      onPointerDown: (_) => sendCommand(command),
      onPointerUp: (_) =>
          sendCommand(0), // Предположим, 0 - это команда остановки
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 50),
      ),
    );
  }

  // Метод для переключения состояния и отправки команды
  void toggleCommand() {
    int command = toggleState ? 3 : 6;
    sendCommand(command);
    setState(() {
      toggleState = !toggleState; // Переключаем состояние
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Управление Yandex Delivery Robot'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                controlButton(Icons.arrow_left, 0x01),
                controlButton(Icons.arrow_upward, 0x05),
                controlButton(Icons.arrow_right, 0x02),
              ],
            ),
            SizedBox(height: 20),
            controlButton(Icons.arrow_downward, 0x04),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => toggleCommand(),
              child: Text(toggleState ? 'Отправить 3' : 'Отправить 6'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: isDeviceConnected ? disconnectDevice : null,
              child: Text('Отключиться от устройства'),
            ),
          ],
        ),
      ),
    );
  }
}
