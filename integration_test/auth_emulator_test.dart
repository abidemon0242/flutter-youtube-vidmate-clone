import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tube_arena/services/google_auth_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Firebase Auth SDK completes Google credential and email-link sign-in', (tester) async {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'fake-api-key',
        appId: '1:123456789:android:abcdef0123456789',
        messagingSenderId: '123456789',
        projectId: 'demo-tube-arena',
      ),
    );

    final firebaseAuth = FirebaseAuth.instance;
    await firebaseAuth.useAuthEmulator('10.0.2.2', 9099);
    await firebaseAuth.signOut();

    final service = GoogleAuthService(
      googleIdTokenProvider: () async => jsonEncode({
        'sub': 'tube-arena-google-emulator-user',
        'email': 'google-emulator@example.test',
        'email_verified': true,
      }),
    );
    await service.initialize();
    expect(service.isConfigured, isTrue);

    // Exercise the same GoogleAuthProvider.credential -> signInWithCredential
    // exchange used in production, with an emulator-only mock ID token.
    await service.signIn();
    expect(service.currentUser?.email, 'google-emulator@example.test');
    await firebaseAuth.signOut();

    // Exercise the actual FlutterFire SDK calls used by the app for email links.
    const email = 'flutter-auth-emulator@example.test';
    await service.sendEmailSignInLink(email);

    final client = HttpClient();
    late Map<String, dynamic> emulatorResponse;
    try {
      final request = await client.getUrl(
        Uri.parse('http://10.0.2.2:9099/emulator/v1/projects/demo-tube-arena/oobCodes'),
      );
      final response = await request.close();
      expect(response.statusCode, HttpStatus.ok);
      emulatorResponse = jsonDecode(await response.transform(utf8.decoder).join()) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }

    final codes = (emulatorResponse['oobCodes'] as List<dynamic>).cast<Map<String, dynamic>>();
    final matchingCode = codes.lastWhere(
      (entry) => entry['email'] == email && entry['requestType'] == 'EMAIL_SIGNIN',
    );
    final code = matchingCode['oobCode'] as String;
    final emailLink = Uri.https(
      'tube-arena-261114-106732.firebaseapp.com',
      '/__/auth/links',
      {
        'mode': 'signIn',
        'oobCode': code,
        'apiKey': 'fake-api-key',
      },
    );

    expect(firebaseAuth.isSignInWithEmailLink(emailLink.toString()), isTrue);
    await service.completeEmailSignInLink(emailLink.toString());
    expect(service.currentUser?.email, email);
    await firebaseAuth.signOut();
  }, timeout: const Timeout(Duration(minutes: 3)));
}
