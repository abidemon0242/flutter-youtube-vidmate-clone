import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'package:tube_arena/services/google_auth_service.dart';
import 'package:tube_arena/ui/screens/onboarding_screen.dart';

class LoginTestAuthService extends GoogleAuthService {
  bool configured = true;
  bool busy = false;
  String? error;
  int signInCalls = 0;
  int emailLinkCalls = 0;

  @override
  Future<void> sendEmailSignInLink(String email) async {
    emailLinkCalls++;
  }

  @override
  bool get isConfigured => configured;

  @override
  bool get isBusy => busy;

  @override
  String? get configurationError => error;

  @override
  Future<void> signIn() async {
    signInCalls++;
  }
}

void main() {
  group('Login screen', () {
    late LoginTestAuthService auth;

    setUp(() {
      auth = LoginTestAuthService();
    });

    Widget buildScreen() => ChangeNotifierProvider<GoogleAuthService>.value(
      value: auth,
      child: const MaterialApp(home: AppEntryScreen()),
    );

    testWidgets('renders the app welcome and Google sign-in action', (tester) async {
      await tester.pumpWidget(buildScreen());

      expect(find.text('Welcome to Tube Arena'), findsOneWidget);
      expect(find.textContaining('Sign in to continue'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Send login link'), findsOneWidget);
    });

    testWidgets('calls the authentication service from the sign-in action', (tester) async {
      await tester.pumpWidget(buildScreen());

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      expect(auth.signInCalls, 1);
    });

    testWidgets('does not allow sign-in when configuration is unavailable', (tester) async {
      auth.configured = false;
      auth.error = 'Firebase configuration is unavailable.';

      await tester.pumpWidget(buildScreen());

      expect(find.text('Firebase configuration is unavailable.'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    });

    testWidgets('shows progress while authentication is busy', (tester) async {
      auth.busy = true;

      await tester.pumpWidget(buildScreen());

      expect(find.text('Signing in…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
