import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state.dart';

/// Connexion / création de compte. Rend `true` via Navigator.pop en cas de succès.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _registerMode = false;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthModel>();
    try {
      if (_registerMode) {
        await auth.register(_email.text.trim(), _password.text,
            _name.text.trim(), _phone.text.trim());
      } else {
        await auth.login(_email.text.trim(), _password.text);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_registerMode ? 'Créer un compte' : 'Connexion')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_registerMode) ...[
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Nom'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phone,
                      decoration: const InputDecoration(
                          labelText: 'Téléphone (facultatif)'),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'Email invalide'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    decoration:
                        const InputDecoration(labelText: 'Mot de passe'),
                    obscureText: true,
                    validator: (v) => (_registerMode && (v?.length ?? 0) < 8)
                        ? '8 caractères minimum'
                        : (v == null || v.isEmpty)
                            ? 'Obligatoire'
                            : null,
                  ),
                  const SizedBox(height: 20),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_registerMode ? 'Créer mon compte' : 'Se connecter'),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _registerMode = !_registerMode;
                              _error = null;
                            }),
                    child: Text(_registerMode
                        ? 'J\'ai déjà un compte'
                        : 'Créer un compte'),
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
