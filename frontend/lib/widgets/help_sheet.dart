import 'package:flutter/material.dart';
import '../theme/echo_theme.dart';

class HelpEntry {
  const HelpEntry(this.label, this.text, {this.icon});
  final String label;
  final String text;
  final IconData? icon;
}

void showHelpSheet(BuildContext context, {required String title, required List<HelpEntry> entries}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: EchoColors.panel,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: EchoColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                  color: EchoColors.accent,
                  fontSize: 17,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w500,
                )),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: entries
                      .map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(e.icon ?? Icons.adjust,
                                    color: EchoColors.accentSoft, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(e.label,
                                          style: const TextStyle(
                                              color: EchoColors.fg,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 3),
                                      Text(e.text,
                                          style: const TextStyle(
                                              color: EchoColors.muted,
                                              fontSize: 12.5,
                                              height: 1.65)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
