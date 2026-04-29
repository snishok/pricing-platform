import 'package:core/core.dart';
import 'package:flutter/foundation.dart';

class AuthState extends ChangeNotifier {
  final ApiClient _api;
  String? _token;
  MeResponse? _me;
  bool _loading = false;
  String? _error;

  AuthState(this._api);

  bool get isLoggedIn => _token != null;
  bool get isLoading => _loading;
  String? get error => _error;
  MeResponse? get me => _me;

  bool get canUpload => _me?.role == 'uploader' || _me?.role == 'admin';
  bool get canEdit => _me?.role == 'editor' || _me?.role == 'admin';

  Future<void> login({required String email, required String password}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _token = await _api.login(email: email, password: password);
      _me = await _api.me();
    } catch (e) {
      _error = 'Login failed';
      _token = null;
      _me = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void logout() {
    _token = null;
    _me = null;
    _api.setAccessToken(null);
    notifyListeners();
  }
}

