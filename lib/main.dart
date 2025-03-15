import 'package:mobile/utilities/index.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: "Pretendard"),
      onGenerateRoute: Routes.generateRoute,
      onUnknownRoute: Routes.errorRoute,
    );
  }
}
