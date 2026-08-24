import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../shared/widgets/widgets.dart';

/// Create a new store.
///
/// Saves nothing — Phase 1 has no persistence. Submitting confirms and returns
/// to the selector, which is enough to demo the flow.
class AddStorePage extends StatefulWidget {
  const AddStorePage({super.key});

  @override
  State<AddStorePage> createState() => _AddStorePageState();
}

class _AddStorePageState extends State<AddStorePage> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _postalCode = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    for (final controller in [_name, _address, _postalCode, _city, _phone]) {
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Belgian postal codes are always four digits, so
                            // the field is sized for exactly that rather than
                            // sharing the row evenly.
                            SizedBox(
                              width: 160,
                              child: AppTextField(
                                label: l10n.addStorePostalCode,
                                controller: _postalCode,
                                hint: '1000',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(
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
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SecondaryButton(
                        label: l10n.actionCancel,
                        onPressed: () => context.goSection(Routes.stores),
                      ),
                      const SizedBox(width: AppSpacing.md),
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

  void _submit() {
    final l10n = AppLocalizations.of(context);

    // Starts with no categories, units, items or suppliers — correct rather
    // than lazy, since all four are per-store by design. What the user sees
    // next is every empty state in the app, doing its job.
    AccountMutations.createStore(
      name: _name.text,
      addressLine: _address.text,
      postalCode: _postalCode.text,
      city: _city.text,
      phone: _phone.text,
    );

    AppSnackBar.success(context, l10n.addStoreCreated);
    context.goSection(Routes.stores);
  }
}
