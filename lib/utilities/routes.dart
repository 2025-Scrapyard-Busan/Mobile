import 'package:flutter/material.dart';
import 'package:mobile/screens/index.dart';

class Routes {
  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    try {
      switch (routeSettings.name) {
        case MainScreen.route:
          return MaterialPageRoute(
            settings: routeSettings,
            builder: (_) => MainScreen(),
          );
        default:
          return errorRoute(routeSettings);
      }
    } catch (_) {
      return errorRoute(routeSettings);
    }
  }

  static Route<dynamic> errorRoute(RouteSettings routeSettings) {
    return MaterialPageRoute(
      settings: routeSettings,
      builder: (_) => ErrorScreen(),
    );
  }
}
