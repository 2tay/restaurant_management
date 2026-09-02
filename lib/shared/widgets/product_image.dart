import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../data/images/product_images.dart';

/// A product's photo, or a placeholder standing in the same space.
///
/// Most of a catalogue has no photo and never will — produce arrives loose and
/// nobody is going to photograph forty kinds of vegetable. So the placeholder
/// is not an error state or a "missing image" apology: it is the normal
/// appearance of a product, drawn to the same size and shape as a photo so a
/// grid stays even whether one card in six has one or five do.
///
/// Resolving the file is a `Future` because the app's support directory is a
/// platform call. It is held in state rather than rebuilt, so scrolling does
/// not re-ask the OS where its own folder is on every frame.
class ProductImage extends StatefulWidget {
  const ProductImage({
    required this.imagePath,
    required this.size,
    this.radius = 12,
    this.icon = LucideIcons.package,
    super.key,
  });

  /// The stored file name, or null for a product with no photo.
  final String? imagePath;

  /// The side of the square the image is drawn in.
  final double size;

  final double radius;

  /// Drawn on the placeholder. The form passes a camera to say "add one".
  final IconData icon;

  @override
  State<ProductImage> createState() => _ProductImageState();
}

class _ProductImageState extends State<ProductImage> {
  File? _file;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(ProductImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A photo replaced on the form has to appear without the card being
    // rebuilt from scratch.
    if (widget.imagePath != oldWidget.imagePath) _resolve();
  }

  Future<void> _resolve() async {
    final file = await ProductImages.fileFor(widget.imagePath);
    if (mounted) setState(() => _file = file);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.radius);

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: _file == null
            ? _placeholder(context)
            : Image.file(
                _file!,
                fit: BoxFit.cover,
                // A name pointing at a file that is gone — the directory was
                // cleared, the database came from another machine — reads as
                // "no photo" rather than as a broken box. The record is the
                // product; the photo is decoration.
                errorBuilder: (context, _, _) => _placeholder(context),
              ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => ColoredBox(
    color: AppColors.surfaceVariant,
    child: Center(
      child: Icon(
        widget.icon,
        size: widget.size * 0.32,
        color: AppColors.textSecondary,
      ),
    ),
  );
}
