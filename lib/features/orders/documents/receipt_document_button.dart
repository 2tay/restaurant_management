import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../mock_data/mock_data.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/widgets.dart';
import 'receipt_export.dart';

/// Generates the bon de réception for one delivery and opens the share sheet.
///
/// Owns the busy state itself so both call sites get it for free. Generating a
/// PDF is the first genuinely asynchronous thing in the app — everything else
/// is an in-memory list write — so this is the first button that can actually
/// be pressed twice before it finishes, and the guard is real rather than
/// defensive decoration.
class ReceiptDocumentButton extends StatefulWidget {
  const ReceiptDocumentButton({
    required this.receipt,
    this.compact = false,
    super.key,
  });

  final GoodsReceipt receipt;

  /// Icon only, for a row in a list. The full button carries its label.
  final bool compact;

  @override
  State<ReceiptDocumentButton> createState() => _ReceiptDocumentButtonState();
}

class _ReceiptDocumentButtonState extends State<ReceiptDocumentButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (widget.compact) {
      return IconButton(
        onPressed: _busy ? null : _share,
        tooltip: l10n.receiptDocAction,
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

    return PrimaryButton(
      label: l10n.receiptDocAction,
      icon: LucideIcons.fileDown,
      isBusy: _busy,
      onPressed: _busy ? null : _share,
    );
  }

  Future<void> _share() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);

    try {
      final shared = await ReceiptExport.share(
        context,
        widget.receipt,
        MockQueries.receiptDocumentSources(widget.receipt),
      );
      if (!mounted) return;
      if (!shared) AppSnackBar.error(context, l10n.receiptDocFailed);
    } catch (_) {
      // Sharing crosses into platform code — a cancelled save dialog, a
      // browser refusing the download, a missing print service. None of it is
      // recoverable here, and none of it should take the screen down.
      if (!mounted) return;
      AppSnackBar.error(context, l10n.receiptDocFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
