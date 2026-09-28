import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/widgets.dart';

/// Create a new store.
///
/// The new establishment is written and the selector shows it on the way back —
/// the grid is watching the same table.
class AddStorePage extends ConsumerStatefulWidget {
  const AddStorePage({super.key});

  @override
  ConsumerState<AddStorePage> createState() => _AddStorePageState();
}

class _AddStorePageState extends ConsumerState<AddStorePage> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _postalCode = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();
  final _vatNumber = TextEditingController();

  @override
  void dispose() {
    for (final controller in [
      _name,
      _address,
      _postalCode,
      _city,
      _phone,
      _vatNumber,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _canSubmit => _name.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextButton.icon(
                    onPressed: () => context.goSection(Routes.stores),
                    icon: const Icon(LucideIcons.arrowLeft),
                    label: Text(l10n.actionBack),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.addStoreTitle,
                    style: theme.textTheme.headlineLarge,
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  AppCard(
                    child: Column(
                      children: [
                        AppTextField(
                          label: l10n.addStoreName,
                          controller: _name,
                          hint: l10n.addStoreNameHint,
                          autofocus: true,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(
                          label: l10n.addStoreAddress,
                          controller: _address,
                          prefixIcon: LucideIcons.mapPin,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AdaptiveRow(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: AppSpacing.lg,
                          runSpacing: AppSpacing.lg,
                          cells: [
                            // Belgian postal codes are always four digits, so
                            // the field is sized for exactly that rather than
                            // sharing the row evenly — until the row has to
                            // stack, where both fields take the full width.
                            AdaptiveCell(
                              width: 160,
                              child: AppTextField(
                                label: l10n.addStorePostalCode,
                                controller: _postalCode,
                                hint: '1000',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            AdaptiveCell(
                              flex: 1,
                              child: AppTextField(
                                label: l10n.addStoreCity,
                                controller: _city,
                                hint: 'Bruxelles',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(
                          label: l10n.addStorePhone,
                          controller: _phone,
                          prefixIcon: LucideIcons.phone,
                          hint: '+32 2 000 00 00',
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        // Last, and optional. It is the only field here that
                        // exists for something outside the app — it prints on
                        // every bon de réception sent to a supplier — and the
                        // helper says so rather than just marking it optional,
                        // because "why does a stock app want my VAT number" is
                        // the obvious question.
                        AppTextField(
                          label: l10n.addStoreVatNumber,
                          controller: _vatNumber,
                          prefixIcon: LucideIcons.receipt,
                          hint: l10n.addStoreVatNumberHint,
                          helperText: l10n.addStoreVatNumberHelp,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.sm,
                    children: [
                      SecondaryButton(
                        label: l10n.actionCancel,
                        onPressed: () => context.goSection(Routes.stores),
                      ),
                      PrimaryButton(
                        label: l10n.addStoreSubmit,
                        icon: LucideIcons.check,
                        // Disabled rather than hidden until the one genuinely
                        // required field is filled.
                        onPressed: _canSubmit ? _submit : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.loginDemoNotice,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textDisabled,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);

    // Starts with no categories, units, items or suppliers — correct rather
    // than lazy, since all four are per-store by design. What the user sees
    // next is every empty state in the app, doing its job.
    await ref
        .read(storeRepositoryProvider)
        .createStore(
          name: _name.text,
          addressLine: _address.text,
          postalCode: _postalCode.text,
          city: _city.text,
          phone: _phone.text,
          vatNumber: _vatNumber.text,
        );

    if (!mounted) return;
    AppSnackBar.success(context, l10n.addStoreCreated);
    context.goSection(Routes.stores);
  }
}
