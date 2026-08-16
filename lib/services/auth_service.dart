import 'package:flutter/material.dart';
import 'package:luci_mobile/services/api_service.dart';
import 'package:luci_mobile/services/local_network_permission.dart';
import 'package:luci_mobile/services/secure_storage_service.dart';
import 'package:luci_mobile/services/interfaces/auth_service_interface.dart';
import 'package:luci_mobile/utils/logger.dart';

class RealAuthService implements IAuthService {
  final SecureStorageService _secureStorageService = SecureStorageService();
  final RealApiService _apiService;

  String? _sysauth;
  String? _ipAddress;
  bool _useHttps = false;

  RealAuthService(this._apiService);

  @override
  String? get sysauth => _sysauth;
  @override
  String? get ipAddress => _ipAddress;
  @override
  bool get useHttps => _useHttps;
  @override
  bool get isAuthenticated => _sysauth != null;

  @override
  Future<bool> login(
    String ipAddress,
    String username,
    String password,
    bool useHttps, {
    BuildContext? context,
  }) async {
    return await _login(ipAddress, username, password, useHttps, context: context);
  }

  Future<bool> _login(
    String ip,
    String user,
    String pass,
    bool useHttps, {
    BuildContext? context,
  }) async {
    try {
      await LocalNetworkPermission.ensureRequested();

      final loginResult = await _apiService.loginWithProtocolDetection(
        ip,
        user,
        pass,
        useHttps,
        context: context,
      );

      if (loginResult.token != null) {
        _sysauth = loginResult.token;
        _ipAddress = ip;
        _useHttps = loginResult.actualUseHttps;

        await _secureStorageService.saveCredentials(
          ipAddress: ip,
          username: user,
          password: pass,
          useHttps: loginResult.actualUseHttps,
        );

        if (loginResult.actualUseHttps != useHttps) {
          Logger.info(
            'Protocol changed from ${useHttps ? "HTTPS" : "HTTP"} to ${loginResult.actualUseHttps ? "HTTPS" : "HTTP"} due to redirect',
          );
        }

        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> tryAutoLogin(
    String? ipAddress,
    String? username,
    String? password,
    bool? useHttps, {
    BuildContext? context,
  }) async {
    if (ipAddress != null &&
        username != null &&
        password != null &&
        useHttps != null) {
      return await _login(
        ipAddress,
        username,
        password,
        useHttps,
        context: context,
      );
    }
    return await _tryAutoLoginFromStorage(context: context);
  }

  Future<bool> _tryAutoLoginFromStorage({BuildContext? context}) async {
    final credentials = await _secureStorageService.getCredentials();
    final ip = credentials['ipAddress'];
    final user = credentials['username'];
    final pass = credentials['password'];
    final useHttps = credentials['useHttps'] == 'true';

    if (ip != null && user != null && pass != null) {
      return await _login(
        ip,
        user,
        pass,
        useHttps,
        context: context?.mounted == true ? context : null,
      );
    }

    return false;
  }

  @override
  Future<void> logout() async {
    _sysauth = null;
    _ipAddress = null;
    _useHttps = false;
    await _secureStorageService.clearCredentials();
  }

  @override
  Future<bool> checkRouterAvailability(
    String ipAddress,
    bool useHttps, {
    BuildContext? context,
  }) async {
    if (ipAddress.isEmpty) return false;

    try {
      final result = await _apiService.call(
        ipAddress,
        '',
        useHttps,
        object: 'system',
        method: 'board',
        params: {},
        context: context,
      );
      return result != null;
    } catch (e) {
      return false;
    }
  }
}
