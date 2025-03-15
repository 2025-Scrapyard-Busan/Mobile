import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:light_sensor/light_sensor.dart';
import 'package:mobile/constants/language.dart';
import 'package:mobile/screens/start.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:http/http.dart' as http;

enum AlarmStatus {
  sleeping,
  weakSound,
  strongSound,
  shake,
  weakLight,
  strongLight,
  complete,
}

class MainScreen extends StatefulWidget {
  static const route = '/main';
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  NoiseMeter? noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  StreamSubscription? _lightSubscription;
  StreamSubscription? _accelerometerSubscription;
  AlarmStatus _alarmStatus = AlarmStatus.sleeping;
  String? _message;
  int _milliseconds = 0;
  late Timer _timer;
  int _score = 0;
  final int _maxScore = 600;
  String? userName;
  bool _isContinue = false;
  double _luxSum = 0.0;
  double _accelerationSum = 0.0;
  double _decibelSum = 0.0;

  Future<bool> checkPermission() async => await Permission.microphone.isGranted;

  @override
  void initState() {
    super.initState();
    startNoiseReading();
    startLuxListening();
    startShakeDetection();
    _timer = Timer.periodic(Duration(milliseconds: 1), (timer) {
      setState(() {
        _milliseconds++;
        if (_milliseconds >= 60000) {
          // 60초 == 60000ms
          stopAllListening();
          print('실패');
        }
      });
    });
  }

  @override
  void dispose() {
    _noiseSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    _lightSubscription?.cancel();
    _timer.cancel();
    super.dispose();
  }

  void updateScore(int points, AlarmStatus status) {
    setState(() {
      // 점수를 업데이트
      _score += points;

      // 상태에 따라 알람 상태 변경
      if (_score >= _maxScore) {
        _alarmStatus = AlarmStatus.complete;
        _score = _maxScore;
        showCompleteDialog();
        stopAllListening(); // 팝업이 뜰 때 리스너 멈추기
      } else {
        // 상태가 변경되지 않아도 메시지 업데이트
        _alarmStatus = status;
        _isContinue = true;

        // 상태에 따라 _message 설정
        switch (_alarmStatus) {
          case AlarmStatus.weakSound:
            _message = "무슨 소리야... 시끄럽게...므믐ㅁ";
            break;
          case AlarmStatus.strongSound:
            _message = "으아ㅏㅏㅏ!!!!!!! 아니 누가 소리를 지르는데??";
            break;
          case AlarmStatus.shake:
            _message = "으아ㅏ 세상이 흔들리고 있어..!!";
            break;
          case AlarmStatus.weakLight:
            _message = "불 좀 꺼봐... 잠 좀 자자..";
            break;
          case AlarmStatus.strongLight:
            _message = "으아앙앙ㅇ아앙앙ㅇ 더 자고 싶은데 너무 밝아 ㅠㅠ";
            break;
          default:
            break;
        }

        // 상태를 감지하는 타이머
        Timer.periodic(Duration(seconds: 1), (timer) {
          if (!_isContinue) {
            _alarmStatus = AlarmStatus.sleeping;
            _isContinue = false; // 상태 초기화
            setState(() {}); // 상태 변경을 UI에 반영
            timer.cancel(); // 타이머 종료
          } else {
            _isContinue = false; // 감지 중이 아니면 다시 false로 설정
          }
        });
      }
    });
  }

  void showCompleteDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TextEditingController nameController = TextEditingController();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "$_milliseconds ms",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text("랭킹에 결과를 올리겠습니까?", style: TextStyle(fontSize: 18)),
                  SizedBox(height: 15),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: "이름을 적어주세요.",
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            double luxPercentage = (_luxSum / _score) * 100;
                            double decibelPercentage =
                                (_decibelSum / _score) * 100;
                            double accelerationPercentage =
                                (_accelerationSum / _score) * 100;

                            var url = Uri.http(
                              'api.yunjisang.me:8080',
                              "/api/rankings",
                            );

                            await http.post(
                              url,
                              headers: {"Content-Type": "application/json"},
                              body: jsonEncode({
                                'nickname': nameController.value.text,
                                'clearTime': _milliseconds,
                                'shining':
                                    luxPercentage >= 100 ? 100 : luxPercentage,
                                'shouting':
                                    decibelPercentage >= 100
                                        ? 100
                                        : decibelPercentage,
                                'shaking':
                                    accelerationPercentage >= 100
                                        ? 100
                                        : accelerationPercentage,
                              }),
                            );

                            if (context.mounted) {
                              Navigator.of(context).pop();
                              Navigator.pushNamed(context, StartScreen.route);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Text("Yes"),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.pushNamed(context, StartScreen.route);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[400],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Text("No"),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  void onError(Object error) {
    print(error);
    stopAllListening();
  }

  Future<void> startNoiseReading() async {
    noiseMeter ??= NoiseMeter();
    if (!(await checkPermission())) await requestPermission();

    _noiseSubscription = noiseMeter?.noise.listen((NoiseReading noiseReading) {
      setState(() {
        if (noiseReading.meanDecibel >= 85 && noiseReading.meanDecibel < 110) {
          updateScore(2, AlarmStatus.weakSound);
          _decibelSum += 2;
        } else if (noiseReading.meanDecibel >= 110) {
          updateScore(5, AlarmStatus.strongSound);
          _decibelSum += 5;
        }
      });
    }, onError: onError);
  }

  void startLuxListening() {
    _lightSubscription = LightSensor.luxStream().listen((luxValue) {
      setState(() {
        if (luxValue >= 600 && luxValue < 900) {
          updateScore(3, AlarmStatus.weakLight);
          _luxSum += 3;
        } else if (luxValue >= 900) {
          updateScore(6, AlarmStatus.strongLight);
          _luxSum += 6;
        }
      });
    });
  }

  void startShakeDetection() {
    const double shakeThreshold = 80.0;
    _accelerometerSubscription = accelerometerEventStream().listen((
      AccelerometerEvent event,
    ) {
      double acceleration = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

      if (acceleration > shakeThreshold) {
        updateScore(7, AlarmStatus.shake);
        _accelerationSum += 7;
      }
    });
  }

  Future<void> requestPermission() async =>
      await Permission.microphone.request();

  void stopAllListening() {
    _noiseSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    _lightSubscription?.cancel();
    _timer.cancel();
  }

  @override
  Widget build(BuildContext context) {
    String imagePath;
    Language language = ModalRoute.of(context)?.settings.arguments as Language;

    switch (_alarmStatus) {
      case AlarmStatus.sleeping:
        imagePath = "assets/images/sleep.png";
        _message = null;
        break;
      case AlarmStatus.weakSound:
        imagePath = "assets/images/weak_sound.png";
        _message =
            language == Language.korean
                ? "무슨 소리야... 시끄럽게...므믐ㅁ"
                : "What is that sound... It's so noisy...";
        break;
      case AlarmStatus.strongSound:
        imagePath = "assets/images/strong_sound.png";
        _message =
            language == Language.korean
                ? "으아ㅏㅏㅏ!!!!!!! 아니 누가 소리를 지르는데??"
                : "Aaahhh!!! Who is shouting like that??";
        break;
      case AlarmStatus.shake:
        imagePath = "assets/images/shake.png";
        _message =
            language == Language.korean
                ? "으아ㅏ 세상이 흔들리고 있어..!!"
                : "Aahh, the world is shaking..!!";
        break;
      case AlarmStatus.weakLight:
        imagePath = "assets/images/weak_light.png";
        _message =
            language == Language.korean
                ? "불 좀 꺼봐... 잠 좀 자자.."
                : "Turn off the light... I want to sleep...";
        break;
      case AlarmStatus.strongLight:
        imagePath = "assets/images/strong_light.png";
        _message =
            language == Language.korean
                ? "으아앙앙ㅇ아앙앙ㅇ 더 자고 싶은데 너무 밝아 ㅠㅠ"
                : "Aaaah, I want to sleep more but it's too bright ㅠㅠ";
        break;
      case AlarmStatus.complete:
        imagePath = "assets/images/complete.png";
        _message = null;
        break;
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_message != null) ...[
              SizedBox(height: 10),
              Container(
                width: 340,
                height: 120,
                padding: EdgeInsets.all(10),
                margin: EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Color(0xffD9D9D9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Flex(
                  direction: Axis.vertical,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _message!,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
            if (_message == null) ...[SizedBox(height: 120)],
            SizedBox(height: 10),
            Image.asset(imagePath, height: 340, width: 340),
          ],
        ),
      ),
    );
  }
}
