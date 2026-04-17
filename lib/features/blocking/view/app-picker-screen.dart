import 'package:flutter/material.dart';

import '../../../infra/blocking/blocking-platform-service.dart';
import '../../../shared/design/atoms/app-button.dart';
import '../../../shared/design/atoms/app-divider.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-spacing.dart';
import '../../../shared/design/tokens/app-typography.dart';
import '../view-model/blocking-view-model.dart';

/// Android: searchable list of installed apps for multi-select.
/// iOS: button that opens the native FamilyActivityPicker sheet.
class AppPickerScreen extends StatefulWidget {
  final BlockingViewModel vm;

  const AppPickerScreen({super.key, required this.vm});

  @override
  State<AppPickerScreen> createState() => _AppPickerScreenState();
}

class _AppPickerScreenState extends State<AppPickerScreen> {
  final _search = TextEditingController();
  final _selected = <InstalledApp>{};
  bool _isLoading = true;

  BlockingViewModel get _vm => widget.vm;

  @override
  void initState() {
    super.initState();
    if (_vm.isIos) {
      // On iOS the native picker does everything — skip this screen entirely.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _vm.openIosPicker();
        if (mounted) Navigator.of(context).pop([]);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _vm.loadInstalledApps();
    if (mounted) setState(() => _isLoading = false);
  }

  List<InstalledApp> get _filtered {
    final query = _search.text.toLowerCase();
    return _vm.installedApps
        .where((a) => a.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // iOS: native picker
    if (_vm.isIos) {
      return Scaffold(
        backgroundColor: AppColors.paper,
        appBar: AppBar(
          backgroundColor: AppColors.paper,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          title: Text(
            'SELECT APPS',
            style: AppTypography.sectionHeader.copyWith(fontSize: 13, letterSpacing: 2),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: AppDivider(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  color: AppColors.paperAlt,
                  child: const Icon(Icons.phone_iphone, size: 40, color: AppColors.inkMuted),
                ),
                const SizedBox(height: AppSpacing.base),
                Text(
                  'Choose apps using iOS Screen Time.',
                  style: AppTypography.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton.primary(
                  'Choose Apps',
                  icon: Icons.add,
                  onPressed: () async {
                    await _vm.openIosPicker();
                    if (context.mounted) Navigator.of(context).pop([]);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Android: searchable list
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text(
          'SELECT APPS',
          style: AppTypography.sectionHeader.copyWith(fontSize: 13, letterSpacing: 2),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: AppButton.primary(
              _selected.isEmpty ? 'Done' : 'Done (${_selected.length})',
              onPressed: _selected.isEmpty
                  ? null
                  : () => Navigator.of(context).pop(_selected.toList()),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: AppDivider(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.base, AppSpacing.sm, AppSpacing.base, 0,
            ),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search apps...',
                hintStyle: AppTypography.labelMuted,
                prefixIcon: const Icon(Icons.search, color: AppColors.inkMuted, size: 18),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const AppDivider(),
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator(color: AppColors.ink)),
            )
          else if (_vm.installedApps.isEmpty)
            Expanded(
              child: Center(
                child: Text('No apps found.', style: AppTypography.labelMuted),
              ),
            )
          else
            Expanded(
              child: ListenableBuilder(
                listenable: _vm,
                builder: (_, _) {
                  final apps = _filtered;
                  return ListView.builder(
                    itemCount: apps.length,
                    itemBuilder: (_, i) {
                      final app = apps[i];
                      final checked = _selected.contains(app);
                      return InkWell(
                        onTap: () => setState(() {
                          if (checked) {
                            _selected.remove(app);
                          } else {
                            _selected.add(app);
                          }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.base, vertical: AppSpacing.md,
                          ),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: AppColors.paperBorder),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: checked ? AppColors.ink : AppColors.paper,
                                  border: Border.all(
                                    color: checked ? AppColors.ink : AppColors.paperBorder,
                                  ),
                                ),
                                child: checked
                                    ? const Icon(Icons.check, size: 14, color: AppColors.paper)
                                    : null,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(app.name, style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
                                    Text(app.packageId, style: AppTypography.labelMuted),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
