import 'package:flutter/material.dart';

import '../../../infra/blocking/blocking-platform-service.dart';
import '../view_model/blocking-view-model.dart';

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
    _load();
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
        appBar: AppBar(title: const Text('Select Apps')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.phone_iphone, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Tap the button below to choose apps\nusing iOS Screen Time.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Choose Apps'),
                onPressed: () async {
                  await _vm.openIosPicker();
                  if (context.mounted) Navigator.of(context).pop([]);
                },
              ),
            ],
          ),
        ),
      );
    }

    // Android: searchable list
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Apps'),
        actions: [
          TextButton(
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.of(context).pop(_selected.toList()),
            child: Text(
              _selected.isEmpty
                  ? 'Done'
                  : 'Done (${_selected.length})',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SearchBar(
              controller: _search,
              hintText: 'Search apps…',
              leading: const Icon(Icons.search),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_vm.installedApps.isEmpty)
            const Expanded(
              child: Center(child: Text('No apps found.')),
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
                      return CheckboxListTile(
                        title: Text(app.name),
                        subtitle: Text(
                          app.packageId,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        value: checked,
                        onChanged: (_) => setState(() {
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
        ],
      ),
    );
  }
}
