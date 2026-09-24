import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import 'adaptive_row.dart';

/// A panel that slides in from the right for a row's detail — the attendance
/// and payment history both open one instead of navigating away or throwing a
/// full-screen modal.
///
/// ~440px on a desktop, near full-width below 600. Dismissed by the close
/// button, the scrim, or Échap.
class DetailDrawer extends StatelessWidget {
  const DetailDrawer({
    required this.children,
    this.title,
    this.header,
    this.dashedRule = false,
    super.key,
  }) : assert(title != null || header != null);

  /// The panel's heading. Null when [header] takes its place.
  final String? title;
  final List<Widget> children;

  /// Under the title — or, with no [title], in its place: context that
  /// belongs to the panel rather than to its content (the board's live date
  /// and time).
  final Widget? header;

  /// A dashed rule under the heading instead of the solid hairline.
  final bool dashedRule;

  static Future<void> show(
    BuildContext context, {
    required List<Widget> children,
    String? title,
    Widget? header,
    bool dashedRule = false,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      transitionDuration: AppMotion.duration(context, AppMotion.page),
      pageBuilder: (context, _, _) =>
          DetailDrawer(
            title: title,
            header: header,
            dashedRule: dashedRule,
            children: children,
          ),
      transitionBuilder: (context, animation, _, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: AppMotion.enter)),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final panelWidth = screenWidth < AppBreakpoints.compact
        ? screenWidth
        : 440.0;

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        elevation: 16,
        color: AppColors.surface,
        child: SizedBox(
          width: panelWidth,
          height: double.infinity,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (title != null)
                              Text(title!, style: theme.textTheme.titleMedium),
                            if (title != null && header != null)
                              const SizedBox(height: AppSpacing.xs),
                            ?header,
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(LucideIcons.x),
                        tooltip: l10n.actionClose,
                      ),
                    ],
                  ),
                ),
                if (dashedRule)
                  const _DashedRule()
                else
                  Divider(
                    height: 1,
                    color: AppColors.border.withValues(alpha: 0.5),
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    children: children,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A 1dp dashed line across the panel — [DetailDrawer.dashedRule].
class _DashedRule extends StatelessWidget {
  const _DashedRule();

  @override
  Widget build(BuildContext context) => const SizedBox(
    key: ValueKey('detail-drawer-dashed-rule'),
    height: 1,
    width: double.infinity,
    child: CustomPaint(painter: _DashPainter(AppColors.border)),
  );
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);

  final Color color;

  static const double _dash = 5;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += _dash + _gap) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + _dash).clamp(0, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// A `label — value` line for the drawer body. `value` may be a string or,
/// via [valueWidget], any widget (a badge, an amount).
class DrawerRow extends StatelessWidget {
  const DrawerRow({required this.label, this.value, this.valueWidget, super.key});

  final String label;
  final String? value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // The 140dp label gutter is right in a 440dp panel and wrong in the
    // full-width one a phone gets, where it leaves a French label like
    // "Heures supplémentaires" wrapping to three lines beside a one-word
    // value. Below the threshold the label sits above the value instead.
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AdaptiveRow(
        breakpoint: 320,
        crossAxisAlignment: CrossAxisAlignment.start,
        runSpacing: AppSpacing.xxs,
        cells: [
          AdaptiveCell(
            width: AppSizing.drawerLabelWidth,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          AdaptiveCell(
            flex: 1,
            child:
                valueWidget ??
                Text(value ?? '—', style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
