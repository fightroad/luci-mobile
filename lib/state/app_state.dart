import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:luci_mobile/services/secure_storage_service.dart';
import 'package:luci_mobile/services/router_service.dart';
import 'package:luci_mobile/services/throughput_service.dart';
import 'package:luci_mobile/models/client.dart';
import 'package:luci_mobile/models/router.dart' as model;
import 'package:luci_mobile/models/dashboard_preferences.dart';
import 'package:luci_mobile/services/interfaces/auth_service_interface.dart';
import 'package:luci_mobile/services/interfaces/api_service_interface.dart';
import 'package:luci_mobile/services/api_service.dart';
import 'package:luci_mobile/services/service_factory.dart';
import 'package:luci_mobile/config/app_config.dart';
import 'package:luci_mobile/utils/http_client_manager.dart';
import 'package:luci_mobile/utils/logger.dart';

class AppState extends ChangeNotifier {
  static AppState? _instance;

  late final SecureStorageService _secureStorageService;
  IApiService? _apiService;
  IAuthService? _authService;
  RouterService? _routerService;
  ThroughputService? _throughputService;
  final HttpClientManager _httpClientManager = HttpClientManager();

  // Reviewer mode state
  bool _reviewerModeEnabled = false;
  bool get reviewerModeEnabled => _reviewerModeEnabled;

  bool _isLoading = false;
  String? _errorMessage;

  Map<String, dynamic>? _dashboardData;
  bool _isDashboardLoading = false;
  String? _dashboardError;

  Timer? _throughputTimer;
  Timer? _pollingTimer;
  int _pollAttempts = 0;
  static const int _maxPollAttempts =
      40; // Max 40 attempts = ~5 minutes with backoff

  // Add rebooting state
  bool _isRebooting = false;
  bool get isRebooting => _isRebooting;

  // Theme mode state
  ThemeMode _themeMode = ThemeMode.system;
  static const String _themeModeKey = 'themeMode';

  // Clients view mode (aggregate across routers)
  bool _clientsAggregateAllRouters = true;
  static const String _clientsAggregateKey = 'clients_aggregate_all';
  bool get clientsAggregateAllRouters => _clientsAggregateAllRouters;

  // Dashboard preferences state
  DashboardPreferences _dashboardPreferences = DashboardPreferences();
  DashboardPreferences get dashboardPreferences => _dashboardPreferences;

  List<model.Router> get routers => _routerService?.routers ?? [];
  model.Router? get selectedRouter => _routerService?.selectedRouter;

  VoidCallback? onRouterBackOnline;

  // Add requestedTab for programmatic tab switching
  int? requestedTab;
  String? requestedInterfaceToScroll;

  void requestTab(int index, {String? interfaceToScroll}) {
    requestedTab = index;
    requestedInterfaceToScroll = interfaceToScroll;
    notifyListeners();
  }

  AppState._() {
    _initialize();
  }

  static AppState get instance {
    return _instance ??= AppState._();
  }

  Future<void> _initialize() async {
    await _loadReviewerMode();
    _initializeServices();
    await _loadThemeMode();
    await loadRouters(); // Load routers on app start (sets selectedRouter)
    await _migrateGlobalDashboardPreferencesIfNeeded(); // Proactively migrate legacy prefs
    await _loadClientsViewMode();
    await loadDashboardPreferences(); // Load prefs scoped to selected router
  }

  /// One-time migration: if a global 'dashboard_preferences' exists,
  /// copy it to each router-specific key that doesn't already have prefs.
  Future<void> _migrateGlobalDashboardPreferencesIfNeeded() async {
    try {
      final globalKey = 'dashboard_preferences';
      final globalJson = await _secureStorageService.readValue(globalKey);
      if (globalJson == null || globalJson.isEmpty) return;

      final routers = _routerService?.routers ?? const <model.Router>[];
      if (routers.isEmpty) return;

      // Validate JSON format before writing
      try {
        jsonDecode(globalJson);
      } catch (_) {
        return; // Not valid JSON; skip migration
      }

      for (final router in routers) {
        final key = 'dashboard_preferences:${router.id}';
        final existing = await _secureStorageService.readValue(key);
        if (existing == null || existing.isEmpty) {
          await _secureStorageService.writeValue(key, globalJson);
        }
      }

      // If all routers now have scoped prefs, remove the legacy global key
      var allHavePrefs = true;
      for (final router in routers) {
        final key = 'dashboard_preferences:${router.id}';
        final v = await _secureStorageService.readValue(key);
        if (v == null || v.isEmpty) {
          allHavePrefs = false;
          break;
        }
      }
      if (allHavePrefs) {
        await _secureStorageService.deleteValue(globalKey);
      }
    } catch (e, stack) {
      Logger.exception('Failed migrating global dashboard preferences', e, stack);
    }
  }

  Future<void> _loadReviewerMode() async {
    // Initialize secure storage service with default factory first
    ServiceContainer.configure(reviewerMode: false);
    _secureStorageService = ServiceContainer.instance.factory
        .createSecureStorageService();

    final stored = await _secureStorageService.readValue(
      AppConfig.reviewerModeKey,
    );
    _reviewerModeEnabled = stored == 'true';
  }

  void _initializeServices() {
    // Configure the service container based on reviewer mode
    ServiceContainer.configure(reviewerMode: _reviewerModeEnabled);

    // Create services using the factory
    final factory = ServiceContainer.instance.factory;
    _authService = factory.createAuthService();
    _apiService = factory.createApiService();
    _routerService = factory.createRouterService();
    _throughputService = factory.createThroughputService();
  }

  Future<void> setReviewerMode(bool enabled) async {
    _reviewerModeEnabled = enabled;
    await _secureStorageService.writeValue(
      AppConfig.reviewerModeKey,
      enabled.toString(),
    );
    _initializeServices();
    notifyListeners();
  }

  Future<void> _loadThemeMode() async {
    final stored = await _secureStorageService.readValue(_themeModeKey);
    if (stored == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (stored == 'light') {
      _themeMode = ThemeMode.light;
    } else if (stored == 'system') {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  ThemeMode get themeMode => _themeMode;
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _secureStorageService.writeValue(_themeModeKey, mode.name);
    notifyListeners();
  }

  Future<void> _loadClientsViewMode() async {
    final stored = await _secureStorageService.readValue(_clientsAggregateKey);
    if (stored == 'true') {
      _clientsAggregateAllRouters = true;
    } else if (stored == 'false') {
      _clientsAggregateAllRouters = false;
    }
  }

  Future<void> setClientsAggregateAllRouters(bool aggregate) async {
    _clientsAggregateAllRouters = aggregate;
    await _secureStorageService.writeValue(
      _clientsAggregateKey,
      aggregate.toString(),
    );
    notifyListeners();
  }

  Future<void> loadDashboardPreferences() async {
    try {
      // Scope preferences by selected router if available
      final routerId = _routerService?.selectedRouter?.id;
      final key = routerId != null
          ? 'dashboard_preferences:$routerId'
          : 'dashboard_preferences';

      // Try router-specific key first
      String? json = await _secureStorageService.readValue(key);
      // Backward-compat: if missing, fall back to global key
      if ((json == null || json.isEmpty) && routerId != null) {
        json = await _secureStorageService.readValue('dashboard_preferences');
      }
      if (json != null && json.isNotEmpty) {
        _dashboardPreferences = DashboardPreferences.fromJson(jsonDecode(json));
        notifyListeners();
      }
    } catch (e, stack) {
      Logger.exception('Failed to load dashboard preferences', e, stack);
      _dashboardPreferences = DashboardPreferences();
    }
  }

  Future<void> saveDashboardPreferences(DashboardPreferences prefs) async {
    try {
      _dashboardPreferences = prefs;
      final routerId = _routerService?.selectedRouter?.id;
      final key = routerId != null
          ? 'dashboard_preferences:$routerId'
          : 'dashboard_preferences';
      await _secureStorageService.writeValue(key, jsonEncode(prefs.toJson()));
      notifyListeners();
    } catch (e, stack) {
      Logger.exception('Failed to save dashboard preferences', e, stack);
      rethrow;
    }
  }

  String? get sysauth => _authService?.sysauth;
  bool get isAuthenticated => _authService?.isAuthenticated ?? false;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  Map<String, dynamic>? get dashboardData => _dashboardData;
  List<double> get rxHistory => _throughputService?.rxHistory ?? [];
  List<double> get txHistory => _throughputService?.txHistory ?? [];
  double get currentRxRate => _throughputService?.currentRxRate ?? 0.0;
  double get currentTxRate => _throughputService?.currentTxRate ?? 0.0;
  bool get isDashboardLoading => _isDashboardLoading;
  String? get dashboardError => _dashboardError;

  // Interface-specific throughput getters
  List<double> getRxHistoryForInterface(String interface) {
    final deviceName = _getDeviceNameForInterface(interface);
    return _throughputService?.getRxHistoryForInterface(deviceName ?? interface) ?? [];
  }

  List<double> getTxHistoryForInterface(String interface) {
    final deviceName = _getDeviceNameForInterface(interface);
    return _throughputService?.getTxHistoryForInterface(deviceName ?? interface) ?? [];
  }

  double getCurrentRxRateForInterface(String interface) {
    final deviceName = _getDeviceNameForInterface(interface);
    return _throughputService?.getCurrentRxRateForInterface(deviceName ?? interface) ?? 0.0;
  }

  double getCurrentTxRateForInterface(String interface) {
    final deviceName = _getDeviceNameForInterface(interface);
    return _throughputService?.getCurrentTxRateForInterface(deviceName ?? interface) ?? 0.0;
  }

  Future<void> loadRouters() async {
    await _routerService?.loadRouters();
    notifyListeners();
  }

  Future<void> addRouter(model.Router router) async {
    await _routerService?.addRouter(router);
    notifyListeners();
  }

  Future<void> removeRouter(String id) async {
    if (_routerService == null) return;

    // Get the router before removing to clear its certificates
    final router = _routerService!.routers.firstWhere(
      (r) => r.id == id,
      orElse: () => throw Exception('Router not found'),
    );

    // Clear certificates for this specific router
    await _httpClientManager.clearCertificatesForHost(router.ipAddress);

    final needsSwitch = await _routerService!.removeRouter(id);
    if (needsSwitch && _routerService!.routers.isNotEmpty) {
      await selectRouter(_routerService!.routers.first.id);
    } else if (_routerService!.selectedRouter == null) {
      _dashboardData = null;
      notifyListeners();
    } else {
      notifyListeners();
    }
  }

  Future<void> selectRouter(String id, {BuildContext? context}) async {
    if (_routerService == null || _routerService!.routers.isEmpty) return;

    final found = _routerService!.selectRouter(id);
    if (found == null) return;

    _isLoading = true;
    _dashboardError = null;

    // Clear throughput data when switching routers to prevent mixing data from different routers
    _cancelThroughputTimer();

    // Determine a safe context before any awaits
    final safeContext = context?.mounted == true ? context : null; // ignore: use_build_context_synchronously

    // Load router-scoped dashboard preferences immediately on selection
    await loadDashboardPreferences();

    notifyListeners();
    // ignore: use_build_context_synchronously
    final loginSuccess = await login(
      found.ipAddress,
      found.username,
      found.password,
      found.useHttps,
      fromRouter: true,
      context: safeContext, // ignore: use_build_context_synchronously
    );
    if (loginSuccess) {
      await fetchDashboardData();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateRouter(model.Router router) async {
    await _routerService?.updateRouter(router);
    notifyListeners();
  }

  Future<bool> login(
    String ip,
    String user,
    String pass,
    bool useHttps, {
    bool fromRouter = false,
    BuildContext? context,
  }) async {
    _isLoading = true;
    _errorMessage = null;

    // Clear throughput data when logging in to prevent mixing data from different sessions
    _cancelThroughputTimer();

    notifyListeners();

    try {
      await _authService!.login(ip, user, pass, useHttps, context: context);

      // Check if authentication was successful
      if (_authService!.isAuthenticated) {
        // Get the actual protocol used (might be different due to redirect)
        final actualUseHttps = _authService!.useHttps;

        if (!fromRouter) {
          // If not from router selection, add or update router with detected protocol
          if (_routerService != null) {
            final router = _routerService!.createRouter(
              ip,
              user,
              pass,
              actualUseHttps, // Use the detected protocol
            );
            final idx = _routerService!.routers.indexWhere(
              (r) => r.id == router.id,
            );
            if (idx == -1) {
              await addRouter(router);
            } else {
              await updateRouter(router);
            }
          }
        } else if (actualUseHttps != useHttps && _routerService != null) {
          // If we're logging in from a saved router and the protocol changed, update it
          final router = _routerService!.selectedRouter;
          if (router != null) {
            final updatedRouter = router.copyWith(useHttps: actualUseHttps);
            await updateRouter(updatedRouter);
            Logger.info(
              'Updated router protocol from ${useHttps ? "HTTPS" : "HTTP"} to ${actualUseHttps ? "HTTPS" : "HTTP"}',
            );
          }
        }
        await fetchDashboardData();
        _startThroughputTimer();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage =
            'Login Failed: Invalid credentials or host unreachable.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'An error occurred: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void logout() {
    _authService?.logout().then((_) {});
    _dashboardData = null;
    _dashboardError = null;
    _cancelThroughputTimer();
    // Optionally, do not clear routers or selectedRouter
    notifyListeners();
  }

  Future<void> fetchDashboardData() async {
    if (_reviewerModeEnabled) {
      // For reviewer mode, return mock data immediately
      _isDashboardLoading = true;
      _dashboardError = null;
      notifyListeners();

      await Future.delayed(
        const Duration(milliseconds: 500),
      ); // Simulate network delay

      try {
        final results = await Future.wait([
          _apiService!.callSimple('system', 'board', {}),
          _apiService!.callSimple('system', 'info', {}),
          _apiService!.callSimple('network', 'device', {}),
          _apiService!.callSimple('network.interface', 'dump', {}),
          _apiService!.callSimple('wireless', 'devices', {}),
          _apiService!.callSimple('luci-rpc', 'getDHCPLeases', {}),
          _apiService!.callSimple('uci', 'get', {'config': 'wireless'}),
          _apiService!.fetchAllAssociatedWirelessMacsWithContext(
            ipAddress: 'mock',
            sysauth: 'mock',
            useHttps: false,
          ),
        ]);

        final interfaceDump = results[3][1] as Map<String, dynamic>;
        final rawDhcpData = results[5][1] as Map<String, dynamic>;
        final processedDhcpData = _processDhcpLeases(rawDhcpData);
        final macToAccessPoint = results[7] as Map<String, String>;

        _dashboardData = {
          'boardInfo': results[0][1],
          'sysInfo': results[1][1],
          'networkDevices': results[2][1],
          'interfaceDump': interfaceDump,
          'wireless': results[4][1],
          'dhcpLeases': processedDhcpData,
          'uciWirelessConfig': results[6][1],
          'wan': _extractWanData(interfaceDump),
          'wireguard': <String, dynamic>{}, // Empty for reviewer mode
          // Same membership as Clients: DHCP ∪ Wi-Fi.
          'onlineClients': _buildClientsFromSources(
            leases: _extractDhcpLeaseMaps(processedDhcpData),
            macToAccessPoint: macToAccessPoint,
          ).length,
          'conntrackCount': 842,
          'conntrackMax': 16384,
          'cpuUsage': '2%',
          'cpuUsageDetail':
              'CPU: 2% HWE: 6% ECM: tcp 44 udp 72 other 0 total 116',
          'luciVersion': 'openwrt-24.10 git-25.068.37183-a5bb34a',
          'temperature': 'CPU: 48.0°C, WiFi: 52.0°C 50.0°C',
          'temperatureShort': '48.0°C',
          'mountPoints': [
            {
              'device': '/dev/root',
              'mount': '/overlay',
              'size': 134217728,
              'free': 67108864,
              'avail': 67108864,
            },
            {
              'device': 'tmpfs',
              'mount': '/tmp',
              'size': 268435456,
              'free': 201326592,
              'avail': 201326592,
            },
          ],
          'ethernetPorts': [
            {'device': 'lan1', 'role': 'lan'},
            {'device': 'lan2', 'role': 'lan'},
            {'device': 'lan3', 'role': 'lan'},
            {'device': 'wan', 'role': 'wan'},
          ],
          '_lastUpdated':
              DateTime.now().millisecondsSinceEpoch, // Force UI updates
        };

        // Update throughput data with mock network data for reviewer mode
        if (_throughputService != null) {
          final networkData = results[2][1] as Map<String, dynamic>?;
          final wanDeviceNames = {
            'lan1',
            'wan',
            'br-lan',
            'wlan0',
          }; // Mock devices aligned with network_devices.json

        // Check if we should track specific interface
        final prefs = _dashboardPreferences;
        String? specificInterface;
        if (!prefs.showAllThroughput &&
            prefs.primaryThroughputInterface != null) {
          // Map interface name to actual device name
          specificInterface = _getDeviceNameForInterface(prefs.primaryThroughputInterface!);
        }

          _throughputService!.updateThroughput(
            networkData,
            wanDeviceNames,
            specificInterface: specificInterface,
          );
        }

        // Start throughput timer for reviewer mode
        _startThroughputTimer();

        // Schedule an immediate throughput update to get initial data faster
        Future.delayed(const Duration(milliseconds: 100), () {
          _updateThroughputOnly();
        });

        _isDashboardLoading = false;
        notifyListeners();
      } catch (e) {
        _dashboardError = 'Failed to fetch dashboard data: $e';
        _isDashboardLoading = false;
        notifyListeners();
      }
      return;
    }

    if (_routerService?.selectedRouter == null ||
        _authService?.sysauth == null) {
      return;
    }

    // If already loading, don't start another request (but this shouldn't prevent pull-to-refresh)
    // We'll let the new request proceed and the loading state will be handled properly
    final ip = _routerService!.selectedRouter!.ipAddress;
    final useHttps = _routerService!.selectedRouter!.useHttps;

    _isDashboardLoading = true;
    _dashboardError = null;
    notifyListeners();

    try {
      // Perform all API calls in parallel
      Future<dynamic> callOptionalRpc({
        required String object,
        required String method,
        Map<String, dynamic>? params,
      }) async {
        try {
          return await _apiService!.call(
            ip,
            _authService!.sysauth!,
            useHttps,
            object: object,
            method: method,
            params: params,
          );
        } catch (e, stack) {
          Logger.warning('Optional RPC $object.$method failed: $e');
          Logger.debug('Optional RPC $object.$method stack: $stack');
          return null;
        }
      }

      final wirelessFuture = callOptionalRpc(
        object: 'luci-rpc',
        method: 'getWirelessDevices',
        params: {},
      );

      // UCI wireless config is optional — wired-only routers may not have it
      final uciWirelessFuture = callOptionalRpc(
        object: 'uci',
        method: 'get',
        params: {'config': 'wireless'},
      );

      final cpuUsageFuture = callOptionalRpc(
        object: 'luci',
        method: 'getCPUUsage',
        params: {},
      );
      final luciVersionFuture = callOptionalRpc(
        object: 'luci',
        method: 'getVersion',
        params: {},
      );
      final assocStationsFuture = _apiService!
          .fetchAllAssociatedWirelessMacsWithContext(
            ipAddress: ip,
            sysauth: _authService!.sysauth!,
            useHttps: useHttps,
          )
          .catchError((Object _, StackTrace __) => <String, String>{});
      final tempInfoFuture = callOptionalRpc(
        object: 'luci',
        method: 'getTempInfo',
        params: {},
      );
      final conntrackCountFuture = callOptionalRpc(
        object: 'file',
        method: 'read',
        params: {'path': '/proc/sys/net/netfilter/nf_conntrack_count'},
      );
      final conntrackMaxFuture = callOptionalRpc(
        object: 'file',
        method: 'read',
        params: {'path': '/proc/sys/net/netfilter/nf_conntrack_max'},
      );
      final mountPointsFuture = callOptionalRpc(
        object: 'luci',
        method: 'getMountPoints',
        params: {},
      );
      final ethernetPortsFuture = callOptionalRpc(
        object: 'luci',
        method: 'getBuiltinEthernetPorts',
        params: {},
      );
      final boardJsonFuture = callOptionalRpc(
        object: 'file',
        method: 'read',
        params: {'path': '/etc/board.json'},
      );

      final results = await Future.wait([
        _apiService!.call(
          ip,
          _authService!.sysauth!,
          useHttps,
          object: 'system',
          method: 'board',
          params: {},
        ),
        _apiService!.call(
          ip,
          _authService!.sysauth!,
          useHttps,
          object: 'system',
          method: 'info',
          params: {},
        ),
        _apiService!.call(
          ip,
          _authService!.sysauth!,
          useHttps,
          object: 'luci-rpc',
          method: 'getNetworkDevices',
          params: {},
        ),
        _apiService!.call(
          ip,
          _authService!.sysauth!,
          useHttps,
          object: 'network.interface',
          method: 'dump',
          params: {},
        ),
        _apiService!.call(
          ip,
          _authService!.sysauth!,
          useHttps,
          object: 'luci-rpc',
          method: 'getDHCPLeases',
          params: {},
        ),
      ]);

      // Helper to safely extract data and handle errors from LuCI's [status, data] responses
      dynamic getData(dynamic result) {
        if (result is List && result.length > 1) {
          if (result[0] == 0) {
            return result[1]; // Success
          } else {
            // Throw an exception with the error message from the API
            final errorMessage = result[1] is String
                ? result[1]
                : 'Unknown API Error';
            throw Exception(errorMessage);
          }
        }
        // Handle cases where the result is not in the expected format
        return result;
      }

      dynamic getOptionalData(dynamic result, String label) {
        try {
          return getData(result);
        } catch (e) {
          Logger.warning('Optional RPC $label returned error: $e');
          return null;
        }
      }

      final boardInfoData = getData(results[0]);
      final sysInfoData = getData(results[1]);
      final networkData = getData(results[2]) as Map<String, dynamic>?;
      final interfaceDump = getData(results[3]) as Map<String, dynamic>?;
      final dhcpLeases = getData(results[4]) as Map<String, dynamic>?;

      // Await optional wireless futures in parallel (won't throw — wired-only routers are fine)
      final optionalResults = await Future.wait([
        wirelessFuture,
        uciWirelessFuture,
        cpuUsageFuture,
        luciVersionFuture,
        tempInfoFuture,
        conntrackCountFuture,
        conntrackMaxFuture,
        mountPointsFuture,
        ethernetPortsFuture,
        boardJsonFuture,
        assocStationsFuture,
      ]);
      final wirelessRaw = optionalResults[0];
      final uciWirelessRaw = optionalResults[1];
      final cpuUsageRaw = optionalResults[2];
      final luciVersionRaw = optionalResults[3];
      final tempInfoRaw = optionalResults[4];
      final conntrackCountRaw = optionalResults[5];
      final conntrackMaxRaw = optionalResults[6];
      final mountPointsRaw = optionalResults[7];
      final ethernetPortsRaw = optionalResults[8];
      final boardJsonRaw = optionalResults[9];
      final macToAccessPoint = optionalResults[10] as Map<String, String>;

      Map<String, dynamic>? wirelessData;
      if (wirelessRaw != null) {
        final parsedWireless =
            getOptionalData(wirelessRaw, 'luci-rpc.getWirelessDevices');
        if (parsedWireless is Map<String, dynamic>) {
          wirelessData = parsedWireless;
        }
      }

      dynamic uciWirelessConfig;
      if (uciWirelessRaw != null) {
        uciWirelessConfig =
            getOptionalData(uciWirelessRaw, 'uci.get wireless');
      }

      final cpuUsageData = cpuUsageRaw != null
          ? getOptionalData(cpuUsageRaw, 'luci.getCPUUsage')
          : null;
      final luciVersionData = luciVersionRaw != null
          ? getOptionalData(luciVersionRaw, 'luci.getVersion')
          : null;
      final tempInfoData = tempInfoRaw != null
          ? getOptionalData(tempInfoRaw, 'luci.getTempInfo')
          : null;
      final conntrackCountData = conntrackCountRaw != null
          ? getOptionalData(conntrackCountRaw, 'file.read conntrack_count')
          : null;
      final conntrackMaxData = conntrackMaxRaw != null
          ? getOptionalData(conntrackMaxRaw, 'file.read conntrack_max')
          : null;
      final mountPointsData = mountPointsRaw != null
          ? getOptionalData(mountPointsRaw, 'luci.getMountPoints')
          : null;
      final ethernetPortsData = ethernetPortsRaw != null
          ? getOptionalData(ethernetPortsRaw, 'luci.getBuiltinEthernetPorts')
          : null;
      final boardJsonData = boardJsonRaw != null
          ? getOptionalData(boardJsonRaw, 'file.read board.json')
          : null;

      final conntrackCount = _parseProcInt(conntrackCountData);
      final conntrackMax = _parseProcInt(conntrackMaxData);
      final temperature = _parseTemperature(tempInfoData);
      final cpuUsageParsed = _parseCpuUsage(cpuUsageData);
      final mountPoints = _parseMountPoints(mountPointsData);
      final ethernetPorts = _parseEthernetPorts(
        ethernetPortsData,
        boardJsonData,
        networkData,
      );
      // Same membership as Clients tab: DHCP ∪ Wi-Fi.
      final onlineClients = _buildClientsFromSources(
        leases: _extractDhcpLeaseMaps(dhcpLeases),
        macToAccessPoint: macToAccessPoint,
      ).length;

      // Fetch WireGuard peer information for WireGuard interfaces
      final wireguardData = <String, dynamic>{};
      if (interfaceDump != null && interfaceDump['interface'] is List) {
        // Check if there are any WireGuard interfaces
        final hasWireGuardInterfaces = interfaceDump['interface'].any((
          interface,
        ) {
          if (interface is Map<String, dynamic>) {
            final proto = interface['proto'] as String?;
            return proto == 'wireguard';
          }
          return false;
        });

        if (hasWireGuardInterfaces) {
          // Fetch all WireGuard data at once
          final allWireGuardData = await _apiService!.fetchWireGuardPeers(
            ipAddress: ip,
            sysauth: _authService!.sysauth!,
            useHttps: useHttps,
            interface: '', // Empty string to get all interfaces
          );

          if (allWireGuardData != null) {
            // The new endpoint returns data for all interfaces
            // We need to extract data for each WireGuard interface
            for (final interface in interfaceDump['interface']) {
              if (interface is Map<String, dynamic>) {
                final ifname = interface['interface'] as String?;
                final proto = interface['proto'] as String?;
                if (proto == 'wireguard' && ifname != null) {
                  // Look for this interface in the WireGuard data
                  final interfaceData = allWireGuardData[ifname];

                  if (interfaceData != null) {
                    wireguardData[ifname] = interfaceData;
                  }
                }
              }
            }
          }
        }
      }

      // Throughput calculation - collect ALL interface devices
      final wanDeviceNames = <String>{};
      if (interfaceDump != null && interfaceDump['interface'] is List) {
        for (final interface in interfaceDump['interface']) {
          if (interface is Map<String, dynamic>) {
            final ifname = interface['interface'] as String?;
            // Skip only loopback interface
            if (ifname != null && ifname != 'loopback' && ifname != 'lo') {
              final device = interface['device'] as String?;
              final l3Device = interface['l3_device'] as String?;
              if (device != null) {
                wanDeviceNames.add(device);
              }
              if (l3Device != null && l3Device != device) {
                wanDeviceNames.add(l3Device);
              }
            }
          }
        }
      }

      // Update throughput data using the service
        // Check if we should track specific interface
        final prefs = _dashboardPreferences;
        String? specificInterface;
        if (!prefs.showAllThroughput &&
            prefs.primaryThroughputInterface != null) {
          // Map interface name to actual device name
          specificInterface = _getDeviceNameForInterface(prefs.primaryThroughputInterface!);
        }

      _throughputService?.updateThroughput(
        networkData,
        wanDeviceNames,
        specificInterface: specificInterface,
      );

      _dashboardData = {
        'boardInfo': boardInfoData,
        'sysInfo': sysInfoData,
        'networkDevices': networkData,
        'interfaceDump': interfaceDump,
        'wireless': wirelessData ?? <String, dynamic>{},
        'dhcpLeases': dhcpLeases,
        'wan': _extractWanData(interfaceDump),
        'uciWirelessConfig': uciWirelessConfig,
        'wireguard': wireguardData,
        'onlineClients': onlineClients,
        'conntrackCount': conntrackCount,
        'conntrackMax': conntrackMax,
        'cpuUsage': cpuUsageParsed?.percent,
        'cpuUsageDetail': cpuUsageParsed?.detail,
        'luciVersion': _formatLuciVersion(luciVersionData),
        'temperature': temperature,
        'temperatureShort': _formatTemperatureShort(temperature),
        'mountPoints': mountPoints,
        'ethernetPorts': ethernetPorts,
        '_lastUpdated':
            DateTime.now().millisecondsSinceEpoch, // Force UI updates
      };

      // Hybrid approach: update lastKnownHostname for the selected router
      final boardInfo = _dashboardData?['boardInfo'] as Map<String, dynamic>?;
      final hostname = boardInfo?['hostname']?.toString();
      if (hostname != null && hostname.isNotEmpty) {
        await _routerService?.updateSelectedRouterHostname(hostname);
      }

      // Ensure throughput timer is running
      _startThroughputTimer();

      // Schedule an immediate throughput update to get initial data faster
      Future.delayed(const Duration(milliseconds: 100), () {
        _updateThroughputOnly();
      });
    } catch (e) {
      final errorMessage = e.toString();
      if (errorMessage.contains('Access denied')) {
        _dashboardError = 'Access Denied: Check RPC permissions for this user.';
      } else {
        _dashboardError = 'Failed to fetch dashboard data: $e';
      }
      // Log error with stack trace for debugging
      // print('Dashboard fetch error: $e\n$stack');
      // Clear dashboard data when there's an error so we don't show stale data
      _dashboardData = null;
    } finally {
      _isDashboardLoading = false;
      notifyListeners();
    }
  }

  Map<String, dynamic> _processDhcpLeases(Map<String, dynamic> rawDhcpData) {
    final stdout = rawDhcpData['stdout'] as String? ?? '';
    final leases = <Map<String, dynamic>>[];

    for (final line in stdout.split('\n')) {
      if (line.trim().isEmpty) continue;

      final parts = line.trim().split(' ');
      if (parts.length >= 5) {
        // Format: timestamp mac_address ip_address hostname client_id
        final timestamp = int.tryParse(parts[0]) ?? 0;
        final macAddress = parts[1];
        final ipAddress = parts[2];
        final hostname = parts[3];

        leases.add({
          'expires': timestamp,
          'macaddr': macAddress,
          'ipaddr': ipAddress,
          'hostname': hostname,
          'activetime': 0, // Default for mock data
          'leasetime': timestamp,
        });
      }
    }

    return {'dhcp_leases': leases};
  }

  int? _parseProcInt(dynamic data) {
    if (data == null) return null;
    if (data is Map) {
      final raw = data['data']?.toString() ?? data['value']?.toString();
      if (raw != null) {
        return int.tryParse(raw.trim().split('\n').first.trim());
      }
    }
    return int.tryParse(data.toString().trim());
  }

  String? _formatLuciVersion(dynamic data) {
    if (data is! Map) return null;
    final branch = data['branch']?.toString().trim() ?? '';
    final revision = data['revision']?.toString().trim() ?? '';
    // Match LuCI status page: "branch revision"
    final parts = <String>[
      if (branch.isNotEmpty) branch,
      if (revision.isNotEmpty) revision,
    ];
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  String? _parseTemperature(dynamic data) {
    if (data == null) return null;
    if (data is Map) {
      final raw = data['tempinfo']?.toString().trim();
      if (raw != null && raw.isNotEmpty && raw != '--') {
        return raw;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _parseEthernetPorts(
    dynamic portsData,
    dynamic boardJsonData,
    Map<String, dynamic>? networkDevices,
  ) {
    final ports = <Map<String, dynamic>>[];
    final seen = <String>{};

    void addPort(String device, String role) {
      final name = device.trim();
      if (name.isEmpty || seen.contains(name)) return;
      seen.add(name);
      ports.add({'device': name, 'role': role});
    }

    dynamic list;
    if (portsData is Map) {
      list = portsData['result'] ?? portsData['ports'];
    } else if (portsData is List) {
      list = portsData;
    }
    if (list is List) {
      for (final item in list) {
        if (item is! Map) continue;
        final device = item['device']?.toString() ?? '';
        final role = item['role']?.toString() ?? 'unknown';
        addPort(device, role);
      }
    }

    if (ports.isEmpty) {
      String? boardRaw;
      if (boardJsonData is Map) {
        boardRaw =
            boardJsonData['data']?.toString() ??
            boardJsonData['value']?.toString();
      } else if (boardJsonData is String) {
        boardRaw = boardJsonData;
      }
      if (boardRaw != null && boardRaw.trim().isNotEmpty) {
        try {
          final board = jsonDecode(boardRaw);
          final network = board is Map ? board['network'] : null;
          if (network is Map) {
            final lan = network['lan'];
            if (lan is Map) {
              final lanPorts = lan['ports'];
              if (lanPorts is List) {
                for (final p in lanPorts) {
                  addPort(p.toString(), 'lan');
                }
              } else if (lan['device'] != null) {
                addPort(lan['device'].toString(), 'lan');
              }
            }
            final wan = network['wan'];
            if (wan is Map) {
              final wanPorts = wan['ports'];
              if (wanPorts is List) {
                for (final p in wanPorts) {
                  addPort(p.toString(), 'wan');
                }
              } else if (wan['device'] != null) {
                addPort(wan['device'].toString(), 'wan');
              }
            }
          }
        } catch (e) {
          Logger.warning('Failed parsing board.json for ethernet ports: $e');
        }
      }
    }

    // Last resort: infer ethernet-like devices from network device dump.
    if (ports.isEmpty && networkDevices != null) {
      for (final entry in networkDevices.entries) {
        final name = entry.key;
        final lower = name.toLowerCase();
        if (lower == 'lo' ||
            lower.startsWith('br-') ||
            lower.startsWith('wlan') ||
            lower.startsWith('phy') ||
            lower.startsWith('wwan') ||
            lower.contains('wireguard') ||
            lower.startsWith('tun') ||
            lower.startsWith('tap')) {
          continue;
        }
        final info = entry.value;
        final type = info is Map
            ? (info['type']?.toString().toLowerCase() ?? '')
            : '';
        if (type.contains('wireless') || type.contains('bridge')) continue;
        if (lower.startsWith('eth') ||
            lower.startsWith('lan') ||
            lower == 'wan' ||
            lower.startsWith('wan')) {
          addPort(name, lower.contains('wan') ? 'wan' : 'lan');
        }
      }
    }

    // Keep board / RPC order (typically LAN ports, then WAN).
    return ports;
  }

  List<Map<String, dynamic>> _parseMountPoints(dynamic data) {
    dynamic list;
    if (data is Map) {
      list = data['result'];
    } else if (data is List) {
      list = data;
    }
    if (list is! List) return const [];

    final mounts = <Map<String, dynamic>>[];
    for (final item in list) {
      if (item is! Map) continue;
      final mount = item['mount']?.toString() ?? '';
      if (mount.isEmpty || mount == '/' || mount == '/dev') continue;
      final size = _asIntValue(item['size']) ?? 0;
      if (size <= 0) continue;
      final free = _asIntValue(item['free']) ?? 0;
      final avail = _asIntValue(item['avail']);
      mounts.add({
        'device': item['device']?.toString() ?? '—',
        'mount': mount,
        'size': size,
        'free': free,
        'avail': avail,
      });
    }

    mounts.sort((a, b) {
      final am = a['mount'] as String;
      final bm = b['mount'] as String;
      if (am == '/overlay') return -1;
      if (bm == '/overlay') return 1;
      if (am == '/tmp') return -1;
      if (bm == '/tmp') return 1;
      return (b['size'] as int).compareTo(a['size'] as int);
    });
    return mounts;
  }

  int? _asIntValue(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }

  /// Prefer vendor realtime CPU% (luci.getCPUUsage); null → UI falls back to loadavg.
  ({String percent, String? detail})? _parseCpuUsage(dynamic data) {
    if (data == null) return null;

    String? raw;
    if (data is Map) {
      raw = data['cpuusage']?.toString().trim();
    } else {
      raw = data.toString().trim();
    }
    if (raw == null || raw.isEmpty) return null;

    final cpuMatch = RegExp(r'CPU:\s*(\d+(?:\.\d+)?)\s*%', caseSensitive: false)
        .firstMatch(raw);
    if (cpuMatch != null) {
      return (percent: '${cpuMatch.group(1)}%', detail: raw);
    }

    final percentMatch = RegExp(r'(\d+(?:\.\d+)?)\s*%').firstMatch(raw);
    if (percentMatch != null) {
      return (percent: '${percentMatch.group(1)}%', detail: raw);
    }

    return null;
  }

  /// Prefer a short value for dashboard cells (e.g. "64.4°C").
  String? _formatTemperatureShort(String? raw) {
    if (raw == null || raw.isEmpty) return null;

    // Prefer explicit CPU reading when present.
    final cpuMatch = RegExp(
      r'CPU:\s*([0-9]+(?:\.[0-9]+)?)\s*°?\s*C',
      caseSensitive: false,
    ).firstMatch(raw);
    if (cpuMatch != null) {
      return '${cpuMatch.group(1)}°C';
    }

    // Otherwise use the first temperature number in the string.
    final firstMatch = RegExp(
      r'([0-9]+(?:\.[0-9]+)?)\s*°?\s*C',
      caseSensitive: false,
    ).firstMatch(raw);
    if (firstMatch != null) {
      return '${firstMatch.group(1)}°C';
    }

    // Fallback: truncate long raw strings.
    if (raw.length <= 8) return raw;
    return '${raw.substring(0, 7)}…';
  }

  Map<String, dynamic>? _extractWanData(Map<String, dynamic>? interfaceDump) {
    if (interfaceDump == null || interfaceDump['interface'] == null) {
      return null;
    }
    try {
      for (var interface in interfaceDump['interface']) {
        if (interface['route'] is List) {
          for (var route in interface['route']) {
            if (route is Map &&
                route['target'] == '0.0.0.0' &&
                route['mask'] == 0) {
              return interface;
            }
          }
        }
      }
    } catch (e) {
      // print('WAN data extraction error: $e');
      return null;
    }
    return null;
  }

  String? _getDeviceNameForInterface(String interfaceName) {
    // Handle wireless format: "SSID (deviceName)"
    if (interfaceName.contains('(')) {
      final match = RegExp(r'\(([^)]+)\)').firstMatch(interfaceName);
      return match?.group(1);
    }
    
    // Map interface names to their actual device names from interface dump
    final interfaceDump = _dashboardData?['interfaceDump'] as Map<String, dynamic>?;
    if (interfaceDump != null && interfaceDump['interface'] is List) {
      for (final interface in interfaceDump['interface']) {
        if (interface is Map<String, dynamic>) {
          final ifname = interface['interface'] as String?;
          if (ifname == interfaceName) {
            // Return the device or l3_device field
            return (interface['device'] ?? interface['l3_device']) as String?;
          }
        }
      }
    }
    
    // If not found in interface dump, check if it's already a device name
    // (e.g., eth0, br-lan, wlan0)
    return interfaceName;
  }

  void _startThroughputTimer() {
    _throughputTimer?.cancel();
    // Don't start timer if we're rebooting
    if (_isRebooting) {
      return;
    }
    _throughputTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _updateThroughputOnly();
    });
  }

  /// Updates only throughput data without refetching the entire dashboard
  Future<void> _updateThroughputOnly() async {
    // Don't try to update throughput during reboot
    if (_isRebooting) {
      return;
    }

    if (_reviewerModeEnabled) {
      // For reviewer mode, get network devices data only
      try {
        final result = await _apiService!.callSimple('network', 'device', {});
        final networkData = result[1] as Map<String, dynamic>?;
        final wanDeviceNames = {'eth0'}; // Mock WAN device

        // Check if we should track specific interface
        final prefs = _dashboardPreferences;
        String? specificInterface;
        if (!prefs.showAllThroughput &&
            prefs.primaryThroughputInterface != null) {
          // Extract device name from interface ID (format: "SSID (deviceName)" or just "deviceName")
          final interfaceId = prefs.primaryThroughputInterface!;
          if (interfaceId.contains('(')) {
            // Wireless format: "SSID (deviceName)"
            final match = RegExp(r'\(([^)]+)\)').firstMatch(interfaceId);
            specificInterface = match?.group(1);
          } else {
            // Wired format: just device name
            specificInterface = interfaceId;
          }
        }

        _throughputService?.updateThroughput(
          networkData,
          wanDeviceNames,
          specificInterface: specificInterface,
        );
        notifyListeners();
      } catch (e) {
        // Don't log throughput update errors as they're non-critical
      }
      return;
    }

    if (_routerService?.selectedRouter == null ||
        _authService?.sysauth == null) {
      return;
    }

    final ip = _routerService!.selectedRouter!.ipAddress;
    final useHttps = _routerService!.selectedRouter!.useHttps;

    try {
      // Only fetch network devices for throughput calculation
      final result = await _apiService!.call(
        ip,
        _authService!.sysauth!,
        useHttps,
        object: 'luci-rpc',
        method: 'getNetworkDevices',
        params: {},
      );

      if (result is List && result.length > 1 && result[0] == 0) {
        final networkData = result[1] as Map<String, dynamic>?;

        // Get ALL device names from cached dashboard data (except loopback)
        final wanDeviceNames = <String>{};
        final interfaceDump =
            _dashboardData?['interfaceDump'] as Map<String, dynamic>?;
        if (interfaceDump != null && interfaceDump['interface'] is List) {
          for (final interface in interfaceDump['interface']) {
            if (interface is Map<String, dynamic>) {
              final ifname = interface['interface'] as String?;
              final device = interface['device'] as String?;
              final l3Device = interface['l3_device'] as String?;
              // Include all interfaces except loopback
              if (ifname != null && ifname != 'loopback' && ifname != 'lo') {
                if (device != null) wanDeviceNames.add(device);
                if (l3Device != null && l3Device != device) {
                  wanDeviceNames.add(l3Device);
                }
              }
            }
          }
        }

        // Check if we should track specific interface
        final prefs = _dashboardPreferences;
        String? specificInterface;
        if (!prefs.showAllThroughput &&
            prefs.primaryThroughputInterface != null) {
          // Extract device name from interface ID (format: "SSID (deviceName)" or just "deviceName")
          final interfaceId = prefs.primaryThroughputInterface!;
          if (interfaceId.contains('(')) {
            // Wireless format: "SSID (deviceName)"
            final match = RegExp(r'\(([^)]+)\)').firstMatch(interfaceId);
            specificInterface = match?.group(1);
          } else {
            // Wired format: just device name
            specificInterface = interfaceId;
          }
        }

        _throughputService?.updateThroughput(
          networkData,
          wanDeviceNames,
          specificInterface: specificInterface,
        );
        notifyListeners();
      }
    } catch (e) {
      // Don't log throughput update errors as they're non-critical
    }
  }

  void _cancelThroughputTimer() {
    _throughputTimer?.cancel();
    _throughputService?.clear();
  }

  Future<bool> reboot({BuildContext? context}) async {
    if (_authService?.sysauth == null || _authService?.ipAddress == null) {
      return false;
    }

    // Cancel throughput timer before starting reboot to prevent "client closed" errors
    _cancelThroughputTimer();

    _isRebooting = true;
    notifyListeners();

    try {
      final result = await _apiService!.reboot(
        _authService!.ipAddress!,
        _authService!.sysauth!,
        _authService!.useHttps,
        context: context,
      );
      // Wait 30 seconds before starting to poll for router availability
      // Some routers take longer to reboot
      Future.delayed(const Duration(seconds: 30), () {
        _pollRouterAvailability();
      });
      return result;
    } catch (e) {
      _isRebooting = false;
      notifyListeners();
      return false;
    }
  }

  void _pollRouterAvailability() {
    // Reset poll attempts
    _pollAttempts = 0;
    _pollingTimer?.cancel();

    // Start polling with exponential backoff
    _scheduleNextPoll();
  }

  void _scheduleNextPoll() {
    if (_pollAttempts >= _maxPollAttempts) {
      // Max attempts reached, stop polling
      _isRebooting = false;
      notifyListeners();
      // print('[Reboot] Timeout: Router did not come back online after $_maxPollAttempts attempts');

      // Show a user-friendly message
      if (onRouterBackOnline != null) {
        // Reuse the callback to show timeout message
        onRouterBackOnline!();
      }
      return;
    }

    // Calculate delay with exponential backoff: 3s, 3s, 5s, 8s, 12s, 18s, then 20s intervals
    int delaySeconds;
    if (_pollAttempts < 2) {
      delaySeconds = 3;
    } else if (_pollAttempts < 4) {
      delaySeconds = 5;
    } else if (_pollAttempts < 6) {
      delaySeconds = 8;
    } else if (_pollAttempts < 8) {
      delaySeconds = 12;
    } else if (_pollAttempts < 10) {
      delaySeconds = 18;
    } else {
      delaySeconds = 20; // Cap at 20 seconds for remaining attempts
    }

    _pollingTimer = Timer(Duration(seconds: delaySeconds), () async {
      _pollAttempts++;
      final available = await _pingRouter();

      if (available) {
        // Router is back online
        _pollingTimer?.cancel();
        _pollingTimer = null;
        _isRebooting = false;
        _pollAttempts = 0;
        notifyListeners();

        // Notify UI that router is back online
        if (onRouterBackOnline != null) {
          onRouterBackOnline!();
        }

        // Force relogin
        if (_routerService?.selectedRouter != null) {
          await login(
            _routerService!.selectedRouter!.ipAddress,
            _routerService!.selectedRouter!.username,
            _routerService!.selectedRouter!.password,
            _routerService!.selectedRouter!.useHttps,
          );
        }
      } else {
        // Schedule next poll
        _scheduleNextPoll();
      }
    });
  }

  Future<bool> _pingRouter() async {
    if (_authService?.ipAddress == null) return false;

    // Clear cached HTTP clients for this host to avoid stale connections
    if (_pollAttempts == 0) {
      _httpClientManager.disposeClient(
        _authService!.ipAddress!,
        _authService!.useHttps,
      );
    }

    // Try multiple endpoints in order
    final scheme = _authService!.useHttps ? 'https' : 'http';
    final endpoints = [
      '/', // Root
      '/cgi-bin/luci/', // LuCI login page
      '/cgi-bin/luci/admin', // Admin page
    ];

    for (final endpoint in endpoints) {
      try {
        final url = '$scheme://${_authService!.ipAddress}$endpoint';

        // Create a fresh Dio client for pinging to avoid certificate/connection issues
        final dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
            sendTimeout: const Duration(seconds: 5),
            followRedirects: false,
            validateStatus: (code) => code != null && code >= 200 && code < 500,
          ),
        );

        if (_authService!.useHttps) {
          final adapter = IOHttpClientAdapter();
          adapter.createHttpClient = () {
            final httpClient = HttpClient();
            httpClient.connectionTimeout = const Duration(seconds: 5);
            // Accept any cert for ping only
            httpClient.badCertificateCallback = (cert, host, port) => true;
            return httpClient;
          };
          dio.httpClientAdapter = adapter;
        }

        // print('[Ping] Attempt $_pollAttempts: Checking $url');
        final response = await dio.get(url);
        // print('[Ping] Response from $endpoint: ${response.statusCode}');

        // Accept various status codes as "alive"
        final isAlive = response.statusCode != null &&
            response.statusCode! >= 200 &&
            response.statusCode! < 500;

        if (isAlive) {
          if (_pollAttempts > 5) {
            // If we've been polling for a while and get a response,
            // wait a bit more to ensure services are fully started
            await Future.delayed(const Duration(seconds: 5));
          }
          return true;
        }
      } catch (e) {
        // Try next endpoint
        if (endpoint == endpoints.last) {
          // print('[Ping] All endpoints failed on attempt $_pollAttempts');
          // print('[Ping] Last error: ${e.toString()}');

          if (e is SocketException) {
            // print('[Ping] Socket error: ${e.message}, OS Error: ${e.osError}');
          } else if (e is HandshakeException) {
            // print('[Ping] SSL handshake error - router may still be starting');
          }
        }
      }
    }

    return false;
  }

  Future<bool> checkRouterAvailability() async {
    if (_reviewerModeEnabled || _authService?.ipAddress == null) {
      return _reviewerModeEnabled;
    }
    return await _authService!.checkRouterAvailability(
      _authService!.ipAddress!,
      _authService!.useHttps,
    );
  }

  Future<bool> setWirelessRadioState(
    String device,
    bool enabled, {
    BuildContext? context,
  }) async {
    if (_reviewerModeEnabled) {
      // Simulate operation for reviewer mode
      await Future.delayed(const Duration(milliseconds: 500));
      await fetchDashboardData();
      return true;
    }

    if (_authService?.sysauth == null || _authService?.ipAddress == null) {
      return false;
    }

    try {
      // 1. Set the disabled state
      await _apiService!.uciSet(
        _authService!.ipAddress!,
        _authService!.sysauth!,
        _authService!.useHttps,
        config: 'wireless',
        section: device,
        values: {'disabled': enabled ? '0' : '1'},
        context: context,
      );

      // 2. Commit the changes
      await _apiService!.uciCommit(
        _authService!.ipAddress!,
        _authService!.sysauth!,
        _authService!.useHttps,
        config: 'wireless',
        context: context?.mounted == true ? context : null,
      );

      // 3. Reload wifi to apply changes
      await _apiService!.systemExec(
        _authService!.ipAddress!,
        _authService!.sysauth!,
        _authService!.useHttps,
        command: 'wifi reload',
        context: context?.mounted == true ? context : null,
      );

      // Refresh dashboard data to reflect the change
      await fetchDashboardData();

      return true;
    } catch (e) {
      _dashboardError = 'Failed to toggle Wi-Fi: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> tryAutoLogin({BuildContext? context}) async {
    if (_reviewerModeEnabled) {
      return await _authService!.tryAutoLogin(
        null,
        null,
        null,
        null,
        context: context,
      );
    }
    return await _authService?.tryAutoLogin(
          null,
          null,
          null,
          null,
          context: context,
        ) ??
        false;
  }

  /// Fetch all associated wireless MAC addresses from all wireless interfaces
  Future<Set<String>> fetchAllAssociatedWirelessMacs() async {
    final macToAp = await fetchAssociatedStationAccessPoints();
    return macToAp.keys.toSet();
  }

  /// Normalized MAC → access point SSID for the current/selected data source.
  Future<Map<String, String>> fetchAssociatedStationAccessPoints() async {
    if (_reviewerModeEnabled) {
      return await _apiService!.fetchAllAssociatedWirelessMacsWithContext(
        ipAddress: 'mock',
        sysauth: 'mock',
        useHttps: false,
      );
    }
    if (_routerService?.selectedRouter == null ||
        _authService?.sysauth == null) {
      return {};
    }

    final ip = _routerService!.selectedRouter!.ipAddress;
    final useHttps = _routerService!.selectedRouter!.useHttps;

    return await _apiService!.fetchAllAssociatedWirelessMacsWithContext(
      ipAddress: ip,
      sysauth: _authService!.sysauth!,
      useHttps: useHttps,
    );
  }

  /// Station count for one wireless ifname via `iwinfo.assoclist`.
  Future<int?> fetchAssociatedStationCount(String ifname) async {
    if (ifname.isEmpty || _apiService == null) return null;
    if (_reviewerModeEnabled) {
      final stations = await _apiService!.fetchAssociatedStationsWithContext(
        ipAddress: 'mock',
        sysauth: 'mock',
        useHttps: false,
        interface: ifname,
      );
      return stations.length;
    }
    if (_routerService?.selectedRouter == null ||
        _authService?.sysauth == null) {
      return null;
    }
    final stations = await _apiService!.fetchAssociatedStationsWithContext(
      ipAddress: _routerService!.selectedRouter!.ipAddress,
      sysauth: _authService!.sysauth!,
      useHttps: _routerService!.selectedRouter!.useHttps,
      interface: ifname,
    );
    return stations.length;
  }

  String _normalizeClientMac(String mac) =>
      mac.toUpperCase().replaceAll('-', ':');

  bool _isValidClientMac(String mac) {
    if (mac.isEmpty || mac == 'N/A') return false;
    if (mac == '00:00:00:00:00:00' || mac == 'FF:FF:FF:FF:FF:FF') return false;
    return RegExp(r'^([0-9A-F]{2}:){5}[0-9A-F]{2}$').hasMatch(mac);
  }

  List<Map<String, dynamic>> _extractDhcpLeaseMaps(dynamic data) {
    if (data is! Map) return const [];
    final leases = data['dhcp_leases'];
    if (leases is List) {
      return leases
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data['stdout'] is String) {
      final processed = _processDhcpLeases(Map<String, dynamic>.from(data));
      final parsed = processed['dhcp_leases'];
      if (parsed is List) {
        return parsed
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return const [];
  }

  List<Client> _buildClientsFromSources({
    required List<Map<String, dynamic>> leases,
    required Map<String, String> macToAccessPoint,
  }) {
    // Official-style: DHCP ∪ Wi-Fi associations.
    final wifiByMac = <String, String>{};
    macToAccessPoint.forEach((macKey, accessPoint) {
      final mac = _normalizeClientMac(macKey);
      if (_isValidClientMac(mac)) {
        wifiByMac[mac] = accessPoint;
      }
    });

    final clients = <String, Client>{};

    for (final lease in leases) {
      final client = Client.fromLease(lease);
      final mac = _normalizeClientMac(client.macAddress);
      if (!_isValidClientMac(mac)) continue;
      final onWifi = wifiByMac.containsKey(mac);
      // Assoc confirms wireless; otherwise keep fromLease heuristic (official).
      clients[mac] = onWifi
          ? client.copyWith(
              connectionType: ConnectionType.wireless,
              accessPoint: wifiByMac[mac],
            )
          : client;
    }

    wifiByMac.forEach((mac, accessPoint) {
      if (clients.containsKey(mac)) return;
      clients[mac] = Client.fromWirelessStation(
        mac,
        accessPoint: accessPoint,
      );
    });

    final list = clients.values.toList();
    list.sort((a, b) {
      int typeOrder(ConnectionType t) {
        switch (t) {
          case ConnectionType.wireless:
            return 0;
          case ConnectionType.wired:
            return 1;
          default:
            return 2;
        }
      }

      final cmpType =
          typeOrder(a.connectionType).compareTo(typeOrder(b.connectionType));
      if (cmpType != 0) return cmpType;
      return a.hostname.toLowerCase().compareTo(b.hostname.toLowerCase());
    });
    return list;
  }

  /// Aggregates DHCP leases and wireless associations across routers.
  Future<List<Client>> fetchAggregatedClients() async {
    try {
      final results = await Future.wait([
        fetchAllAssociatedStationAccessPointsAggregated()
            .catchError((Object _, StackTrace __) => <String, String>{}),
        fetchAggregatedDhcpLeases().catchError(
          (Object _, StackTrace __) => <Map<String, dynamic>>[],
        ),
      ]);
      return _buildClientsFromSources(
        leases: results[1] as List<Map<String, dynamic>>,
        macToAccessPoint: results[0] as Map<String, String>,
      );
    } catch (e, stack) {
      Logger.exception('Failed to aggregate clients', e, stack);
      return [];
    }
  }

  /// Returns clients for the currently selected router only
  Future<List<Client>> fetchClientsForSelectedRouter() async {
    try {
      if (_reviewerModeEnabled) {
        final results = await Future.wait([
          _apiService!
              .fetchAllAssociatedWirelessMacsWithContext(
                ipAddress: 'mock',
                sysauth: 'mock',
                useHttps: false,
              )
              .catchError((_) => <String, String>{}),
          _apiService!
              .callSimple('luci-rpc', 'getDHCPLeases', {})
              .catchError((_) => null),
        ]);
        final macToAccessPoint = results[0] as Map<String, String>;
        final leaseResult = results[1];
        var leases = <Map<String, dynamic>>[];
        if (leaseResult is List &&
            leaseResult.length > 1 &&
            leaseResult[0] == 0) {
          leases = _extractDhcpLeaseMaps(leaseResult[1]);
        }
        return _buildClientsFromSources(
          leases: leases,
          macToAccessPoint: macToAccessPoint,
        );
      }

      if (_routerService?.selectedRouter == null ||
          _authService?.sysauth == null) {
        return [];
      }
      final router = _routerService!.selectedRouter!;

      final results = await Future.wait([
        _apiService!
            .fetchAllAssociatedWirelessMacsWithContext(
              ipAddress: router.ipAddress,
              sysauth: _authService!.sysauth!,
              useHttps: router.useHttps,
            )
            .catchError((Object _, StackTrace __) => <String, String>{}),
        _apiService!
            .call(
              router.ipAddress,
              _authService!.sysauth!,
              router.useHttps,
              object: 'luci-rpc',
              method: 'getDHCPLeases',
              params: {},
            )
            .catchError((Object _, StackTrace __) => null),
      ]);

      final macToAccessPoint = results[0] as Map<String, String>;
      final leaseResult = results[1];
      var leases = <Map<String, dynamic>>[];
      if (leaseResult is List && leaseResult.length > 1 && leaseResult[0] == 0) {
        leases = _extractDhcpLeaseMaps(leaseResult[1]);
      }

      return _buildClientsFromSources(
        leases: leases,
        macToAccessPoint: macToAccessPoint,
      );
    } catch (e, stack) {
      Logger.exception('Failed to fetch clients for selected router', e, stack);
      return [];
    }
  }

  /// Returns MAC → SSID for associated stations across all routers.
  Future<Map<String, String>>
      fetchAllAssociatedStationAccessPointsAggregated() async {
    try {
      if (_reviewerModeEnabled) {
        return await _apiService!.fetchAllAssociatedWirelessMacsWithContext(
          ipAddress: 'mock',
          sysauth: 'mock',
          useHttps: false,
        );
      }

      final routers = _routerService?.routers ?? const <model.Router>[];
      if (routers.isEmpty) return {};

      final tasks = routers.map((r) async {
        try {
          if (_apiService is RealApiService) {
            final real = _apiService as RealApiService;
            final res = await real.loginWithProtocolDetection(
              r.ipAddress,
              r.username,
              r.password,
              r.useHttps,
            );
            if (res.token == null) return <String, String>{};
            return await _apiService!.fetchAllAssociatedWirelessMacsWithContext(
              ipAddress: r.ipAddress,
              sysauth: res.token!,
              useHttps: res.actualUseHttps,
            );
          }
        } catch (e) {
          // Skip router on failure
        }
        return <String, String>{};
      }).toList();

      final results = await Future.wait(tasks);
      final merged = <String, String>{};
      for (final map in results) {
        merged.addAll(map);
      }
      return merged;
    } catch (e, stack) {
      Logger.exception('Failed to aggregate wireless access points', e, stack);
      return {};
    }
  }

  /// Returns a union set of associated wireless MAC addresses across all routers
  Future<Set<String>> fetchAllAssociatedWirelessMacsAggregated() async {
    final map = await fetchAllAssociatedStationAccessPointsAggregated();
    return map.keys.toSet();
  }

  /// Returns a combined list of DHCP lease maps from all routers
  Future<List<Map<String, dynamic>>> fetchAggregatedDhcpLeases() async {
    try {
      if (_reviewerModeEnabled) {
        // Use mock data
        final result = await _apiService!.callSimple('luci-rpc', 'getDHCPLeases', {});
        if (result is List && result.length > 1 && result[0] == 0) {
          return _extractDhcpLeaseMaps(result[1]);
        }
        return [];
      }

      final routers = _routerService?.routers ?? const <model.Router>[];
      if (routers.isEmpty) return [];

      final tasks = routers.map((r) async {
        try {
          if (_apiService is RealApiService) {
            final real = _apiService as RealApiService;
            final res = await real.loginWithProtocolDetection(
              r.ipAddress,
              r.username,
              r.password,
              r.useHttps,
            );
            if (res.token == null) return <Map<String, dynamic>>[];
            final callRes = await _apiService!.call(
              r.ipAddress,
              res.token!,
              res.actualUseHttps,
              object: 'luci-rpc',
              method: 'getDHCPLeases',
              params: {},
            );
            if (callRes is List && callRes.length > 1 && callRes[0] == 0) {
              return _extractDhcpLeaseMaps(callRes[1]);
            }
          }
        } catch (e) {
          // Skip router on failure
        }
        return <Map<String, dynamic>>[];
      }).toList();

      final results = await Future.wait(tasks);
      // Deduplicate by MAC + IP
      final seen = <String, Map<String, dynamic>>{};
      for (final list in results) {
        for (final lease in list) {
          final mac = (lease['macaddr']?.toString() ?? '').toUpperCase();
          final ip = lease['ipaddr']?.toString() ?? '';
          final key = '$mac|$ip';
          if (!seen.containsKey(key)) {
            seen[key] = lease;
          }
        }
      }
      return seen.values.toList();
    } catch (e, stack) {
      Logger.exception('Failed to aggregate DHCP leases', e, stack);
      return [];
    }
  }
}
