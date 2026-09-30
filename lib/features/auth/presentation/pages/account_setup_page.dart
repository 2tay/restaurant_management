import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/credential_status.dart';
import '../../../../core/utils/permissions.dart';
import '../../../../data/device_access.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/auth_service.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/auth_layout.dart';
import '../widgets/auth_notice.dart';

/// The step after signing up (SYNC_PLAN.md, Phase 4): an account with no
/// restaurant either creates one (it becomes the owner) or joins one with the
/// code an owner gave (it becomes a manager).
class AccountSetupPage extends ConsumerStatefulWidget {
  const AccountSetupPage({super.key});

  @override
  ConsumerState<AccountSetupPage> createState() => _AccountSetupPageState();
}

class _AccountSetupPageState extends ConsumerState<AccountSetupPage> {
  late final Future<AccountSummary?> _summary = ref
      .read(deviceAccessProvider.notifier)
      .currentSummary()
      .catchError((Object _) => null);

  bool _joining = false;
  bool _busy = false;
  String? _error;

  /// The device's own establishments, when it holds some (Phase 9). Empty
  /// for a fresh install or the demo.
  List<String> _ownStores = const [];

  /// Create the restaurant from the device's own data, rather than empty.
  bool _useLocalData = true;

  @override
  void initState() {
    super.initState();
    _loadOwnStores();
  }

  Future<void> _loadOwnStores() async {
    final controller = ref.read(deviceAccessProvider.notifier);
    if (await controller.localData() != LocalDataKind.own) return;
    final names = await controller.ownStoreNames();
    if (mounted) setState(() => _ownStores = names);
  }

  bool get _fromLocalData => !_joining && _ownStores.isNotEmpty && _useLocalData;

  final _restaurant = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _pin = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();

  @override
  void dispose() {
    for (final controller in [
      _restaurant,
      _city,
      _phone,
      _firstName,
      _lastName,
      _pin,
      _password,
      _code,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return FutureBuilder<AccountSummary?>(
      future: _summary,
      builder: (context, snapshot) {
        final summary = snapshot.data;
        final loading = snapshot.connectionState != ConnectionState.done;
        return AuthLayout(
          title: l10n.setupTitle,
          subtitle: l10n.setupSubtitle,
          children: [
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (summary == null) ...[
              AuthNotice.info(l10n.setupNotSignedIn),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: l10n.accountSignIn,
                icon: LucideIcons.logIn,
                fullWidth: true,
                onPressed: () => context.goSection(Routes.welcome),
              ),
            ] else ...[
              Text(
                l10n.setupSignedInAs(summary.email),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text(l10n.setupCreateTab),
                    icon: const Icon(LucideIcons.store),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text(l10n.setupJoinTab),
                    icon: const Icon(LucideIcons.ticket),
                  ),
                ],
                selected: {_joining},
                onSelectionChanged: (value) => setState(() {
                  _joining = value.first;
                  _error = null;
                }),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (_ownStores.isNotEmpty) ...[
                AuthNotice.info(
                  _joining
                      ? l10n.existingDataJoinNotice(_ownStores.join(', '))
                      : l10n.existingDataOnDevice(_ownStores.join(', ')),
                ),
                const SizedBox(height: AppSpacing.md),
                if (!_joining) ...[
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: true,
                        label: Text(l10n.existingDataUse),
                        icon: const Icon(LucideIcons.cloudUpload),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text(l10n.existingDataStartEmpty),
                        icon: const Icon(LucideIcons.archive),
                      ),
                    ],
                    selected: {_useLocalData},
                    onSelectionChanged: (value) => setState(() {
                      _useLocalData = value.first;
                      _error = null;
                    }),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ] else if (ref.watch(deviceAccessProvider).mode ==
                  DeviceMode.demo) ...[
                AuthNotice.info(l10n.accountDemoWipeWarning),
                const SizedBox(height: AppSpacing.lg),
              ],
              ...(_joining
                  ? _joinForm(l10n)
                  : _fromLocalData
                  ? _nameOnlyForm(l10n)
                  : _createForm(l10n)),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                AuthNotice.error(_error!),
              ],
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: _joining ? l10n.setupJoinSubmit : l10n.setupCreateSubmit,
                icon: _joining ? LucideIcons.logIn : LucideIcons.store,
                fullWidth: true,
                large: true,
                isBusy: _busy,
                onPressed: _busy ? null : (_joining ? _join : _create),
              ),
            ],
          ],
        );
      },
    );
  }

  List<Widget> _createForm(AppLocalizations l10n) => [
    AppTextField(
      label: l10n.setupRestaurantName,
      controller: _restaurant,
      prefixIcon: LucideIcons.store,
      textInputAction: TextInputAction.next,
    ),
    const SizedBox(height: AppSpacing.lg),
    AppTextField(
      label: l10n.setupCity,
      controller: _city,
      prefixIcon: LucideIcons.mapPin,
      textInputAction: TextInputAction.next,
    ),
    const SizedBox(height: AppSpacing.lg),
    AppTextField(
      label: l10n.setupPhone,
      controller: _phone,
      prefixIcon: LucideIcons.phone,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
    ),
    const SizedBox(height: AppSpacing.lg),
    AppTextField(
      label: l10n.setupFirstName,
      controller: _firstName,
      prefixIcon: LucideIcons.user,
      textInputAction: TextInputAction.next,
    ),
    const SizedBox(height: AppSpacing.lg),
    AppTextField(
      label: l10n.setupLastName,
      controller: _lastName,
      prefixIcon: LucideIcons.user,
      textInputAction: TextInputAction.next,
    ),
    const SizedBox(height: AppSpacing.lg),
    AppTextField(
      label: l10n.setupPin,
      helperText: l10n.setupPinHint,
      controller: _pin,
      prefixIcon: LucideIcons.idCard,
      textInputAction: TextInputAction.next,
    ),
    const SizedBox(height: AppSpacing.lg),
    AppTextField(
      label: l10n.setupEmployeePassword,
      controller: _password,
      prefixIcon: LucideIcons.lock,
      obscureText: true,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(AuthRules.passwordLength),
      ],
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _create(),
    ),
  ];

  /// Creating from the device's own data: only the restaurant's name; its
  /// establishments and staff are already here.
  List<Widget> _nameOnlyForm(AppLocalizations l10n) => [
    AppTextField(
      label: l10n.setupRestaurantName,
      controller: _restaurant,
      prefixIcon: LucideIcons.store,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _create(),
    ),
  ];

  List<Widget> _joinForm(AppLocalizations l10n) => [
    AppTextField(
      label: l10n.setupJoinCode,
      helperText: l10n.setupJoinCodeHint,
      controller: _code,
      prefixIcon: LucideIcons.ticket,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _join(),
    ),
  ];

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    if (_fromLocalData) {
      if (_restaurant.text.trim().isEmpty) {
        setState(() => _error = l10n.setupFieldsRequired);
        return;
      }
      await _run(() async {
        await ref
            .read(deviceAccessProvider.notifier)
            .createRestaurantFromLocalData(_restaurant.text);
        if (!mounted) return;
        AppSnackBar.success(context, l10n.existingDataSent);
        context.goSection(Routes.login);
      });
      return;
    }
    final required = [
      _restaurant,
      _city,
      _phone,
      _firstName,
      _lastName,
      _pin,
      _password,
    ];
    if (required.any((c) => c.text.trim().isEmpty)) {
      setState(() => _error = l10n.setupFieldsRequired);
      return;
    }
    if (!isValidPassword(_password.text)) {
      setState(() => _error = l10n.setupPasswordFormat);
      return;
    }

    await _run(() async {
      await _backupOwnData();
      final owner = await ref
          .read(deviceAccessProvider.notifier)
          .createRestaurant(
            restaurantName: _restaurant.text,
            city: _city.text,
            phone: _phone.text,
            firstName: _firstName.text,
            lastName: _lastName.text,
            pin: _pin.text,
            password: _password.text,
          );
      if (!mounted) return;
      context.goSection(
        can(owner.role, Capability.spanAllStores)
            ? Routes.stores
            : Routes.toDashboard(owner.storeId),
      );
    });
  }

  Future<void> _join() async {
    final l10n = AppLocalizations.of(context);
    if (_code.text.trim().isEmpty) {
      setState(() => _error = l10n.setupFieldsRequired);
      return;
    }
    await _run(() async {
      await _backupOwnData();
      await ref.read(deviceAccessProvider.notifier).joinWithCode(_code.text);
      if (!mounted) return;
      context.goSection(Routes.login);
    });
  }

  /// Before the device's own data is replaced, a copy goes to a file, and
  /// the screen says where.
  Future<void> _backupOwnData() async {
    if (_ownStores.isEmpty) return;
    final file = await ref.read(deviceAccessProvider.notifier).backupLocalData();
    if (!mounted) return;
    AppSnackBar.success(
      context,
      AppLocalizations.of(context).existingDataBackedUp(file.path),
    );
  }

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
