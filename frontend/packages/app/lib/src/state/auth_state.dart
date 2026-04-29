import 'package:core/core.dart';
import 'package:flutter/foundation.dart';

class AuthState extends ChangeNotifier {
  final ApiClient _api;
  String? _token;
  bool _loading = false;
  String? _error;

  AuthState(this._api);

  bool get isLoggedIn => _token != null;
  bool get isLoading => _loading;
  String? get error => _error;

  Future<void> login({required String email, required String password}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _token = await _api.login(email: email, password: password);
    } catch (e) {
      _error = 'Login failed';
      _token = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void logout() {
    _token = null;
    _api.setAccessToken(null);
    notifyListeners();
  }
}

