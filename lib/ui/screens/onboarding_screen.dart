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
      final message = auth.lastError ?? 'Google sign-in failed: $error';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _sendLoginLink(GoogleAuthService auth) async {
    if (_signingIn || !auth.isConfigured || auth.isBusy) return;
    final emailController = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign in with email'),
        content: TextField(
          controller: emailController,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Email address', hintText: 'name@example.com'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(emailController.text.trim()),
            child: const Text('Send link'),
          ),
        ],
      ),
    );
    emailController.dispose();
    if (!mounted || email == null) return;
    final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailPattern.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid email address.')));
      return;
    }

    setState(() => _signingIn = true);
    try {
      await auth.sendEmailSignInLink(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in link sent to $email. Open it on this device to finish signing in.')),
      );
    } catch (error) {
      if (!mounted) return;
      final message = auth.lastError ?? 'Could not send the sign-in link: $error';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
                    'Sign in to continue. Choose Google or receive a secure sign-in link by email.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: !auth.isConfigured || !auth.isGoogleConfigured || busy ? null : () => _signIn(auth),
                    icon: busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.login),
                    label: Text(busy ? 'Signing in…' : 'Continue with Google'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: !auth.isConfigured || busy ? null : () => _sendLoginLink(auth),
                    icon: const Icon(Icons.mail_outline),
                    label: const Text('Send login link'),
                  ),
                  if (auth.isConfigured && !auth.isGoogleConfigured) ...[
                    const SizedBox(height: 14),
                    Text(
                      auth.googleConfigurationError ?? 'Google sign-in is unavailable. You can use the email link option.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (auth.lastError != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      auth.lastError!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                    ),
                  ],
                  if (!auth.isConfigured) ...[
                    const SizedBox(height: 14),
                    Text(
                      auth.configurationError ??
                          'Firebase authentication is not configured. Check the Firebase Android configuration.',
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
