import 'package:core/core.dart';
import 'package:flutter/foundation.dart';

const String _roleAdmin = 'admin';
const String _roleEditor = 'editor';
const String _roleUploader = 'uploader';

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

  bool get canUpload => _hasRole(_roleUploader) || _hasRole(_roleAdmin);
  bool get canEdit => _hasRole(_roleEditor) || _hasRole(_roleAdmin);

  bool _hasRole(String role) => _me?.role == role;

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
