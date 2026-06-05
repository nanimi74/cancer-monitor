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
  Future<AuthSession> signInWithEmail() {
    throw const AuthFailure('이메일 로그인은 이메일 입력 화면에서 연결됩니다.');
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
    final userCredential = await _firebaseAuth.signInWithCredential(credential);
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
    final userCredential =
        await _firebaseAuth.signInWithCredential(oauthCredential);
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
}
