import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/device_access.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/auth_layout.dart';
import '../widgets/auth_notice.dart';

/// An account device whose restaurant data has not arrived yet
/// (SYNC_PLAN.md, Phase 4): a manager who just joined, or an owner on a
/// second tablet. The first sync (Phase 6) brings the data and this screen
/// gives way to the employee login.
class AccountWaitingPage extends ConsumerStatefulWidget {
  const AccountWaitingPage({super.key});

  @override
  ConsumerState<AccountWaitingPage> createState() => _AccountWaitingPageState();
}

class _AccountWaitingPageState extends ConsumerState<AccountWaitingPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final access = ref.watch(deviceAccessProvider);

    return AuthLayout(
      title: l10n.waitingTitle,
      children: [
        AuthNotice.info(l10n.waitingBody(access.organizationName ?? '')),
        if (access.accountEmail != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.setupSignedInAs(access.accountEmail!),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        SecondaryButton(
          label: l10n.accountSignOut,
          icon: LucideIcons.logOut,
          fullWidth: true,
          onPressed: _busy ? null : _signOut,
        ),
      ],
    );
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    await ref.read(deviceAccessProvider.notifier).signOutAccount();
    if (!mounted) return;
    context.goSection(Routes.welcome);
  }
}
