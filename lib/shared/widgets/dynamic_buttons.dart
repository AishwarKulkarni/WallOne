import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wallone/core/utils/constants.dart';

class DynamicButtonsWidget extends StatefulWidget {
  final Function(bool) onSelectionChanged;

  const DynamicButtonsWidget({super.key, required this.onSelectionChanged});

  @override
  State<DynamicButtonsWidget> createState() => _DynamicButtonsWidgetState();
}

class _DynamicButtonsWidgetState extends State<DynamicButtonsWidget> {
  bool isExpensesSelected = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48.0, // Fixed height for accessibility (min 48dp)
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: boxColor(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: shadowColor(context),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Expenses Button
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => isExpensesSelected = true);
                widget.onSelectionChanged(true);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: isExpensesSelected
                      ? purpleColors(context).withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      style: GoogleFonts.outfit(
                        color: isExpensesSelected
                            ? purpleColors(context)
                            : cardTextColor(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      child: const Text("Expenses"),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Income Button
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => isExpensesSelected = false);
                widget.onSelectionChanged(false);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: isExpensesSelected
                      ? Colors.transparent
                      : purpleColors(context).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      style: GoogleFonts.outfit(
                        color: isExpensesSelected
                            ? cardTextColor(context)
                            : purpleColors(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      child: const Text("Income"),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
