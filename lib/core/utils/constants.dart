import 'package:flutter/material.dart';

// --- Premium Monochromatic Theme Colors ---

// Backgrounds
Color mainColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFF3F4F6)
        : const Color(0xFF0E0E0E);

Color boxColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : const Color(0xFF232326);

// Primary Text/Icons
Color primaryColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.grey.shade800
        : Colors.white70;

Color inversePrimaryColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : const Color(0xFF424345);

const Color switchColor = Color(0xFF424345);

Color actualInversePrimaryColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.white70
        : Colors.black;

// Accent Colors (Subtle & Sophisticated)
Color purpleColors(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.deepPurpleAccent.shade100
        : const Color.fromARGB(255, 83, 34, 168);

Color cardTextColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.deepPurpleAccent.shade100
        : Colors.white70;

// Shadows & Overlays
Color shadowColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.black26
        : Colors.black38;

Color snackbarColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : Colors.grey.shade900;

// Budget Colors (Desaturated/Sophisticated)
Color budgetBackgroundLight(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.grey.shade100
        : const Color(0xFF2A2A2D);

Color budgetTextLight(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.grey.shade600
        : Colors.grey.shade400;

Color budgetProgressGreen(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.green.shade400
        : Colors.green.shade700;

Color budgetProgressOrange(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.orange.shade400
        : Colors.orange.shade700;

Color budgetProgressDeepOrange(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.deepOrange.shade400
        : Colors.deepOrange.shade700;

Color budgetProgressRed(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.red.shade400
        : Colors.red.shade700;

Color budgetDeleteBackground(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.red.shade400
        : Colors.red.shade700;

// --- 8pt Grid Spacing Tokens ---
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

// --- Border Radius Tokens ---
class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
}

// Snackbar

void showCustomSnackBar(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final overlay = Overlay.of(context);
  final overlayEntry = OverlayEntry(
    builder: (context) {
      return Positioned(
        bottom: 100, // Position from the bottom
        left: 50,
        right: 40,
        child: _CustomSnackBar(
          message: message,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
      );
    },
  );

  // Insert the custom snackbar into the overlay
  overlay.insert(overlayEntry);

  // Remove the snackbar after the duration
  Future.delayed(const Duration(seconds: 2), () {
    overlayEntry.remove();
  });
}

class _CustomSnackBar extends StatefulWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _CustomSnackBar({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  State<_CustomSnackBar> createState() => _CustomSnackBarState();
}

class _CustomSnackBarState extends State<_CustomSnackBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _controller.forward(); // Start the fade-in animation
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.deepPurple,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              if (widget.actionLabel != null && widget.onAction != null) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: widget.onAction,
                  child: Text(
                    widget.actionLabel!,
                    style: const TextStyle(
                      color: Colors.yellow,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
