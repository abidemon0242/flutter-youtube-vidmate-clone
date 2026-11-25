import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:tube_arena/services/google_auth_service.dart';
import 'package:tube_arena/app.dart';

// Generate mocks
@GenerateMocks([GoogleAuthService, User])
import 'login_screen_test.mocks.dart';

void main() {
  group('Login Screen Tests', () {
    late MockGoogleAuthService mockGoogleAuth;
    late MockUser mockUser;

    setUp(() {
      mockGoogleAuth = MockGoogleAuthService();
      mockUser = MockUser();

      when(mockGoogleAuth.isConfigured).thenReturn(true);
      when(mockGoogleAuth.isBusy).thenReturn(false);
      when(mockGoogleAuth.currentUser).thenReturn(null);
      when(mockGoogleAuth.configurationError).thenReturn(null);

      when(mockUser.displayName).thenReturn('Test User');
      when(mockUser.email).thenReturn('test@example.com');
      when(mockUser.photoURL).thenReturn(null);
      when(mockUser.uid).thenReturn('test-uid');
    });

    Widget createTestApp({required bool isSignedIn}) {
      if (isSignedIn) {
        when(mockGoogleAuth.currentUser).thenReturn(mockUser);
      } else {
        when(mockGoogleAuth.currentUser).thenReturn(null);
      }

      return MaterialApp(
        home: ChangeNotifierProvider<GoogleAuthService>.value(
          value: mockGoogleAuth,
          child: const SettingsScreen(),
        ),
      );
    }

    testWidgets('Shows sign in button when signed out', (tester) async {
      await tester.pumpWidget(createTestApp(isSignedIn: false));
      await tester.pumpAndSettle();

      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Not signed in'), findsOneWidget);
    });

    testWidgets('Shows user info and sign out when signed in', (tester) async {
      await tester.pumpWidget(createTestApp(isSignedIn: true));
      await tester.pumpAndSettle();

      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('Shows busy state during sign in', (tester) async {
      when(mockGoogleAuth.isBusy).thenReturn(true);

      await tester.pumpWidget(createTestApp(isSignedIn: false));
      await tester.pumpAndSettle();

      expect(find.text('Please wait…'), findsOneWidget);
    });

    testWidgets('Shows configuration error when Firebase not configured', (tester) async {
      when(mockGoogleAuth.isConfigured).thenReturn(false);
      when(mockGoogleAuth.configurationError).thenReturn('Google sign-in setup is required.');

      await tester.pumpWidget(createTestApp(isSignedIn: false));
      await tester.pumpAndSettle();

      expect(find.text('Google sign-in setup is required.'), findsOneWidget);
      expect(find.text('Sign in'), findsNothing);
    });

    testWidgets('Sign in button triggers signIn method', (tester) async {
      await tester.pumpWidget(createTestApp(isSignedIn: false));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in'));
      await tester.pump();

      verify(mockGoogleAuth.signIn()).called(1);
    });

    testWidgets('Sign out button triggers signOut method', (tester) async {
      await tester.pumpWidget(createTestApp(isSignedIn: true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign out'));
      await tester.pump();

      verify(mockGoogleAuth.signOut()).called(1);
    });

    testWidgets('Displays user avatar when photoURL is available', (tester) async {
      when(mockUser.photoURL).thenReturn('https://example.com/avatar.jpg');

      await tester.pumpWidget(createTestApp(isSignedIn: true));
      await tester.pumpAndSettle();

      // Should show CircleAvatar with network image
      expect(find.byType(CircleAvatar), findsOneWidget);
    });

    testWidgets('Displays placeholder avatar when photoURL is null', (tester) async {
      when(mockUser.photoURL).thenReturn(null);

      await tester.pumpWidget(createTestApp(isSignedIn: true));
      await tester.pumpAndSettle();

      // Should show CircleAvatar with icon
      final circleAvatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(circleAvatar.child, isA<Icon>());
    });
  });
}
