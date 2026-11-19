import 'package:flutter/material.dart';

/// Drop-in replacement for a tappable [GestureDetector] that is also accessible:
/// announced as a button by TalkBack/VoiceOver (with a tap action), focusable and
/// activatable with a keyboard / switch access (Enter or Space).
///
/// A bare GestureDetector is invisible to assistive technology, which made many of the
/// app's custom cards and buttons unusable for screen-reader users.
class TapArea extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final GestureTapDownCallback? onTapDown;
  final GestureTapUpCallback? onTapUp;
  final GestureTapCancelCallback? onTapCancel;
  final HitTestBehavior? behavior;
  final String? semanticLabel;

  const TapArea({
    super.key,
    required this.child,
    this.onTap,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
    this.behavior,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return FocusableActionDetector(
      enabled: enabled,
      mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          onTap?.call();
          return null;
        }),
      },
      child: Semantics(
        button: true,
        enabled: enabled,
        label: semanticLabel,
        onTap: onTap,
        child: GestureDetector(
          onTap: onTap,
          onTapDown: enabled ? onTapDown : null,
          onTapUp: enabled ? onTapUp : null,
          onTapCancel: enabled ? onTapCancel : null,
          behavior: behavior ?? HitTestBehavior.opaque,
          child: child,
        ),
      ),
    );
  }
}
