import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/home/entry_screen.dart';
import '../features/home/login_screen.dart';
import '../features/home_shell.dart';
import '../services/auth/auth_service.dart';

class CancerMonitorApp extends StatelessWidget {
  const CancerMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '항암기록관리',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AppStartFlow(),
    );
  }
}

class AppStartFlow extends StatefulWidget {
  const AppStartFlow({super.key});

  @override
  State<AppStartFlow> createState() => _AppStartFlowState();
}

class _AppStartFlowState extends State<AppStartFlow> {
  final AuthService _authService = const MockAuthService();
  _StartStage _stage = _StartStage.entry;
  AuthSession? _session;

  void _showLogin() {
    setState(() => _stage = _StartStage.login);
  }

  void _startPreview() {
    setState(() {
      _session = const AuthSession(
        provider: AuthProvider.email,
        isPreview: true,
      );
      _stage = _StartStage.shell;
    });
  }

  void _completeSignIn(AuthSession session) {
    setState(() {
      _session = session;
      _stage = _StartStage.shell;
    });
  }

  void _backToEntry() {
    setState(() => _stage = _StartStage.entry);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_stage) {
      _StartStage.entry => EntryScreen(
          onLogin: _showLogin,
          onPreview: _startPreview,
        ),
      _StartStage.login => LoginScreen(
          authService: _authService,
          onBack: _backToEntry,
          onSignedIn: _completeSignIn,
        ),
      _StartStage.shell => HomeShell(
          isPreview: _session?.isPreview ?? false,
          hasRequiredInfo: !(_session?.isPreview ?? false),
        ),
    };
  }
}

enum _StartStage {
  entry,
  login,
  shell,
}
