import '../../../app/app-coordinator.dart';

class DashboardCoordinator {
  final AppCoordinator _app;

  DashboardCoordinator(this._app);

  void goToSettings() => _app.showSettings();

  void goToWorkoutBuilder() => _app.showWorkoutBuilder();
}
