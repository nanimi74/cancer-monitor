import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/home_shell.dart';

class CancerMonitorApp extends StatelessWidget {
  const CancerMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '항암기록관리',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomeShell(),
    );
  }
}
