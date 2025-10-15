import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/password_data_mdl.dart';
import '../services/auth_s.dart';
import '../services/fss_s.dart';
import '../services/password_s.dart';
import '../utils/debouncer.dart';
import 'add_edit_password.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // For search
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchText = '';

  // Debouncer with 700ms delay
  final Debouncer _debouncer = Debouncer(milliSecs: 700);

  // filter helpers
  String? _selectedFilter;
  final Map<String, Color> categoryColors = {
    'Banking': Colors.green.shade400,
    'Social': Colors.blue.shade400,
    'Shopping': Colors.orange.shade400,
    'Work': Colors.purple.shade400,
    'Entertainment': Colors.red.shade400,
    'General': Colors.grey.shade500,
  };

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PasswordService>().loadPasswords();
    });

    // listening search controller
    _searchController.addListener(() {
      _debouncer.run(() {
        if (!mounted) return;
        setState(() {
          _searchText = _searchController.text;
        });
      });
    });
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final passwordService = context.watch<PasswordService>();

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
              )
            : InkWell(
                onTap: () async =>
                    await context.read<PasswordService>().loadPasswords(),
                child: const Text('Vault'),
              ),
        actions: [
          if (_isSearching)
            IconButton(icon: const Icon(Icons.close), onPressed: _stopSearch)
          else ...[
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search',
              onPressed: _startSearch,
            ),
            PopupMenuButton<SortOrder>(
              icon: const Icon(Icons.sort),
              tooltip: 'Sort',
              onSelected: (SortOrder result) {
                passwordService.setSortOrder(result);
              },
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<SortOrder>>[
                    const PopupMenuItem<SortOrder>(
                      value: SortOrder.byDate,
                      child: Text('Sort by Date'),
                    ),
                    const PopupMenuItem<SortOrder>(
                      value: SortOrder.byAccountName,
                      child: Text('Sort by Name'),
                    ),
                  ],
            ),
            IconButton(
              padding: EdgeInsets.zero,
              tooltip: 'Profile',
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: () async {
                final userMail = await SecurePrefs.readSecure('email');
                if (!context.mounted) return;
                showDialog(
                  context: context,
                  builder: (_) => ProfileDialog(
                    userEmail: userMail ?? '-',
                    passCount: context.read<PasswordService>().passwords.length,
                    // userName: userName ?? '-',
                  ),
                );
              },
            ),
          ],
        ],
      ),
      body: Consumer<PasswordService>(
        builder: (context, passwordService, child) {
          if (passwordService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (passwordService.passwords.isEmpty) {
            return const Center(
              child: Text(
                'No passwords saved yet.\nTap the + button to add one!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          // Build category list dynamically (exclude 'Other' if you want)
          final categories =
              passwordService.passwords.map((e) => e.category).toSet().toList()
                ..remove('Other')
                ..sort();

          // Filter passwords based on search and selected category
          final filteredPasswords = passwordService.passwords.where((entry) {
            final matchesSearch =
                entry.account.toLowerCase().contains(
                  _searchText.toLowerCase(),
                ) ||
                entry.username.toLowerCase().contains(
                  _searchText.toLowerCase(),
                );
            final matchesCategory =
                _selectedFilter == null || entry.category == _selectedFilter;
            return matchesSearch && matchesCategory;
          }).toList();

          if (filteredPasswords.isEmpty) {
            return const Center(
              child: Text(
                'No passwords found',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          return RefreshIndicator.adaptive(
            onRefresh: () async {
              await context.read<PasswordService>().loadPasswords();
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 80),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      // 'All' chip
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _selectedFilter == null,
                        selectedColor: Colors.teal.shade300,
                        backgroundColor: Colors.grey.shade300,
                        labelStyle: TextStyle(
                          color: _selectedFilter == null
                              ? Colors.white
                              : Colors.black87,
                        ),
                        onSelected: (_) =>
                            setState(() => _selectedFilter = null),
                      ),
                      const SizedBox(width: 8),
                      // Category chips
                      ...categories.map((cat) {
                        final color =
                            categoryColors[cat] ?? Colors.teal.shade300;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: _selectedFilter == cat,
                            selectedColor: color,
                            backgroundColor: color.withValues(alpha: 0.3),
                            labelStyle: TextStyle(
                              color: _selectedFilter == cat
                                  ? Colors.white
                                  : color,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (_) =>
                                setState(() => _selectedFilter = cat),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                // Password entries
                ...filteredPasswords.map((e) => PasswordTile(passwordEntry: e)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AddEditPasswordScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class PasswordTile extends StatefulWidget {
  final PasswordEntry passwordEntry;

  const PasswordTile({super.key, required this.passwordEntry});

  @override
  State<PasswordTile> createState() => _PasswordTileState();
}

class _PasswordTileState extends State<PasswordTile> {
  bool _isPasswordVisible = false;

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 10),
            Text('$label copied to clipboard for 30s'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Future.delayed(const Duration(seconds: 30), () {
      Clipboard.setData(const ClipboardData(text: ''));
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasWebsite = widget.passwordEntry.website?.isNotEmpty ?? false;
    final faviconUrl =
        'https://www.google.com/s2/favicons?sz=64&domain_url=${widget.passwordEntry.website?.toLowerCase()}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade700, Colors.tealAccent.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account name + username/email
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white,
                  child: hasWebsite
                      ? Image.network(
                          faviconUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.vpn_key_outlined,
                              color: Colors.teal,
                              size: 28,
                            );
                          },
                        )
                      : const Icon(
                          Icons.vpn_key_outlined,
                          color: Colors.teal,
                          size: 28,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.passwordEntry.account,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.passwordEntry.username,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.copy,
                              size: 20,
                              color: Colors.white,
                            ),
                            tooltip: 'Copy Email/Username',
                            onPressed: () {
                              _copyToClipboard(
                                widget.passwordEntry.username,
                                'Username/Email',
                              );
                            },
                          ),
                        ],
                      ),
                      // Password block
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _isPasswordVisible
                                  ? widget.passwordEntry.password
                                  : '••••••••••',
                              style: const TextStyle(
                                fontSize: 16,
                                fontFamily: 'monospace',
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              size: 20,
                              color: Colors.white,
                            ),
                            tooltip: _isPasswordVisible
                                ? 'Hide Password'
                                : 'Show Password',
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.copy,
                              size: 20,
                              color: Colors.white,
                            ),
                            tooltip: 'Copy Password',
                            onPressed: () {
                              _copyToClipboard(
                                widget.passwordEntry.password,
                                'Password',
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(color: Colors.white24, thickness: 0.8),
            const SizedBox(height: 12),

            Wrap(
              runSpacing: 8,
              spacing: 8,
              children: [
                if (widget.passwordEntry.category.isNotEmpty)
                  _infoRow(
                    Icons.category_outlined,
                    widget.passwordEntry.category,
                    "Category",
                  ),
                if (widget.passwordEntry.website?.isNotEmpty ?? false)
                  _infoRow(
                    Icons.link,
                    widget.passwordEntry.website!,
                    "Website",
                  ),
                if (widget.passwordEntry.recoveryEmail?.isNotEmpty ?? false)
                  _infoRow(
                    Icons.email_outlined,
                    widget.passwordEntry.recoveryEmail!,
                    "Recovery Email",
                  ),
                if (widget.passwordEntry.hint?.isNotEmpty ?? false)
                  _infoRow(
                    Icons.lightbulb_outline,
                    widget.passwordEntry.hint!,
                    "Hint",
                  ),
                if (widget.passwordEntry.securityQuestion?.isNotEmpty ?? false)
                  _infoRow(
                    Icons.help_outline,
                    widget.passwordEntry.securityQuestion!,
                    "Security Question",
                  ),
                if (widget.passwordEntry.securityAnswer?.isNotEmpty ?? false)
                  _infoRow(
                    Icons.question_answer_outlined,
                    widget.passwordEntry.securityAnswer!,
                    "Security Answer",
                  ),
                if (widget.passwordEntry.notes?.isNotEmpty ?? false)
                  _infoRow(
                    Icons.note_outlined,
                    widget.passwordEntry.notes!,
                    "Notes",
                  ),
              ],
            ),

            const SizedBox(height: 8),
            const Divider(color: Colors.white24, thickness: 0.8),

            // Footer actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  label: const Text(
                    'Edit',
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () async {
                    final authService = context.read<AuthService>();

                    // Check if user has any app protection
                    final hasProtection =
                        authService.canCheckBiometrics ||
                        authService.availableBiometrics.isNotEmpty;

                    if (hasProtection) {
                      // User has protection → require authentication
                      final canProceed = await authService
                          .sensitiveActionWithBiometrics();

                      if (!canProceed) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Authentication required to proceed'),
                          ),
                        );
                        return;
                      }
                    } else {
                      // User has no protection → just notify and proceed
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Warning: Your app has no lock enabled. This action is not protected.',
                            ),
                          ),
                        );
                      }
                    }

                    if (!context.mounted) return;

                    // Proceed with the sensitive action (edit)
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AddEditPasswordScreen(
                          passwordEntry: widget.passwordEntry,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  label: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onPressed: () async {
                    final authService = context.read<AuthService>();

                    // Check if user has any app protection
                    final hasProtection =
                        authService.canCheckBiometrics ||
                        authService.availableBiometrics.isNotEmpty;

                    if (hasProtection) {
                      // User has protection → require authentication
                      final canProceed = await authService
                          .sensitiveActionWithBiometrics();

                      if (!canProceed) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Authentication required to proceed'),
                          ),
                        );
                        return;
                      }
                    } else {
                      // User has no protection → just notify and proceed
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Warning: Your app has no lock enabled. This action is not protected.',
                            ),
                          ),
                        );
                      }
                    }

                    if (!context.mounted) return;

                    // Proceed with the sensitive action (delete)
                    await _deletePasswordDialog(
                      context,
                      widget.passwordEntry.id,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String value, String label) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.white70),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.copy, size: 18, color: Colors.white70),
          tooltip: 'Copy $label',
          onPressed: () =>
              _copyToClipboard(widget.passwordEntry.username, 'Username/Email'),
        ),
      ],
    );
  }
}

Future<void> _deletePasswordDialog(BuildContext context, String id) async {
  // Capture stable references from the active parent context BEFORE showing the dialog.
  final messenger = ScaffoldMessenger.of(context);
  final passwordService = context.read<PasswordService>();

  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Are you sure?'),
      content: const Text('Do you want to delete this password?'),
      actions: [
        TextButton(
          child: const Text('No'),
          onPressed: () => Navigator.of(ctx).pop(),
        ),
        TextButton(
          child: const Text('Yes'),
          onPressed: () async {
            // Close the dialog first so UI can update.
            Navigator.of(ctx).pop();

            try {
              // Use the captured service reference to perform delete.
              // This avoids calling context.read(...) after the widget may be disposed.
              await passwordService.deletePassword(id);

              // Show feedback using the captured messenger (stable context).
              messenger.showSnackBar(
                const SnackBar(content: Text('Password deleted.')),
              );
            } catch (e) {
              // messenger.showSnackBar(
              //   SnackBar(content: Text('Failed to delete password: $e')),
              // );
            }
          },
        ),
      ],
    ),
  );
}

class ProfileDialog extends StatelessWidget {
  // final String userName;
  final String userEmail;
  final int passCount;
  const ProfileDialog({
    super.key,
    // required this.userName,
    required this.userEmail,
    required this.passCount,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();

    return AlertDialog(
      title: const Text('Profile Details'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text('Username: $userName'),
          const SizedBox(height: 8),
          Text('Email: $userEmail'),
          Text('Total Passwords: $passCount'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        TextButton(
          onPressed: () {
            auth.signOut();
            Navigator.pop(context);
          },
          child: const Text('Logout', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}
