import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A utility for handling clipboard operations with user feedback and security.
class ClipboardHandler {
  /// Copies the given [text] to the clipboard and shows a [SnackBar].
  ///
  /// The [label] is used in the SnackBar message (e.g., "Password copied...").
  /// For security, the clipboard is cleared after 30 seconds.
  static void copyToClipboard(
    BuildContext context, {
    required String text,
    required String label,
  }) {
    if (!context.mounted) return;

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
      // To be safe, only clear if the content is still what we set.
      // This is an edge case, but good practice.
      Clipboard.getData(Clipboard.kTextPlain).then((data) {
        if (data?.text == text) {
          Clipboard.setData(const ClipboardData(text: ''));
        }
      });
    });
  }
}
