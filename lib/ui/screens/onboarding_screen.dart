import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/google_auth_service.dart';
import 'home_screen.dart';

/// First-run entry point. Google sign-in is presented before the main app;
/// guest access remains available when Firebase has not been configured.
class AppEntryScreen extends StatefulWidget {
  const AppEntryScreen({super.key});

  @override
  State<AppEntryScreen> createState() => _AppEntryScreenState();
}

class _AppEntryScreenState extends State<AppEntryScreen> {
  static const _completedKey = 'onboarding_completed';
  bool _loading = true;
  bool _completed = false;
  bool _signingIn = false;

  @override
  void initState() {
    super.initState();
    _restoreEntryState();
  }

  Future<void> _restoreEntryState() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _completed = preferences.getBool(_completedKey) ?? false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _continueAsGuest() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_completedKey, true);
    if (mounted) setState(() => _completed = true);
  }

  Future<void> _signIn(GoogleAuthService auth) async {
    if (_signingIn || !auth.isConfigured) return;
    setState(() => _signingIn = true);
    try {
      await auth.signIn();
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_completedKey, true);
      if (mounted) setState(() => _completed = true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in failed: $error')),
      );
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<GoogleAuthService>();
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_completed || auth.currentUser != null) {
      return const HomeScreen();
    }

    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.play_circle_fill_rounded,
                    size: 76,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Welcome to Tube Arena',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Sign in with Google to connect your account. You can review app permissions when a feature needs them.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: !auth.isConfigured || auth.isBusy || _signingIn
                        ? null
                        : () => _signIn(auth),
                    icon: _signingIn || auth.isBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(
                      _signingIn || auth.isBusy
                          ? 'Signing in…'
                          : 'Continue with Google',
                    ),
                  ),
                  if (!auth.isConfigured) ...[
                    const SizedBox(height: 10),
                    Text(
                      auth.configurationError ??
                          'Google sign-in needs Firebase configuration. See docs/GOOGLE_SIGN_IN_SETUP.md.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _signingIn ? null : _continueAsGuest,
                    child: const Text('Continue as guest'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Guest mode keeps the public feed, search and local media tools available. You can sign in later from Settings.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
