// lib/widgets/notification_card.dart
import 'dart:ui'; // for ImageFilter
import 'package:flutter/material.dart';

/// A glass‑morphism styled notification card used for in‑app alerts.
///
/// The card features a subtle blur, semi‑transparent gradient background,
/// and an optional icon. It can be used inside an overlay to display
/// animated notifications.
class NotificationCard extends StatelessWidget {
  final String title;
  final String body;
  final IconData? icon;
  final VoidCallback? onTap;

  const NotificationCard({
    super.key,
    required this.title,
    required this.body,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0x33FFFFFF), Color(0x0AFFFFFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                if (icon != null)
                  Icon(icon, color: theme.primaryColor, size: 28)
                else
                  const SizedBox(width: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
