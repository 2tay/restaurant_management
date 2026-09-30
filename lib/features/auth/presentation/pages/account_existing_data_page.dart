import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/device_access.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/auth_service.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/auth_layout.dart';
import '../widgets/auth_notice.dart';

/// Signing in to an account on a device that already holds the
/// restaurant's own data (SYNC_PLAN.md, Phase 9).
///
/// - The account's restaurant has no data yet: send the device's
///   ("Envoyer mes données"), or start empty after a backup.
/// - It already has data: the device's is saved to a backup file, then
///   replaced by the account's. Nothing is merged automatically.
///
/// Demo data never comes here: joining an account simply clears it.
class AccountExistingDataPage extends ConsumerStatefulWidget {
  const AccountExistingDataPage({super.key});

  @override
  ConsumerState<AccountExistingDataPage> createState() =>
      _AccountExistingDataPageState();
}

class _AccountExistingDataPageState
    extends ConsumerState<AccountExistingDataPage> {
  late final Future<_Situation?> _situation = _load();
  bool _busy = false;
  String? _error;

  Future<_Situation?> _load() async {
    final controller = ref.read(deviceAccessProvider.notifier);
    try {
      final summary = await controller.currentSummary();
      if (summary == null || !summary.hasOrganization) return null;
      return _Situation(
        summary: summary,
        accountHasData: await controller.accountHasData(),
        stores: await controller.ownStoreNames(),
      );
    } on AccountException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return FutureBuilder<_Situation?>(
      future: _situation,
      builder: (context, snapshot) {
        final situation = snapshot.data;
        return AuthLayout(
          title: l10n.existingDataTitle,
          children: [
            if (snapshot.connectionState != ConnectionState.done)
              const Center(child: CircularProgressIndicator())
            else if (situation == null) ...[
              AuthNotice.info(l10n.setupNotSignedIn),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: l10n.accountSignIn,
                icon: LucideIcons.logIn,
                fullWidth: true,
                onPressed: () => context.goSection(Routes.welcome),
              ),
            ] else ...[
              AuthNotice.info(
                situation.accountHasData
                    ? l10n.existingDataAccountFull(
                        situation.summary.organizationName ?? '',
                        situation.stores.join(', '),
                      )
                    : l10n.existingDataAccountEmpty(
                        situation.summary.organizationName ?? '',
                        situation.stores.join(', '),
                      ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                AuthNotice.error(_error!),
              ],
              const SizedBox(height: AppSpacing.xl),
              if (!situation.accountHasData) ...[
                PrimaryButton(
                  label: l10n.existingDataSend,
                  icon: LucideIcons.cloudUpload,
                  fullWidth: true,
                  large: true,
                  isBusy: _busy,
                  onPressed: _busy ? null : () => _send(situation),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              SecondaryButton(
                label: situation.accountHasData
                    ? l10n.existingDataBackupAndContinue
                    : l10n.existingDataStartEmpty,
                icon: LucideIcons.archive,
                fullWidth: true,
                onPressed: _busy ? null : () => _backupAndContinue(situation),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _send(_Situation situation) => _run(() async {
    await ref
        .read(deviceAccessProvider.notifier)
        .adoptLocalData(situation.summary);
    if (!mounted) return;
    AppSnackBar.success(context, AppLocalizations.of(context).existingDataSent);
    context.goSection(Routes.login);
  });

  Future<void> _backupAndContinue(_Situation situation) => _run(() async {
    final file = await ref
        .read(deviceAccessProvider.notifier)
        .backupAndFinish(situation.summary);
    if (!mounted) return;
    AppSnackBar.success(
      context,
      AppLocalizations.of(context).existingDataBackedUp(file.path),
    );
    context.goSection(Routes.login);
  });

  Future<void> _run(Future<void> Function() body) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await body();
    } catch (error) {
      if (mounted) setState(() => _error = accountErrorMessage(l10n, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Situation {
  const _Situation({
    required this.summary,
    required this.accountHasData,
    required this.stores,
  });

  final AccountSummary summary;
  final bool accountHasData;
  final List<String> stores;
}
