import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/widgets.dart';
import 'order_export.dart';

/// Downloads the order as a bon de commande PDF, to send to the supplier.
///
/// A labelled button on the order's page; an icon in a row of the orders
/// list ([compact]).
class OrderDocumentButton extends ConsumerStatefulWidget {
  const OrderDocumentButton({
    required this.order,
    this.compact = false,
    super.key,
  });

  final PurchaseOrder order;
  final bool compact;

  @override
  ConsumerState<OrderDocumentButton> createState() =>
      _OrderDocumentButtonState();
}

class _OrderDocumentButtonState extends ConsumerState<OrderDocumentButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (widget.compact) {
      return IconButton(
        onPressed: _busy ? null : _share,
        tooltip: l10n.orderDocAction,
        icon: _busy
            ? const SizedBox(
                width: AppSizing.iconSm,
                height: AppSizing.iconSm,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(
                LucideIcons.fileDown,
                size: AppSizing.iconMd,
                color: AppColors.textSecondary,
              ),
      );
    }

    return SecondaryButton(
      label: l10n.orderDocAction,
      shortLabel: l10n.orderDocActionShort,
      icon: LucideIcons.fileDown,
      onPressed: _busy ? null : _share,
    );
  }

  Future<void> _share() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);

    try {
      final sources = await ref
          .read(orderRepositoryProvider)
          .orderDocumentSources(widget.order);
      if (!mounted) return;

      final shared = await OrderExport.share(context, sources);
      if (!mounted) return;
      if (!shared) AppSnackBar.error(context, l10n.receiptDocFailed);
    } catch (_) {
      // Sharing crosses into platform code — a cancelled save dialog, a
      // browser refusing the download. None of it should take the screen
      // down.
      if (!mounted) return;
      AppSnackBar.error(context, l10n.receiptDocFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
