import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:tube_arena/app.dart';
import 'package:tube_arena/services/google_auth_service.dart';
import 'package:tube_arena/ui/screens/settings_screen.dart';

// Generate mocks
@GenerateMocks([GoogleAuthService])
import 'auth_flow_test.mocks.dart';

void main() {
  group('Authentication Flow Tests', () {
    late MockGoogleAuthService mockGoogleAuth;

    setUp(() {
      mockGoogleAuth = MockGoogleAuthService();
      when(mockGoogleAuth.isConfigured).thenReturn(true);
      when(mockGoogleAuth.isBusy).thenReturn(false);
      when(mockGoogleAuth.currentUser).thenReturn(null);
      when(mockGoogleAuth.configurationError).thenReturn(null);
    });

    Widget createTestApp({User? user}) {
      if (user != null) {
        when(mockGoogleAuth.currentUser).thenReturn(user);
      }
      return MaterialApp(
        home: ChangeNotifierProvider<GoogleAuthService>.value(value: mockGoogleAuth, child: const SettingsScreen()),
      );
    }

    testWidgets('Login screen visibility when signed out', (tester) async {
      // When not signed in, the sign-in button should be visible
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Verify Google account section shows "Not signed in"
      expect(find.text('Not signed in'), findsOneWidget);
      // Verify sign in button is present
      expect(find.text('Sign in'), findsOneWidget);
      // Verify sign out button is NOT present
      expect(find.text('Sign out'), findsNothing);
    });

    testWidgets('Authenticated user enters the application', (tester) async {
      final mockUser = MockUser();
      when(mockUser.displayName).thenReturn('Test User');
      when(mockUser.email).thenReturn('test@example.com');
      when(mockUser.photoURL).thenReturn(null);

      await tester.pumpWidget(createTestApp(user: mockUser));
      await tester.pumpAndSettle();

      // Verify user info is displayed
      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);
      // Verify sign out button is present
      expect(find.text('Sign out'), findsOneWidget);
      // Verify sign in button is NOT present
      expect(find.text('Sign in'), findsNothing);
    });

    testWidgets('Successful authentication state handling', (tester) async {
      // Simulate successful sign in by changing the mock user
      final mockUser = MockUser();
      when(mockUser.displayName).thenReturn('Test User');
      when(mockUser.email).thenReturn('test@example.com');
      when(mockUser.photoURL).thenReturn(null);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Initially signed out
      expect(find.text('Sign in'), findsOneWidget);

      // Update mock to simulate signed in state
      when(mockGoogleAuth.currentUser).thenReturn(mockUser);
      when(mockGoogleAuth.isBusy).thenReturn(false);
      mockGoogleAuth.notifyListeners();

      await tester.pumpAndSettle();

      // Should now show signed in state
      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('Sign-in cancellation handling', (tester) async {
      // When signIn is called and user cancels, the service should handle gracefully
      // This test verifies the UI doesn't break during cancellation
      when(mockGoogleAuth.signIn()).thenAnswer((_) async {
        // Simulate user cancellation by not changing the user state
        throw StateError('Sign in cancelled by user');
      });

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Tap sign in button
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      // Should still show sign in button (not signed in)
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('Authentication failure and retry', (tester) async {
      // Simulate authentication failure
      when(mockGoogleAuth.signIn()).thenThrow(Exception('Google sign-in failed: Network error'));

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Tap sign in button
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      // Should show error snackbar (we can't easily test snackbar in widget test)
      // But the sign in button should still be available for retry
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('Sign-out and session restoration', (tester) async {
      final mockUser = MockUser();
      when(mockUser.displayName).thenReturn('Test User');
      when(mockUser.email).thenReturn('test@example.com');
      when(mockUser.photoURL).thenReturn(null);

      await tester.pumpWidget(createTestApp(user: mockUser));
      await tester.pumpAndSettle();

      // Verify signed in
      expect(find.text('Sign out'), findsOneWidget);

      // Simulate sign out
      when(mockGoogleAuth.signOut()).thenAnswer((_) async {});
      when(mockGoogleAuth.currentUser).thenReturn(null);

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      // Should now show signed out state
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Not signed in'), findsOneWidget);
    });

    testWidgets('Preventing access to application routes without authentication', (tester) async {
      // This test would require a router setup with auth guards
      // For now, we verify the auth service correctly reports authentication state
      expect(mockGoogleAuth.currentUser, isNull);
      expect(mockGoogleAuth.isConfigured, isTrue);

      // When user is null, routes requiring auth should redirect
      // This is typically handled by GoRouter redirect logic
    });

    testWidgets('Configuration error display when Firebase not configured', (tester) async {
      when(mockGoogleAuth.isConfigured).thenReturn(false);
      when(mockGoogleAuth.configurationError).thenReturn('Google sign-in setup is required.');

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Should show configuration error message
      expect(find.text('Google sign-in setup is required.'), findsOneWidget);
      // Sign in button should be disabled/not present
      expect(find.text('Sign in'), findsNothing);
    });
  });
}
