import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tube_arena/services/google_auth_service.dart';

void main() {
  group('GoogleAuthService.mapGoogleSignInError', () {
    test('maps Account reauth failed without assuming a certificate mismatch', () {
      final error = GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: '[16] Account reauth failed.',
      );
      final message = GoogleAuthService.mapGoogleSignInError(error);
      expect(message, contains('stale Google sign-in state or an APK signing certificate'));
      expect(message, contains('SHA-1'));
      expect(message, contains('reauthentication failed'));
    });

    test('maps client configuration errors clearly', () {
      final error = GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
        description: 'serverClientId must be provided on Android',
      );
      final message = GoogleAuthService.mapGoogleSignInError(error);
      expect(message, contains('misconfigured'));
      expect(message, contains('serverClientId'));
    });

    test('falls back to a generic message for other codes', () {
      final error = GoogleSignInException(code: GoogleSignInExceptionCode.unknownError, description: 'something else');
      final message = GoogleAuthService.mapGoogleSignInError(error);
      expect(message, contains('unknownError'));
      expect(message, contains('something else'));
    });

    test('maps canceled without Account reauth failed as generic cancellation', () {
      final error = GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: 'User cancelled the sign-in flow',
      );
      final message = GoogleAuthService.mapGoogleSignInError(error);
      expect(message, isNot(contains('signing certificate is not registered')));
      expect(message, contains('canceled'));
    });

    test('maps provider configuration errors clearly', () {
      final error = GoogleSignInException(
        code: GoogleSignInExceptionCode.providerConfigurationError,
        description: 'OAuth client not found',
      );
      final message = GoogleAuthService.mapGoogleSignInError(error);
      expect(message, contains('misconfigured'));
    });
  });

  group('GoogleAuthService.mapFirebaseAuthError', () {
    test('maps user-disabled error', () {
      final error = FirebaseAuthException(code: 'user-disabled');
      final message = GoogleAuthService.mapFirebaseAuthError(error);
      expect(message, contains('disabled'));
    });

    test('maps invalid-credential error', () {
      final error = FirebaseAuthException(code: 'invalid-credential');
      final message = GoogleAuthService.mapFirebaseAuthError(error);
      expect(message, contains('invalid or has expired'));
    });

    test('maps network-request-failed error', () {
      final error = FirebaseAuthException(code: 'network-request-failed');
      final message = GoogleAuthService.mapFirebaseAuthError(error);
      expect(message, contains('Network error'));
    });

    test('maps too-many-requests error', () {
      final error = FirebaseAuthException(code: 'too-many-requests');
      final message = GoogleAuthService.mapFirebaseAuthError(error);
      expect(message, contains('Too many sign-in attempts'));
    });

    test('maps requires-recent-login error', () {
      final error = FirebaseAuthException(code: 'requires-recent-login');
      final message = GoogleAuthService.mapFirebaseAuthError(error);
      expect(message, contains('recent authentication'));
    });

    test('falls back to generic message for unknown error codes', () {
      final error = FirebaseAuthException(code: 'unknown-error-code', message: 'Something went wrong');
      final message = GoogleAuthService.mapFirebaseAuthError(error);
      expect(message, contains('unknown-error-code'));
      expect(message, contains('Something went wrong'));
    });

    test('maps operation-not-allowed error', () {
      final error = FirebaseAuthException(code: 'operation-not-allowed');
      final message = GoogleAuthService.mapFirebaseAuthError(error);
      expect(message, contains('not enabled in Firebase'));
    });

    test('maps account-exists-with-different-credential error', () {
      final error = FirebaseAuthException(code: 'account-exists-with-different-credential');
      final message = GoogleAuthService.mapFirebaseAuthError(error);
      expect(message, contains('different sign-in method'));
    });
  });

  group('GoogleAuthService error handling logic', () {
    test('cancellation without Account reauth is preserved as cancellation', () {
      final error = GoogleSignInException(code: GoogleSignInExceptionCode.canceled, description: 'User cancelled');
      final message = GoogleAuthService.mapGoogleSignInError(error);
      expect(message, isNot(contains('SHA-1')));
      expect(message, isNot(contains('signing certificate')));
    });

    test('Account reauth failure is recognized for one-time session recovery', () {
      final error = GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: '[16] Account reauth failed.',
      );
      final message = GoogleAuthService.mapGoogleSignInError(error);
      expect(GoogleAuthService.isAccountReauthFailure(error), isTrue);
      expect(message, contains('SHA-1 fingerprint'));
    });

    test('case-insensitive matching for account reauth failed', () {
      final error = GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: 'ACCOUNT REAUTH FAILED',
      );
      final message = GoogleAuthService.mapGoogleSignInError(error);
      expect(GoogleAuthService.isAccountReauthFailure(error), isTrue);
    });
  });
}
