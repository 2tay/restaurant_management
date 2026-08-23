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
class SearchField extends StatefulWidget {
  const SearchField({
    required this.onChanged,
    this.hint,
    this.initialValue,
    this.autofocus = false,
    super.key,
  });

  final ValueChanged<String> onChanged;
  final String? hint;
  final String? initialValue;
  final bool autofocus;

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

    return TextField(
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
      ),
    );
  }
}
