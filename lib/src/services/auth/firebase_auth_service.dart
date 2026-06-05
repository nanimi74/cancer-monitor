import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'auth_service.dart';

class FirebaseAuthService implements AuthService {
  FirebaseAuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  var _googleInitialized = false;

  @override
  Future<AuthSession> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || password.isEmpty) {
      throw const AuthFailure('이메일과 비밀번호를 입력해 주세요.');
    }

    try {
      final created = await _firebaseAuth.createUserWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );
      return _sessionFromUserCredential(created, AuthProvider.email);
    } on FirebaseAuthException catch (error) {
      if (error.code != 'email-already-in-use') {
        throw AuthFailure(_emailAuthMessage(error));
      }
    }

    try {
      final signedIn = await _firebaseAuth.signInWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );
      return _sessionFromUserCredential(signedIn, AuthProvider.email);
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_emailAuthMessage(error));
    }
  }

  @override
  Future<AuthSession> signInWithGoogle() async {
    await _initializeGoogleSignIn();

    final account = await _googleSignIn.authenticate();
    final auth = account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      throw const AuthFailure('Google 로그인 토큰을 확인할 수 없습니다.');
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final userCredential = await _signInWithCredential(
      credential,
      providerLabel: 'Google',
    );
    return _sessionFromUserCredential(
      userCredential,
      AuthProvider.google,
      fallbackEmail: account.email,
    );
  }

  @override
  Future<AuthSession> signInWithApple() async {
    final available = await SignInWithApple.isAvailable();
    if (!available) {
      throw const AuthFailure('현재 기기에서 Apple 로그인을 사용할 수 없습니다.');
    }

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: const [AppleIDAuthorizationScopes.email],
    );
    final idToken = appleCredential.identityToken;
    if (idToken == null) {
      throw const AuthFailure('Apple 로그인 토큰을 확인할 수 없습니다.');
    }

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: idToken,
      accessToken: appleCredential.authorizationCode,
    );
    final userCredential = await _signInWithCredential(
      oauthCredential,
      providerLabel: 'Apple',
    );
    return _sessionFromUserCredential(
      userCredential,
      AuthProvider.apple,
      fallbackEmail: appleCredential.email,
    );
  }

  Future<void> _initializeGoogleSignIn() async {
    if (_googleInitialized) {
      return;
    }
    await _googleSignIn.initialize();
    _googleInitialized = true;
  }

  AuthSession _sessionFromUserCredential(
    UserCredential credential,
    AuthProvider provider, {
    String? fallbackEmail,
  }) {
    final user = credential.user;
    if (user == null) {
      throw const AuthFailure('로그인 사용자 정보를 확인할 수 없습니다.');
    }
    return AuthSession(
      provider: provider,
      isPreview: false,
      email: user.email ?? fallbackEmail,
      userId: user.uid,
    );
  }

  Future<UserCredential> _signInWithCredential(
    AuthCredential credential, {
    required String providerLabel,
  }) async {
    try {
      return await _firebaseAuth.signInWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_oauthAuthMessage(error, providerLabel));
    }
  }

  String _emailAuthMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-email' => '이메일 형식을 확인해 주세요.',
      'weak-password' => '비밀번호는 6자 이상으로 입력해 주세요.',
      'wrong-password' || 'invalid-credential' => '이메일 또는 비밀번호를 확인해 주세요.',
      'too-many-requests' => '로그인 시도가 많습니다. 잠시 후 다시 시도해 주세요.',
      'operation-not-allowed' => 'Firebase 콘솔에서 이메일/비밀번호 로그인을 먼저 활성화해 주세요.',
      _ => '이메일 로그인 중 문제가 발생했습니다.',
    };
  }

  String _oauthAuthMessage(FirebaseAuthException error, String providerLabel) {
    return switch (error.code) {
      'operation-not-allowed' =>
        'Firebase 콘솔에서 $providerLabel 로그인을 먼저 활성화해 주세요.',
      'account-exists-with-different-credential' =>
        '이미 다른 로그인 방식으로 가입된 이메일입니다.',
      'invalid-credential' => '$providerLabel 로그인 정보를 확인할 수 없습니다.',
      'network-request-failed' => '네트워크 연결을 확인해 주세요.',
      _ => '$providerLabel 로그인 중 문제가 발생했습니다.',
    };
  }
}
