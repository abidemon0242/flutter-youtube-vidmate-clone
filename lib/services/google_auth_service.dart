import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService extends ChangeNotifier {
  static const _serverClientId =
      '1097230695627-dtdgldj4sifdld7bfjg3qm3bb20d6fc7.apps.googleusercontent.com';

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
      await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
      // Restore a previous Google session silently when possible so Firebase
      // can re-establish the authenticated user without an interactive prompt.
      try {
        final account = await GoogleSignIn.instance
            .attemptLightweightAuthentication();
        if (account != null) {
          final idToken = account.authentication.idToken;
          if (idToken != null &&
              idToken.isNotEmpty &&
              FirebaseAuth.instance.currentUser == null) {
            final credential = GoogleAuthProvider.credential(idToken: idToken);
            await FirebaseAuth.instance.signInWithCredential(credential);
          }
        }
      } catch (e) {
        debugPrint('Lightweight authentication skipped: $e');
      }
      _initialized = true;
      _configurationError = null;
    } catch (error, stackTrace) {
      _configurationError =
          'Google sign-in could not be initialized. Check Firebase configuration, the OAuth client, '
          'and the registered signing certificate.';
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
      // Do not sign out before every sign-in attempt. Credential Manager
      // should handle the account selection/authentication flow directly.
      // GoogleSignIn.signOut() is called by the explicit signOut() action.
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError(
          'Google did not return an ID token. Check the OAuth client ID and Firebase Google provider configuration.',
        );
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await FirebaseAuth.instance.signInWithCredential(credential);
    } on GoogleSignInException catch (error) {
      throw StateError(mapGoogleSignInError(error));
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Maps Credential Manager / GoogleSignIn failures to actionable messages.
  ///
  /// The Android Credential Manager often returns a "canceled" exception with
  /// the description "[16] Account reauth failed" for configuration problems
  /// (most commonly a SHA-1 fingerprint that is not registered for the
  /// package name in the Firebase / Google Cloud OAuth Android client).
  /// The plugin cannot distinguish this from a real user cancellation.
  @visibleForTesting
  static String mapGoogleSignInError(GoogleSignInException error) {
    final description = error.description?.toLowerCase() ?? '';
    if (error.code == GoogleSignInExceptionCode.canceled &&
        (description.contains('account reauth failed') ||
            description.contains('[16]'))) {
      return 'Google sign-in failed because the app signing certificate is not registered '
          'with the Firebase Android OAuth client (error [16] Account reauth failed). '
          'Add the SHA-1 (and SHA-256) fingerprint of the exact APK you installed '
          '(debug keystore, CI keystore, or release keystore) in Firebase Project Settings '
          '→ Your apps → Android, then download a fresh google-services.json and rebuild.';
    }
    if (error.code == GoogleSignInExceptionCode.clientConfigurationError ||
        error.code == GoogleSignInExceptionCode.providerConfigurationError) {
      return 'Google sign-in is misconfigured: ${error.description ?? error.code.name}. '
          'Verify the web OAuth client ID, package name, and registered SHA fingerprints.';
    }
    return 'Google sign-in failed (${error.code.name}): ${error.description ?? 'unknown error'}';
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
