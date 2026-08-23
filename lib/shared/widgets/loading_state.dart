import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';

/// Shown while something is loading.
///
/// Nothing in Phase 1 is actually slow — every screen reads a list that is
/// already in memory. This exists so the state is *designed* now rather than
/// improvised in Phase 2 when real queries arrive and screens suddenly need it.
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
/// Preferred over a spinner for lists and cards: it keeps the layout from
/// jumping when the real content lands, which matters more on a tablet where
/// the user is aiming at a target from a distance.
class SkeletonBlock extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: borderRadius,
      ),
    );
  }
}
