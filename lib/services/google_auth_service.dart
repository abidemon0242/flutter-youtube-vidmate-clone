import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService extends ChangeNotifier {
  bool _initialized = false;
  bool _busy = false;
  String? _configurationError;
  String? _lastError;

  bool get isConfigured => _initialized;
  bool get isBusy => _busy;
  String? get configurationError => _configurationError;
  String? get lastError => _lastError;
  User? get currentUser => _initialized ? FirebaseAuth.instance.currentUser : null;

  void _clearLastError() {
    _lastError = null;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      // The Web OAuth client ID is required on Android to request an ID token
      // for Firebase credential exchange. CI injects it from google-services.json.
      const serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
      await GoogleSignIn.instance.initialize(
        serverClientId: serverClientId.isEmpty ? null : serverClientId,
      );
      // Firebase Auth restores its persisted user session automatically.
      _initialized = true;
      _configurationError = null;
      _lastError = null;
    } catch (error, stackTrace) {
      _configurationError =
          'Google sign-in could not be initialized. Check Firebase configuration, '
          'the OAuth client ID, and the APK signing SHA-1/SHA-256.';
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
    _clearLastError();
    notifyListeners();
    try {
      // Start Google Credential Manager only after the user explicitly taps sign-in.
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Google did not return an ID token. Check the Firebase OAuth configuration.');
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await FirebaseAuth.instance.signInWithCredential(credential);
      _lastError = null;
    } on GoogleSignInException catch (error) {
      final message = mapGoogleSignInError(error);
      _lastError = message;
      // Re-throw as a StateError with the mapped message so callers can display it.
      // Cancellation is preserved as a distinct case — not every cancellation is
      // a SHA-1 fingerprint problem.
      if (error.code == GoogleSignInExceptionCode.canceled) {
        final description = error.description?.toLowerCase() ?? '';
        if (!(description.contains('account reauth failed') || description.contains('[16]'))) {
          _lastError = 'Sign-in was cancelled.';
        }
      }
      throw StateError(_lastError!);
    } on FirebaseAuthException catch (error) {
      final message = mapFirebaseAuthError(error);
      _lastError = message;
      throw StateError(message);
    } catch (error) {
      final message = 'Google sign-in failed: $error';
      _lastError = message;
      throw StateError(message);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @visibleForTesting
  static String mapFirebaseAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-disabled':
        return 'This account has been disabled. Contact support for assistance.';
      case 'user-not-found':
        return 'No account found for this credential.';
      case 'invalid-credential':
        return 'The authentication credential is invalid or has expired. Please try again.';
      case 'operation-not-allowed':
        return 'Google sign-in is not enabled in Firebase. Contact the app administrator.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      case 'network-request-failed':
        return 'Network error during authentication. Check your connection and try again.';
      case 'too-many-requests':
        return 'Too many sign-in attempts. Please wait and try again.';
      case 'invalid-verification-code':
        return 'Invalid verification code. Please try again.';
      case 'invalid-verification-id':
        return 'Invalid verification ID. Please try again.';
      case 'credential-already-in-use':
        return 'This credential is already associated with a different account.';
      case 'requires-recent-login':
        return 'This operation requires recent authentication. Please sign in again.';
      default:
        return 'Firebase authentication failed (${error.code}): ${error.message ?? 'unknown error'}';
    }
  }

  @visibleForTesting
  static bool isAccountReauthFailure(GoogleSignInException error) => _isAccountReauthFailure(error);

  static bool _isAccountReauthFailure(GoogleSignInException error) {
    final description = error.description?.toLowerCase() ?? '';
    return error.code == GoogleSignInExceptionCode.canceled &&
        (description.contains('account reauth failed') || description.contains('[16]'));
  }

  @visibleForTesting
  static String mapGoogleSignInError(GoogleSignInException error) {
    if (_isAccountReauthFailure(error)) {
      return 'Google account authentication was rejected (error [16]). Check that the Google account '
          'can complete Google security prompts, and verify the Android package name, Web OAuth client, '
          'and SHA-1 fingerprint for this exact APK in Firebase.';
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
    _clearLastError();
    notifyListeners();
    try {
      try {
        await GoogleSignIn.instance.signOut();
      } finally {
        await FirebaseAuth.instance.signOut();
      }
    } catch (error) {
      _lastError = 'Sign-out failed: $error';
      throw StateError(_lastError!);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
