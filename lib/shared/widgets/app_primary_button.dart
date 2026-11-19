import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Main call-to-action button.
///
/// Built on Material [ElevatedButton] so it is announced as a button by TalkBack/VoiceOver,
/// can be reached with a keyboard or switch access, shows a focus highlight, and has a
/// 56dp minimum height. Labels wrap onto two lines instead of overflowing when the user
/// has large text turned on (common for older users, and Bangla labels are long).
class AppPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? backgroundColor;
  final bool isLoading;

  const AppPrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.backgroundColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final bg = backgroundColor ?? AppColors.primary;
    return Semantics(
      button: true,
      enabled: enabled,
      label: isLoading ? '$text, please wait' : null,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE5E7EB),
          disabledForegroundColor: const Color(0xFF4B5563),
          minimumSize: const Size(double.infinity, 56),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          elevation: enabled ? 2 : 0,
          shadowColor: bg.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        ),
        child: isLoading
            ? const SizedBox(
                height: 26,
                width: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 24),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, height: 1.2),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
