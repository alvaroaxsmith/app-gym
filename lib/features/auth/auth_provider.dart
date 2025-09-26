import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._client) {
    _init();
  }

  final SupabaseClient _client;
  Session? _session;
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription<AuthState>? _sub;

  Session? get session => _session;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  User? get currentUser => _session?.user;

  Future<void> _init() async {
    _session = _client.auth.currentSession;
    _isLoading = false;
    notifyListeners();
    _sub = _client.auth.onAuthStateChange.listen((data) {
      _session = data.session;
      notifyListeners();
    });
  }

  Future<void> signIn({required String email, required String password}) async {
    _setLoading(true);
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      _errorMessage = null;
    } on AuthException catch (err) {
      _errorMessage = err.message;
    } catch (err) {
      _errorMessage = 'Erro inesperado ao fazer login.';
      if (kDebugMode) {
        print(err);
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
        },
      );
      if (response.user != null) {
        await _client.from('profiles').upsert({
          'id': response.user!.id,
          'full_name': fullName,
        });
      }
      _errorMessage = null;
    } on AuthException catch (err) {
      _errorMessage = err.message;
    } catch (err) {
      _errorMessage = 'Erro ao criar conta.';
      if (kDebugMode) {
        print(err);
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    _setLoading(true);
    try {
      await _client.auth.resetPasswordForEmail(email);
      _errorMessage = null;
    } on AuthException catch (err) {
      _errorMessage = err.message;
    } catch (err) {
      _errorMessage = 'Não foi possível enviar o e-mail de recuperação.';
      if (kDebugMode) {
        print(err);
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
