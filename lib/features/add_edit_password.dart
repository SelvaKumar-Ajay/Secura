import 'package:flutter/material.dart';
import 'package:password_strength_checker/password_strength_checker.dart';
import 'package:provider/provider.dart';

import '../models/password_data_mdl.dart';
import '../services/password_s.dart';
import 'password_generate.dart';

class AddEditPasswordScreen extends StatefulWidget {
  final PasswordEntry? passwordEntry;

  const AddEditPasswordScreen({super.key, this.passwordEntry});

  @override
  State<AddEditPasswordScreen> createState() => _AddEditPasswordScreenState();
}

class _AddEditPasswordScreenState extends State<AddEditPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _accountController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  bool get _isEditing => widget.passwordEntry != null;
  final passNotifier = ValueNotifier<PasswordStrength?>(null);

  @override
  void initState() {
    super.initState();
    _accountController = TextEditingController(
      text: widget.passwordEntry?.account ?? '',
    );
    _usernameController = TextEditingController(
      text: widget.passwordEntry?.username ?? '',
    );
    _passwordController = TextEditingController(
      text: widget.passwordEntry?.password ?? '',
    );
    // Listen to the password controller to update the strength checker
    _passwordController.addListener(() {
      final password = _passwordController.text.trim();
      passNotifier.value = PasswordStrength.calculate(text: password);
    });
  }

  @override
  void dispose() {
    _accountController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    passNotifier.dispose();
    super.dispose();
  }

  void _saveForm() {
    if (_formKey.currentState!.validate()) {
      final newEntry = PasswordEntry(
        id: widget.passwordEntry?.id,
        account: _accountController.text,
        username: _usernameController.text,
        password: _passwordController.text,
        createdAt: DateTime.now(),
      );

      if (_isEditing) {
        context.read<PasswordService>().updatePassword(newEntry);
      } else {
        context.read<PasswordService>().addPassword(newEntry);
      }

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password for ${_accountController.text} saved.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Password' : 'Add New Password'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveForm),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _accountController,
                decoration: const InputDecoration(
                  labelText: 'Account (e.g., Google)',
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter an account name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username / Email',
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a username or email' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a password' : null,
              ),
              const SizedBox(height: 16),
              // This widget will display the strength of the password in real-time.
              PasswordStrengthChecker(strength: passNotifier),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                icon: const Icon(Icons.generating_tokens),
                label: const Text('Generate Secure Password'),
                onPressed: () async {
                  final generatedPassword = await Navigator.of(context)
                      .push<String>(
                        MaterialPageRoute(
                          builder: (context) => const PasswordGeneratorScreen(),
                        ),
                      );
                  if (generatedPassword != null) {
                    setState(() {
                      _passwordController.text = generatedPassword;
                    });
                  }
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.tealAccent),
                  foregroundColor: Colors.tealAccent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveForm,
                child: Text(_isEditing ? 'Update' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
