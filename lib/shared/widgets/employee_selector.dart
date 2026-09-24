import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/employee_status.dart';
import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import 'employee_avatar.dart';
import 'search_field.dart';

/// Pick one employee by name or PIN — the combobox the pointage board and the
/// two history pages share instead of each rolling its own search + dropdown.
///
/// Closed, it shows the chosen person (avatar + name) or the hint. Open, it is
/// a search box over a scrollable list of rows: avatar, name, and — only when
/// [showPin] — the PIN. Typing filters on name **or** PIN either way. The ✕
/// clears the selection.
///
/// [showPin] defaults to false: on the shared kiosk the PIN must not be on
/// screen (it is what confirms an action). The admin history pages pass true.
///
/// [searchBar] draws the closed state as the Personnel page's search bar
/// (see `searchFieldDecoration`): one types straight into it and the matching
/// people drop down beneath — no second search box inside the list.
class EmployeeSelector extends StatefulWidget {
  const EmployeeSelector({
    required this.employees,
    required this.value,
    required this.onChanged,
    this.showPin = false,
    this.hint,
    this.searchBar = false,
    super.key,
  });

  final List<Employee> employees;
  final Employee? value;
  final ValueChanged<Employee?> onChanged;
  final bool showPin;
  final String? hint;
  final bool searchBar;

  @override
  State<EmployeeSelector> createState() => _EmployeeSelectorState();
}

class _EmployeeSelectorState extends State<EmployeeSelector> {
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  double _fieldWidth = 280;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<Employee> get _filtered {
    final sorted = [...widget.employees]
      ..sort((a, b) => employeeDisplayName(a).compareTo(employeeDisplayName(b)));
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return sorted;
    return sorted
        .where(
          (e) =>
              employeeDisplayName(e).toLowerCase().contains(q) ||
              e.pin.toLowerCase().contains(q),
        )
        .toList();
  }

  void _open() {
    _portal.show();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _searchFocus.requestFocus(),
    );
  }

  void _close() {
    _portal.hide();
    _searchController.clear();
    if (widget.searchBar) _searchFocus.unfocus();
    setState(() => _query = '');
  }

  void _select(Employee? employee) {
    widget.onChanged(employee);
    _close();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.searchBar) return _buildSearchBar(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.hasBoundedWidth) _fieldWidth = constraints.maxWidth;
        return CompositedTransformTarget(
          link: _link,
          child: OverlayPortal(
            controller: _portal,
            overlayChildBuilder: _buildOverlay,
            child: _ClosedField(
              value: widget.value,
              hint: widget.hint,
              onTap: () => _portal.isShowing ? _close() : _open(),
              onClear: widget.value == null ? null : () => _select(null),
            ),
          ),
        );
      },
    );
  }

  /// The [searchBar] variant: the input *is* the closed field. A [TapRegion]
  /// spans the field and the list, so a click back into the text keeps the
  /// list open and only a click elsewhere closes it.
  Widget _buildSearchBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final employee = widget.value;

    final Widget field = employee == null
        ? TextField(
            key: const ValueKey('employee-selector-search'),
            controller: _searchController,
            focusNode: _searchFocus,
            textInputAction: TextInputAction.search,
            onTap: () {
              if (!_portal.isShowing) _portal.show();
            },
            onChanged: (v) {
              if (!_portal.isShowing) _portal.show();
              setState(() => _query = v);
            },
            decoration: searchFieldDecoration(
              context,
              hint: widget.hint ?? l10n.employeesSearchHint,
            ),
          )
        : _SelectedSearchBar(
            employee: employee,
            showPin: widget.showPin,
            onClear: () => widget.onChanged(null),
          );

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppSizing.searchFieldMaxWidth,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.hasBoundedWidth) {
              _fieldWidth = constraints.maxWidth;
            }
            return TapRegion(
              groupId: this,
              onTapOutside: (_) {
                if (_portal.isShowing) _close();
              },
              child: CompositedTransformTarget(
                link: _link,
                child: OverlayPortal(
                  controller: _portal,
                  overlayChildBuilder: _buildOverlay,
                  child: field,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final results = _filtered;
    final searchBar = widget.searchBar;

    return Stack(
      children: [
        // The search-bar variant closes through its TapRegion instead: a
        // full-screen barrier would swallow the click back into the text.
        if (!searchBar)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
            ),
          ),
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, AppSpacing.xs),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: _fieldWidth,
              child: TapRegion(
                groupId: this,
                child: Material(
                  elevation: 8,
                  color: AppColors.surface,
                  surfaceTintColor: Colors.transparent,
                  borderRadius: AppRadius.mdAll,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!searchBar) ...[
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocus,
                              onChanged: (v) => setState(() => _query = v),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: widget.hint ?? l10n.employeesSearchHint,
                                prefixIcon: const Icon(
                                  LucideIcons.search,
                                  size: AppSizing.iconSm,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                        ],
                        Flexible(
                          child: results.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(AppSpacing.lg),
                                  child: Text(
                                    l10n.emptyStateNoResultsTitle,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  itemCount: results.length,
                                  itemBuilder: (context, i) => _OptionRow(
                                    key: ValueKey(
                                      'employee-option-${results[i].id}',
                                    ),
                                    employee: results[i],
                                    selected: results[i].id == widget.value?.id,
                                    showPin: widget.showPin,
                                    onTap: () => _select(results[i]),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The search bar once someone is picked: same white, borderless box, their
/// avatar and name in place of the placeholder, and a clear button that drops
/// the pick and gives the empty search back.
class _SelectedSearchBar extends StatelessWidget {
  const _SelectedSearchBar({
    required this.employee,
    required this.showPin,
    required this.onClear,
  });

  final Employee employee;
  final bool showPin;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      key: const ValueKey('employee-selector-selected'),
      constraints: const BoxConstraints(minHeight: AppSizing.minTapTarget),
      padding: const EdgeInsets.only(left: AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          EmployeeAvatar(employee: employee, size: 28),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    employeeDisplayName(employee),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                if (showPin) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      employee.pin,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(LucideIcons.x, size: AppSizing.iconSm),
            tooltip: l10n.actionClear,
          ),
        ],
      ),
    );
  }
}

class _ClosedField extends StatelessWidget {
  const _ClosedField({
    required this.value,
    required this.hint,
    required this.onTap,
    required this.onClear,
  });

  final Employee? value;
  final String? hint;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final employee = value;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSizing.minTapTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            if (employee == null)
              const Icon(
                LucideIcons.search,
                size: AppSizing.iconSm,
                color: AppColors.textSecondary,
              )
            else
              EmployeeAvatar(employee: employee, size: 24),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                employee == null
                    ? (hint ?? l10n.employeeSelectorHint)
                    : employeeDisplayName(employee),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: employee == null
                      ? AppColors.textDisabled
                      : AppColors.textPrimary,
                ),
              ),
            ),
            if (onClear != null)
              IconButton(
                onPressed: onClear,
                icon: const Icon(LucideIcons.x, size: AppSizing.iconSm),
                tooltip: l10n.actionClear,
                visualDensity: VisualDensity.compact,
              )
            else
              const Icon(
                LucideIcons.chevronDown,
                size: AppSizing.iconSm,
                color: AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.employee,
    required this.selected,
    required this.showPin,
    required this.onTap,
    super.key,
  });

  final Employee employee;
  final bool selected;
  final bool showPin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? AppColors.surfaceVariant : null,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            EmployeeAvatar(employee: employee, size: 28),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    employeeDisplayName(employee),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (showPin)
                    Text(
                      employee.pin,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                LucideIcons.check,
                size: AppSizing.iconSm,
                color: AppColors.primary600,
              ),
          ],
        ),
      ),
    );
  }
}
