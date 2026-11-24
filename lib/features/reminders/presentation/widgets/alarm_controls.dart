import 'package:flutter/material.dart';

/// Small round button with a label under the icon (Listen on the alarm).
class RoundAlarmButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const RoundAlarmButton({super.key, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 30),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  );
}

/// One dot per medicine: wide for the one on screen, green once taken.
class AlarmPageDots extends StatelessWidget {
  final int count;
  final int page;
  final List<bool> taken;
  const AlarmPageDots({super.key, required this.count, required this.page, required this.taken});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == page ? 26 : 10,
            height: 10,
            decoration: BoxDecoration(
              color: taken[i] ? const Color(0xFF34D399) : Colors.white.withValues(alpha: i == page ? 0.95 : 0.4),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
      ],
    ),
  );
}
