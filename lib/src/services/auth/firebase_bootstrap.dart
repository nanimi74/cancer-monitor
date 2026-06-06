import 'package:firebase_core/firebase_core.dart';
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
      return FirebaseAuthService();
    } catch (error, stackTrace) {
      debugPrint('Firebase is not configured yet. Using MockAuthService.');
      debugPrint('$error');
      debugPrintStack(stackTrace: stackTrace);
      return const MockAuthService();
    }
  }
}
