import '../../../app/app-coordinator.dart';
import '../view-model/auth-view-model.dart';

class AuthCoordinator {
  final AppCoordinator _app;

  const AuthCoordinator(this._app);

  /// Called after any successful authentication. Clears the auth stack and
  /// routes to onboarding (new / un-onboarded users) or the dashboard.
  void handleAuthSuccess(AuthViewModel vm) {
    if (vm.needsOnboarding) {
      _app.showOnboarding();
    } else {
      _app.showDashboard();
    }
  }
}
