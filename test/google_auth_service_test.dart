import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tube_arena/services/google_auth_service.dart';

void main() {
  group('GoogleAuthService.mapGoogleSignInError', () {
    test('maps Account reauth failed to a SHA-1 registration message', () {
      final error = GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: '[16] Account reauth failed.',
      );
      final message = GoogleAuthService.mapGoogleSignInError(error);
      expect(message, contains('signing certificate is not registered'));
      expect(message, contains('SHA-1'));
      expect(message, contains('Account reauth failed'));
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
      // Should NOT contain SHA-1 message since this is a normal cancellation
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

  group('GoogleAuthService error handling logic', () {
    test('cancellation without Account reauth is preserved as cancellation', () {
      // Verify that a normal cancellation doesn't get misreported as SHA issue
      final error = GoogleSignInException(code: GoogleSignInExceptionCode.canceled, description: 'User cancelled');
      final message = GoogleAuthService.mapGoogleSignInError(error);
      expect(message, isNot(contains('SHA-1')));
      expect(message, isNot(contains('signing certificate')));
    });

    test('Account reauth failed is correctly identified as SHA issue', () {
      final error = GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: '[16] Account reauth failed.',
      );
      final message = GoogleAuthService.mapGoogleSignInError(error);
      expect(message, contains('SHA-1'));
      expect(message, contains('signing certificate is not registered'));
    });

    test('case-insensitive matching for account reauth failed', () {
      final error = GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: 'ACCOUNT REAUTH FAILED',
      );
      final message = GoogleAuthService.mapGoogleSignInError(error);
      expect(message, contains('SHA-1'));
    });
  });
}
