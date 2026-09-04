import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';

/// The search box on a list screen.
///
/// Filters as you type — no submit button. A clear button appears once there is
/// something to clear, because backspacing out of a query on a touch keyboard
/// with one hand is miserable.
///
/// Capped at [AppSizing.searchFieldMaxWidth] and left-aligned rather than
/// stretched across whatever it is given. Call sites hand it an `Expanded` so
/// it takes the slack from the filters beside it; that is about where the
/// filters sit, not about how wide the input should be.
class SearchField extends StatefulWidget {
  const SearchField({
    required this.onChanged,
    this.hint,
    this.initialValue,
    this.autofocus = false,
    this.maxWidth = AppSizing.searchFieldMaxWidth,
    super.key,
  });

  final ValueChanged<String> onChanged;
  final String? hint;
  final String? initialValue;
  final bool autofocus;

  /// Widest the input is drawn, however much room it is given.
  ///
  /// This is a cap on a box that still *fills* what it is handed — which is
  /// what a caller wants inside an `Expanded`, and the opposite of what one
  /// wants inside a `Wrap`, where filling the line pushes every control beside
  /// it onto the next one. A `Wrap` call site should hand it a `SizedBox` of
  /// the width it wants instead.
  final double maxWidth;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasText = _controller.text.isNotEmpty;

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        child: TextField(
          controller: _controller,
          autofocus: widget.autofocus,
          textInputAction: TextInputAction.search,
          onChanged: (value) {
            widget.onChanged(value);
            // Rebuilds only to show or hide the clear button.
            setState(() {});
          },
          decoration: InputDecoration(
            hintText: widget.hint ?? l10n.actionSearch,
            prefixIcon: const Icon(
              LucideIcons.search,
              color: AppColors.textSecondary,
            ),
            suffixIcon: hasText
                ? IconButton(
                    onPressed: _clear,
                    icon: const Icon(LucideIcons.x),
                    tooltip: l10n.actionClose,
                  )
                : null,
            // Tighter than the form-field rhythm on purpose. A search box is
            // not part of a column of inputs the eye reads down; it sits in a
            // control bar beside filter pills, and matching their 48dp height
            // is what makes that bar read as one row rather than as an input
            // with some chips next to it.
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
          ),
        ),
      ),
    );
  }
}
