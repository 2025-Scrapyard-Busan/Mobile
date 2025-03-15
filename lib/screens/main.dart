import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:light_sensor/light_sensor.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';

class MainScreen extends StatefulWidget {
  static const route = '/';
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  NoiseReading? _latestReading;
  NoiseMeter? noiseMeter;
  int? _lux;
  bool _isShaking = false; // 흔들기 감지 상태maxDecibel
  StreamSubscription<NoiseReading>? _noiseSubscription;
  StreamSubscription? _lightSubscription;
  StreamSubscription? _accelerometerSubscription;

  Future<bool> checkPermission() async => await Permission.microphone.isGranted;

  @override
  void initState() {
    super.initState();
    startNoiseReading();
    startLuxListening();
    startShakeDetection();
  }

  @override
  void dispose() {
    _noiseSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    _lightSubscription?.cancel();
    super.dispose();
  }

  void onData(NoiseReading noiseReading) =>
      setState(() => _latestReading = noiseReading);

  void onError(Object error) {
    print(error);
    stopNoiseReading();
  }

  Future<void> startNoiseReading() async {
    noiseMeter ??= NoiseMeter();
    if (!(await checkPermission())) await requestPermission();

    _noiseSubscription = noiseMeter?.noise.listen(onData, onError: onError);
  }

  void startLuxListening() {
    _lightSubscription = LightSensor.luxStream().listen((luxValue) {
      setState(() {
        _lux = luxValue;
      });
    });
  }

  void startShakeDetection() {
    const double shakeThreshold = 30.0;
    _accelerometerSubscription = accelerometerEventStream().listen((
      AccelerometerEvent event,
    ) {
      double acceleration = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

      if (acceleration > shakeThreshold) {
        setState(() {
          _isShaking = true;
        });

        Future.delayed(Duration(seconds: 1), () {
          setState(() {
            _isShaking = false;
          });
        });
      }
    });
  }

  Future<void> requestPermission() async =>
      await Permission.microphone.request();

  void stopNoiseReading() {
    _noiseSubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Text('Noise: ${_latestReading?.meanDecibel.toStringAsFixed(2)} dB'),
            Text('Lux : $_lux lux'),
            Text(_isShaking ? 'Shaking' : "Shake it"),
          ],
        ),
      ),
    );
  }
}
