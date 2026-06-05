enum AuthProvider {
  email,
  apple,
  google,
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthSession {
  const AuthSession({
    required this.provider,
    required this.isPreview,
    this.email,
    this.userId,
  });

  final AuthProvider provider;
  final bool isPreview;
  final String? email;
  final String? userId;
}

abstract class AuthService {
  Future<AuthSession> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AuthSession> signInWithApple();

  Future<AuthSession> signInWithGoogle();
}

class MockAuthService implements AuthService {
  const MockAuthService();

  @override
  Future<AuthSession> signInWithEmail({
    required String email,
    required String password,
  }) =>
      _mockSignIn(AuthProvider.email, email: email);

  @override
  Future<AuthSession> signInWithApple() => _mockSignIn(AuthProvider.apple);

  @override
  Future<AuthSession> signInWithGoogle() => _mockSignIn(AuthProvider.google);

  Future<AuthSession> _mockSignIn(
    AuthProvider provider, {
    String? email,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 280));
    return AuthSession(
      provider: provider,
      isPreview: false,
      email:
          provider == AuthProvider.email ? email ?? 'user@example.com' : null,
    );
  }
}
