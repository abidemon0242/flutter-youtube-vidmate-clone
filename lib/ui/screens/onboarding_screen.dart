import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../services/google_auth_service.dart';

class AppEntryScreen extends StatefulWidget {
  const AppEntryScreen({super.key});

  @override
  State<AppEntryScreen> createState() => _AppEntryScreenState();
}

class _AppEntryScreenState extends State<AppEntryScreen> {
  bool _signingIn = false;

  Future<void> _signIn(GoogleAuthService auth) async {
    if (_signingIn || !auth.isConfigured || auth.isBusy) return;
    setState(() => _signingIn = true);
    try {
      await auth.signIn();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google sign-in failed: $error')));
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<GoogleAuthService>();
    final theme = Theme.of(context);
    final busy = _signingIn || auth.isBusy;

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
                  Icon(Icons.play_circle_fill_rounded, size: 76, color: theme.colorScheme.primary),
                  const SizedBox(height: 20),
                  Text('Welcome to Tube Arena', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 10),
                  Text(
                    'Sign in with your Google account to continue. Authentication is required to use Tube Arena.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: !auth.isConfigured || busy ? null : () => _signIn(auth),
                    icon: busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.login),
                    label: Text(busy ? 'Signing in…' : 'Continue with Google'),
                  ),
                  if (!auth.isConfigured) ...[
                    const SizedBox(height: 14),
                    Text(
                      auth.configurationError ??
                          'Google sign-in is not configured. Check Firebase Android configuration and Google provider settings.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
