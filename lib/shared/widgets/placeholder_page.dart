import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'app_scaffold.dart';

/// Stand-in for a route whose screen has not been built yet.
///
/// Exists so Stage 3 can prove every route in the app is reachable before any
/// screen content exists. Stage 5 replaces these one at a time; when the last
/// one goes, this file goes with it.
///
/// Deliberately looks unfinished. A placeholder that looked plausible would
/// eventually get demoed by accident.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    required this.title,
    this.note,
    this.standalone = false,
    super.key,
  });

  final String title;
  final String? note;

  /// True for routes outside the shell — login, store selector — which have no
  /// [AppScaffold] above them and so must supply their own [Scaffold].
  final bool standalone;

  @override
  Widget build(BuildContext context) {
    final page = _buildBody(context);
    return standalone ? Scaffold(body: SafeArea(child: page)) : page;
  }

  Widget _buildBody(BuildContext context) {
    return ShellPage(
      title: title,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xxl),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Column(
          children: [
            const Icon(
              LucideIcons.hammer,
              size: 40,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Écran à construire',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (note != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(note!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
