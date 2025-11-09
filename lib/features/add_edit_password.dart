import 'package:flutter/material.dart';
import 'package:password_manager/services/prefs_s.dart';
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

  // Controllers
  late final TextEditingController _accountController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _websiteController;
  late final TextEditingController _notesController;
  late final TextEditingController _hintController;
  late final TextEditingController _recoveryEmailController;
  late final TextEditingController _categoryController;
  late final TextEditingController _securityQuestionController;
  late final TextEditingController _securityAnswerController;

  final passNotifier = ValueNotifier<PasswordStrength?>(null);
  bool get _isEditing => widget.passwordEntry != null;
  bool _showAdvanced = false;

  // Focus nodes for smoother keyboard navigation
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _websiteFocus = FocusNode();
  final _notesFocus = FocusNode();

  // category holder
  String? _selectedCategory;
  // basic categories
  final List<String> _defaultCategories = [
    'General',
    'Banking',
    'Social',
    'Shopping',
    'Work',
    'Entertainment',
    'Email',
    'Gaming',
    'Travel',
    'Utilities',
  ];

  late List<String> _categories;
  late List<String> _customCategories;

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
    _websiteController = TextEditingController(
      text: widget.passwordEntry?.website ?? '',
    );
    _notesController = TextEditingController(
      text: widget.passwordEntry?.notes ?? '',
    );
    _hintController = TextEditingController(
      text: widget.passwordEntry?.hint ?? '',
    );
    _recoveryEmailController = TextEditingController(
      text: widget.passwordEntry?.recoveryEmail ?? '',
    );
    _categoryController = TextEditingController(
      text: widget.passwordEntry?.category ?? '',
    );
    _securityQuestionController = TextEditingController(
      text: widget.passwordEntry?.securityQuestion ?? '',
    );
    _securityAnswerController = TextEditingController(
      text: widget.passwordEntry?.securityAnswer ?? '',
    );

    // Build categories: defaults + persisted custom categories
    List<String> normalize(List<String> list) {
      return list
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .map((s) => s[0].toUpperCase() + s.substring(1))
          .toSet()
          .toList();
    }

    final savedCustom = Prefs.getStringList('custom_categories');
    _customCategories = normalize(savedCustom);
    final normalizedDefaults = normalize(_defaultCategories);

    // Merge while preserving defaults first, then custom
    final merged = <String>{};
    merged.addAll(normalizedDefaults);
    merged.addAll(_customCategories);
    _categories = merged.toList();

    // Ensure 'Other' is present and placed last
    _categories.removeWhere((c) => c.toLowerCase() == 'other');
    _categories.add('Other');

    // init selected category from the existing entry (or fallback to first default)
    _selectedCategory = widget.passwordEntry?.category.isNotEmpty == true
        ? (widget.passwordEntry!.category)
        : (normalizedDefaults.isNotEmpty
              ? normalizedDefaults[0]
              : _categories.first);

    // ensure the selected category exists in list
    if (!_categories.contains(_selectedCategory)) {
      _categories.insert(0, _selectedCategory!);
    }

    // keep controller in sync with selectedCategory
    _categoryController.text = _selectedCategory ?? '';

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
    _websiteController.dispose();
    _notesController.dispose();
    _hintController.dispose();
    _recoveryEmailController.dispose();
    _categoryController.dispose();
    _securityQuestionController.dispose();
    _securityAnswerController.dispose();
    passNotifier.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _websiteFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  void _saveForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Password strength check
    final strength = passNotifier.value;
    if (strength == PasswordStrength.weak ||
        strength == PasswordStrength.medium) {
      final continueAnyway = await _showWeakPasswordWarning(context);
      if (continueAnyway == false) return; // User cancelled
    }

    final newEntry = PasswordEntry(
      id: widget.passwordEntry?.id,
      account: _accountController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
      createdAt: DateTime.now(),
      website: _websiteController.text.trim(),
      notes: _notesController.text.trim(),
      hint: _hintController.text.trim(),
      recoveryEmail: _recoveryEmailController.text.trim(),
      category: _selectedCategory ?? 'General',
      securityQuestion: _securityQuestionController.text.trim(),
      securityAnswer: _securityAnswerController.text.trim(),
    );

    // ignore: use_build_context_synchronously
    final service = context.read<PasswordService>();
    _isEditing
        ? service.updatePassword(newEntry)
        : service.addPassword(newEntry);

    if (!mounted) return;

    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text('Password for ${_accountController.text} saved.')),
    );
  }

  Future<bool?> _showWeakPasswordWarning(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Weak Password'),
        content: const Text(
          'This password is weak and can be easily guessed. Are you sure you want to use it?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Use Anyway'),
          ),
        ],
      ),
    );
  }

  Future<void> _addNewCategoryDialog(BuildContext context) async {
    final controller = TextEditingController();
    final newCategory = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Category name',
            hintText: 'e.g., Education or Crypto',
          ),
          autofocus: true,
          textInputAction: TextInputAction.done,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.pop(context, text);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (newCategory != null && newCategory.isNotEmpty) {
      final normalizedCategory =
          newCategory[0].toUpperCase() + newCategory.substring(1);

      // Don't add if it already exists (case-insensitive check)
      if (_categories.any(
        (c) => c.toLowerCase() == normalizedCategory.toLowerCase(),
      )) {
        setState(() {
          _selectedCategory = _categories.firstWhere(
            (c) => c.toLowerCase() == normalizedCategory.toLowerCase(),
          );
          _categoryController.text = _selectedCategory!;
        });
        return;
      }

      setState(() {
        _customCategories.add(normalizedCategory);
        _categories.insert(_categories.length - 1, normalizedCategory);
        _selectedCategory = normalizedCategory;
        _categoryController.text = _selectedCategory!;
      });

      // Persist custom categories
      Prefs.setStringList('custom_categories', _customCategories);
    }
  }

  void _deleteCategory(String category) async {
    // This will be called from the dropdown item's button.
    // First, we need to close the dropdown menu.
    Navigator.of(context).pop();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text(
          'Are you sure you want to delete the category "$category"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _categories.remove(category);
        _customCategories.remove(category);

        if (_selectedCategory == category) {
          _selectedCategory = 'General';
          _categoryController.text = 'General';
        }
      });

      Prefs.setStringList('custom_categories', _customCategories);
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
      body: GestureDetector(
        onTap: () =>
            FocusScope.of(context).unfocus(), // dismiss keyboard on tap
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _accountController,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.text,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  labelText: 'Account (e.g., Google)',
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter an account name' : null,
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_usernameFocus),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                focusNode: _usernameFocus,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                decoration: const InputDecoration(
                  labelText: 'Username / Email',
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a username or email' : null,
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_passwordFocus),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                textInputAction: TextInputAction.next,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                keyboardType: TextInputType.visiblePassword,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a password' : null,
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_websiteFocus),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: PasswordStrengthChecker(strength: passNotifier),
              ),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                isExpanded: true,
                items: _categories.map((cat) {
                  final isCustom = _customCategories.contains(cat);
                  return DropdownMenuItem<String>(
                    value: cat,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(cat),
                        if (isCustom)
                          InkWell(
                            onTap: () => _deleteCategory(cat),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8.0),
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) async {
                  if (value == 'Other') {
                    await _addNewCategoryDialog(context);
                  } else {
                    setState(() {
                      _selectedCategory = value;
                      _categoryController.text = _selectedCategory!;
                    });
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Category',
                  hintText: 'Select or add a category',
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Please select a category'
                    : null,
              ),
              const SizedBox(height: 16),
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
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  _showAdvanced ? 'Hide Advanced Options' : 'More Options',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onExpansionChanged: (expanded) =>
                    setState(() => _showAdvanced = expanded),
                children: [
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _websiteController,
                    focusNode: _websiteFocus,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.url,
                    autofillHints: const [AutofillHints.url],
                    decoration: const InputDecoration(
                      labelText: 'Website / URL',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return null;
                      }
                      final uri = Uri.tryParse(value);
                      if (uri == null || !uri.hasAbsolutePath) {
                        return 'Please enter a valid URL';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _hintController,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.multiline,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(
                      labelText: 'Password Hint',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _recoveryEmailController,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Recovery Email / Phone',
                    ),
                  ),

                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _securityQuestionController,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                      labelText: 'Security Question',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _securityAnswerController,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                      labelText: 'Security Answer',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    focusNode: _notesFocus,
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                    keyboardType: TextInputType.multiline,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveForm,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: Text(_isEditing ? 'Update' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
