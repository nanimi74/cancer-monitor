import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  AuthProvider? _loadingProvider;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _signIn(AuthProvider provider) async {
    setState(() {
      _loadingProvider = provider;
      _errorMessage = null;
    });
    try {
      final session = switch (provider) {
        AuthProvider.email => await widget.authService.signInWithEmail(
            email: _emailController.text,
            password: _passwordController.text,
          ),
        AuthProvider.apple => await widget.authService.signInWithApple(),
        AuthProvider.google => await widget.authService.signInWithGoogle(),
      };
      if (!mounted) return;
      setState(() => _loadingProvider = null);
      widget.onSignedIn(session);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingProvider = null;
        _errorMessage =
            error is AuthFailure ? error.message : '로그인 중 문제가 발생했습니다.';
      });
    }
  }

  void _showSoftKeyboard(FocusNode focusNode) {
    focusNode.requestFocus();
    Future<void>.delayed(const Duration(milliseconds: 40), () {
      if (!mounted || !focusNode.hasFocus) return;
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    });
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
                      TextField(
                        controller: _emailController,
                        focusNode: _emailFocusNode,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const [AutofillHints.email],
                        onTap: () => _showSoftKeyboard(_emailFocusNode),
                        onSubmitted: (_) =>
                            _showSoftKeyboard(_passwordFocusNode),
                        decoration: const InputDecoration(
                          hintText: '이메일을 입력해 주세요.',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _passwordController,
                        focusNode: _passwordFocusNode,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onTap: () => _showSoftKeyboard(_passwordFocusNode),
                        onSubmitted: (_) => _signIn(AuthProvider.email),
                        decoration: const InputDecoration(
                          hintText: '비밀번호를 입력해 주세요.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ProviderButton(
                        label: '이메일로 로그인/가입',
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
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
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
