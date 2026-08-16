import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:luci_mobile/l10n/app_localizations.dart';
import 'package:luci_mobile/state/app_state.dart';
import 'package:luci_mobile/main.dart';
import 'package:luci_mobile/widgets/luci_app_bar.dart';
import 'package:luci_mobile/widgets/luci_animation_system.dart';
import 'package:luci_mobile/models/router.dart' as model;

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final ScrollController _wirelessScrollController = ScrollController();
  bool _showWirelessLeftArrow = false;
  bool _showWirelessRightArrow = false;

  final ScrollController _wanScrollController = ScrollController();
  bool _showWanLeftArrow = false;
  bool _showWanRightArrow = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appStateProvider).fetchDashboardData();
      // Initialize arrows after layout
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateWirelessArrows();
        _updateWanArrows();
      });
    });
    _wirelessScrollController.addListener(_updateWirelessArrows);
    _wanScrollController.addListener(_updateWanArrows);
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateWirelessArrows();
      _updateWanArrows();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateWirelessArrows();
      _updateWanArrows();
    });
  }

  void _updateWirelessArrows() {
    if (!_wirelessScrollController.hasClients) return;
    final max = _wirelessScrollController.position.maxScrollExtent;
    final min = _wirelessScrollController.position.minScrollExtent;
    final offset = _wirelessScrollController.offset;
    setState(() {
      _showWirelessLeftArrow = offset > min + 2;
      _showWirelessRightArrow = offset < max - 2;
    });
  }

  void _updateWanArrows() {
    if (!_wanScrollController.hasClients) return;
    final max = _wanScrollController.position.maxScrollExtent;
    final min = _wanScrollController.position.minScrollExtent;
    final offset = _wanScrollController.offset;
    setState(() {
      _showWanLeftArrow = offset > min + 2;
      _showWanRightArrow = offset < max - 2;
    });
  }

  @override
  void dispose() {
    _wirelessScrollController.removeListener(_updateWirelessArrows);
    _wirelessScrollController.dispose();
    _wanScrollController.removeListener(_updateWanArrows);
    _wanScrollController.dispose();
    super.dispose();
  }

  String _formatUptime(int seconds) {
    final duration = Duration(seconds: seconds);
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    final parts = <String>[];
    if (days > 0) parts.add('${days}d');
    if (hours > 0 || days > 0) parts.add('${hours}h');
    parts.add('${minutes}m');
    return parts.join(' ');
  }

  /// OpenWrt `system.info.localtime` is not a UTC unix timestamp — it is
  /// `time(NULL) + tm_gmtoff`, i.e. wall-clock seconds with the router TZ
  /// already baked in. Format with [isUtc] so the phone timezone is not
  /// applied a second time.
  String _formatRouterLocaltime(int epochSeconds, {bool includeDate = true}) {
    final dt = DateTime.fromMillisecondsSinceEpoch(
      epochSeconds * 1000,
      isUtc: true,
    );
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
    if (!includeDate) return time;
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} $time';
  }

  List<({String label, String value})> _uptimeDetailRows(
    int seconds, {
    required AppLocalizations l10n,
    int? localtime,
  }) {
    final hasLocaltime = localtime != null && localtime > 0;
    final bootEpoch = hasLocaltime ? localtime - seconds : null;
    final bootText =
        (bootEpoch != null && bootEpoch > 0)
        ? _formatRouterLocaltime(bootEpoch)
        : '—';
    final localText =
        hasLocaltime ? _formatRouterLocaltime(localtime) : '—';

    return [
      (label: l10n.bootTime, value: bootText),
      (label: l10n.localTime, value: localText),
    ];
  }

  String _formatCpuLoad(List<dynamic> load) {
    if (load.isEmpty) return 'N/A';
    // Use the first value as the main CPU load
    final percent = ((load[0] / 65536) * 100).clamp(0, 100);
    return '${percent.toStringAsFixed(0)}%';
  }

  String _deriveReleaseChannel(Map<String, dynamic>? release) {
    if (release == null || release.isEmpty) {
      return 'stable';
    }

    final buffer = StringBuffer();
    // Check ALL release fields, not just a hardcoded subset
    for (final value in release.values) {
      if (value == null) continue;
      buffer
        ..write(' ')
        ..write(value.toString().toLowerCase());
    }

    final combined = buffer.toString();

    if (combined.contains('snapshot')) {
      return 'snapshot';
    }
    if (combined.contains('beta')) {
      return 'beta';
    }
    // Use pattern matching for 'rc' to avoid false positives on words like "source"
    if (RegExp(r'[\b\-_.]rc[\d\b\-_.]').hasMatch(combined) ||
        combined.contains('-rc') ||
        combined.endsWith('rc')) {
      return 'rc';
    }
    if (combined.contains('testing')) {
      return 'testing';
    }

    return 'stable';
  }

  ({Color background, Color foreground}) _channelColors(String channel) {
    switch (channel) {
      case 'snapshot':
        return (
          background: Colors.orange.withValues(alpha: 0.15),
          foreground: Colors.orange.shade800,
        );
      case 'beta':
        return (
          background: Colors.blue.withValues(alpha: 0.15),
          foreground: Colors.blue.shade800,
        );
      case 'rc':
        return (
          background: Colors.purple.withValues(alpha: 0.15),
          foreground: Colors.purple.shade800,
        );
      case 'testing':
        return (
          background: Colors.amber.withValues(alpha: 0.18),
          foreground: Colors.amber.shade900,
        );
      default:
        return (
          background: Colors.green.withValues(alpha: 0.15),
          foreground: Colors.green.shade800,
        );
    }
  }

  Widget _buildDeviceInfoCard(AppState appState) {
    final l10n = AppLocalizations.of(context)!;
    final boardInfo =
        appState.dashboardData?['boardInfo'] as Map<String, dynamic>?;
    final fullModel = boardInfo?['model']?.toString().trim();
    final displayModel = _shortModelName(
      (fullModel == null || fullModel.isEmpty) ? 'N/A' : fullModel,
    );
    final release = boardInfo?['release'] as Map<String, dynamic>?;
    final channel = _deriveReleaseChannel(release);
    final channelLabel = channel.toUpperCase();
    final channelColors = _channelColors(channel);

    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
    );
    final valueStyle = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showDeviceBoardDetailDialog(
          boardInfo,
          appState.dashboardData?['luciVersion'] as String?,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.model, style: labelStyle),
                    const SizedBox(height: 4),
                    Text(
                      displayModel,
                      style: valueStyle,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.versionLabel, style: labelStyle),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: channelColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        channelLabel,
                        style: TextStyle(
                          color: channelColors.foreground,
                          fontWeight: FontWeight.bold,
                          fontSize: Theme.of(
                            context,
                          ).textTheme.bodySmall?.fontSize,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Drop parenthetical suffixes for compact dashboard display.
  String _shortModelName(String model) {
    final stripped = model
        .replaceAll(RegExp(r'\s*[（(][^）)]*[）)]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return stripped.isEmpty ? model.trim() : stripped;
  }

  /// Firmware string from board release (description, else distribution/version/revision).
  String _parseFirmwareVersion(Map<String, dynamic>? release) {
    final description = release?['description']?.toString().trim();
    if (description != null && description.isNotEmpty) return description;

    final parts = <String>[];
    final distribution = release?['distribution']?.toString().trim();
    final version = release?['version']?.toString().trim();
    final revision = release?['revision']?.toString().trim();
    if (distribution != null && distribution.isNotEmpty) {
      parts.add(distribution);
    }
    if (version != null && version.isNotEmpty) parts.add(version);
    if (revision != null && revision.isNotEmpty) parts.add(revision);
    return parts.isEmpty ? '' : parts.join(' ');
  }

  void _showDeviceBoardDetailDialog(
    Map<String, dynamic>? boardInfo,
    String? luciVersion,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final hostname = boardInfo?['hostname']?.toString().trim();
    final model = boardInfo?['model']?.toString().trim();
    final release = boardInfo?['release'] as Map<String, dynamic>?;
    final firmware = _parseFirmwareVersion(release);
    final architecture = boardInfo?['system']?.toString().trim();
    final platform = release?['target']?.toString().trim();
    final kernel = boardInfo?['kernel']?.toString().trim();

    String valueOrDash(String? value) =>
        (value == null || value.isEmpty) ? '—' : value;

    _showLabeledDetailDialog(l10n.deviceInfo, [
      (label: l10n.hostname, value: valueOrDash(hostname)),
      (label: l10n.model, value: valueOrDash(model)),
      (
        label: l10n.firmwareVersion,
        value: valueOrDash(firmware.isEmpty ? null : firmware),
      ),
      (label: l10n.luciVersion, value: valueOrDash(luciVersion)),
      (label: l10n.architecture, value: valueOrDash(architecture)),
      (label: l10n.platform, value: valueOrDash(platform)),
      (label: l10n.kernel, value: valueOrDash(kernel)),
    ]);
  }

  Widget _buildTitleWithTimestamp(String title, AppState appState) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildRealtimeThroughputCard(AppState appState) {
    final prefs = appState.dashboardPreferences;

    // Determine which throughput data to use
    List<double> rxHistory;
    List<double> txHistory;
    double currentRxRate;
    double currentTxRate;
    String throughputLabel = '';

    if (!prefs.showAllThroughput && prefs.primaryThroughputInterface != null) {
      // Use specific interface throughput
      final interface = prefs.primaryThroughputInterface!;
      rxHistory = appState.getRxHistoryForInterface(interface);
      txHistory = appState.getTxHistoryForInterface(interface);
      currentRxRate = appState.getCurrentRxRateForInterface(interface);
      currentTxRate = appState.getCurrentTxRateForInterface(interface);
      throughputLabel = ' - $interface';
    } else {
      // Use combined throughput
      rxHistory = appState.rxHistory;
      txHistory = appState.txHistory;
      currentRxRate = appState.currentRxRate;
      currentTxRate = appState.currentTxRate;
    }

    // Show loading state if we don't have any throughput data yet
    final hasValidData =
        rxHistory.isNotEmpty ||
        txHistory.isNotEmpty ||
        currentRxRate > 0 ||
        currentTxRate > 0; // Show data as soon as we have any throughput info
    // Only show switching state if we're loading AND no dashboard data is available (true router switch)
    final isSwitchingRouter =
        appState.isLoading && appState.dashboardData == null;

    final card = Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (throughputLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Center(
                child: Text(
                  AppLocalizations.of(context)!.throughputLabel(throughputLabel.replaceFirst(' - ', '')),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSpeedIndicator(
                  Icons.arrow_downward,
                  Colors.green,
                  '',
                  isSwitchingRouter ? 0.0 : currentRxRate,
                ),
                _buildSpeedIndicator(
                  Icons.arrow_upward,
                  Colors.blue,
                  '',
                  isSwitchingRouter ? 0.0 : currentTxRate,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                top: 16.0,
              ), // Add space above the chart
              child: AnimatedSwitcher(
                duration: const Duration(
                  milliseconds: 600,
                ), // Smoother transition
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(0, 0.2),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                      child: child,
                    ),
                  );
                },
                child: hasValidData && !isSwitchingRouter
                    ? LineChart(
                        key: ValueKey('chart_${appState.selectedRouter?.id}'),
                        LineChartData(
                          gridData: FlGridData(show: false),
                          titlesData: FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              fitInsideVertically: true,
                              getTooltipColor: (LineBarSpot spot) => Theme.of(
                                context,
                              ).colorScheme.surface.withValues(alpha: 0.9),
                              tooltipBorderRadius: BorderRadius.circular(8),
                              tooltipPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              getTooltipItems:
                                  (List<LineBarSpot> touchedSpots) {
                                    return touchedSpots.map((barSpot) {
                                      final flSpot = barSpot;
                                      final Color color =
                                          flSpot.bar.gradient?.colors.first ??
                                          flSpot.bar.color ??
                                          Colors.white;

                                      return LineTooltipItem(
                                        _formatSpeed(flSpot.y),
                                        TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.w900,
                                        ),
                                        textAlign: TextAlign.left,
                                      );
                                    }).toList();
                                  },
                            ),
                          ),
                          lineBarsData: [
                            _buildLineChartBarData(rxHistory, [
                              Colors.green.shade700,
                              Colors.green.shade400,
                            ]),
                            _buildLineChartBarData(txHistory, [
                              Colors.blue.shade700,
                              Colors.blue.shade400,
                            ]),
                          ],
                        ),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeInOut,
                      )
                    : Center(
                        key: ValueKey('loading_${appState.selectedRouter?.id}'),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.trending_up,
                              size: 48,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isSwitchingRouter
                                  ? AppLocalizations.of(context)!.switchingRouter
                                  : AppLocalizations.of(context)!.collectingThroughputData,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.8),
                                  ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );

    // Always return the card without fixed height - let parent control sizing
    return card;
  }

  Widget _buildSpeedIndicator(
    IconData icon,
    Color color,
    String label,
    double speed,
  ) {
    // Show 0 if we don't have valid throughput data yet
    final displaySpeed = speed.isNaN || speed.isInfinite || speed < 0
        ? 0.0
        : speed;
    final speedText = AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Text(
        _formatSpeed(displaySpeed),
        key: ValueKey(displaySpeed),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        if (label.isNotEmpty)
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                speedText,
              ],
            ),
          )
        else
          Flexible(child: speedText),
      ],
    );
  }

  LineChartBarData _buildLineChartBarData(
    List<double> data,
    List<Color> gradientColors,
  ) {
    // Handle single data point case - show a flat line at that value
    if (data.length == 1) {
      return LineChartBarData(
        spots: [
          FlSpot(0, data[0]),
          FlSpot(1, data[0]), // Duplicate the point to create a flat line
        ],
        isCurved: false, // Don't curve a flat line
        gradient: LinearGradient(colors: gradientColors),
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            return FlDotCirclePainter(
              radius: 3,
              color: gradientColors.first,
              strokeWidth: 0,
            );
          },
        ),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            colors: gradientColors
                .map((color) => color.withValues(alpha: 0.1))
                .toList(),
          ),
        ),
      );
    }

    // Don't show chart data if we don't have any data points
    if (data.isEmpty) {
      return LineChartBarData(
        spots: [],
        isCurved: true,
        gradient: LinearGradient(colors: gradientColors),
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      );
    }

    return LineChartBarData(
      spots: data
          .asMap()
          .entries
          .map((e) => FlSpot(e.key.toDouble(), e.value))
          .toList(),
      isCurved: true,
      gradient: LinearGradient(colors: gradientColors),
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: gradientColors
              .map((color) => color.withValues(alpha: 0.3))
              .toList(),
        ),
      ),
    );
  }

  String _formatSpeed(double bytesPerSecond) {
    // Handle edge cases
    if (bytesPerSecond.isNaN ||
        bytesPerSecond.isInfinite ||
        bytesPerSecond < 0) {
      return '0 bps';
    }

    final bitsPerSecond = bytesPerSecond * 8;
    if (bitsPerSecond < 1_000) return '${bitsPerSecond.toStringAsFixed(0)} bps';
    if (bitsPerSecond < 1_000_000) {
      return '${(bitsPerSecond / 1_000).toStringAsFixed(1)} Kbps';
    }
    return '${(bitsPerSecond / 1_000_000).toStringAsFixed(2)} Mbps';
  }

  // Consistent card builder for all dashboard vitals and summary cards
  Widget _buildVitalsColumn(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
    );
    final valueStyle = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 4),
        Text(
          value,
          style: valueStyle,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSystemVitalsCard(AppState appState) {
    final l10n = AppLocalizations.of(context)!;
    final sysInfo = appState.dashboardData?['sysInfo'] as Map<String, dynamic>?;

    final cpuUsage = appState.dashboardData?['cpuUsage']?.toString();
    final cpuUsageDetail = appState.dashboardData?['cpuUsageDetail']?.toString();
    final cpuLoad = sysInfo?['load'] as List<dynamic>?;
    final cpuLoadValue = (cpuUsage != null && cpuUsage.isNotEmpty)
        ? cpuUsage
        : (cpuLoad != null ? _formatCpuLoad(cpuLoad) : 'N/A');
    final cpuDetail =
        (cpuUsageDetail != null && cpuUsageDetail.isNotEmpty)
        ? cpuUsageDetail
        : null;

    final totalMem = _asInt(sysInfo?['memory']?['total']) ?? 0;
    final freeMem = _asInt(sysInfo?['memory']?['free']) ?? 0;
    final bufferedMem = _asInt(sysInfo?['memory']?['buffered']) ?? 0;
    final cachedMem = _asInt(sysInfo?['memory']?['cached']);
    // LuCI Total Available / 「可用数」: prefer MemAvailable, else free+buffered.
    final availableMem = _asInt(sysInfo?['memory']?['available']) ??
        (totalMem > 0 ? freeMem + bufferedMem : null);
    // LuCI Used / 「已使用」 (20_memory.js): total - free.
    final usedMem =
        totalMem > 0 ? (totalMem - freeMem).clamp(0, totalMem) : 0;
    // LuCI progressbar: Math.floor((100 / total) * value)
    final memoryValue = totalMem > 0
        ? '${((100 * usedMem) / totalMem).floor()}%'
        : 'N/A';
    final memoryDetail = totalMem > 0
        ? _formatMemoryDetail(
            l10n: l10n,
            used: usedMem,
            total: totalMem,
            buffered: bufferedMem,
            cached: cachedMem,
            available: availableMem,
          )
        : null;

    final mountPoints = _mountPointsFromDashboard(appState);
    final primaryMount = mountPoints.isNotEmpty ? mountPoints.first : null;
    final storageValue = primaryMount == null
        ? '—'
        : '${_mountUsagePercent(primaryMount)}%';
    final storageDetail = mountPoints.isEmpty
        ? null
        : _formatStorageDetail(l10n: l10n, mounts: mountPoints);

    final onlineClients = _asInt(appState.dashboardData?['onlineClients']);
    final onlineValue = onlineClients != null ? '$onlineClients' : 'N/A';

    final connCount = _asInt(appState.dashboardData?['conntrackCount']);
    final connMax = _asInt(appState.dashboardData?['conntrackMax']);
    final connectionsValue = _formatConnections(connCount, connMax);
    final connectionsDetail = _formatConnectionsDetail(connCount, connMax);

    final temperature = appState.dashboardData?['temperature']?.toString();
    final temperatureShort =
        appState.dashboardData?['temperatureShort']?.toString();
    final temperatureValue =
        (temperatureShort != null && temperatureShort.isNotEmpty)
        ? temperatureShort
        : '—';
    final temperatureDetail =
        (temperature != null && temperature.isNotEmpty) ? temperature : null;

    final uptime = _asInt(sysInfo?['uptime']);
    final localtime = _asInt(sysInfo?['localtime']);
    final uptimeValue = uptime != null ? _formatUptime(uptime) : 'N/A';
    final uptimeRows = uptime != null
        ? _uptimeDetailRows(uptime, l10n: l10n, localtime: localtime)
        : null;
    final hasLocaltime = localtime != null && localtime > 0;
    final localTimeValue =
        hasLocaltime
        ? _formatRouterLocaltime(localtime, includeDate: false)
        : '—';
    final localTimeDetail =
        hasLocaltime ? _formatRouterLocaltime(localtime) : null;

    final network = _networkAddressSummary(appState);
    final lanValue = network.lanIpv4 ?? '—';
    String valueOrDash(String? value) =>
        (value == null || value.isEmpty) ? '—' : value;
    final ipRows = <({String label, String value})>[
      (
        label: l10n.lanIpv4,
        value: valueOrDash(network.lanIpv4Detail ?? network.lanIpv4),
      ),
      (label: l10n.lanIpv6, value: valueOrDash(network.lanIpv6)),
      (label: l10n.wanIpv4, value: valueOrDash(network.wanIpv4)),
      (label: l10n.wanIpv6, value: valueOrDash(network.wanIpv6)),
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Column(
          children: [
            Row(
              children: [
                _buildTappableVitalsColumn(
                  label: l10n.cpuLoad,
                  value: cpuLoadValue,
                  onTap: cpuDetail == null
                      ? null
                      : () => _showVitalDetailDialog(l10n.cpuLoad, cpuDetail),
                ),
                _buildTappableVitalsColumn(
                  label: l10n.memory,
                  value: memoryValue,
                  onTap: memoryDetail == null
                      ? null
                      : () => _showVitalDetailDialog(l10n.memory, memoryDetail),
                ),
                _buildTappableVitalsColumn(
                  label: l10n.storage,
                  value: storageValue,
                  onTap: storageDetail == null
                      ? null
                      : () =>
                            _showVitalDetailDialog(l10n.storage, storageDetail),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(
              height: 1,
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildTappableVitalsColumn(
                  label: l10n.onlineClients,
                  value: onlineValue,
                  onTap: () async {
                    await appState.setClientsAggregateAllRouters(false);
                    appState.requestTab(1);
                  },
                ),
                _buildTappableVitalsColumn(
                  label: l10n.activeConnections,
                  value: connectionsValue,
                  onTap: connCount == null
                      ? null
                      : () => _showVitalDetailDialog(
                          l10n.activeConnections,
                          connectionsDetail,
                        ),
                ),
                _buildTappableVitalsColumn(
                  label: l10n.temperature,
                  value: temperatureValue,
                  onTap: temperatureDetail == null
                      ? null
                      : () => _showVitalDetailDialog(
                          l10n.temperature,
                          temperatureDetail,
                        ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(
              height: 1,
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildTappableVitalsColumn(
                  label: l10n.ipAddressShort,
                  value: lanValue,
                  onTap: () => _showLabeledDetailDialog(
                    l10n.ipAddressShort,
                    ipRows,
                  ),
                ),
                _buildTappableVitalsColumn(
                  label: l10n.localTime,
                  value: localTimeValue,
                  onTap: localTimeDetail == null
                      ? null
                      : () => _showVitalDetailDialog(
                          l10n.localTime,
                          localTimeDetail,
                        ),
                ),
                _buildTappableVitalsColumn(
                  label: l10n.uptime,
                  value: uptimeValue,
                  onTap: uptimeRows == null
                      ? null
                      : () => _showLabeledDetailDialog(
                          l10n.uptime,
                          uptimeRows,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ({
    String? lanIpv4,
    String? lanIpv4Detail,
    String? lanIpv6,
    String? wanIpv4,
    String? wanIpv6,
  })
  _networkAddressSummary(AppState appState) {
    final interfaces =
        appState.dashboardData?['interfaceDump']?['interface']
            as List<dynamic>?;
    if (interfaces == null || interfaces.isEmpty) {
      return (
        lanIpv4: null,
        lanIpv4Detail: null,
        lanIpv6: null,
        wanIpv4: null,
        wanIpv6: null,
      );
    }

    final wanFromDefaultRoute =
        appState.dashboardData?['wan'] as Map<String, dynamic>?;
    final wan =
        wanFromDefaultRoute ?? _findInterfaceByName(interfaces, 'wan');
    final wan6 = _findWan6Interface(interfaces);
    final lan = _findInterfaceByName(interfaces, 'lan') ??
        _findInterfaceByName(interfaces, 'br-lan');

    return (
      lanIpv4: _formatInterfaceAddress(lan, 'ipv4-address', withMask: false),
      lanIpv4Detail:
          _formatInterfaceAddress(lan, 'ipv4-address', withMask: true),
      lanIpv6: _formatLanIpv6(lan),
      wanIpv4: _formatInterfaceAddress(wan, 'ipv4-address', withMask: true),
      // Prefer wan_6 / wan6 (PPPoE DHCPv6); skip link-local fe80 on wan.
      wanIpv6: _formatInterfaceAddress(wan6, 'ipv6-address', withMask: true) ??
          _formatInterfaceAddress(wan, 'ipv6-address', withMask: true),
    );
  }

  Map<String, dynamic>? _findInterfaceByName(
    List<dynamic> interfaces,
    String name,
  ) {
    for (final item in interfaces) {
      if (item is Map && item['interface']?.toString() == name) {
        return Map<String, dynamic>.from(item);
      }
    }
    return null;
  }

  /// PPPoE with ipv6=auto spawns dynamic `wan_6`; classic setups use `wan6`.
  Map<String, dynamic>? _findWan6Interface(List<dynamic> interfaces) {
    for (final name in ['wan_6', 'wan6']) {
      final iface = _findInterfaceByName(interfaces, name);
      if (_formatInterfaceAddress(iface, 'ipv6-address', withMask: false) !=
          null) {
        return iface;
      }
    }
    for (final item in interfaces) {
      if (item is! Map) continue;
      final routes = item['route'];
      if (routes is! List) continue;
      final hasDefaultV6 = routes.any((route) {
        if (route is! Map) return false;
        final target = route['target']?.toString();
        final mask = route['mask'];
        return target == '::' && (mask == 0 || mask == '0');
      });
      if (!hasDefaultV6) continue;
      final iface = Map<String, dynamic>.from(item);
      if (_formatInterfaceAddress(iface, 'ipv6-address', withMask: false) !=
          null) {
        return iface;
      }
    }
    return null;
  }

  bool _isIpv6LinkLocal(String address) {
    return address.toLowerCase().startsWith('fe80:');
  }

  String? _formatLanIpv6(Map<String, dynamic>? lan) {
    final fromAddress =
        _formatInterfaceAddress(lan, 'ipv6-address', withMask: true);
    if (fromAddress != null) return fromAddress;

    final assignments = lan?['ipv6-prefix-assignment'];
    if (assignments is! List) return null;
    for (final item in assignments) {
      if (item is! Map) continue;
      final local = item['local-address'];
      if (local is! Map) continue;
      final address = local['address']?.toString().trim();
      if (address == null ||
          address.isEmpty ||
          _isIpv6LinkLocal(address)) {
        continue;
      }
      final mask = local['mask'];
      if (mask == null) return address;
      return '$address/$mask';
    }
    return null;
  }

  String? _formatInterfaceAddress(
    Map<String, dynamic>? iface,
    String field, {
    required bool withMask,
  }) {
    final list = iface?[field];
    if (list is! List || list.isEmpty) return null;

    Map? chosen;
    for (final item in list) {
      if (item is! Map) continue;
      final address = item['address']?.toString().trim();
      if (address == null || address.isEmpty) continue;
      if (field == 'ipv4-address' && address.startsWith('127.')) continue;
      if (field == 'ipv6-address' && _isIpv6LinkLocal(address)) continue;
      chosen = item;
      break;
    }
    if (chosen == null) return null;

    final address = chosen['address']?.toString().trim();
    if (address == null || address.isEmpty) return null;
    if (!withMask) return address;
    final mask = chosen['mask'];
    if (mask == null) return address;
    return '$address/$mask';
  }

  List<Map<String, dynamic>> _mountPointsFromDashboard(AppState appState) {
    final raw = appState.dashboardData?['mountPoints'];
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  int _mountUsagePercent(Map<String, dynamic> mount) {
    final size = _asInt(mount['size']) ?? 0;
    if (size <= 0) return 0;
    final free = _asInt(mount['free']) ?? 0;
    final used = (size - free).clamp(0, size);
    return ((used / size) * 100).round().clamp(0, 100);
  }

  String _formatStorageDetail({
    required AppLocalizations l10n,
    required List<Map<String, dynamic>> mounts,
  }) {
    final blocks = <String>[];
    for (final mount in mounts) {
      final name = mount['mount']?.toString() ?? '—';
      final device = mount['device']?.toString() ?? '—';
      final size = _asInt(mount['size']) ?? 0;
      final free = _asInt(mount['free']) ?? 0;
      final used = (size - free).clamp(0, size);
      final percent = size > 0 ? ((used / size) * 100).round() : 0;
      blocks.add(
        '${l10n.storageMount}: $name\n'
        '${l10n.storageDevice}: $device\n'
        '${_formatMemoryBytes(used)} / ${_formatMemoryBytes(size)} ($percent%)',
      );
    }
    return blocks.join('\n\n');
  }

  Widget _buildTappableVitalsColumn({
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: _buildVitalsColumn(
            context,
            label: label,
            value: value,
          ),
        ),
      ),
    );
  }

  void _showVitalDetailDialog(String title, String detail) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(detail),
      ),
    );
  }

  void _showLabeledDetailDialog(
    String title,
    List<({String label, String value})> rows,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  Text(
                    rows[i].label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    rows[i].value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatConnections(int? count, int? max) {
    if (count == null) return 'N/A';
    if (max == null || max <= 0) return 'N/A';
    final percent = ((count / max) * 100).clamp(0, 100);
    return '${percent.toStringAsFixed(percent >= 10 ? 0 : 1)}%';
  }

  String _formatConnectionsDetail(int? count, int? max) {
    if (count == null) return 'N/A';
    if (max == null || max <= 0) return '$count';
    final percent = ((count / max) * 100).clamp(0, 100);
    return '$count / $max (${percent.toStringAsFixed(1)}%)';
  }

  String _formatMemoryBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var i = 0;
    while (value >= 1024 && i < suffixes.length - 1) {
      value /= 1024;
      i++;
    }
    final digits = value >= 10 || i == 0 ? 0 : 1;
    return '${value.toStringAsFixed(digits)} ${suffixes[i]}';
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }

  String _formatMemoryDetail({
    required AppLocalizations l10n,
    required int used,
    required int total,
    required int buffered,
    int? cached,
    int? available,
  }) {
    String bar(int value) {
      final pct = ((100 * value) / total).floor().clamp(0, 100);
      return '${_formatMemoryBytes(value)} / ${_formatMemoryBytes(total)} ($pct%)';
    }

    // Match LuCI 20_memory.js rows: Available, Used, Buffered?, Cached?
    return [
      if (available != null) '${l10n.memoryAvailable}: ${bar(available)}',
      '${l10n.memory}: ${bar(used)}',
      if (buffered > 0) '${l10n.memoryBuffered}: ${bar(buffered)}',
      if (cached != null && cached > 0) '${l10n.memoryCached}: ${bar(cached)}',
    ].join('\n');
  }

  Widget _buildWirelessInfoCardContent(
    BuildContext context, {
    required String ssid,
    required bool isEnabled,
    required int? signal,
    required String channel,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi,
              color: isEnabled
                  ? primaryColor
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              ssid,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            if (signal != null)
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.network_cell,
                      size: 16,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '$signal dBm',
                        style: textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            if (signal != null) const SizedBox(width: 8),
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.settings_input_antenna,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Ch: $channel',
                      style: textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWirelessNetworksCard(AppState appState) {
    final prefs = appState.dashboardPreferences;
    final wirelessRadios =
        appState.dashboardData?['wireless'] as Map<String, dynamic>?;
    final uciWirelessConfig = appState.dashboardData?['uciWirelessConfig'];

    // Track which interfaces we've already added from runtime data
    final addedInterfaces = <String>{};

    List<Widget> networkCardWidgets = [];

    // First, add interfaces from runtime wireless data
    if (wirelessRadios != null) {
      wirelessRadios.forEach((radioName, radioData) {
        final interfaces = radioData['interfaces'] as List<dynamic>?;
        if (interfaces != null) {
          for (var interface in interfaces) {
            final config = interface['config'] ?? {};
            final iwinfo = interface['iwinfo'] ?? {};
            final ssid = iwinfo['ssid'] ?? config['ssid'] ?? 'N/A';
            if (ssid == 'N/A') continue;

            final deviceName = config['device'] ?? radioName;
            final interfaceId = '$ssid ($deviceName)';
            final uciName = interface['section'] as String?;

            if (uciName != null) {
              addedInterfaces.add(uciName);
            }

            // If preferences are not empty, check if this interface should be shown
            // Empty preferences means show all interfaces by default
            if (prefs.enabledWirelessInterfaces.isNotEmpty &&
                !prefs.enabledWirelessInterfaces.contains(interfaceId)) {
              continue; // Skip this interface
            }

            final isEnabled = !(config['disabled'] as bool? ?? false);
            final channel = (iwinfo['channel'] ?? config['channel'] ?? 'N/A')
                .toString();
            final signal = iwinfo['signal'] as int?;

            networkCardWidgets.add(
              Card(
                margin: EdgeInsets.zero,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onLongPress: () {
                    // Navigate to interfaces tab with the specific interface name
                    final appState = ref.read(appStateProvider);
                    appState.requestTab(2, interfaceToScroll: deviceName);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: _buildWirelessInfoCardContent(
                      context,
                      ssid: ssid,
                      isEnabled: isEnabled,
                      signal: signal,
                      channel: channel,
                    ),
                  ),
                ),
              ),
            );
          }
        }
      });
    }

    // Now add disabled interfaces from UCI config that aren't in runtime data
    if (uciWirelessConfig != null) {
      final uciValues = uciWirelessConfig['values'] as Map?;
      if (uciValues != null) {
        final uciRadios = <String, Map>{};
        final uciInterfaces = <String, Map>{};

        // Categorize UCI entries
        uciValues.forEach((key, value) {
          final typedValue = value as Map?;
          if (typedValue?['.type'] == 'wifi-device') {
            uciRadios[key] = typedValue!;
          } else if (typedValue?['.type'] == 'wifi-iface') {
            uciInterfaces[key] = typedValue!;
          }
        });

        // Add interfaces that aren't in runtime data
        uciInterfaces.forEach((uciName, config) {
          if (!addedInterfaces.contains(uciName)) {
            final ssid = config['ssid'] ?? 'Unnamed';
            final device = config['device'] ?? '';
            final interfaceId = '$ssid ($device)';

            // Check if this interface should be shown based on preferences
            if (prefs.enabledWirelessInterfaces.isNotEmpty &&
                !prefs.enabledWirelessInterfaces.contains(interfaceId)) {
              return; // Skip this interface
            }

            final isRadioEnabled = uciRadios[device]?['disabled'] != '1';
            final isIfaceEnabled = config['disabled'] != '1';
            final isEnabled = isRadioEnabled && isIfaceEnabled;

            networkCardWidgets.add(
              Card(
                margin: EdgeInsets.zero,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onLongPress: () {
                    // Navigate to interfaces tab with the specific interface name
                    final appState = ref.read(appStateProvider);
                    appState.requestTab(2, interfaceToScroll: device);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: _buildWirelessInfoCardContent(
                      context,
                      ssid: ssid,
                      isEnabled: isEnabled,
                      signal: null, // No signal for disabled interfaces
                      channel: config['channel']?.toString() ?? 'N/A',
                    ),
                  ),
                ),
              ),
            );
          }
        });
      }
    }

    if (networkCardWidgets.isEmpty) {
      return const SizedBox.shrink();
    }

    List<Widget> rowChildren = [];
    final isScrollable = networkCardWidgets.length > 2;
    for (int i = 0; i < networkCardWidgets.length; i++) {
      if (isScrollable) {
        rowChildren.add(SizedBox(width: 180, child: networkCardWidgets[i]));
      } else {
        rowChildren.add(Expanded(child: networkCardWidgets[i]));
      }
      if (i < networkCardWidgets.length - 1) {
        rowChildren.add(SizedBox(width: isScrollable ? 4 : 8));
      }
    }

    if (isScrollable) {
      return Stack(
        children: [
          SizedBox(
            height: 110, // or whatever height fits the card
            child: ListView(
              controller: _wirelessScrollController,
              scrollDirection: Axis.horizontal,
              children: rowChildren,
            ),
          ),
          if (_showWirelessRightArrow)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  width: 28,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.transparent,
                        Theme.of(context).colorScheme.surface,
                      ],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 18,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
          if (_showWirelessLeftArrow)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  width: 28,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        Colors.transparent,
                        Theme.of(context).colorScheme.surface,
                      ],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
        ],
      );
    } else {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rowChildren,
      );
    }
  }

  /// Link info from luci-rpc.getNetworkDevices: nested under `link` on current
  /// OpenWrt; older/mock payloads may put carrier/speed at the top level.
  Map<String, dynamic>? _networkDeviceLinkInfo(dynamic deviceInfo) {
    if (deviceInfo is! Map) return null;
    final link = deviceInfo['link'];
    if (link is Map) {
      return Map<String, dynamic>.from(link);
    }
    return Map<String, dynamic>.from(deviceInfo);
  }

  dynamic _lookupNetworkDevice(
    Map<String, dynamic>? networkDevices,
    String device,
  ) {
    if (networkDevices == null || device.isEmpty) return null;
    final direct = networkDevices[device];
    if (direct != null) return direct;
    final lower = device.toLowerCase();
    for (final entry in networkDevices.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }
    return null;
  }

  bool _isCarrierUp(dynamic carrier) {
    return carrier == true ||
        carrier == 1 ||
        carrier == '1' ||
        carrier?.toString().toLowerCase() == 'true';
  }

  String _formatPortSpeed(dynamic speedRaw) {
    int? speed;
    if (speedRaw is int) {
      speed = speedRaw;
    } else if (speedRaw is num) {
      speed = speedRaw.toInt();
    } else if (speedRaw != null) {
      final text = speedRaw.toString().trim();
      // Some firmwares report values like "1000F" / "100H".
      final match = RegExp(r'(\d+)').firstMatch(text);
      if (match != null) {
        speed = int.tryParse(match.group(1)!);
      }
    }
    if (speed == null || speed <= 0) return '';
    if (speed >= 1000) {
      final gb = speed / 1000;
      final label = gb == gb.roundToDouble()
          ? gb.toInt().toString()
          : gb.toStringAsFixed(1);
      return '${label}GbE';
    }
    return '${speed}MbE';
  }

  Widget _buildInterfaceStatusCards(AppState appState) {
    final ports =
        appState.dashboardData?['ethernetPorts'] as List<dynamic>?;
    if (ports == null || ports.isEmpty) {
      return const SizedBox.shrink();
    }

    final networkDevices =
        appState.dashboardData?['networkDevices'] as Map<String, dynamic>?;
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    List<Widget> portCardWidgets = [];
    for (final item in ports) {
      if (item is! Map) continue;
      final device = item['device']?.toString() ?? '';
      if (device.isEmpty) continue;
      final role = (item['role']?.toString() ?? '').toLowerCase();
      final isWan = role == 'wan' || device.toLowerCase().contains('wan');

      final deviceInfo = _lookupNetworkDevice(networkDevices, device);
      bool linked = false;
      String speedLabel = '';
      final linkInfo = _networkDeviceLinkInfo(deviceInfo);
      if (linkInfo != null) {
        linked = _isCarrierUp(linkInfo['carrier']);
        if (linked) {
          speedLabel = _formatPortSpeed(linkInfo['speed']);
        }
      }

      final Color accent;
      if (!linked) {
        accent = scheme.outline;
      } else if (isWan) {
        accent = scheme.primary;
      } else {
        accent = Colors.green.shade700;
      }

      final statusText = linked
          ? (speedLabel.isNotEmpty ? speedLabel : l10n.connected)
          : l10n.notConnected;

      portCardWidgets.add(
        Card(
          margin: EdgeInsets.zero,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 12.0,
              horizontal: 10.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  isWan
                      ? Icons.public_rounded
                      : Icons.settings_ethernet_rounded,
                  color: accent,
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  device,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: linked
                        ? accent.withValues(alpha: 0.15)
                        : scheme.outlineVariant.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SizedBox(
                    width: 72,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            linked
                                ? Icons.link_rounded
                                : Icons.link_off_rounded,
                            size: 11,
                            color: linked
                                ? accent
                                : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: linked
                                  ? accent
                                  : scheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (portCardWidgets.isEmpty) {
      return const SizedBox.shrink();
    }

    List<Widget> rowChildren = [];
    final isScrollable = portCardWidgets.length >= 5;
    for (int i = 0; i < portCardWidgets.length; i++) {
      rowChildren.add(Expanded(child: portCardWidgets[i]));
      if (i < portCardWidgets.length - 1) {
        rowChildren.add(const SizedBox(width: 6));
      }
    }

    if (isScrollable) {
      return LayoutBuilder(
        builder: (context, constraints) {
          // 4 cards visible, 3 gaps between them
          final totalSpacing = 6.0 * 3;
          final width = constraints.maxWidth;
          final calculatedCardWidth = (width - totalSpacing) / 4;
          final localRowChildren = <Widget>[];
          for (int i = 0; i < portCardWidgets.length; i++) {
            localRowChildren.add(
              SizedBox(
                width: calculatedCardWidth,
                child: portCardWidgets[i],
              ),
            );
            if (i < portCardWidgets.length - 1) {
              localRowChildren.add(const SizedBox(width: 6));
            }
          }
          return Stack(
            children: [
              SizedBox(
                height: 110,
                child: ListView(
                  controller: _wanScrollController,
                  scrollDirection: Axis.horizontal,
                  children: localRowChildren,
                ),
              ),
              if (_showWanRightArrow)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: 28,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.transparent,
                            Theme.of(context).colorScheme.surface,
                          ],
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 18,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
              if (_showWanLeftArrow)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: 28,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: [
                            Colors.transparent,
                            Theme.of(context).colorScheme.surface,
                          ],
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
    } else {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rowChildren,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final List<model.Router> routers = appState.routers;
    final model.Router? selected = appState.selectedRouter;
    final boardInfo =
        appState.dashboardData?['boardInfo'] as Map<String, dynamic>?;
    final hostname = boardInfo?['hostname']?.toString();
    final headerText = (hostname != null && hostname.isNotEmpty)
        ? hostname
        : (selected?.ipAddress ?? AppLocalizations.of(context)!.loading);
    return Scaffold(
      appBar: LuciAppBar(
        centerTitle: true,
        title: null, // Always use titleWidget now
        titleWidget: routers.length > 1
            ? Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.1,
                    ),
                  ),
                  constraints: const BoxConstraints(minHeight: 36),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () async {
                        final selectedId = await showModalBottomSheet<String>(
                          context: context,
                          isScrollControlled: false,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surface,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(18),
                            ),
                          ),
                          builder: (context) {
                            return SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  top: 12,
                                  left: 8,
                                  right: 8,
                                  bottom: 8,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Center(
                                      child: Container(
                                        width: 40,
                                        height: 4,
                                        margin: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.outlineVariant,
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12.0,
                                        vertical: 4,
                                      ),
                                      child: Center(
                                        child: Text(
                                          AppLocalizations.of(context)!.selectRouter,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    const Divider(height: 16),
                                    ...routers.map((r) {
                                      final isSelected = r.id == selected?.id;
                                      String routerTitle;
                                      bool isStale = false;
                                      if (isSelected && boardInfo != null) {
                                        final hostname = boardInfo['hostname']
                                            ?.toString();
                                        routerTitle =
                                            (hostname != null &&
                                                hostname.isNotEmpty)
                                            ? hostname
                                            : (r.lastKnownHostname ??
                                                  r.ipAddress);
                                      } else if (r.lastKnownHostname != null &&
                                          r.lastKnownHostname!.isNotEmpty) {
                                        routerTitle = r.lastKnownHostname!;
                                        isStale = true;
                                      } else {
                                        routerTitle = r.ipAddress;
                                      }
                                      return ListTile(
                                        leading: Icon(
                                          Icons.router,
                                          color: isSelected
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.primary
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                        ),
                                        title: Tooltip(
                                          message: isStale
                                              ? AppLocalizations.of(context)!.lastKnownHostname
                                              : '',
                                          child: Text(
                                            routerTitle,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: isStale
                                                      ? Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant
                                                            .withValues(
                                                              alpha: 0.7,
                                                            )
                                                      : Theme.of(
                                                          context,
                                                        ).colorScheme.onSurface,
                                                ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        subtitle: Text(
                                          r.ipAddress,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                        trailing: isSelected
                                            ? Icon(
                                                Icons.check_circle,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                              )
                                            : null,
                                        selected: isSelected,
                                        selectedTileColor: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.07),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        onTap: () =>
                                            Navigator.of(context).pop(r.id),
                                      );
                                    }),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                        if (selectedId != null &&
                            selectedId != selected?.id &&
                            context.mounted) {
                          await appState.selectRouter(
                            selectedId,
                            context: context,
                          );
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 16.0,
                          right: 8.0,
                          top: 4.0,
                          bottom: 4.0,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              headerText,
                              style:
                                  Theme.of(
                                    context,
                                  ).appBarTheme.titleTextStyle ??
                                  Theme.of(
                                    context,
                                  ).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).appBarTheme.titleTextStyle?.color,
                                  ),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.arrow_drop_down,
                              size: 20,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : _buildTitleWithTimestamp(headerText, appState),
      ),
      body: Stack(children: [_buildBody(appState)]),
    );
  }

  Widget _buildBody(AppState appState) {
    final l10n = AppLocalizations.of(context)!;
    if (appState.dashboardError != null) {
      return LuciErrorDisplay(
        title: l10n.connectionFailed,
        message: l10n.connectionFailedMessage,
        actionLabel: l10n.retryConnection,
        onAction: () => appState.fetchDashboardData(),
        icon: Icons.wifi_off_rounded,
      );
    }

    if (appState.isDashboardLoading && appState.dashboardData == null) {
      return const LuciLoadingWidget();
    }

    if (appState.dashboardData == null) {
      return LuciEmptyState(
        title: l10n.noDataAvailable,
        message: l10n.noDataAvailableMessage,
        icon: Icons.dashboard_outlined,
        actionLabel: l10n.fetchData,
        onAction: () => appState.fetchDashboardData(),
      );
    }

    return RefreshIndicator(
      onRefresh: () => appState.fetchDashboardData(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape =
              MediaQuery.of(context).orientation == Orientation.landscape;

          // Split layout handling to avoid Expanded widget conflicts with staggered animations
          if (isLandscape) {
            final landscapeContent = [
              const SizedBox(height: 16),
              _buildDeviceInfoCard(appState),
              const SizedBox(height: 12),
              SizedBox(
                height: 240,
                child: _buildRealtimeThroughputCard(appState),
              ),
              const SizedBox(height: 12),
              _buildSystemVitalsCard(appState),
              const SizedBox(height: 12),
              _buildWirelessNetworksCard(appState),
              const SizedBox(height: 12),
              _buildInterfaceStatusCards(appState),
              const SizedBox(height: 12),
              // Extra padding to ensure scroll behavior for RefreshIndicator
              const SizedBox(height: 100),
            ];

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: LuciStaggeredAnimation(
                  staggerDelay: const Duration(milliseconds: 50),
                  children: landscapeContent,
                ),
              ),
            );
          } else {
            // Portrait mode: Fill available height exactly without scrolling
            return LayoutBuilder(
              builder: (context, constraints) {
                return RefreshIndicator(
                  onRefresh: () => appState.fetchDashboardData(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: constraints.maxHeight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            _buildDeviceInfoCard(appState),
                            const SizedBox(height: 12),
                            Expanded(
                              child: _buildRealtimeThroughputCard(appState),
                            ),
                            const SizedBox(height: 12),
                            _buildSystemVitalsCard(appState),
                            const SizedBox(height: 12),
                            _buildWirelessNetworksCard(appState),
                            const SizedBox(height: 12),
                            _buildInterfaceStatusCards(appState),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
