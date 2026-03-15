import 'package:flutter/material.dart';

import '../../../app/app-coordinator.dart';
import '../view/app-picker-screen.dart';
import '../view_model/blocking-view-model.dart';

class BlockingCoordinator {
  final AppCoordinator _app;

  const BlockingCoordinator(this._app);

  Future<void> showAppPicker(
    BuildContext context,
    BlockingViewModel vm,
  ) async {
    final selected = await Navigator.of(context).push<List<dynamic>>(
      MaterialPageRoute(builder: (_) => AppPickerScreen(vm: vm)),
    );
    if (selected != null && selected.isNotEmpty) {
      await vm.addRules(selected.cast());
    }
  }

  void pop() => _app.pop();
}
