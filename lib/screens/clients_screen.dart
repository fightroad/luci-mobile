import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/l10n/app_localizations.dart';
import 'package:luci_mobile/models/client.dart';
import 'package:luci_mobile/main.dart';
import 'package:luci_mobile/widgets/luci_app_bar.dart';
import 'package:luci_mobile/design/luci_design_system.dart';
import 'package:luci_mobile/widgets/luci_loading_states.dart';
import 'package:luci_mobile/widgets/luci_refresh_components.dart';
import 'package:luci_mobile/widgets/luci_animation_system.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  final Set<int> _expandedClientIndices = {};
  late AnimationController _controller;
  late TextEditingController _searchController;
  bool _aggregateAllRouters = true;
  Future<List<Client>>? _clientsFuture;
  String? _lastSelectedRouterId;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _searchController = TextEditingController();
    _searchController.addListener(() {
      if (_searchQuery != _searchController.text) {
        setState(() {
          _searchQuery = _searchController.text;
        });
      }
    });
    // Initialize toggle from persisted state
    final initState = ref.read(appStateProvider);
    _aggregateAllRouters = initState.clientsAggregateAllRouters;
    _lastSelectedRouterId = initState.selectedRouter?.id;
    _computeClientsFuture();

  }

  void _computeClientsFuture() {
    final appState = ref.read(appStateProvider);
    _clientsFuture = _aggregateAllRouters
        ? appState.fetchAggregatedClients()
        : appState.fetchClientsForSelectedRouter();
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final watchedAppState = ref.watch(appStateProvider);
    // Recompute future only when selected router changes
    Future<List<Client>>? future = _clientsFuture;
    final currentId = watchedAppState.selectedRouter?.id;
    if (currentId != _lastSelectedRouterId) {
      _lastSelectedRouterId = currentId;
      _computeClientsFuture();
      future = _clientsFuture;
    }
    return FutureBuilder<List<Client>>(
      future: future,
      builder: (context, snapshot) {
        final aggregatedClients = snapshot.data ?? [];
        final l10n = AppLocalizations.of(context)!;
        return Scaffold(
          appBar: LuciAppBar(title: l10n.clients),
          body: Stack(
            children: [
              LuciPullToRefresh(
                onRefresh: () async {
                  // Trigger a refresh by re-fetching dashboard data for selected router
                  await ref.read(appStateProvider).fetchDashboardData();
                  setState(() { _computeClientsFuture(); });
                },
                child: Builder(
                  builder: (context) {
                    final appState = ref.watch(appStateProvider);
                    final isLoading = snapshot.connectionState == ConnectionState.waiting && (aggregatedClients.isEmpty);
                    final dashboardError = appState.dashboardError;

                    if (isLoading) {
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: LuciSpacing.md,
                        ),
                        child: Column(
                          children: [
                            SizedBox(height: LuciSpacing.md),
                            // Search bar skeleton
                            LuciSkeleton(
                              width: double.infinity,
                              height: 56,
                              borderRadius: BorderRadius.circular(
                                LuciSpacing.sm,
                              ),
                            ),
                            SizedBox(height: LuciSpacing.md),
                            // Client list skeletons
                            Expanded(
                              child: ListView.separated(
                                itemCount: 6,
                                separatorBuilder: (context, index) =>
                                    SizedBox(height: LuciSpacing.sm),
                                itemBuilder: (context, index) =>
                                    LuciListItemSkeleton(
                                      showLeading: true,
                                      showTrailing: true,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (dashboardError != null && aggregatedClients.isEmpty) {
                      final l10n = AppLocalizations.of(context)!;
                      return LuciErrorDisplay(
                        title: l10n.failedToLoadClients,
                        message: l10n.failedToLoadClientsMessage,
                        actionLabel: l10n.retry,
                        onAction: () =>
                            ref.read(appStateProvider).fetchDashboardData(),
                        icon: Icons.wifi_off_rounded,
                      );
                    }

                    final clients = aggregatedClients;

                    final filteredClients = clients.where((client) {
                      final query = _searchQuery.toLowerCase();
                      return client.hostname.toLowerCase().contains(query) ||
                          client.ipAddress.toLowerCase().contains(query) ||
                          client.macAddress.toLowerCase().contains(query) ||
                          (client.vendor != null &&
                              client.vendor!.toLowerCase().contains(query)) ||
                          (client.dnsName != null &&
                              client.dnsName!.toLowerCase().contains(query));
                    }).toList();

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          child: TextField(
                            autofocus: false,
                            onChanged: (value) {
                              // No need to setState here, listener handles it
                            },
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: l10n.searchClients,
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        setState(() {
                                          _searchController.clear();
                                        });
                                      },
                                      tooltip: l10n.clearSearch,
                                    )
                                  : null,
                              filled: true,
                              fillColor: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24.0),
                                borderSide: BorderSide.none,
                              ),
                              hintStyle: TextStyle(
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 4.0,
                          ),
                          child: SegmentedButton<bool>(
                            segments: [
                              ButtonSegment<bool>(
                                value: true,
                                label: Text(l10n.all),
                                icon: const Icon(Icons.apartment),
                              ),
                              ButtonSegment<bool>(
                                value: false,
                                label: Text(l10n.selected),
                                icon: const Icon(Icons.router),
                              ),
                            ],
                            selected: {_aggregateAllRouters},
                            showSelectedIcon: false,
                            style: SegmentedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onSelectionChanged: (s) {
                              setState(() {
                                _aggregateAllRouters = s.first;
                                _computeClientsFuture();
                              });
                              // Persist selection
                              ref
                                  .read(appStateProvider)
                                  .setClientsAggregateAllRouters(
                                      _aggregateAllRouters);
                            },
                          ),
                        ),
                        Expanded(
                          child: filteredClients.isEmpty
                              ? LuciEmptyState(
                                  title: _searchQuery.isEmpty
                                      ? l10n.noActiveClientsFound
                                      : l10n.noMatchingClients,
                                  message: _searchQuery.isEmpty
                                      ? l10n.noActiveClientsMessage
                                      : l10n.noMatchingClientsMessage,
                                  icon: Icons.people_outline,
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  separatorBuilder: (context, idx) =>
                                      const SizedBox(height: 4),
                                  itemCount: filteredClients.length,
                                  itemBuilder: (context, index) {
                                    final client = filteredClients[index];
                                    final isExpanded = _expandedClientIndices
                                        .contains(index);

                                    return LuciSlideTransition(
                                      direction: LuciSlideDirection.up,
                                      delay: Duration(milliseconds: index * 50),
                                      distance: 30,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0,
                                          vertical: 8.0,
                                        ),
                                        child: _UnifiedClientCard(
                                          client: client,
                                          isExpanded: isExpanded,
                                          onTap: () {
                                            setState(() {
                                              if (isExpanded) {
                                                _expandedClientIndices.remove(
                                                  index,
                                                );
                                              } else {
                                                _expandedClientIndices.add(
                                                  index,
                                                );
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String normalizeMac(String mac) => mac.toUpperCase().replaceAll('-', ':');
}

class _UnifiedClientCard extends StatefulWidget {
  final Client client;
  final bool isExpanded;
  final VoidCallback onTap;

  const _UnifiedClientCard({
    required this.client,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  State<_UnifiedClientCard> createState() => _UnifiedClientCardState();
}

class _UnifiedClientCardState extends State<_UnifiedClientCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    if (widget.isExpanded) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_UnifiedClientCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: widget.isExpanded ? 6 : 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18.0),
        side: BorderSide(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.10),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedScale(
        scale: widget.isExpanded ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        child: Column(
          children: [
            InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(18.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withValues(
                              alpha: 0.13,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: AnimatedScale(
                            scale: widget.isExpanded ? 1.1 : 1.0,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.elasticOut,
                            child: Icon(
                              Icons.person_outline,
                              color: colorScheme.primary,
                              size: 22,
                              semanticLabel: AppLocalizations.of(context)!.clientIcon,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Tooltip(
                            message:
                                widget.client.connectionType ==
                                    ConnectionType.unknown
                                ? AppLocalizations.of(context)!.unknownConnectionType
                                : AppLocalizations.of(context)!.clientIsOnline,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color:
                                    widget.client.connectionType ==
                                            ConnectionType.wireless ||
                                        widget.client.connectionType ==
                                            ConnectionType.wired
                                    ? Colors.green
                                    : Colors.amber,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colorScheme.surface,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.client.hostname,
                            style: LuciTextStyles.cardTitle(context),
                            semanticsLabel:
                                'Client hostname: ${widget.client.hostname}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: LuciSpacing.xs),
                          Container(
                            margin: const EdgeInsets.only(right: 32),
                            child: Divider(
                              color: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.10),
                              thickness: 1,
                              height: 8,
                            ),
                          ),
                          Text(
                            _buildMinimalClientSubtitle(widget.client),
                            style: LuciTextStyles.cardSubtitle(context),
                            semanticsLabel:
                                'Client details: ${_buildMinimalClientSubtitle(widget.client)}',
                          ),
                          if (widget.client.vendor != null &&
                              widget.client.vendor!.isNotEmpty)
                            Text(
                              widget.client.vendor!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              semanticsLabel: 'Vendor: ${widget.client.vendor}',
                            ),
                        ],
                      ),
                    ),
                    _buildConnectionTypeChip(
                      context,
                      widget.client.connectionType,
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      widget.isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: colorScheme.onSurfaceVariant,
                      size: 26,
                      semanticLabel: widget.isExpanded
                          ? AppLocalizations.of(context)!.collapseDetails
                          : AppLocalizations.of(context)!.expandDetails,
                    ),
                  ],
                ),
              ),
            ),
            if (widget.isExpanded)
              Column(
                children: [
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildClientDetails(context, widget.client),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionTypeChip(BuildContext context, ConnectionType type) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    String label;
    IconData icon;
    Color bgColor;
    Color fgColor;

    final l10n = AppLocalizations.of(context)!;
    switch (type) {
      case ConnectionType.wireless:
        label = l10n.wiFi;
        icon = Icons.wifi;
        bgColor = colorScheme.primaryContainer;
        fgColor = colorScheme.onPrimaryContainer;
        break;
      case ConnectionType.wired:
        label = l10n.wired;
        icon = Icons.settings_ethernet;
        bgColor = colorScheme.secondaryContainer;
        fgColor = colorScheme.onSecondaryContainer;
        break;
      default:
        label = l10n.unknown;
        icon = Icons.devices_other_outlined;
        bgColor = colorScheme.surfaceContainerHighest;
        fgColor = colorScheme.onSurfaceVariant;
        break;
    }

    return Chip(
      label: Text(label),
      avatar: Icon(icon, size: 16, color: fgColor),
      backgroundColor: bgColor,
      labelStyle: theme.textTheme.labelSmall?.copyWith(color: fgColor),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildClientDetails(BuildContext context, Client client) {
    final theme = Theme.of(context);

    Widget detailRow(
      String title,
      String value, {
      Color? valueColor,
      VoidCallback? onTap,
      String? semanticsLabel,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LuciSpacing.md,
            vertical: LuciSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: LuciTextStyles.detailLabel(context),
                semanticsLabel: title,
              ),
              Row(
                children: [
                  Text(
                    value,
                    style: valueColor != null
                        ? LuciTextStyles.detailValue(
                            context,
                          ).copyWith(color: valueColor)
                        : LuciTextStyles.detailValue(context),
                    semanticsLabel: semanticsLabel ?? value,
                  ),
                  if (onTap != null)
                    GestureDetector(
                      onTap: onTap,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Icon(
                          Icons.copy_all_outlined,
                          size: 16,
                          semanticLabel: AppLocalizations.of(context)!.copy,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.18,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
      ),
      child: Column(
        children: [
          Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return Column(
                children: [
                  detailRow(
                    l10n.ipAddress,
                    client.ipAddress,
                    onTap: () =>
                        _copyToClipboard(context, client.ipAddress, l10n.ipAddress),
                    semanticsLabel: '${l10n.ipAddress}: ${client.ipAddress}',
                  ),
                  if (client.ipv6Addresses != null && client.ipv6Addresses!.isNotEmpty)
                    ...client.ipv6Addresses!.map(
                      (ipv6) => detailRow(
                        l10n.ipv6Address,
                        ipv6,
                        onTap: () => _copyToClipboard(context, ipv6, l10n.ipv6Address),
                        semanticsLabel: '${l10n.ipv6Address}: $ipv6',
                      ),
                    ),
                  detailRow(
                    l10n.macAddress,
                    client.macAddress,
                    onTap: () =>
                        _copyToClipboard(context, client.macAddress, l10n.macAddress),
                    semanticsLabel: '${l10n.macAddress}: ${client.macAddress}',
                  ),
                  if (client.vendor != null && client.vendor!.isNotEmpty)
                    detailRow(
                      l10n.vendor,
                      client.vendor!,
                      semanticsLabel: '${l10n.vendor}: ${client.vendor}',
                    ),
                  if (client.dnsName != null && client.dnsName!.isNotEmpty)
                    detailRow(
                      l10n.dnsName,
                      client.dnsName!,
                      semanticsLabel: '${l10n.dnsName}: ${client.dnsName}',
                    ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  const SizedBox(height: 8),
                  detailRow(
                    l10n.leaseTimeRemaining,
                    client.formattedLeaseTime,
                    valueColor: client.formattedLeaseTime == l10n.expired
                        ? theme.colorScheme.error
                        : null,
                    semanticsLabel:
                        '${l10n.leaseTimeRemaining}: ${client.formattedLeaseTime}',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _buildMinimalClientSubtitle(Client client) {
    final v4 = client.ipAddress;
    final v6s = client.ipv6Addresses ?? [];
    final v6 = v6s.isNotEmpty ? v6s.first : null;
    String? shown;
    int extra = 0;
    if (v4 != 'N/A') {
      shown = v4;
      if (v6 != null) extra++;
    } else if (v6 != null) {
      shown = v6;
    }
    if (shown == null) return '';
    if (extra > 0) {
      return '$shown  +$extra';
    } else {
      return shown;
    }
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    final l10n = AppLocalizations.of(context)!;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.copiedToClipboard(label)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
