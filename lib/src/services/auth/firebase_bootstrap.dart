import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import '../../../firebase_options.dart';
import 'auth_service.dart';
import 'firebase_auth_service.dart';

class FirebaseBootstrap {
  const FirebaseBootstrap();

  Future<AuthService> buildAuthService() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleAppAttestProvider(),
      );
      return FirebaseAuthService();
    } catch (error, stackTrace) {
      debugPrint('$error');
      debugPrintStack(stackTrace: stackTrace);
      if (!kDebugMode) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      debugPrint('Firebase is not configured yet. Using MockAuthService.');
      return const MockAuthService();
    }
  }
}
