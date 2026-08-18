import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:luci_mobile/models/easytier_status.dart';
import 'package:luci_mobile/models/passwall_config.dart';
import 'package:luci_mobile/services/interfaces/api_service_interface.dart';
import '../utils/http_client_manager.dart';
import '../utils/logger.dart';

class LoginResult {
  final String? token;
  final bool actualUseHttps;

  LoginResult({required this.token, required this.actualUseHttps});
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
      return LoginResult(token: token, actualUseHttps: true);
    }

    if (result != null) {
      return LoginResult(token: result, actualUseHttps: initialUseHttps);
    }

    // If login failed and we were using HTTP, try HTTPS in case of redirect
    if (!initialUseHttps) {
      Logger.info('HTTP login failed or redirected, attempting HTTPS');
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
        return LoginResult(token: result, actualUseHttps: true);
      }
    }

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

    try {
      // Normal POST request - Dio will follow redirects by default
      final response = await client.post(
        uri.toString(),
        data: params,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          followRedirects: true,
          validateStatus: (code) => code != null && code >= 200 && code < 400 || code == 302,
        ),
      );

      // Check if we were redirected to HTTPS (only relevant for initial HTTP attempts)
      if (checkRedirect && !useHttps) {
        final finalUrl = response.realUri;
        if (finalUrl.scheme == 'https') {
          Logger.info('Detected HTTP to HTTPS redirect: $uri -> $finalUrl');
          // If we got a successful login after redirect, extract the token
          if (response.statusCode == 302 || response.statusCode == 200) {
            final setCookies = response.headers.map['set-cookie'];
            if (setCookies != null && setCookies.isNotEmpty) {
              final cookies = setCookies.join(',').split(',');
              for (final cookie in cookies) {
                if (cookie.contains('sysauth')) {
                  final cookieValue = cookie.split(';')[0].split('=')[1];
                  // Signal that HTTPS should be used by returning a special marker
                  // We'll handle this in loginWithProtocolDetection
                  return 'HTTPS_REDIRECT:$cookieValue';
                }
              }
            }
          }
          // No token found, trigger HTTPS retry
          return null;
        }
      }

      if (response.statusCode == 302 || response.statusCode == 200) {
        // Parse Set-Cookie headers to find sysauth cookie
        final setCookies = response.headers.map['set-cookie'];
        if (setCookies != null && setCookies.isNotEmpty) {
          final cookies = setCookies.join(',').split(',');
          for (final cookie in cookies) {
            if (cookie.contains('sysauth')) {
              final cookieValue = cookie.split(';')[0].split('=')[1];
              return cookieValue;
            }
          }
        }
      }
      return null;
    } on DioException catch (e, stack) {
      Logger.exception('Login failed', e, stack);

      final isCertError =
          e.error is HandshakeException || e.message?.contains('CERTIFICATE_VERIFY_FAILED') == true;

      if (!useHttps && checkRedirect && isCertError) {
        Logger.info('Detected HTTPS certificate issue during redirect; retrying with HTTPS');
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
          Logger.exception('HTTPS retry after redirect failed', httpsError, httpsStack);
        }
      }

      if (useHttps && context != null && context.mounted && isCertError) {
        // Try to prompt for certificate acceptance
        final accepted = await _httpClientManager.promptForCertificateAcceptance(
          context: context,
          hostWithPort: ipAddress,
          useHttps: useHttps,
        );

        if (accepted && context.mounted) {
          // Create a new client and retry the login
          final retryClient = _createHttpClient(useHttps, ipAddress, context: context);
          try {
            final retryResponse = await retryClient.post(
              uri.toString(),
              data: params,
              options: Options(
                contentType: Headers.formUrlEncodedContentType,
                followRedirects: true,
                validateStatus: (code) => code != null && code >= 200 && code < 400 || code == 302,
              ),
            );

            if (retryResponse.statusCode == 302 || retryResponse.statusCode == 200) {
              final setCookies = retryResponse.headers.map['set-cookie'];
              if (setCookies != null && setCookies.isNotEmpty) {
                final cookies = setCookies.join(',').split(',');
                for (final cookie in cookies) {
                  if (cookie.contains('sysauth')) {
                    final cookieValue = cookie.split(';')[0].split('=')[1];
                    return cookieValue;
                  }
                }
              }
            }
          } on DioException catch (retryError, retryStack) {
            Logger.exception('Login retry failed', retryError, retryStack);
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
  Future<Map<String, String>> fetchAllAssociatedWirelessMacsWithContext({
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

        final result = <String, String>{};

        // For each wireless radio, get the associated stations
        for (final entry in wirelessData.entries) {
          final radioData = entry.value as Map<String, dynamic>?;
          if (radioData == null || radioData['interfaces'] == null) continue;

          final interfaces = radioData['interfaces'] as List?;
          if (interfaces == null) continue;

          for (final iface in interfaces) {
            if (iface is! Map<String, dynamic>) continue;
            final ifname = iface['ifname'] as String?;
            if (ifname == null) continue;

            final config = iface['config'];
            final iwinfo = iface['iwinfo'];
            final ssid =
                (iwinfo is Map ? iwinfo['ssid']?.toString() : null) ??
                (config is Map ? config['ssid']?.toString() : null) ??
                ifname;

            final stations = await fetchAssociatedStationsWithContext(
              ipAddress: ipAddress,
              sysauth: sysauth,
              useHttps: useHttps,
              interface: ifname,
              context: context?.mounted == true ? context : null,
            );
            for (final mac in stations) {
              final normalized = mac.toUpperCase().replaceAll('-', ':');
              if (normalized.isNotEmpty) {
                result[normalized] = ssid;
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
  Future<dynamic> uciApply(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    bool rollback = false,
    int timeout = 10,
    BuildContext? context,
  }) async {
    return await callWithContext(
      ipAddress,
      sysauth,
      useHttps,
      object: 'uci',
      method: 'apply',
      params: {'rollback': rollback, 'timeout': timeout},
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

  String _luciSessionCookie(String sysauth) {
    // LuCI may emit sysauth, sysauth_http, or sysauth_https depending on scheme.
    return 'sysauth=$sysauth; sysauth_http=$sysauth; sysauth_https=$sysauth';
  }

  String? _extractLuciToken(String html) {
    final fromJson = RegExp(r'"token"\s*:\s*"([^"]+)"').firstMatch(html);
    if (fromJson != null) return fromJson.group(1);
    final fromInput = RegExp(
      r'name="token"\s+value="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(html);
    return fromInput?.group(1);
  }

  bool _isJsonSubscribeSuccess(dynamic data) {
    if (data is Map) return data['success'] == true;
    final raw = data is String ? data : data?.toString();
    if (raw == null) return false;
    final trimmed = raw.trimLeft();
    if (!trimmed.startsWith('{')) return false;
    try {
      final decoded = jsonDecode(trimmed);
      return decoded is Map && decoded['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _tryPasswallSubscribeManualAllApi(
    Dio client,
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required List<PasswallSubscribe> subscriptions,
  }) async {
    final uri = _buildUrl(
      ipAddress,
      useHttps,
      '/cgi-bin/luci/admin/services/passwall/subscribe_manual_all',
    );
    final response = await client.post(
      uri.toString(),
      data: {
        'sections': subscriptions.map((s) => s.id).join(','),
        'urls': subscriptions.map((s) => s.url).join(','),
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'Cookie': _luciSessionCookie(sysauth),
          'Accept': 'application/json',
        },
        followRedirects: false,
        validateStatus: (code) => code != null && code < 500,
      ),
    );
    return _isJsonSubscribeSuccess(response.data);
  }

  Future<bool> _tryPasswallSubscribeCbiForm(
    Dio client,
    String ipAddress,
    String sysauth,
    bool useHttps, {
    String? globalSubscribeSection,
  }) async {
    final pageUri = _buildUrl(
      ipAddress,
      useHttps,
      '/cgi-bin/luci/admin/services/passwall/node_subscribe',
    );
    final page = await client.get(
      pageUri.toString(),
      options: Options(
        headers: {'Cookie': _luciSessionCookie(sysauth)},
        validateStatus: (code) => code != null && code < 500,
      ),
    );
    final html = page.data?.toString() ?? '';
    if (html.isEmpty) return false;

    final token = _extractLuciToken(html);
    var section = globalSubscribeSection;
    if (section == null || section.isEmpty) {
      final allBtn = RegExp(
        r'name="cbid\.passwall\.([^.]+)\._update"[^>]*value="[^"]*All[^"]*"',
        caseSensitive: false,
      ).firstMatch(html);
      section = allBtn?.group(1);
    }
    if (token == null || section == null || section.isEmpty) {
      return false;
    }

    // Old CBI builds start a background job then redirect (often to /log).
    // Do not judge by final URL — firing the form is enough to treat as started.
    await client.post(
      pageUri.toString(),
      data: {
        'token': token,
        'cbi.submit': '1',
        'cbid.passwall.$section._update': 'Manual subscription All',
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {'Cookie': _luciSessionCookie(sysauth)},
        followRedirects: true,
        validateStatus: (code) => code != null && code < 500,
      ),
    );
    return true;
  }

  @override
  Future<bool> triggerPasswallSubscribeAll(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required List<PasswallSubscribe> subscriptions,
    String? globalSubscribeSection,
    BuildContext? context,
  }) async {
    final usable =
        subscriptions.where((s) => s.id.isNotEmpty && s.hasUrl).toList();
    if (usable.isEmpty) return false;

    final client = _createHttpClient(useHttps, ipAddress, context: context);

    try {
      if (await _tryPasswallSubscribeManualAllApi(
        client,
        ipAddress,
        sysauth,
        useHttps,
        subscriptions: usable,
      )) {
        return true;
      }
    } catch (e, stack) {
      Logger.warning('Passwall subscribe_manual_all unavailable: $e');
      Logger.debug('Passwall subscribe_manual_all stack: $stack');
    }

    try {
      return await _tryPasswallSubscribeCbiForm(
        client,
        ipAddress,
        sysauth,
        useHttps,
        globalSubscribeSection: globalSubscribeSection,
      );
    } catch (e, stack) {
      Logger.exception('Passwall CBI subscribe-all failed', e, stack);
      return false;
    }
  }

  @override
  Future<String> fetchPasswallLog(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    BuildContext? context,
  }) async {
    final client = _createHttpClient(useHttps, ipAddress, context: context);
    final uri = _buildUrl(
      ipAddress,
      useHttps,
      '/cgi-bin/luci/admin/services/passwall/get_log',
    );
    final response = await client.get(
      uri.toString(),
      options: Options(
        headers: {
          'Cookie': _luciSessionCookie(sysauth),
          'Accept': 'text/plain,*/*',
        },
        responseType: ResponseType.plain,
        validateStatus: (code) => code != null && code < 500,
      ),
    );
    if (response.statusCode != null && response.statusCode! >= 400) {
      throw Exception('Failed to fetch Passwall log (${response.statusCode})');
    }
    final raw = response.data?.toString() ?? '';
    // LuCI login / missing page often returns HTML.
    final trimmed = raw.trimLeft();
    if (trimmed.toLowerCase().startsWith('<!DOCTYPE') ||
        trimmed.toLowerCase().startsWith('<html')) {
      throw Exception('Failed to fetch Passwall log');
    }
    return raw;
  }

  @override
  Future<bool> clearPasswallLog(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    BuildContext? context,
  }) async {
    final client = _createHttpClient(useHttps, ipAddress, context: context);
    final uri = _buildUrl(
      ipAddress,
      useHttps,
      '/cgi-bin/luci/admin/services/passwall/clear_log',
    );
    final response = await client.get(
      uri.toString(),
      options: Options(
        headers: {'Cookie': _luciSessionCookie(sysauth)},
        responseType: ResponseType.plain,
        validateStatus: (code) => code != null && code < 500,
      ),
    );
    // LuCI call() returns empty 200 on success; also accept 204.
    final code = response.statusCode;
    return code != null && code >= 200 && code < 400;
  }

  @override
  Future<double?> testPasswallConnect(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    // Match Passwall status page: host/path only, no scheme.
    // New firmware often prepends http(s)://; a full URL becomes
    // https://https://... and returns empty use_time. Bare host also
    // works on older builds that pass the url straight to curl.
    String url = 'www.google.com/generate_204',
    String type = 'google',
    BuildContext? context,
  }) async {
    final client = _createHttpClient(useHttps, ipAddress, context: context);
    final uri = _buildUrl(
      ipAddress,
      useHttps,
      '/cgi-bin/luci/admin/services/passwall/connect_status',
    ).replace(
      queryParameters: {'type': type, 'url': url},
    );
    final response = await client.get(
      uri.toString(),
      options: Options(
        headers: {
          'Cookie': _luciSessionCookie(sysauth),
          'Accept': 'application/json',
        },
        responseType: ResponseType.json,
        // Curl on router may take a few seconds.
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 10),
        validateStatus: (code) => code != null && code < 500,
      ),
    );
    if (response.statusCode != null && response.statusCode! >= 400) {
      return null;
    }

    dynamic data = response.data;
    if (data is String) {
      final trimmed = data.trimLeft();
      if (!trimmed.startsWith('{')) return null;
      try {
        data = jsonDecode(trimmed);
      } catch (_) {
        return null;
      }
    }
    if (data is! Map) return null;
    if (data['ping_type']?.toString() != 'curl') return null;
    final useTime = double.tryParse(data['use_time']?.toString() ?? '');
    if (useTime == null || useTime <= 0) return null;
    return useTime;
  }

  Map<String, dynamic>? _decodeLuciJsonResponse(dynamic data) {
    dynamic decoded = data;
    if (decoded is String) {
      final trimmed = decoded.trimLeft();
      if (trimmed.toLowerCase().startsWith('<!DOCTYPE') ||
          trimmed.toLowerCase().startsWith('<html')) {
        return null;
      }
      if (!trimmed.startsWith('{')) return null;
      try {
        decoded = jsonDecode(trimmed);
      } catch (_) {
        return null;
      }
    }
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  }

  @override
  Future<EasyTierStatus> fetchEasyTierStatus(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    BuildContext? context,
  }) async {
    final client = _createHttpClient(useHttps, ipAddress, context: context);
    final uri = _buildUrl(
      ipAddress,
      useHttps,
      '/cgi-bin/luci/admin/vpn/easytier/api_status',
    );
    final response = await client.get(
      uri.toString(),
      options: Options(
        headers: {
          'Cookie': _luciSessionCookie(sysauth),
          'Accept': 'application/json',
        },
        responseType: ResponseType.json,
        validateStatus: (code) => code != null && code < 500,
      ),
    );
    if (response.statusCode != null && response.statusCode! >= 400) {
      throw Exception(
        'Failed to fetch EasyTier status (${response.statusCode})',
      );
    }
    final json = _decodeLuciJsonResponse(response.data);
    if (json == null) {
      throw Exception('Failed to fetch EasyTier status');
    }
    return EasyTierStatus.fromJson(json);
  }

  @override
  Future<bool> setEasyTierCoreEnabled(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    required bool enabled,
    BuildContext? context,
  }) async {
    final client = _createHttpClient(useHttps, ipAddress, context: context);
    final uri = _buildUrl(
      ipAddress,
      useHttps,
      '/cgi-bin/luci/admin/vpn/easytier/toggle_core',
    );
    final response = await client.post(
      uri.toString(),
      data: {'enabled': enabled ? '1' : '0'},
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'Cookie': _luciSessionCookie(sysauth),
          'Accept': 'application/json',
        },
        validateStatus: (code) => code != null && code < 500,
      ),
    );
    if (response.statusCode != null && response.statusCode! >= 400) {
      return false;
    }
    final json = _decodeLuciJsonResponse(response.data);
    return json?['success'] == true;
  }

  @override
  Future<bool> restartEasyTier(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    BuildContext? context,
  }) async {
    final client = _createHttpClient(useHttps, ipAddress, context: context);
    final uri = _buildUrl(
      ipAddress,
      useHttps,
      '/cgi-bin/luci/admin/vpn/easytier/restart_service',
    );
    final response = await client.post(
      uri.toString(),
      options: Options(
        headers: {
          'Cookie': _luciSessionCookie(sysauth),
          'Accept': 'application/json',
        },
        validateStatus: (code) => code != null && code < 500,
      ),
    );
    if (response.statusCode != null && response.statusCode! >= 400) {
      return false;
    }
    final json = _decodeLuciJsonResponse(response.data);
    return json?['success'] == true;
  }

  static const _peerListSectionKey = 'peer';

  @override
  Future<String> fetchEasyTierPeerList(
    String ipAddress,
    String sysauth,
    bool useHttps, {
    BuildContext? context,
  }) async {
    final client = _createHttpClient(useHttps, ipAddress, context: context);
    final uri = _buildUrl(
      ipAddress,
      useHttps,
      '/cgi-bin/luci/admin/vpn/easytier/api_conninfo',
    ).replace(queryParameters: {'section': _peerListSectionKey});
    final response = await client.get(
      uri.toString(),
      options: Options(
        headers: {
          'Cookie': _luciSessionCookie(sysauth),
          'Accept': 'application/json',
        },
        responseType: ResponseType.json,
        validateStatus: (code) => code != null && code < 500,
      ),
    );
    if (response.statusCode != null && response.statusCode! >= 400) {
      throw Exception(
        'Failed to fetch EasyTier peer list (${response.statusCode})',
      );
    }
    final json = _decodeLuciJsonResponse(response.data);
    if (json == null) {
      throw Exception('Failed to fetch EasyTier peer list');
    }
    final value = json[_peerListSectionKey];
    if (value == null) {
      throw Exception('EasyTier peer list missing in response');
    }
    return value.toString();
  }
}
