import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'package:tube_arena/services/google_auth_service.dart';
import 'package:tube_arena/ui/screens/onboarding_screen.dart';

class FakeGoogleAuthService extends GoogleAuthService {
  bool configured = true;
  bool busy = false;
  String? error;
  int signInCalls = 0;
  int emailLinkCalls = 0;
  String? requestedEmail;
  Future<void> Function()? onSignIn;

  @override
  Future<void> sendEmailSignInLink(String email) async {
    emailLinkCalls++;
    requestedEmail = email;
  }

  @override
  bool get isConfigured => configured;

  @override
  bool get isGoogleConfigured => true;

  @override
  bool get isBusy => busy;

  @override
  String? get configurationError => error;

  @override
  Future<void> signIn() async {
    signInCalls++;
    await onSignIn?.call();
  }
}

Widget createTestApp(FakeGoogleAuthService auth) {
  return ChangeNotifierProvider<GoogleAuthService>.value(
    value: auth,
    child: const MaterialApp(home: AppEntryScreen()),
  );
}

void main() {
  group('Authentication flow', () {
    late FakeGoogleAuthService auth;

    setUp(() {
      auth = FakeGoogleAuthService();
    });

    testWidgets('shows Google sign-in entry when signed out', (tester) async {
      await tester.pumpWidget(createTestApp(auth));

      expect(find.text('Welcome to Tube Arena'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Send login link'), findsOneWidget);
    });

    testWidgets('starts sign-in when the button is tapped', (tester) async {
      await tester.pumpWidget(createTestApp(auth));

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      expect(auth.signInCalls, 1);
    });

    testWidgets('requests an email and sends a login link', (tester) async {
      await tester.pumpWidget(createTestApp(auth));

      await tester.tap(find.text('Send login link'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'student@example.com');
      await tester.tap(find.text('Send link'));
      await tester.pumpAndSettle();

      expect(auth.emailLinkCalls, 1);
      expect(auth.requestedEmail, 'student@example.com');
      expect(find.textContaining('Sign-in link sent to student@example.com'), findsOneWidget);
    });

    testWidgets('rejects an invalid email before requesting a link', (tester) async {
      await tester.pumpWidget(createTestApp(auth));

      await tester.tap(find.text('Send login link'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'not-an-email');
      await tester.tap(find.text('Send link'));
      await tester.pumpAndSettle();

      expect(auth.emailLinkCalls, 0);
      expect(find.text('Enter a valid email address.'), findsOneWidget);
    });

    testWidgets('shows configuration error and disables sign-in', (tester) async {
      auth.configured = false;
      auth.error = 'Google sign-in setup is required.';

      await tester.pumpWidget(createTestApp(auth));

      expect(find.text('Google sign-in setup is required.'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('disables sign-in while authentication is busy', (tester) async {
      auth.busy = true;

      await tester.pumpWidget(createTestApp(auth));

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(find.text('Signing in…'), findsOneWidget);
    });

    testWidgets('shows a recoverable error when sign-in fails', (tester) async {
      auth.onSignIn = () async => throw StateError('Network unavailable');

      await tester.pumpWidget(createTestApp(auth));
      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Google sign-in failed:'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
    });
  });
}
