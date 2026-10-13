import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/repositories.dart';
import '../../../data/view_models/view_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../../stock_movement/presentation/widgets/picker/product_picker_sheet.dart';
import 'barcode_camera_page.dart';
import 'barcode_support.dart';
import 'hardware_scan_listener.dart';
import '../../inventory/presentation/widgets/product_wizard_dialog.dart';

export 'barcode_camera_page.dart' show ScanOutcome, ScanOutcomeKind;

/// What a screen does with a product somebody scanned: put it on the form,
/// open it, tick it off. Says what happened, for the snackbar or the strip
/// under the viewfinder.
typedef ScannedItemHandler = Future<ScanOutcome> Function(ItemRowView row);

/// The product carrying [code], with its category and unit resolved, or null.
///
/// Read from the repository rather than from a list already on screen: right
/// after a code is linked or a product created, a stream held by the page may
/// not have caught up, and the scan that follows must still find it.
Future<ItemRowView?> lookupBarcode(
  WidgetRef ref,
  String storeId,
  String code,
) async {
  final matches = await ref
      .read(itemRepositoryProvider)
      .itemsWithBarcode(storeId, code);
  if (matches.isEmpty) return null;
  final item = matches.first;

  final catalog = ref.read(catalogRepositoryProvider);
  final unit = await catalog.unit(item.unitId);
  final category = await catalog.category(item.categoryId);
  return ItemRowView(
    item: item,
    categoryName: category?.name ?? '—',
    unitAbbreviation: unit?.abbreviation ?? '',
  );
}

/// Runs one code through the whole flow — find the product, or offer to
/// create it or link the code; then hand it to [onItem] and say what
/// happened.
///
/// For codes that arrive typed: from a scan field, a handheld scanner, or a
/// camera that closed on a code nobody has.
Future<void> handleScannedCode(
  BuildContext context,
  WidgetRef ref, {
  required String storeId,
  required String code,
  required ScannedItemHandler onItem,
}) async {
  var row = await lookupBarcode(ref, storeId, code);
  if (!context.mounted) return;
  if (row == null) {
    scanMissFeedback();
    final itemId = await resolveUnknownBarcode(
      context,
      ref,
      storeId: storeId,
      code: code,
    );
    if (itemId == null || !context.mounted) return;
    row = await lookupBarcode(ref, storeId, code);
    if (row == null || !context.mounted) return;
  }

  final outcome = await onItem(row);
  if (!context.mounted) return;
  switch (outcome.kind) {
    case ScanOutcomeKind.added:
      scanFeedback();
      AppSnackBar.success(context, outcome.message ?? row.item.name);
    case ScanOutcomeKind.refused:
      scanMissFeedback();
      AppSnackBar.warning(context, outcome.message ?? row.item.name);
    case ScanOutcomeKind.unknown || ScanOutcomeKind.none:
      break;
  }
}

/// Opens the viewfinder and keeps it open: each product read goes through
/// [onItem]. A code nobody has closes it, and is then offered for creating or
/// linking like a typed one.
Future<void> scanWithCamera(
  BuildContext context,
  WidgetRef ref, {
  required String storeId,
  required ScannedItemHandler onItem,
}) async {
  final unknown = await BarcodeCameraPage.scanContinuous(
    context,
    onCode: (code) async {
      final row = await lookupBarcode(ref, storeId, code);
      if (row == null) return const ScanOutcome.unknown();
      return onItem(row);
    },
  );
  if (unknown == null || !context.mounted) return;
  await handleScannedCode(
    context,
    ref,
    storeId: storeId,
    code: unknown,
    onItem: onItem,
  );
}

// -----------------------------------------------------------------------------
// A code nobody has.
// -----------------------------------------------------------------------------

enum _UnknownChoice { create, link }

/// « Code inconnu »: create the product with this code, or give the code to
/// a product that has none yet. Returns the product's id, or null when the
/// person did neither.
///
/// This is how the catalogue fills itself in: the first delivery of a product
/// teaches the app its barcode, and every delivery after is a scan.
Future<String?> resolveUnknownBarcode(
  BuildContext context,
  WidgetRef ref, {
  required String storeId,
  required String code,
}) async {
  final choice = await showModalBottomSheet<_UnknownChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => _UnknownBarcodeSheet(code: code),
  );
  if (choice == null || !context.mounted) return null;
  final l10n = AppLocalizations.of(context);

  switch (choice) {
    case _UnknownChoice.create:
      // The form comes back with the new product's id rather than going on
      // to the catalogue, so whatever was being scanned carries on.
      return showProductWizard(
        context,
        storeId: storeId,
        initialBarcode: code,
      );

    case _UnknownChoice.link:
      // Only products with no code yet: giving one that has a code another
      // would silently take the old one away.
      final rows = await ref.read(
        itemRowsProvider((storeId: storeId, filter: ItemFilter.none)).future,
      );
      if (!context.mounted) return null;
      final picked = await ProductPickerSheet.show(
        context,
        storeId: storeId,
        onlyItemIds: {
          for (final row in rows)
            if ((row.item.barcode ?? '').trim().isEmpty) row.item.id,
        },
      );
      if (picked == null || picked.isEmpty || !context.mounted) return null;
      final target = picked.first.item;
      final updated = await ref
          .read(itemRepositoryProvider)
          .update(target.id, barcode: code);
      if (!context.mounted) return null;
      if (updated == null) {
        AppSnackBar.error(context, l10n.scanLinkFailed);
        return null;
      }
      AppSnackBar.success(context, l10n.scanLinked(target.name));
      return target.id;
  }
}

class _UnknownBarcodeSheet extends StatelessWidget {
  const _UnknownBarcodeSheet({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.lowStock.container,
                  borderRadius: AppRadius.mdAll,
                ),
                child: Icon(
                  LucideIcons.scanBarcode,
                  color: AppColors.lowStock.solid,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.scanUnknownTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    SelectableText(
                      code,
                      style: AppTypography.numeric.copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.scanUnknownBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: l10n.scanUnknownCreate,
            icon: LucideIcons.plus,
            onPressed: () => Navigator.of(context).pop(_UnknownChoice.create),
          ),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: l10n.scanUnknownLink,
            icon: LucideIcons.link,
            onPressed: () => Navigator.of(context).pop(_UnknownChoice.link),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.actionCancel),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// How much, when a scan cannot say.
// -----------------------------------------------------------------------------

/// Asks how much of a weighed product a scan was — the 25 kg sack of flour.
/// Returns null when dismissed.
Future<double?> askScanQuantity(
  BuildContext context, {
  required ItemRowView row,
  required String title,
  double initial = 1,
}) {
  return showDialog<double>(
    context: context,
    builder: (context) =>
        _QuantityDialog(row: row, title: title, initial: initial),
  );
}

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({
    required this.row,
    required this.title,
    required this.initial,
  });

  final ItemRowView row;
  final String title;
  final double initial;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late double _value = widget.initial;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Straight into the figure: the person has the scale's reading in their
    // head and nothing else to do here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_value > 0) Navigator.of(context).pop(_value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final item = widget.row.item;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ProductImage(imagePath: item.imagePath, size: 48, radius: 10),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: theme.textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.row.categoryName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            QuantityStepper(
              value: _value,
              unitAbbreviation: widget.row.unitAbbreviation,
              onChanged: (value) => setState(() => _value = value),
              focusNode: _focus,
              textInputAction: TextInputAction.done,
              onSubmitted: _confirm,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _value > 0 ? _confirm : null,
          child: Text(l10n.scanQuantityConfirm),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// The scan bar on a form.
// -----------------------------------------------------------------------------

/// « Scanner ou saisir un code-barres », and the camera beside it where there
/// is one — the way into a movement form for anything that has a code.
///
/// Three ways in, one flow: the field (typed, or a handheld scanner while it
/// has focus), a handheld scanner with nothing focused (the
/// [HardwareScanListener] this carries), and the camera.
class BarcodeScanBar extends ConsumerStatefulWidget {
  const BarcodeScanBar({
    required this.storeId,
    required this.onItem,
    super.key,
  });

  final String storeId;
  final ScannedItemHandler onItem;

  @override
  ConsumerState<BarcodeScanBar> createState() => _BarcodeScanBarState();
}

class _BarcodeScanBarState extends ConsumerState<BarcodeScanBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _run(String code, {bool fromField = false}) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await handleScannedCode(
        context,
        ref,
        storeId: widget.storeId,
        code: trimmed,
        onItem: widget.onItem,
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _controller.clear();
        // Ready for the next one when it came through the field.
        if (fromField) _focus.requestFocus();
      }
    }
  }

  Future<void> _camera() async {
    await scanWithCamera(
      context,
      ref,
      storeId: widget.storeId,
      onItem: widget.onItem,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final field = TextField(
      controller: _controller,
      focusNode: _focus,
      enabled: !_busy,
      textInputAction: TextInputAction.done,
      keyboardType: TextInputType.number,
      onSubmitted: (value) => _run(value, fromField: true),
      decoration: searchFieldDecoration(context, hint: l10n.scanFieldHint)
          .copyWith(
            prefixIcon: const Icon(LucideIcons.scanBarcode),
            suffixIcon: _busy
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: l10n.scanFieldSubmit,
                    icon: const Icon(LucideIcons.cornerDownLeft),
                    onPressed: () => _run(_controller.text, fromField: true),
                  ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: AppRadius.mdAll,
              borderSide: BorderSide(color: AppColors.border),
            ),
            disabledBorder: const OutlineInputBorder(
              borderRadius: AppRadius.mdAll,
              borderSide: BorderSide(color: AppColors.border),
            ),
          ),
    );

    return HardwareScanListener(
      enabled: !_busy,
      onScan: _run,
      child: Row(
        children: [
          Expanded(child: field),
          if (cameraScanAvailable) ...[
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              height: AppSizing.minTapTarget,
              child: FilledButton.icon(
                onPressed: _busy ? null : _camera,
                icon: const Icon(LucideIcons.scanLine, size: AppSizing.iconSm),
                label: Text(l10n.scanCameraButton),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
