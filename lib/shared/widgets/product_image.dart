import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/images/product_images.dart';

/// How the stand-in for a product with no photo is drawn.
enum ProductImagePlaceholder {
  /// A flat neutral panel with the icon in the middle. The form field and the
  /// detail header, where the grey block reads as "there could be a photo here".
  fill,

  /// The icon inside a soft tinted disc on a near-white ground. The catalogue
  /// card, where most products have no photo and a grid of grey blocks is what
  /// the eye sees instead of the products.
  ///
  /// The disc is [AppColors.primaryContainer] rather than the in-stock green:
  /// it appears on every card whatever the stock says, and the status palette
  /// has to keep meaning status. It reads as the same soft green in place.
  disc,
}

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
    this.placeholder = ProductImagePlaceholder.fill,
    super.key,
  });

  /// The stored file name, or null for a product with no photo.
  final String? imagePath;

  /// The side of the square the image is drawn in.
  final double size;

  final double radius;

  /// Drawn on the placeholder. The form passes a camera to say "add one".
  final IconData icon;

  /// Which of the two placeholders stands in when there is no photo.
  final ProductImagePlaceholder placeholder;

  /// The side assumed when neither [size] nor the incoming constraints give a
  /// finite one. Nothing in the app lays a product image out unbounded today;
  /// this keeps a future caller that does from crashing the page it is on.
  static const double _unboundedSide = 48;

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

  Widget _placeholder(BuildContext context) {
    final disc = widget.placeholder == ProductImagePlaceholder.disc;

    return ColoredBox(
      color: disc ? AppColors.neutral50 : AppColors.surfaceVariant,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // [size] is `double.infinity` wherever the caller means "fill
          // whatever you are given" — the picture band across the top of a
          // grid card. The `SizedBox` above copes with that because its parent
          // constrains it, but an icon needs a real number, and
          // `infinity * 0.32` is what threw `fontSize.isFinite` on every
          // product without a photo. So measure the box that was actually laid
          // out rather than trusting the declared side.
          final side = constraints.biggest.shortestSide;
          final resolved = side.isFinite
              ? side
              : (widget.size.isFinite
                    ? widget.size
                    : ProductImage._unboundedSide);

          if (!disc) {
            return Center(
              child: Icon(
                widget.icon,
                size: resolved * 0.32,
                color: AppColors.textSecondary,
              ),
            );
          }

          // The disc is capped so a full-width card on a phone does not draw a
          // dinner-plate-sized circle, and floored so a 40px avatar in a list
          // row still shows a recognisable icon.
          final discSide = (resolved * 0.42).clamp(28.0, 96.0);

          return Center(
            child: Container(
              width: discSide,
              height: discSide,
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.icon,
                size: (discSide * 0.5).clamp(AppSizing.iconSm, 44.0),
                color: AppColors.onPrimaryContainer,
              ),
            ),
          );
        },
      ),
    );
  }
}
