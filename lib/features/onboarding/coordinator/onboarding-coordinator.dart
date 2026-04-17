import '../../../app/app-coordinator.dart';

class OnboardingCoordinator {
  final AppCoordinator _app;

  OnboardingCoordinator(this._app);

  void done() => _app.showDashboard();
}
