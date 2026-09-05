import 'package:flutter/material.dart';
import 'package:luci_mobile/models/easytier_status.dart';
import 'package:luci_mobile/models/passwall_config.dart';
import 'package:luci_mobile/models/passwall_status.dart';

/// API service interface for LuCI RPC communication.
///
/// All RPC methods that return dynamic data follow the LuCI RPC response format:
/// [status, data] where:
/// - status: Integer (0 = success, non-zero = error)
/// - data: The actual response data (varies by method)
///
/// Example: [0, {"hostname": "router", "model": "TP-Link"}]
abstract class IApiService {
  Future<String> login(
    String ipAddress,
    String username,
    String password,
    bool useHttps, {
    BuildContext? context,
  });
  Future<dynamic> call(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required String object,
    required String method,
    Map<String, dynamic>? params,
    BuildContext? context,
  });
  Future<bool> reboot(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    BuildContext? context,
  });
  Future<Map<String, dynamic>?> fetchWireGuardPeers({
    required String ipAddress,
    required String sysauth,
    required bool useHttps,
    required String interface,
    BuildContext? context,
  });
  Future<List<String>> fetchAssociatedStationsWithContext({
    required String ipAddress,
    required String sysauth,
    required bool useHttps,
    required String interface,
    BuildContext? context,
  });
  /// Associated wireless clients mapped as normalized MAC → access point SSID.
  Future<Map<String, String>> fetchAllAssociatedWirelessMacsWithContext({
    required String ipAddress,
    required String sysauth,
    required bool useHttps,
    BuildContext? context,
  });
  Future<dynamic> uciSet(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required String config,
    required String section,
    required Map<String, String> values,
    BuildContext? context,
  });
  Future<dynamic> uciCommit(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required String config,
    BuildContext? context,
  });
  /// Persist staged UCI changes (`uci.apply`). Prefer over [uciCommit] when
  /// the session ACL denies `uci.commit` (common on some Lean/iStoreOS builds).
  Future<dynamic> uciApply(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    bool rollback = false,
    int timeout = 10,
    BuildContext? context,
  });
  Future<dynamic> systemExec(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required String command,
    BuildContext? context,
  });
  /// Triggers Passwall "manual subscribe all" via LuCI JSON API.
  Future<bool> triggerPasswallSubscribeAll(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required List<PasswallSubscribe> subscriptions,
    BuildContext? context,
  });

  /// Reads Passwall runtime log (`/tmp/log/passwall.log`) via LuCI CGI.
  Future<String> fetchPasswallLog(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    BuildContext? context,
  });

  /// Clears Passwall runtime log via LuCI CGI.
  Future<bool> clearPasswallLog(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    BuildContext? context,
  });

  /// Runs Passwall homepage connectivity check (same CGI as LuCI status).
  /// Returns latency in milliseconds when successful.
  Future<double?> testPasswallConnect(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    String url = 'https://www.google.com/generate_204',
    String type = 'google',
    BuildContext? context,
  });

  /// Reads Passwall homepage TCP/UDP/DNS flags (`index_status`).
  Future<PasswallIndexStatus> fetchPasswallIndexStatus(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    BuildContext? context,
  });

  /// Reads EasyTier runtime status via LuCI CGI (`api_status`).
  Future<EasyTierStatus> fetchEasyTierStatus(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    BuildContext? context,
  });

  /// Enables or disables EasyTier core via LuCI CGI (`toggle_core`).
  Future<bool> setEasyTierCoreEnabled(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required bool enabled,
    BuildContext? context,
  });

  /// Restarts EasyTier service via LuCI CGI (`restart_service`).
  Future<bool> restartEasyTier(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    BuildContext? context,
  });

  /// Reads EasyTier peer list via LuCI CGI (`api_conninfo?section=peer`).
  Future<String> fetchEasyTierPeerList(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    BuildContext? context,
  });
}
