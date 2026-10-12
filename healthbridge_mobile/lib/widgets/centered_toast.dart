import 'dart:async';
import 'package:flutter/material.dart';

/// Shows a centered, auto-dismissing toast.
/// Replaces ScaffoldMessenger.showSnackBar across the app for a more
/// visible notification that doesn't get hidden behind the bottom nav.
void showCenterToast(
  BuildContext context, {
  required String message,
  Color color = const Color(0xFF1E3A8A),
  IconData icon = Icons.info_outline,
  Duration duration = const Duration(seconds: 2),
}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  late OverlayEntry entry;
  bool removed = false;

  void removeEntry() {
    if (removed) return;
    removed = true;
    try {
      entry.remove();
    } catch (_) {}
  }

  entry = OverlayEntry(
    builder: (context) => Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  Timer(duration, removeEntry);
}