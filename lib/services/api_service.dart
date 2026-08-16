import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:luci_mobile/services/interfaces/api_service_interface.dart';
import '../utils/http_client_manager.dart';
import '../utils/logger.dart';

class LoginResult {
  final String? token;
  final bool actualUseHttps;

  LoginResult({required this.token, required this.actualUseHttps});
}

/// Temporary login diagnostics for release builds (shown on failure UI).
/// Never logs passwords.
class LoginProbe {
  static final StringBuffer _buf = StringBuffer();

  static void clear() => _buf.clear();

  static void add(String line) {
    _buf.writeln(line);
    Logger.probe(line);
  }

  static String get text => _buf.toString().trim();
}

Uri _buildUrl(String ipAddress, bool useHttps, String path) {
  final scheme = useHttps ? 'https' : 'http';
  // Handle cases where ipAddress might already include a port
  String host = ipAddress;
  // Don't add scheme if the address already has one (shouldn't happen with our parser)
  if (host.startsWith('http://') || host.startsWith('https://')) {
    return Uri.parse('$host$path');
  }
  return Uri.parse('$scheme://$host$path');
}

class RealApiService implements IApiService {
  final HttpClientManager _httpClientManager = HttpClientManager();

  Dio _createHttpClient(
    bool useHttps,
    String hostWithPort, {
    BuildContext? context,
  }) {
    return _httpClientManager.getClient(
      hostWithPort,
      useHttps,
      context: context,
    );
  }

  @override
  Future<String> login(
    String ipAddress,
    String username,
    String password,
    bool useHttps, {
    BuildContext? context,
  }) async {
    final result = await loginWithProtocolDetection(
      ipAddress,
      username,
      password,
      useHttps,
      context: context,
    );
    if (result.token == null) {
      throw Exception('Login failed');
    }
    return result.token!;
  }

  /// Login with automatic HTTPS redirect detection
  /// Returns both the auth token and the actual protocol used
  Future<LoginResult> loginWithProtocolDetection(
    String ipAddress,
    String username,
    String password,
    bool initialUseHttps, {
    BuildContext? context,
  }) async {
    LoginProbe.clear();
    LoginProbe.add(
      'start host=$ipAddress user=$username https=$initialUseHttps',
    );

    // First try with the initial protocol
    var result = await _login(
      ipAddress,
      username,
      password,
      initialUseHttps,
      context: context,
      checkRedirect: true,
    );

    // Check if we got a redirect marker
    if (result != null && result.startsWith('HTTPS_REDIRECT:')) {
      final token = result.substring('HTTPS_REDIRECT:'.length);
      Logger.info('Login successful via HTTP to HTTPS redirect');
      LoginProbe.add('ok via HTTPS_REDIRECT tokenLen=${token.length}');
      return LoginResult(token: token, actualUseHttps: true);
    }

    if (result != null) {
      LoginProbe.add(
        'ok via initial protocol https=$initialUseHttps tokenLen=${result.length}',
      );
      return LoginResult(token: result, actualUseHttps: initialUseHttps);
    }

    LoginProbe.add('initial protocol login returned null');

    // If login failed and we were using HTTP, try HTTPS in case of redirect
    if (!initialUseHttps) {
      Logger.info('HTTP login failed or redirected, attempting HTTPS');
      LoginProbe.add('retry with HTTPS');
      final safeContext = context?.mounted == true ? context : null;
      result = await _login(
        ipAddress,
        username,
        password,
        true, // Try with HTTPS
        context: safeContext, // ignore: use_build_context_synchronously
        checkRedirect: false,
      );

      if (result != null) {
        Logger.info('Login successful with HTTPS after redirect detection');
        LoginProbe.add('ok via HTTPS retry tokenLen=${result.length}');
        return LoginResult(token: result, actualUseHttps: true);
      }
      LoginProbe.add('HTTPS retry also returned null');
    }

    LoginProbe.add('FAILED: no token');
    return LoginResult(token: null, actualUseHttps: initialUseHttps);
  }

  Future<String?> _login(
    String ipAddress,
    String username,
    String password,
    bool useHttps, {
    BuildContext? context,
    bool checkRedirect = false,
  }) async {
    final client = _createHttpClient(useHttps, ipAddress, context: context);
    final uri = _buildUrl(ipAddress, useHttps, '/cgi-bin/luci/');
    final params =
        'luci_username=${Uri.encodeComponent(username)}&luci_password=${Uri.encodeComponent(password)}';

    LoginProbe.add(
      '_login begin https=$useHttps checkRedirect=$checkRedirect uri=$uri',
    );

    try {
      // Normal POST request - Dio will follow redirects by default
      final response = await client.post(
        uri.toString(),
        data: params,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          followRedirects: true,
          validateStatus: (code) =>
              code != null && code >= 200 && code < 400 || code == 302,
        ),
      );

      final setCookies = response.headers.map['set-cookie'];
      final headerKeys = response.headers.map.keys.toList()..sort();
      LoginProbe.add(
        'response status=${response.statusCode} realUri=${response.realUri} '
        'redirects=${response.redirects.length} '
        'hasSetCookie=${setCookies != null && setCookies.isNotEmpty} '
        'setCookieCount=${setCookies?.length ?? 0}',
      );
      LoginProbe.add('headerKeys=$headerKeys');
      if (setCookies != null && setCookies.isNotEmpty) {
        // Log cookie names only, not full values
        final names = <String>[];
        for (final raw in setCookies) {
          final first = raw.split(';').first;
          final eq = first.indexOf('=');
          names.add(eq > 0 ? first.substring(0, eq).trim() : first.trim());
        }
        LoginProbe.add('setCookieNames=$names');
        LoginProbe.add(
          'setCookieRawPreview=${setCookies.map((e) => e.length > 80 ? '${e.substring(0, 80)}...' : e).toList()}',
        );
      }
      if (response.redirects.isNotEmpty) {
        for (final r in response.redirects) {
          LoginProbe.add(
            'redirect status=${r.statusCode} loc=${r.location} method=${r.method}',
          );
        }
      }

      // Check if we were redirected to HTTPS (only relevant for initial HTTP attempts)
      if (checkRedirect && !useHttps) {
        final finalUrl = response.realUri;
        if (finalUrl.scheme == 'https') {
          Logger.info('Detected HTTP to HTTPS redirect: $uri -> $finalUrl');
          LoginProbe.add('detected scheme upgrade to https');
          // If we got a successful login after redirect, extract the token
          if (response.statusCode == 302 || response.statusCode == 200) {
            if (setCookies != null && setCookies.isNotEmpty) {
              final cookies = setCookies.join(',').split(',');
              for (final cookie in cookies) {
                if (cookie.contains('sysauth')) {
                  final cookieValue = cookie.split(';')[0].split('=')[1];
                  LoginProbe.add(
                    'extracted HTTPS_REDIRECT tokenLen=${cookieValue.length}',
                  );
                  // Signal that HTTPS should be used by returning a special marker
                  // We'll handle this in loginWithProtocolDetection
                  return 'HTTPS_REDIRECT:$cookieValue';
                }
              }
            }
            LoginProbe.add(
              'https upgrade path: status ok but no sysauth in set-cookie',
            );
          }
          // No token found, trigger HTTPS retry
          return null;
        }
      }

      if (response.statusCode == 302 || response.statusCode == 200) {
        // Parse Set-Cookie headers to find sysauth cookie
        if (setCookies != null && setCookies.isNotEmpty) {
          final cookies = setCookies.join(',').split(',');
          for (final cookie in cookies) {
            if (cookie.contains('sysauth')) {
              final cookieValue = cookie.split(';')[0].split('=')[1];
              LoginProbe.add(
                'extracted sysauth tokenLen=${cookieValue.length}',
              );
              return cookieValue;
            }
          }
          LoginProbe.add(
            'status ${response.statusCode}: set-cookie present but no sysauth* name matched',
          );
        } else {
          LoginProbe.add(
            'status ${response.statusCode}: NO set-cookie header visible to Dio',
          );
        }
      } else {
        LoginProbe.add('unexpected status=${response.statusCode}');
      }
      return null;
    } on DioException catch (e, stack) {
      Logger.exception('Login failed', e, stack);
      LoginProbe.add(
        'DioException type=${e.type} status=${e.response?.statusCode} '
        'msg=${e.message} error=${e.error}',
      );

      final isCertError =
          e.error is HandshakeException ||
          e.message?.contains('CERTIFICATE_VERIFY_FAILED') == true;
      LoginProbe.add('isCertError=$isCertError');

      if (!useHttps && checkRedirect && isCertError) {
        Logger.info(
          'Detected HTTPS certificate issue during redirect; retrying with HTTPS',
        );
        LoginProbe.add('cert error on HTTP path -> retry HTTPS');
        final retryContext = context != null && context.mounted ? context : null;
        try {
          return await _login(
            ipAddress,
            username,
            password,
            true,
            context: retryContext, // ignore: use_build_context_synchronously
            checkRedirect: false,
          );
        } on DioException catch (httpsError, httpsStack) {
          Logger.exception(
            'HTTPS retry after redirect failed',
            httpsError,
            httpsStack,
          );
          LoginProbe.add('HTTPS retry DioException: ${httpsError.message}');
        }
      }

      if (useHttps && context != null && context.mounted && isCertError) {
        // Try to prompt for certificate acceptance
        LoginProbe.add('prompting certificate acceptance dialog');
        final accepted = await _httpClientManager.promptForCertificateAcceptance(
          context: context,
          hostWithPort: ipAddress,
          useHttps: useHttps,
        );
        LoginProbe.add('certificate accepted=$accepted');

        if (accepted && context.mounted) {
          // Create a new client and retry the login
          final retryClient = _createHttpClient(
            useHttps,
            ipAddress,
            context: context,
          );
          try {
            final retryResponse = await retryClient.post(
              uri.toString(),
              data: params,
              options: Options(
                contentType: Headers.formUrlEncodedContentType,
                followRedirects: true,
                validateStatus: (code) =>
                    code != null && code >= 200 && code < 400 || code == 302,
              ),
            );

            LoginProbe.add(
              'cert-retry status=${retryResponse.statusCode} '
              'realUri=${retryResponse.realUri} '
              'setCookie=${retryResponse.headers.map['set-cookie']}',
            );

            if (retryResponse.statusCode == 302 ||
                retryResponse.statusCode == 200) {
              final setCookies = retryResponse.headers.map['set-cookie'];
              if (setCookies != null && setCookies.isNotEmpty) {
                final cookies = setCookies.join(',').split(',');
                for (final cookie in cookies) {
                  if (cookie.contains('sysauth')) {
                    final cookieValue = cookie.split(';')[0].split('=')[1];
                    LoginProbe.add(
                      'cert-retry extracted tokenLen=${cookieValue.length}',
                    );
                    return cookieValue;
                  }
                }
              }
            }
          } on DioException catch (retryError, retryStack) {
            Logger.exception('Login retry failed', retryError, retryStack);
            LoginProbe.add('cert-retry DioException: ${retryError.message}');
          }
        }
      }

      if (isCertError) {
        return null;
      }

      rethrow;
    }
  }

  @override
  Future<dynamic> call(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required String object,
    required String method,
    Map<String, dynamic>? params,
    BuildContext? context,
  }) async {
    return await callWithContext(
      ipAddress,
      sysauth,
      useHttps,
      object: object,
      method: method,
      params: params,
      context: context,
    );
  }

  // Simplified call method for reviewer mode
  @override
  Future<dynamic> callSimple(
    String object,
    String method,
    Map<String, dynamic> params,
  ) async {
    // Use default values for ipAddress, sysauth, and useHttps
    // This is primarily for mock/testing scenarios
    return await call(
      'localhost', // Default IP address
      '', // Default sysauth (empty for mock scenarios)
      false, // Default to HTTP
      object: object,
      method: method,
      params: params,
    );
  }

  Future<dynamic> callWithContext(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required String object,
    required String method,
    Map<String, dynamic>? params,
    BuildContext? context,
  }) async {
    final url = _buildUrl(ipAddress, useHttps, '/cgi-bin/luci/admin/ubus');
    final client = _createHttpClient(useHttps, ipAddress, context: context);

    final rpcPayload = {
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'call',
      'params': [sysauth, object, method, params ?? {}],
    };

    try {
      final response = await client.post(
        url.toString(),
        data: jsonEncode(rpcPayload),
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200) {
        final decoded = response.data is String
            ? jsonDecode(response.data as String)
            : response.data;
        if (decoded['error'] != null) {
          throw Exception('RPC error: ${decoded['error']['message']}');
        }
        // Return in LuCI RPC format: [status, data]
        final result = decoded['result'];
        if (result is List && result.isNotEmpty) {
          // Result is already in [status, data] format
          return result;
        } else {
          // Wrap single result in format: [0, data]
          return [0, result];
        }
      } else {
        throw Exception('Failed to call RPC: HTTP ${response.statusCode}');
      }
    } on DioException catch (e, stack) {
      Logger.exception('API call failed', e, stack);
      rethrow;
    }
  }

  @override
  Future<bool> reboot(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    BuildContext? context,
  }) async {
    return await rebootWithContext(
      ipAddress,
      sysauth,
      useHttps,
      context: context,
    );
  }

  Future<bool> rebootWithContext(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    BuildContext? context,
  }) async {
    try {
      final result = await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'system',
        method: 'reboot',
        context: context,
      );
      // Handle LuCI RPC format: [status, data] - successful reboot returns [0, ...]
      if (result is List && result.isNotEmpty && result[0] == 0) {
        Logger.info('Router reboot initiated successfully');
        return true;
      }
      Logger.warning('Router reboot call returned unexpected result: $result');
      return false;
    } catch (e, stack) {
      Logger.exception('Router reboot failed', e, stack);
      return false;
    }
  }

  @override
  Future<Map<String, Set<String>>> fetchAssociatedStations() async {
    // This method is mainly used by the mock service
    // For real implementation, individual interface queries via fetchAssociatedStationsWithContext should be used
    // The app_state.dart should call fetchAllAssociatedWirelessMacsWithContext instead
    throw UnimplementedError(
      'Use fetchAllAssociatedWirelessMacsWithContext for real implementation',
    );
  }

  /// Fetches all associated wireless MAC addresses from all wireless interfaces for real API
  @override
  Future<Map<String, Set<String>>> fetchAllAssociatedWirelessMacsWithContext({
    required String ipAddress,
    required String sysauth,
    required bool useHttps,
    BuildContext? context,
  }) async {
    try {
      // First, get wireless device information to find all wireless interfaces
      final wirelessResult = await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'luci-rpc',
        method: 'getWirelessDevices',
        context: context,
      );

      if (wirelessResult is List &&
          wirelessResult.length > 1 &&
          wirelessResult[0] == 0) {
        final wirelessData = wirelessResult[1] as Map<String, dynamic>?;
        if (wirelessData == null) return {};

        final result = <String, Set<String>>{};

        // For each wireless radio, get the associated stations
        for (final entry in wirelessData.entries) {
          final radioData = entry.value as Map<String, dynamic>?;
          if (radioData == null || radioData['interfaces'] == null) continue;

          final interfaces = radioData['interfaces'] as List?;
          if (interfaces == null) continue;

          for (final iface in interfaces) {
            if (iface is Map<String, dynamic>) {
              final ifname = iface['ifname'] as String?;
              if (ifname != null) {
                // Fetch associated stations for this interface
                final stations = await fetchAssociatedStationsWithContext(
                  ipAddress: ipAddress,
                  sysauth: sysauth,
                  useHttps: useHttps,
                  interface: ifname,
                  context: context?.mounted == true ? context : null,
                );
                if (stations.isNotEmpty) {
                  result[ifname] = stations.toSet();
                }
              }
            }
          }
        }
        return result;
      }
      return {};
    } catch (e, stack) {
      Logger.exception('Failed to fetch all associated stations', e, stack);
      return {};
    }
  }

  /// Fetches associated stations (wireless clients) for a given wireless interface (e.g., wlan0)
  @override
  Future<List<String>> fetchAssociatedStationsWithContext({
    required String ipAddress,
    required String sysauth,
    required bool useHttps,
    required String interface,
    BuildContext? context,
  }) async {
    try {
      final result = await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'iwinfo',
        method: 'assoclist',
        params: {'device': interface},
        context: context,
      );
      // Handle LuCI RPC format: [status, data]
      if (result is List && result.length > 1 && result[0] == 0) {
        final data = result[1];
        if (data is Map && data['results'] is List) {
          final resultsList = data['results'] as List;
          return resultsList
              .map(
                (entry) => (entry as Map<String, dynamic>)['mac']?.toString(),
              )
              .where((mac) => mac != null)
              .cast<String>()
              .toList();
        }
      }
      return [];
    } catch (e, stack) {
      Logger.exception('Failed to fetch associated stations', e, stack);
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>?> fetchWireGuardPeers({
    required String ipAddress,
    required String sysauth,
    required bool useHttps,
    required String interface,
    BuildContext? context,
  }) async {
    return await fetchWireGuardPeersWithContext(
      ipAddress: ipAddress,
      sysauth: sysauth,
      useHttps: useHttps,
      interface: interface,
      context: context,
    );
  }

  /// Fetches WireGuard peer information for a given interface
  /// If interface is empty, returns data for all WireGuard interfaces
  Future<Map<String, dynamic>?> fetchWireGuardPeersWithContext({
    required String ipAddress,
    required String sysauth,
    required bool useHttps,
    required String interface,
    BuildContext? context,
  }) async {
    try {
      // Use the correct luci.wireguard.getWgInstances method
      final result = await callWithContext(
        ipAddress,
        sysauth,
        useHttps,
        object: 'luci.wireguard',
        method: 'getWgInstances',
        params: {},
        context: context,
      );

      // Handle LuCI RPC format: [status, data]
      if (result is List && result.length > 1 && result[0] == 0) {
        final data = result[1] as Map<String, dynamic>?;
        if (data != null) {
          return _parseWireGuardFromInstances(data, interface);
        }
      }

      return null;
    } catch (e, stack) {
      Logger.exception('Failed to fetch WireGuard peers', e, stack);
      return null;
    }
  }

  Map<String, dynamic>? _parseWireGuardFromInstances(
    Map<String, dynamic> data,
    String targetInterface,
  ) {
    final wireguardData = <String, dynamic>{};

    data.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        // Look for peers in the interface data
        final peers = <String, dynamic>{};

        // The structure might have peers in different formats
        if (value['peers'] is List) {
          final peersList = value['peers'] as List;
          for (final peer in peersList) {
            if (peer is Map<String, dynamic>) {
              final publicKey = peer['public_key'] as String?;
              if (publicKey != null) {
                peers[publicKey] = {
                  'public_key': publicKey,
                  'endpoint': peer['endpoint'] ?? 'N/A',
                  'last_handshake':
                      int.tryParse(
                        peer['latest_handshake']?.toString() ?? '0',
                      ) ??
                      0,
                };
              }
            }
          }
        } else if (value['peers'] is Map<String, dynamic>) {
          final peersMap = value['peers'] as Map<String, dynamic>;
          peersMap.forEach((peerKey, peerData) {
            if (peerData is Map<String, dynamic>) {
              peers[peerKey] = {
                'public_key': peerKey,
                'endpoint': peerData['endpoint'] ?? 'N/A',
                'last_handshake':
                    int.tryParse(
                      peerData['latest_handshake']?.toString() ?? '0',
                    ) ??
                    0,
              };
            }
          });
        }

        if (peers.isNotEmpty) {
          wireguardData[key] = {'interface': key, 'peers': peers};
        }
      }
    });

    if (targetInterface.isEmpty) {
      return wireguardData;
    } else {
      return wireguardData[targetInterface];
    }
  }

  @override
  Future<dynamic> uciSet(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required String config,
    required String section,
    required Map<String, String> values,
    BuildContext? context,
  }) async {
    return await callWithContext(
      ipAddress,
      sysauth,
      useHttps,
      object: 'uci',
      method: 'set',
      params: {'config': config, 'section': section, 'values': values},
      context: context,
    );
  }

  @override
  Future<dynamic> uciCommit(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required String config,
    BuildContext? context,
  }) async {
    return await callWithContext(
      ipAddress,
      sysauth,
      useHttps,
      object: 'uci',
      method: 'commit',
      params: {'config': config},
      context: context,
    );
  }

  @override
  Future<dynamic> systemExec(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required String command,
    BuildContext? context,
  }) async {
    return await callWithContext(
      ipAddress,
      sysauth,
      useHttps,
      object: 'system',
      method: 'exec',
      params: {'command': command},
      context: context,
    );
  }
}
