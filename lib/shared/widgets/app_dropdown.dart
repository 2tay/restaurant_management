import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';

/// One option in an [AppDropdown].
class DropdownOption<T> {
  const DropdownOption({
    required this.value,
    required this.label,
    this.secondaryLabel,
  });

  final T value;
  final String label;

  /// Trailing detail — a supplier's city, a unit's abbreviation.
  final String? secondaryLabel;
}

/// A picker with an inline "+ Créer" row.
///
/// This one widget carries a load-bearing rule from the brief: categories and
/// units are created inside the app, not hardcoded. Every category and unit
/// picker therefore has to offer creation *without leaving the form* — a cook
/// halfway through adding an article should not have to abandon it, go to a
/// settings screen, add "botte", and start over.
///
/// [onCreateNew] is what makes that work. When it is supplied the create row
/// appears, pinned below the options.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.hint,
    this.onCreateNew,
    this.createNewLabel,
    this.errorText,
    this.enabled = true,
    super.key,
  });

  final String label;
  final List<DropdownOption<T>> options;
  final T? value;
  final ValueChanged<T?> onChanged;
  final String? hint;

  /// Supplying this adds the inline create row. Required for category and unit
  /// pickers; usually null elsewhere.
  final VoidCallback? onCreateNew;

  /// Overrides the default "+ Créer" wording — "+ Créer une catégorie".
  final String? createNewLabel;

  final String? errorText;
  final bool enabled;

  static const String _createSentinel = '__create_new__';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<Object?>(
          initialValue: value,
          isExpanded: true,
          menuMaxHeight: 420,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
          ),
          icon: const Icon(LucideIcons.chevronDown),
          borderRadius: AppRadius.mdAll,
          onChanged: enabled
              ? (selected) {
                  if (selected == _createSentinel) {
                    // Deliberately does not change the selection — the create
                    // flow decides what the new value is.
                    onCreateNew?.call();
                    return;
                  }
                  onChanged(selected as T?);
                }
              : null,
          items: [
            for (final option in options)
              DropdownMenuItem<Object?>(
                value: option.value,
                child: _OptionRow(option: option),
              ),
            if (onCreateNew != null)
              DropdownMenuItem<Object?>(
                value: _createSentinel,
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.circlePlus,
                      size: AppSizing.iconMd,
                      color: AppColors.primary600,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Flexible: "+ Créer une unité de mesure" is longer than
                    // the field it sits in on a narrow form.
                    Flexible(
                      child: Text(
                        createNewLabel ?? l10n.actionCreateNew,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.primary600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.option});

  final DropdownOption<Object?> option;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            option.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge,
          ),
        ),
        if (option.secondaryLabel != null) ...[
          const SizedBox(width: AppSpacing.sm),
          // Flexible, not a bare Text: in a menu narrower than the label plus
          // this hint (a dropdown in a tight column), the fixed Text used to
          // push the row past its width. It ellipsizes now instead.
          Flexible(
            child: Text(
              option.secondaryLabel!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }
}
