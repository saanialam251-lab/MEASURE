import 'package:flutter/material.dart';
import 'ui/theme.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/measure_screen.dart';
import 'ui/screens/history_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/widgets/pop.dart';

class MeasureRealityApp extends StatelessWidget {
  const MeasureRealityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Measure Reality',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.1)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      initialRoute: '/',
      onGenerateRoute: (s) {
        switch (s.name) {
          case '/measure':
            return fadeSlide(const MeasureScreen());
          case '/history':
            return fadeSlide(const HistoryScreen());
          case '/settings':
            return fadeSlide(const SettingsScreen());
          default:
            return fadeSlide(const HomeScreen());
        }
      },
    );
  }
}
