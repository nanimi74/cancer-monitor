import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/auth/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.authService,
    required this.onBack,
    required this.onSignedIn,
  });

  final AuthService authService;
  final VoidCallback onBack;
  final ValueChanged<AuthSession> onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  AuthProvider? _loadingProvider;

  Future<void> _signIn(AuthProvider provider) async {
    setState(() => _loadingProvider = provider);
    final session = switch (provider) {
      AuthProvider.email => await widget.authService.signInWithEmail(),
      AuthProvider.apple => await widget.authService.signInWithApple(),
      AuthProvider.google => await widget.authService.signInWithGoogle(),
    };
    if (!mounted) return;
    setState(() => _loadingProvider = null);
    widget.onSignedIn(session);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton.outlined(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.chevron_left),
                    tooltip: '이전',
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '로그인',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '회원 전용 서비스입니다.\n비회원의 경우 가입 후 이용해주세요.',
                  style: TextStyle(color: AppColors.muted, height: 1.55),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x081F2937),
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _ProviderButton(
                        label: '이메일로 계속하기',
                        provider: AuthProvider.email,
                        loadingProvider: _loadingProvider,
                        primary: true,
                        onPressed: _signIn,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                '또는',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                      ),
                      _ProviderButton(
                        label: 'Apple로 계속하기',
                        provider: AuthProvider.apple,
                        loadingProvider: _loadingProvider,
                        onPressed: _signIn,
                      ),
                      const SizedBox(height: 10),
                      _ProviderButton(
                        label: 'Google로 계속하기',
                        provider: AuthProvider.google,
                        loadingProvider: _loadingProvider,
                        onPressed: _signIn,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '로그인하면 '),
                      TextSpan(
                        text: '서비스 이용약관',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: '과 '),
                      TextSpan(
                        text: '개인정보처리방침',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: '을 확인한 것으로 간주됩니다.\n'),
                      TextSpan(
                        text: 'AI 분석은 참고용이며 의학적 진단이나 치료 결정을 대체하지 않아요.',
                      ),
                    ],
                  ),
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.label,
    required this.provider,
    required this.loadingProvider,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final AuthProvider provider;
  final AuthProvider? loadingProvider;
  final ValueChanged<AuthProvider> onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final isLoading = loadingProvider == provider;
    final disabled = loadingProvider != null;
    final child = isLoading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label);

    if (primary) {
      return ElevatedButton(
        onPressed: disabled ? null : () => onPressed(provider),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentSoft,
          foregroundColor: AppColors.accent,
          disabledBackgroundColor: AppColors.accentSoft,
          disabledForegroundColor: AppColors.accent,
        ),
        child: child,
      );
    }

    return OutlinedButton(
      onPressed: disabled ? null : () => onPressed(provider),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      child: child,
    );
  }
}
