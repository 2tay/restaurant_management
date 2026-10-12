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
/// list ([compact]). The order panel's footer uses the two [footer] forms:
/// one to read the PDF over, one to send it.
class OrderDocumentButton extends ConsumerStatefulWidget {
  const OrderDocumentButton({
    required this.order,
    this.compact = false,
    super.key,
  }) : preview = false,
       prominent = false,
       footer = false;

  /// A full-width footer button: « Voir le PDF » when [preview], otherwise
  /// « Télécharger » — teal when [prominent], outlined when not.
  const OrderDocumentButton.footer({
    required this.order,
    this.preview = false,
    this.prominent = false,
    super.key,
  }) : compact = false,
       footer = true;

  final PurchaseOrder order;
  final bool compact;
  final bool footer;

  /// Opens the PDF in a preview instead of the share sheet.
  final bool preview;
  final bool prominent;

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
        onPressed: _busy ? null : _run,
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

    if (widget.footer) {
      final label = widget.preview
          ? l10n.orderDocPreview
          : l10n.orderDocDownload;
      final icon = widget.preview ? LucideIcons.eye : LucideIcons.download;
      return widget.prominent
          ? PrimaryButton(
              label: label,
              icon: icon,
              isBusy: _busy,
              fullWidth: true,
              onPressed: _busy ? null : _run,
            )
          : SecondaryButton(
              label: label,
              icon: icon,
              fullWidth: true,
              onPressed: _busy ? null : _run,
            );
    }

    return SecondaryButton(
      label: l10n.orderDocAction,
      shortLabel: l10n.orderDocActionShort,
      icon: LucideIcons.fileDown,
      onPressed: _busy ? null : _run,
    );
  }

  Future<void> _run() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);

    try {
      final sources = await ref
          .read(orderRepositoryProvider)
          .orderDocumentSources(widget.order);
      if (!mounted) return;

      final bool shared;
      if (widget.preview) {
        shared = await OrderExport.preview(context, sources);
      } else {
        shared = await OrderExport.share(context, sources);
      }
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
