import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Optional Google authentication for Tube Arena.
///
/// The app remains usable when Firebase is not configured. To enable sign-in,
/// add the Firebase Android configuration described in
/// docs/GOOGLE_SIGN_IN_SETUP.md.
class GoogleAuthService extends ChangeNotifier {
  bool _initialized = false;
  bool _busy = false;
  String? _configurationError;

  bool get isConfigured => _initialized;
  bool get isBusy => _busy;
  String? get configurationError => _configurationError;
  User? get currentUser =>
      _initialized ? FirebaseAuth.instance.currentUser : null;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      await GoogleSignIn.instance.initialize();
      _initialized = true;
      _configurationError = null;
    } catch (error, stackTrace) {
      _configurationError =
          'Google sign-in is not configured yet. Add the Firebase Android configuration and enable Google as a sign-in provider.';
      debugPrint('Google authentication initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    notifyListeners();
  }

  Future<void> signIn() async {
    if (!_initialized) {
      throw StateError(
        _configurationError ?? 'Google sign-in is not configured.',
      );
    }
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError(
          'Google did not return an ID token. Check the Firebase OAuth configuration.',
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
      await GoogleSignIn.instance.signOut();
      await FirebaseAuth.instance.signOut();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
