import 'package:flutter/material.dart';

import 'glossary_data.dart';

void showSnack(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : null,
      ),
    );
}

class GlossaryButton extends StatelessWidget {
  final String termKey;
  final Color? color;
  final double size;

  const GlossaryButton({
    super.key,
    required this.termKey,
    this.color,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.help_outline, size: size, color: color ?? Colors.grey),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onPressed: () => _showGlossary(context, termKey),
      tooltip: 'O que é isso?',
    );
  }

  void _showGlossary(BuildContext context, String key) {
    final term = GlossaryData.terms[key];
    if (term == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book_rounded, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    term.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 32),
            Text(
              term.definition,
              style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            Text(
              term.details,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            if (term.source != null) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  const Icon(Icons.science, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Fonte: ${term.source}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 32), // Bottom padding
          ],
        ),
      ),
    );
  }
}
