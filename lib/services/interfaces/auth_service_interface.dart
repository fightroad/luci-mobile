import 'package:flutter/material.dart';

abstract class IAuthService {
  Future<bool> login(
    String ipAddress,
    String username,
    String password,
    bool useHttps, {
    BuildContext? context,
  });
  Future<bool> tryAutoLogin(
    String? ipAddress,
    String? username,
    String? password,
    bool? useHttps, {
    BuildContext? context,
  });
  Future<void> logout();
  Future<bool> checkRouterAvailability(
    String ipAddress,
    bool useHttps, {
    BuildContext? context,
  });

  String? get sysauth;
  String? get ipAddress;
  bool get useHttps;
  bool get isAuthenticated;
}
