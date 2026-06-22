import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
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
  static const _googleIosClientId =
      '210055151747-ap0ac39o8mjog7akg6vitfcse9sjvbtg.apps.googleusercontent.com';
  static const _googleServerClientId =
      '210055151747-2a166q7h53om9deb7ri5rtktqths62u4.apps.googleusercontent.com';

  @override
  Future<AuthSession?> currentSession() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    return _sessionFromUser(user);
  }

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

    final rawNonce = _generateNonce();
    final hashedNonce = _sha256ofString(rawNonce);

    final AuthorizationCredentialAppleID appleCredential;
    try {
      appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const [AppleIDAuthorizationScopes.email],
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      throw AuthFailure(_appleAuthorizationMessage(error));
    } catch (_) {
      throw const AuthFailure('Apple 로그인 중 문제가 발생했습니다.');
    }

    final idToken = appleCredential.identityToken;
    if (idToken == null) {
      throw const AuthFailure('Apple 로그인 토큰을 확인할 수 없습니다.');
    }

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: idToken,
      rawNonce: rawNonce,
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

  @override
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Google 로그인이 아니면 별도 처리 없이 Firebase 세션만 종료합니다.
    }
    await _firebaseAuth.signOut();
  }

  @override
  Future<void> deleteAccount() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AuthFailure('로그인 정보를 확인할 수 없습니다.');
    }

    try {
      await user.delete();
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // Google 로그인이 아니면 별도 처리 없이 넘어갑니다.
      }
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_deleteAccountMessage(error));
    }
  }

  Future<void> _initializeGoogleSignIn() async {
    if (_googleInitialized) {
      return;
    }
    await _googleSignIn.initialize(
      clientId: defaultTargetPlatform == TargetPlatform.iOS
          ? _googleIosClientId
          : null,
      serverClientId: _googleServerClientId,
    );
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
    return _sessionFromUser(user,
        provider: provider, fallbackEmail: fallbackEmail);
  }

  AuthSession _sessionFromUser(
    User user, {
    AuthProvider? provider,
    String? fallbackEmail,
  }) {
    return AuthSession(
      provider: provider ?? _providerFromUser(user),
      isPreview: false,
      email: user.email ?? fallbackEmail,
      userId: user.uid,
    );
  }

  AuthProvider _providerFromUser(User user) {
    final providerIds = user.providerData.map((info) => info.providerId);
    if (providerIds.contains('apple.com')) return AuthProvider.apple;
    if (providerIds.contains('google.com')) return AuthProvider.google;
    return AuthProvider.email;
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
      'missing-or-invalid-nonce' => 'Apple 로그인 보안값을 확인할 수 없습니다. 다시 시도해 주세요.',
      'network-request-failed' => '네트워크 연결을 확인해 주세요.',
      _ => '$providerLabel 로그인 중 문제가 발생했습니다.',
    };
  }

  String _appleAuthorizationMessage(
      SignInWithAppleAuthorizationException error) {
    return switch (error.code) {
      AuthorizationErrorCode.canceled => 'Apple 로그인이 취소되었습니다.',
      AuthorizationErrorCode.failed => 'Apple 로그인 승인 중 문제가 발생했습니다.',
      AuthorizationErrorCode.invalidResponse => 'Apple 로그인 응답을 확인할 수 없습니다.',
      AuthorizationErrorCode.notHandled => 'Apple 로그인 요청이 완료되지 않았습니다.',
      AuthorizationErrorCode.notInteractive =>
        '현재 상태에서는 Apple 로그인을 진행할 수 없습니다.',
      AuthorizationErrorCode.credentialExport => 'Apple 로그인 정보를 가져올 수 없습니다.',
      AuthorizationErrorCode.credentialImport => 'Apple 로그인 정보를 불러올 수 없습니다.',
      AuthorizationErrorCode.unknown => 'Apple 로그인 중 문제가 발생했습니다.',
      _ => 'Apple 로그인 중 문제가 발생했습니다.',
    };
  }

  String _deleteAccountMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'requires-recent-login' => '보안을 위해 다시 로그인한 뒤 회원탈퇴를 진행해 주세요.',
      'network-request-failed' => '네트워크 연결을 확인해 주세요.',
      _ => '회원탈퇴 처리 중 문제가 발생했습니다.',
    };
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
