import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService extends ChangeNotifier {
  static const _serverClientId = '1097230695627-dtdgldj4sifdld7bfjg3qm3bb20d6fc7.apps.googleusercontent.com';

  bool _initialized = false;
  bool _busy = false;
  String? _configurationError;

  bool get isConfigured => _initialized;
  bool get isBusy => _busy;
  String? get configurationError => _configurationError;
  User? get currentUser => _initialized ? FirebaseAuth.instance.currentUser : null;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
      _initialized = true;
      _configurationError = null;
    } catch (error, stackTrace) {
      _configurationError =
          'Google sign-in could not be initialized. Check Firebase configuration, the OAuth client, and the registered signing certificate.';
      debugPrint('Google authentication initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    notifyListeners();
  }

  Future<void> signIn() async {
    if (!_initialized) {
      throw StateError(_configurationError ?? 'Google sign-in is not configured.');
    }
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError(
          'Google did not return an ID token. Check the OAuth client ID and Firebase Google provider configuration.',
        );
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await FirebaseAuth.instance.signInWithCredential(credential);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (!_initialized || _busy) return;
    _busy = true;
    notifyListeners();
    try {
      try {
        await GoogleSignIn.instance.signOut();
      } finally {
        await FirebaseAuth.instance.signOut();
      }
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
