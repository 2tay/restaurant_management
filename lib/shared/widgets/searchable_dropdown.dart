import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'app_dropdown.dart';

/// A picker that filters its options as you type.
///
/// Same label-above-the-field shape as [AppDropdown], but the closed field is a
/// text box: tapping it opens the menu and the keystrokes narrow the list. Used
/// where the option set is long enough that scrolling a plain dropdown is slow
/// — the employee pickers on the pointage and paiement pages.
///
/// The field fills its parent's width, so wrap it in a `SizedBox(width: …)` the
/// same way [AppDropdown] is wrapped.
class SearchableDropdown<T> extends StatefulWidget {
  const SearchableDropdown({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.hint,
    super.key,
  });

  final String label;
  final List<DropdownOption<T>> options;
  final T? value;
  final ValueChanged<T?> onChanged;
  final String? hint;

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _syncControllerText();
    // A filter typed but not committed (menu dismissed without a pick) should
    // not linger in the closed field.
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _syncControllerText();
    });
  }

  @override
  void didUpdateWidget(covariant SearchableDropdown<T> old) {
    super.didUpdateWidget(old);
    // Only when the selection changes from outside — not on every parent
    // rebuild, which would wipe a filter the user is part-way through typing.
    if (old.value != widget.value && !_focusNode.hasFocus) {
      _syncControllerText();
    }
  }

  /// Keeps the closed field showing the selected option's label — the menu can
  /// leave a half-typed filter behind when it is dismissed without a pick.
  void _syncControllerText() {
    final match = widget.options
        .where((o) => o.value == widget.value)
        .map((o) => o.label)
        .firstOrNull;
    final text = match ?? '';
    if (_controller.text != text) _controller.text = text;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: theme.textTheme.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        DropdownMenu<T>(
          controller: _controller,
          focusNode: _focusNode,
          initialSelection: widget.value,
          expandedInsets: EdgeInsets.zero,
          enableFilter: true,
          requestFocusOnTap: true,
          menuHeight: 320,
          hintText: widget.hint,
          leadingIcon: const Icon(
            LucideIcons.search,
            size: AppSizing.iconSm,
            color: AppColors.textSecondary,
          ),
          trailingIcon: const Icon(
            LucideIcons.chevronDown,
            size: AppSizing.iconSm,
            color: AppColors.textSecondary,
          ),
          selectedTrailingIcon: const Icon(
            LucideIcons.chevronUp,
            size: AppSizing.iconSm,
            color: AppColors.textSecondary,
          ),
          menuStyle: const MenuStyle(
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
            ),
          ),
          dropdownMenuEntries: [
            for (final option in widget.options)
              DropdownMenuEntry<T>(
                value: option.value,
                label: option.label,
                trailingIcon: option.secondaryLabel == null
                    ? null
                    : Text(
                        option.secondaryLabel!,
                        style: theme.textTheme.bodySmall,
                      ),
              ),
          ],
          onSelected: (selected) {
            widget.onChanged(selected);
            // Fold the keyboard away once a choice lands.
            FocusScope.of(context).unfocus();
          },
        ),
      ],
    );
  }
}
