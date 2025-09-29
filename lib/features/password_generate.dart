import 'package:flutter/material.dart';
import 'package:clipboard/clipboard.dart';
import 'dart:math';

class PasswordGeneratorScreen extends StatefulWidget {
  const PasswordGeneratorScreen({super.key});

  @override
  State<PasswordGeneratorScreen> createState() =>
      _PasswordGeneratorScreenState();
}

class _PasswordGeneratorScreenState extends State<PasswordGeneratorScreen> {
  double _length = 16.0;
  bool _includeUppercase = true;
  bool _includeLowercase = true;
  bool _includeNumbers = true;
  bool _includeSymbols = true;
  String _generatedPassword = '';

  void _generatePassword() {
    String chars = '';
    if (_includeLowercase) chars += 'abcdefghijklmnopqrstuvwxyz';
    if (_includeUppercase) chars += 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    if (_includeNumbers) chars += '0123456789';
    if (_includeSymbols) chars += r'!@#$%&*()_+-=.?';

    if (chars.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('You must select at least one character type!'),
        ),
      );
      return;
    }

    final random = Random.secure();
    setState(() {
      _generatedPassword = String.fromCharCodes(
        Iterable.generate(
          _length.toInt(),
          (_) => chars.codeUnitAt(random.nextInt(chars.length)),
        ),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _generatePassword();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Password Generator')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Display Generated Password
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _generatedPassword,
                      style: const TextStyle(
                        fontSize: 20,
                        fontFamily: 'monospace',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      FlutterClipboard.copy(_generatedPassword);
                      Future.delayed(
                        const Duration(seconds: 30),
                        () => FlutterClipboard.copy(''),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password copied to clipboard for 30s'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Length Slider
            Text(
              'Length: ${_length.toInt()}',
              style: const TextStyle(fontSize: 16),
            ),
            Slider(
              value: _length,
              min: 8,
              max: 64,
              divisions: 56,
              label: _length.toInt().toString(),
              onChanged: (value) {
                setState(() => _length = value);
              },
            ),
            const SizedBox(height: 16),

            // Character Type Switches
            SwitchListTile(
              title: const Text('Include Uppercase (A-Z)'),
              value: _includeUppercase,
              onChanged: (val) => setState(() => _includeUppercase = val),
            ),
            SwitchListTile(
              title: const Text('Include Lowercase (a-z)'),
              value: _includeLowercase,
              onChanged: (val) => setState(() => _includeLowercase = val),
            ),
            SwitchListTile(
              title: const Text('Include Numbers (0-9)'),
              value: _includeNumbers,
              onChanged: (val) => setState(() => _includeNumbers = val),
            ),
            SwitchListTile(
              title: const Text('Include Symbols (!@# etc.)'),
              value: _includeSymbols,
              onChanged: (val) => setState(() => _includeSymbols = val),
            ),
            const SizedBox(height: 24),

            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Regenerate'),
              onPressed: _generatePassword,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.tealAccent),
                foregroundColor: Colors.tealAccent,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              child: const Text('Use This Password'),
              onPressed: () {
                Navigator.of(context).pop(_generatedPassword);
              },
            ),
          ],
        ),
      ),
    );
  }
}
