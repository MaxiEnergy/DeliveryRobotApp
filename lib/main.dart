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
                GestureDetector(
                  onLongPress: () => sendCommand(0x03), // Начать вращение влево
                  onLongPressUp: () => sendCommand(0x00), // Остановить вращение
                  child: FloatingActionButton(
                    onPressed:
                        () {}, // Обработчик нажатия нужен, но не используется
                    child: Icon(Icons.arrow_left),
                  ),
                ),
                GestureDetector(
                  onLongPress: () =>
                      sendCommand(0x03), // Начать вращение вперед
                  onLongPressUp: () => sendCommand(0x00), // Остановить вращение
                  child: FloatingActionButton(
                    onPressed:
                        () {}, // Обработчик нажатия нужен, но не используется
                    child: Icon(Icons.arrow_upward),
                  ),
                ),
                GestureDetector(
                  onLongPress: () =>
                      sendCommand(0x03), // Начать вращение вправо
                  onLongPressUp: () => sendCommand(0x00), // Остановить вращение
                  child: FloatingActionButton(
                    onPressed:
                        () {}, // Обработчик нажатия нужен, но не используется
                    child: Icon(Icons.arrow_right),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            GestureDetector(
              onLongPress: () => sendCommand(0x03), // Начать вращение назад
              onLongPressUp: () => sendCommand(0x00), // Остановить вращение
              child: FloatingActionButton(
                onPressed:
                    () {}, // Обработчик нажатия нужен, но не используется
                child: Icon(Icons.arrow_downward),
              ),
            ),
            SizedBox(height: 40),
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
