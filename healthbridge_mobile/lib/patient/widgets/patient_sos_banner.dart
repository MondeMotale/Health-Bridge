import 'package:flutter/material.dart';

/// Global banner shown to the patient while their SOS is active.
/// Three visual states:
///   - active → red, "SOS active — help is coming"
///   - responding + coming → orange, "[CHW] is on the way"
///   - responding + help_sent → blue, "Help has been sent"
class PatientSosBanner extends StatelessWidget {
  final String status;
  final String? responseType; // 'coming' | 'help_sent' | null
  final String chwName;
  final String timeSince;

  const PatientSosBanner({
    super.key,
    required this.status,
    required this.responseType,
    required this.chwName,
    required this.timeSince,
  });

  @override
  Widget build(BuildContext context) {
    final isResponding = status == 'responding';
    final isHelpSent = isResponding && responseType == 'help_sent';
    final isComing = isResponding && responseType == 'coming';

    Color bgColor;
    IconData icon;
    String headline;
    String subline;

    if (isHelpSent) {
      bgColor = const Color(0xFF3B82F6); // blue
      icon = Icons.local_hospital;
      headline = 'Help has been sent to you';
      subline = '$chwName dispatched assistance.';
    } else if (isComing) {
      bgColor = const Color(0xFFF59E0B); // orange
      icon = Icons.directions_run;
      headline = '$chwName is on the way';
      subline = 'Stay where you are.';
    } else {
      bgColor = const Color(0xFFEF4444); // red
      icon = Icons.emergency;
      headline = 'SOS active — help is coming';
      subline = '$chwName has been notified.';
    }

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: bgColor,
        elevation: 8,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Row(
              children: [
                _PulsingIcon(icon: icon, isActive: !isResponding),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        headline,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$timeSince · $subline',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
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

/// Pulsing icon — the pulse animation runs while the alert is `active`
/// (before any response), and stops once the CHW has responded.
class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final bool isActive;

  const _PulsingIcon({required this.icon, required this.isActive});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
    _scale = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant _PulsingIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the state flips from active to inactive (or vice versa)
    // while the widget is alive, start/stop the pulse accordingly.
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        shape: BoxShape.circle,
      ),
      child: Icon(widget.icon, color: Colors.white, size: 22),
    );

    if (!widget.isActive) return circle;
    return ScaleTransition(scale: _scale, child: circle);
  }
}