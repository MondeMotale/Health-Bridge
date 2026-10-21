import 'package:flutter/material.dart';

class EmergencyAlertBanner extends StatelessWidget {
  final String patientName;
  final String timeSince;
  final VoidCallback onTap;

  const EmergencyAlertBanner({
    super.key,
    required this.patientName,
    required this.timeSince,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          bottom: false,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(30),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.emergency,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$patientName triggered SOS',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '$timeSince · Tap to respond',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}