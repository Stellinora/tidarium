import '../plugin/plugin.dart';

abstract interface class AuthManager {
  Future<AuthState> restore(String pluginId);

  Future<AuthState> authenticate(String pluginId);

  Future<void> signOut(String pluginId);
}
