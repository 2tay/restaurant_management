import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';

/// A centred spinner.
///
/// Kept for the rare case where nothing is known about the shape of what is
/// coming. Prefer [SkeletonList] or [SkeletonGrid] — a spinner on a blank page
/// tells the user to wait but not what for, and the layout jumps when content
/// finally lands.
class LoadingState extends StatelessWidget {
  const LoadingState({this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            message ?? l10n.loadingLabel,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// A grey block standing in for content that has not arrived.
///
/// Gently pulses so the screen reads as busy rather than broken. The pulse is
/// slow and low-contrast on purpose: a fast shimmer across a full page of rows
/// is its own kind of noise.
class SkeletonBlock extends StatefulWidget {
  const SkeletonBlock({
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = AppRadius.smAll,
    super.key,
  });

  final double width;
  final double height;
  final BorderRadius borderRadius;

  @override
  State<SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<SkeletonBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A user who has asked for reduced motion gets a flat block; the layout
    // still communicates that content is coming.
    final animate = !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = animate ? _controller.value : 0.5;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(AppColors.neutral100, AppColors.neutral200, t),
            borderRadius: widget.borderRadius,
          ),
        );
      },
    );
  }
}

/// Placeholder rows shaped like the list they stand in for.
///
/// Matching the real layout is the point: when content arrives nothing moves,
/// which is what separates a considered loading state from a spinner.
class SkeletonList extends StatelessWidget {
  const SkeletonList({this.rows = 6, this.rowHeight = 76, super.key});

  final int rows;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: rows,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => Container(
        height: rowHeight,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: AppColors.hairline),
          boxShadow: AppElevation.card,
        ),
        child: const Row(
          children: [
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SkeletonBlock(width: 180, height: 14),
                  SizedBox(height: AppSpacing.sm),
                  SkeletonBlock(width: 110, height: 12),
                ],
              ),
            ),
            SizedBox(width: AppSpacing.lg),
            SkeletonBlock(width: 80, height: 14),
            SizedBox(width: AppSpacing.lg),
            SkeletonBlock(
              width: 96,
              height: 28,
              borderRadius: AppRadius.pillAll,
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder cards for a grid — the store selector, the supplier list.
class SkeletonGrid extends StatelessWidget {
  const SkeletonGrid({
    this.count = 6,
    this.columns = 3,
    this.itemHeight = 200,
    super.key,
  });

  final int count;
  final int columns;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: AppSpacing.lg,
        mainAxisSpacing: AppSpacing.lg,
        mainAxisExtent: itemHeight,
      ),
      itemCount: count,
      itemBuilder: (context, index) => Container(
        padding: AppSpacing.cardInsets,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: AppColors.hairline),
          boxShadow: AppElevation.card,
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBlock(width: 44, height: 44, borderRadius: AppRadius.mdAll),
            SizedBox(height: AppSpacing.lg),
            SkeletonBlock(width: 160, height: 16),
            SizedBox(height: AppSpacing.sm),
            SkeletonBlock(width: 120, height: 12),
            Spacer(),
            SkeletonBlock(
              width: 90,
              height: 24,
              borderRadius: AppRadius.pillAll,
            ),
          ],
        ),
      ),
    );
  }
}
