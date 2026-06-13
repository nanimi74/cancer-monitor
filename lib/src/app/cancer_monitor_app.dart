import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/home/entry_screen.dart';
import '../features/home/login_screen.dart';
import '../features/home_shell.dart';
import '../services/auth/auth_service.dart';
import '../services/auth/firebase_bootstrap.dart';

class CancerMonitorApp extends StatelessWidget {
  const CancerMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '항암기록관리',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scrollBehavior: const _CancerMonitorScrollBehavior(),
      home: const AppStartFlow(),
    );
  }
}

class _CancerMonitorScrollBehavior extends MaterialScrollBehavior {
  const _CancerMonitorScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const _SmoothClampingScrollPhysics();
  }
}

class _SmoothClampingScrollPhysics extends ClampingScrollPhysics {
  const _SmoothClampingScrollPhysics({super.parent});

  @override
  _SmoothClampingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _SmoothClampingScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }

    final tolerance = toleranceFor(position);
    final adjustedVelocity = velocity * 0.82;

    if (adjustedVelocity.abs() < tolerance.velocity) {
      return null;
    }
    if (adjustedVelocity > 0.0 && position.pixels >= position.maxScrollExtent) {
      return null;
    }
    if (adjustedVelocity < 0.0 && position.pixels <= position.minScrollExtent) {
      return null;
    }

    return ClampingScrollSimulation(
      position: position.pixels,
      velocity: adjustedVelocity,
      friction: 0.02,
      tolerance: tolerance,
    );
  }
}

class AppStartFlow extends StatefulWidget {
  const AppStartFlow({super.key});

  @override
  State<AppStartFlow> createState() => _AppStartFlowState();
}

class _AppStartFlowState extends State<AppStartFlow> {
  late final Future<AuthService> _authServiceFuture =
      const FirebaseBootstrap().buildAuthService();
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

  Future<void> _signOut(AuthService authService) async {
    await authService.signOut();
    if (!mounted) return;
    setState(() {
      _session = null;
      _stage = _StartStage.entry;
    });
  }

  Future<void> _deleteAccount(AuthService authService) async {
    await authService.deleteAccount();
    if (!mounted) return;
    setState(() {
      _session = null;
      _stage = _StartStage.entry;
    });
  }

  void _backToEntry() {
    setState(() {
      _session = null;
      _stage = _StartStage.entry;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthService>(
      future: _authServiceFuture,
      builder: (context, snapshot) {
        final authService = snapshot.data ?? const MockAuthService();
        return switch (_stage) {
          _StartStage.entry => EntryScreen(
              onLogin: _showLogin,
              onPreview: _startPreview,
            ),
          _StartStage.login => LoginScreen(
              authService: authService,
              onBack: _backToEntry,
              onSignedIn: _completeSignIn,
            ),
          _StartStage.shell => HomeShell(
              isPreview: _session?.isPreview ?? false,
              hasRequiredInfo: false,
              onExitPreview: _backToEntry,
              onSignOut: () => _signOut(authService),
              onDeleteAccount: () => _deleteAccount(authService),
            ),
        };
      },
    );
  }
}

enum _StartStage {
  entry,
  login,
  shell,
}
