import 'package:flutter/material.dart';

import '../../../infra/blocking/blocking-platform-service.dart';
import '../../../shared/design/atoms/app-button.dart';
import '../../../shared/design/atoms/app-text.dart';
import '../../../shared/design/atoms/app-wasm-badge.dart';
import '../../../shared/design/molecules/app-card.dart';
import '../../../shared/design/organisms/app-scaffold.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-radii.dart';
import '../../../shared/design/tokens/app-spacing.dart';
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
      // The native picker owns selection on iOS. Keep the Nashaat surface
      // visible underneath it, then return to Focus when it closes.
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
    final query = _search.text.trim().toLowerCase();
    return _vm.installedApps
        .where((app) => app.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: SafeArea(
        child: _vm.isIos ? _buildIos(context) : _buildAndroid(context),
      ),
    );
  }

  Widget _buildIos(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PickerHeader(onBack: () => Navigator.of(context).maybePop()),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 270),
              child: AppText.body(
                'Choose apps using iPhone Screen Time. They lock when your time runs out.',
                color: context.nashaatPalette.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _AppSwatchGrid(),
          const SizedBox(height: AppSpacing.lg),
          _PickerNote(text: 'Apple shows its own list after this.'),
          const SizedBox(height: AppSpacing.lg),
          AppButton.primary(
            'Choose apps',
            onPressed: () async {
              await _vm.openIosPicker();
              if (context.mounted) Navigator.of(context).pop([]);
            },
            width: double.infinity,
          ),
        ],
      ),
    );
  }

  Widget _buildAndroid(BuildContext context) {
    final palette = context.nashaatPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 0),
          child: _PickerHeader(
            onBack: () => Navigator.of(context).maybePop(),
            trailing: _selected.isEmpty
                ? null
                : AppText.bodyMuted('${_selected.length} selected'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Search apps',
              prefixIcon: Icon(Icons.search, color: palette.textMuted),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                      icon: Icon(Icons.close, color: palette.textMuted),
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: ListenableBuilder(
            listenable: _vm,
            builder: (_, _) {
              if (_isLoading) {
                return Center(
                  child: CircularProgressIndicator(color: palette.accent),
                );
              }
              final apps = _filtered;
              if (apps.isEmpty) {
                return Center(
                  child: AppText.bodyMuted(
                    _vm.installedApps.isEmpty
                        ? 'No apps found.'
                        : 'No apps match your search.',
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                itemCount: apps.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, index) {
                  final app = apps[index];
                  final checked = _selected.contains(app);
                  return _AndroidAppRow(
                    app: app,
                    checked: checked,
                    onTap: () => setState(() {
                      if (checked) {
                        _selected.remove(app);
                      } else {
                        _selected.add(app);
                      }
                    }),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: AppButton.primary(
            _selected.isEmpty
                ? 'Choose apps'
                : 'Choose apps (${_selected.length})',
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.of(context).pop(_selected.toList()),
            width: double.infinity,
          ),
        ),
      ],
    );
  }
}

class _PickerHeader extends StatelessWidget {
  final VoidCallback onBack;
  final Widget? trailing;

  const _PickerHeader({required this.onBack, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: onBack,
          tooltip: 'Back',
          padding: EdgeInsets.zero,
          alignment: AlignmentDirectional.topStart,
          icon: const Icon(Icons.arrow_back, size: 28),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: AppText.hero('Select\napps')),
        if (trailing != null)
          Padding(padding: const EdgeInsets.only(top: 10), child: trailing!),
      ],
    );
  }
}

class _AppSwatchGrid extends StatelessWidget {
  const _AppSwatchGrid();

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    final colors = [
      palette.locked,
      palette.dangerText,
      palette.calmText,
      palette.saduBrown,
      palette.reward,
      palette.accentText,
      palette.saduRed,
      palette.textMuted,
      palette.saduBrown.withValues(alpha: 0.9),
      palette.lockedText,
      palette.calm,
      palette.locked,
    ];
    const lockedIndexes = {0, 2, 5, 9};
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: colors.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (_, index) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors[index],
                borderRadius: AppRadii.card,
              ),
              child: const SizedBox.expand(),
            ),
            if (lockedIndexes.contains(index))
              PositionedDirectional(
                end: -4,
                bottom: -4,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: palette.lockedText,
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.background, width: 3),
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PickerNote extends StatelessWidget {
  final String text;

  const _PickerNote({required this.text});

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.calm.withValues(alpha: 0.10),
        border: Border.all(color: palette.calmText),
        borderRadius: AppRadii.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: palette.calmText),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: AppText.body(text, color: palette.textSecondary)),
        ],
      ),
    );
  }
}

class _AndroidAppRow extends StatelessWidget {
  final InstalledApp app;
  final bool checked;
  final VoidCallback onTap;

  const _AndroidAppRow({
    required this.app,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    final label = app.name.isEmpty ? '?' : app.name.substring(0, 1);
    return AppCard.standard(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
      onTap: onTap,
      child: Row(
        children: [
          AppWasmBadge(label: label.toUpperCase(), size: 42),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText.body(app.name),
                AppText.mono(
                  app.packageId,
                  color: palette.textMuted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _SelectionMark(checked: checked),
        ],
      ),
    );
  }
}

class _SelectionMark extends StatelessWidget {
  final bool checked;

  const _SelectionMark({required this.checked});

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: checked ? palette.accent : Colors.transparent,
        border: Border.all(
          color: checked ? palette.accent : palette.border,
          width: 1.5,
        ),
        borderRadius: AppRadii.control,
      ),
      child: checked
          ? Icon(Icons.check, size: 18, color: palette.accentInk)
          : null,
    );
  }
}
