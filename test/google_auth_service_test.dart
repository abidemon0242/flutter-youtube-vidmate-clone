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
  });
}
