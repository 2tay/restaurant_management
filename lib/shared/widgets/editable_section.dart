import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../l10n/app_localizations.dart';
import 'app_card.dart';
import 'primary_button.dart';

/// A titled block of fields laid straight on the page, read-only until its
/// pencil is pressed (the settings pages).
///
/// The parent owns [editing]: it is the one that knows which fields to make
/// read-only and what « Annuler » puts back. Pressing the pencil calls
/// [onEdit]; while editing, « Annuler » and « Enregistrer » sit under the
/// fields and the pencil is gone. A null [onEdit] — someone who may not change
/// these values — hides the pencil altogether.
class EditableSection extends StatelessWidget {
  const EditableSection({
    required this.title,
    required this.child,
    this.description,
    this.editing = false,
    this.saving = false,
    this.onEdit,
    this.onCancel,
    this.onSave,
    this.editKey,
    super.key,
  });

  final String title;

  /// A short paragraph under the title saying what the block is for.
  final String? description;

  final Widget child;
  final bool editing;

  /// Shows a spinner on « Enregistrer » and blocks both buttons.
  final bool saving;

  final VoidCallback? onEdit;
  final VoidCallback? onCancel;
  final VoidCallback? onSave;

  /// Key of the pencil, for the tests of a page with several sections.
  final Key? editKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionTitle(
          title: title,
          description: description,
          trailing: onEdit != null && !editing
              ? IconButton(
                  key: editKey,
                  onPressed: onEdit,
                  tooltip: l10n.actionEdit,
                  icon: const Icon(LucideIcons.pencil, size: AppSizing.iconSm),
                  color: AppColors.primary600,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.brandTint.container,
                  ),
                )
              : null,
        ),
        child,
        if (editing) ...[
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              SecondaryButton(
                label: l10n.actionCancel,
                tone: SecondaryButtonTone.surface,
                onPressed: saving ? null : onCancel,
              ),
              PrimaryButton(
                label: l10n.actionSave,
                icon: LucideIcons.check,
                isBusy: saving,
                onPressed: onSave,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The title of a settings block, with an optional control right beside it
/// (the pencil) rather than pushed to the far edge.
class SettingsSectionTitle extends StatelessWidget {
  const SettingsSectionTitle({
    required this.title,
    this.description,
    this.trailing,
    super.key,
  });

  final String title;

  /// A short paragraph under the title, in the secondary text colour.
  final String? description;

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleRow = ConstrainedBox(
      // The pencil's height, so a block with and one without line up.
      constraints: const BoxConstraints(minHeight: 40),
      child: Row(
        children: [
          Flexible(
            child: Text(
              title,
              style: theme.textTheme.titleLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: description == null
          ? titleRow
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleRow,
                Text(
                  description!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
    );
  }
}

/// Fields two per line, or one per line below a medium screen
/// ([ResponsiveContext.isSmallScreen]). An odd last field keeps half the width
/// rather than stretching across both columns.
class FieldGrid extends StatelessWidget {
  const FieldGrid({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final single = context.isSmallScreen;
    final rows = <Widget>[];
    if (single) {
      rows.addAll(children);
    } else {
      for (var i = 0; i < children.length; i += 2) {
        rows.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: children[i]),
              const SizedBox(width: AppSpacing.xl),
              Expanded(
                child: i + 1 < children.length
                    ? children[i + 1]
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.lg),
          rows[i],
        ],
      ],
    );
  }
}

/// Two fields kept side by side at every width — the postal code and the
/// commune, which read as one line of an address.
class FieldPair extends StatelessWidget {
  const FieldPair({
    required this.first,
    required this.second,
    this.firstFlex = 2,
    this.secondFlex = 3,
    super.key,
  });

  final Widget first;
  final Widget second;
  final int firstFlex;
  final int secondFlex;

  @override
  Widget build(BuildContext context) {
    // Bottom-aligned: the inputs stay level even if one label wraps.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(flex: firstFlex, child: first),
        const SizedBox(width: AppSpacing.md),
        Expanded(flex: secondFlex, child: second),
      ],
    );
  }
}

/// A card in the notification-settings style: a tinted round icon, a title,
/// a line under it, and an optional control at the end. For the sync figures
/// and the linked establishments.
class IconInfoCard extends StatelessWidget {
  const IconInfoCard({
    required this.icon,
    required this.title,
    required this.value,
    this.trailing,
    this.onTap,
    this.highlighted = false,
    this.valueIsFigure = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String value;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Draws the icon in the brand tint instead of grey.
  final bool highlighted;

  /// The value is the point of the card (a count, a date): drawn larger than
  /// the title instead of as a caption under it.
  final bool valueIsFigure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // No hairline: the soft shadow alone sets it off the page, like the
    // notification cards.
    return AppCard(
      bordered: false,
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: highlighted
                  ? AppColors.primaryContainer
                  : AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: AppSizing.iconMd,
              color: highlighted
                  ? AppColors.onPrimaryContainer
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: valueIsFigure
                  ? [
                      Text(title, style: theme.textTheme.bodySmall),
                      const SizedBox(height: 2),
                      Text(value, style: theme.textTheme.titleMedium),
                    ]
                  : [
                      Text(title, style: theme.textTheme.titleSmall),
                      if (value.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(value, style: theme.textTheme.bodySmall),
                      ],
                    ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.md),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// A value shown in the shape of a plain [AppTextField] that is never typed
/// into — the role on the profile, the restaurant account's name — so it
/// lines up with the editable fields around it without a controller.
class ReadOnlyValueField extends StatelessWidget {
  const ReadOnlyValueField({
    required this.label,
    required this.value,
    this.icon,
    this.trailing,
    super.key,
  });

  final String label;
  final String value;
  final IconData? icon;

  /// A control inside the field's end — « Modifier » beside the password.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        Container(
          // A plain field's height: 24 of text and 14 above and below.
          constraints: const BoxConstraints(minHeight: 52),
          padding: EdgeInsets.only(
            left: icon == null ? AppSpacing.lg : 0,
            right: trailing == null ? AppSpacing.lg : AppSpacing.xs,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.mdAll,
          ),
          child: Row(
            children: [
              if (icon != null)
                SizedBox(
                  width: 48,
                  child: Icon(icon, size: 24, color: AppColors.textSecondary),
                ),
              Expanded(
                child: Text(
                  value,
                  style: theme.textTheme.bodyLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ],
    );
  }
}
