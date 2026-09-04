import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/images/product_images.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/widgets.dart';

/// The product photo on the product form.
///
/// Picking copies the file into the app's own directory **immediately**, and
/// hands back the stored name. That is deliberate: the alternative is to hold
/// the picked path until save, which means a form abandoned halfway leaves
/// nothing behind but a form saved after the user has tidied their downloads
/// folder saves a name pointing at a file that is already gone. Copying on
/// pick makes the preview and the saved result the same thing.
///
/// The cost is an orphaned file when somebody picks a photo and then abandons
/// the form. That is a few hundred kilobytes on disk against a product whose
/// photo silently fails to appear, and the trade is not close.
class ItemImageField extends StatefulWidget {
  const ItemImageField({
    required this.imagePath,
    required this.onChanged,
    super.key,
  });

  /// The stored file name, or null for no photo.
  final String? imagePath;

  /// Called with the new stored name, or null when the photo is removed.
  final ValueChanged<String?> onChanged;

  @override
  State<ItemImageField> createState() => _ItemImageFieldState();
}

class _ItemImageFieldState extends State<ItemImageField> {
  bool _busy = false;

  Future<void> _pick() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);

    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.image,
        // The picker's own image filter is not enough on every platform, and a
        // .bmp that Flutter cannot decode would save fine and render as a
        // placeholder with no explanation.
        allowedExtensions: null,
      );

      final path = picked.singleOrNull?.path;
      if (path == null) return;

      final saved = await ProductImages.save(File(path));
      if (!mounted) return;

      if (saved == null) {
        AppSnackBar.error(context, l10n.itemImageFailed);
        return;
      }
      widget.onChanged(saved);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Forgets the photo without deleting the file.
  ///
  /// The repository deletes the old one once the row that named it has been
  /// written — deleting here would destroy the photo of a product whose edit
  /// the user then abandons.
  void _remove() => widget.onChanged(null);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hasImage = widget.imagePath != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProductImage(
          imagePath: widget.imagePath,
          size: 96,
          icon: LucideIcons.camera,
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.itemImageLabel, style: theme.textTheme.labelMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.itemImageHelp,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  SecondaryButton(
                    label: hasImage
                        ? l10n.itemImageReplace
                        : l10n.itemImageChoose,
                    icon: LucideIcons.imagePlus,
                    onPressed: _busy ? null : _pick,
                  ),
                  if (hasImage)
                    TextButton.icon(
                      onPressed: _busy ? null : _remove,
                      icon: const Icon(LucideIcons.x, size: 16),
                      label: Text(l10n.itemImageRemove),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
