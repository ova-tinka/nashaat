import '../../../app/app-coordinator.dart';

class SettingsCoordinator {
  final AppCoordinator _app;

  SettingsCoordinator(this._app);

  void goToLogin() => _app.showLogin();
}
