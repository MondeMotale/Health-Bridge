import 'package:flutter/material.dart';

class IncomingVideoCallOverlay extends StatelessWidget {
  final String callerName;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const IncomingVideoCallOverlay({
    super.key,
    required this.callerName,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.92),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              _PulsingVideoAvatar(name: callerName),
              const SizedBox(height: 24),
              Text(
                callerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Incoming video call...',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const Spacer(),
              Container(
                width: 200,
                height: 120,
                margin: const EdgeInsets.only(bottom: 30),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Center(
                  child: Icon(
                    Icons.videocam_off_outlined,
                    color: Colors.white38,
                    size: 40,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 60),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _LargeCallButton(
                      icon: Icons.call_end,
                      color: const Color(0xFFEF4444),
                      label: 'Decline',
                      onTap: onDecline,
                    ),
                    _LargeCallButton(
                      icon: Icons.videocam,
                      color: const Color(0xFF10B981),
                      label: 'Accept',
                      onTap: onAccept,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LargeCallButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _LargeCallButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 34),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _PulsingVideoAvatar extends StatefulWidget {
  final String name;
  const _PulsingVideoAvatar({required this.name});

  @override
  State<_PulsingVideoAvatar> createState() => _PulsingVideoAvatarState();
}

class _PulsingVideoAvatarState extends State<_PulsingVideoAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _glow = Tween<double>(begin: 0.2, end: 0.6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: AnimatedBuilder(
        animation: _glow,
        builder: (context, child) {
          return Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1E3A8A),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E3A8A).withValues(alpha: _glow.value),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Center(
              child: Text(
                widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 52,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}