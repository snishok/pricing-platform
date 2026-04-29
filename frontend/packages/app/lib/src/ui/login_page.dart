import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final canSubmit =
        !auth.isLoading &&
        _email.text.trim().isNotEmpty &&
        _password.text.isNotEmpty;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Sign in',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [
                      AutofillHints.username,
                      AutofillHints.email,
                    ],
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _password,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: !canSubmit
                        ? null
                        : (_) => context.read<AuthState>().login(
                            email: _email.text.trim(),
                            password: _password.text,
                          ),
                  ),
                  const SizedBox(height: 12),
                  if (auth.error != null) ...[
                    Text(
                      auth.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: !canSubmit
                          ? null
                          : () => context.read<AuthState>().login(
                              email: _email.text.trim(),
                              password: _password.text,
                            ),
                      child: auth.isLoading
                          ? const Text('Signing in...')
                          : const Text('Login'),
                    ),
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
