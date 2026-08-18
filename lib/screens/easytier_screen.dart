import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/design/luci_design_system.dart';
import 'package:luci_mobile/l10n/app_localizations.dart';
import 'package:luci_mobile/main.dart';
import 'package:luci_mobile/models/easytier_peer.dart';
import 'package:luci_mobile/models/easytier_status.dart';
import 'package:luci_mobile/widgets/luci_app_bar.dart';

class EasyTierScreen extends ConsumerStatefulWidget {
  const EasyTierScreen({super.key});

  @override
  ConsumerState<EasyTierScreen> createState() => _EasyTierScreenState();
}

class _EasyTierScreenState extends ConsumerState<EasyTierScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    if (_busy) return;
    setState(() => _busy = true);
    await ref
        .read(appStateProvider)
        .refreshEasyTier(context: mounted ? context : null);
    if (!mounted) return;
    setState(() => _busy = false);
  }

  void _showToast(String message, {required bool success}) {
    if (!mounted) return;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error_outline,
              color: success ? colorScheme.onPrimary : colorScheme.onError,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: success ? colorScheme.onPrimary : colorScheme.onError,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: success ? colorScheme.primary : colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _toggleCore(bool enabled) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            enabled ? l10n.easytierEnableTitle : l10n.easytierDisableTitle,
          ),
          content: Text(
            enabled ? l10n.easytierEnableMessage : l10n.easytierDisableMessage,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                enabled ? l10n.easytierEnableConfirm : l10n.easytierDisableConfirm,
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted || _busy) return;

    setState(() => _busy = true);
    final ok = await ref.read(appStateProvider).setEasyTierCoreEnabled(
      enabled,
      context: context,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _showToast(
      ok
          ? (enabled ? l10n.easytierEnabledOk : l10n.easytierDisabledOk)
          : l10n.easytierToggleFailed,
      success: ok,
    );
  }

  Future<void> _restart() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.easytierRestartTitle),
          content: Text(l10n.easytierRestartMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.easytierRestart),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted || _busy) return;

    setState(() => _busy = true);
    final ok = await ref
        .read(appStateProvider)
        .restartEasyTier(context: context);
    if (!mounted) return;
    setState(() => _busy = false);
    _showToast(
      ok ? l10n.easytierRestartOk : l10n.easytierRestartFailed,
      success: ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = ref.watch(appStateProvider);
    final status = appState.easytierStatus;
    final peers = appState.easytierPeers;
    final peersError = appState.easytierPeersError;
    final loading = _busy || appState.isEasytierLoading;

    return Scaffold(
      appBar: LuciAppBar(
        title: l10n.easytier,
        showBack: true,
        actions: [
          IconButton(
            tooltip: l10n.easytierRefresh,
            onPressed: loading ? null : () => _reload(),
            icon: loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: status == null && appState.easytierError != null
          ? LuciErrorDisplay(
              title: l10n.easytier,
              message:
                  appState.easytierError ?? l10n.easytierUnavailableMessage,
              actionLabel: l10n.retry,
              onAction: () => _reload(),
            )
          : status == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: LuciSpacing.sm),
              children: [
                  LuciSectionHeader(l10n.easytierQuickActions),
                  _QuickActionsCard(
                    enabled: status.coreEnabled,
                    busy: loading,
                    onToggle: _toggleCore,
                    onRestart: _restart,
                  ),
                  LuciSectionHeader(l10n.easytierStatus),
                  _StatusCard(status: status),
                  LuciSectionHeader(l10n.easytierNodeList),
                  _PeerListSection(
                    peers: peers,
                    error: peersError,
                    coreRunning: status.coreRunning,
                  ),
                ],
              ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  final bool enabled;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRestart;

  const _QuickActionsCard({
    required this.enabled,
    required this.busy,
    required this.onToggle,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(
        horizontal: LuciSpacing.md,
        vertical: LuciSpacing.sm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: LuciCardStyles.standardRadius,
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: Text(
              l10n.easytierCore,
              style: LuciTextStyles.cardTitle(context),
            ),
            subtitle: Text(
              l10n.easytierCoreSubtitle,
              style: LuciTextStyles.cardSubtitle(context),
            ),
            value: enabled,
            onChanged: busy ? null : onToggle,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: Icon(Icons.restart_alt, color: colorScheme.error),
            title: Text(
              l10n.easytierRestart,
              style: LuciTextStyles.cardTitle(context).copyWith(
                color: colorScheme.error,
              ),
            ),
            enabled: !busy,
            onTap: busy ? null : onRestart,
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final EasyTierStatus status;

  const _StatusCard({required this.status});

  String _displayValue(String value, String fallback) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '*') return fallback;
    return trimmed;
  }

  Widget _statTileRow(List<Widget> tiles) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: tiles[i]),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final running = status.coreRunning;
    final runningColor = running ? Colors.green : colorScheme.error;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(
        horizontal: LuciSpacing.md,
        vertical: LuciSpacing.sm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: LuciCardStyles.standardRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.easytierCore,
                    style: LuciTextStyles.cardTitle(context),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: runningColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: runningColor),
                      const SizedBox(width: 6),
                      Text(
                        running ? l10n.easytierRunning : l10n.easytierStopped,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: runningColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final tiles = [
                  _StatTile(
                    icon: Icons.memory_outlined,
                    label: l10n.easytierCpu,
                    value: _displayValue(status.cpu, 'N/A'),
                  ),
                  _StatTile(
                    icon: Icons.sd_storage_outlined,
                    label: l10n.easytierMemory,
                    value: _displayValue(status.memory, 'N/A'),
                  ),
                  _StatTile(
                    icon: Icons.schedule_outlined,
                    label: l10n.easytierUptime,
                    value: _displayValue(status.uptime, 'N/A'),
                  ),
                  _StatTile(
                    icon: Icons.info_outline,
                    label: l10n.easytierVersion,
                    value: _displayValue(status.version, 'N/A'),
                  ),
                ];
                if (constraints.maxWidth >= 520) {
                  return _statTileRow(tiles);
                }
                return Column(
                  children: [
                    _statTileRow(tiles.sublist(0, 2)),
                    const SizedBox(height: 12),
                    _statTileRow(tiles.sublist(2)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PeerListSection extends StatelessWidget {
  final List<EasyTierPeer> peers;
  final String? error;
  final bool coreRunning;

  const _PeerListSection({
    required this.peers,
    required this.error,
    required this.coreRunning,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (!coreRunning) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: LuciSpacing.lg,
          vertical: LuciSpacing.md,
        ),
        child: Text(
          l10n.easytierNodeListStopped,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (error != null && error!.trim().isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: LuciSpacing.lg,
          vertical: LuciSpacing.md,
        ),
        child: Text(
          error!,
          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.error),
        ),
      );
    }

    if (peers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: LuciSpacing.lg,
          vertical: LuciSpacing.md,
        ),
        child: Text(
          l10n.easytierNodeListEmpty,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      children: peers
          .map(
            (peer) => _PeerCard(
              key: ValueKey('${peer.ipv4}|${peer.hostname}'),
              peer: peer,
            ),
          )
          .toList(),
    );
  }
}

class _PeerCard extends StatefulWidget {
  final EasyTierPeer peer;

  const _PeerCard({super.key, required this.peer});

  @override
  State<_PeerCard> createState() => _PeerCardState();
}

class _PeerCardState extends State<_PeerCard> {
  bool _expanded = false;

  EasyTierPeer get peer => widget.peer;

  String _display(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '*') return '-';
    return trimmed;
  }

  String _displayRoute(String route) {
    if (route.trim().toLowerCase() == 'p2p') return 'P2P';
    return route.trim();
  }

  String _displayNatType(AppLocalizations l10n, String raw) {
    final key = raw.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (key.isEmpty || key == '*') return '-';
    switch (key) {
      case 'unknown':
        return l10n.easytierNatUnknown;
      case 'symmetric':
        return l10n.easytierNatSymmetric;
      case 'restricted':
        return l10n.easytierNatRestricted;
      case 'portrestricted':
        return l10n.easytierNatPortRestricted;
      case 'addressrestricted':
        return l10n.easytierNatAddressRestricted;
      case 'fullcone':
        return l10n.easytierNatFullCone;
      case 'nopat':
        return l10n.easytierNatNoPat;
      default:
        return raw.trim();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = peer.hostname.isNotEmpty ? peer.hostname : peer.ipv4;
    final latency = _display(peer.latency);
    final subtitleParts = <String>[
      if (peer.ipv4.isNotEmpty) peer.ipv4,
      if (!peer.isLocal && peer.route.isNotEmpty) _displayRoute(peer.route),
      if (latency != '-') latency,
    ];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(
        horizontal: LuciSpacing.md,
        vertical: LuciSpacing.sm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: LuciCardStyles.standardRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: LuciTextStyles.cardTitle(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitleParts.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitleParts.join(' · '),
                            style: LuciTextStyles.cardSubtitle(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (peer.isLocal) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(
                          alpha: 0.35,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        l10n.easytierLocalNode,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: colorScheme.onSurfaceVariant,
                    semanticLabel: _expanded
                        ? l10n.collapseDetails
                        : l10n.expandDetails,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Column(
                children: [
                  _PeerDetailRow(
                    label: l10n.easytierPeerLatency,
                    value: latency,
                  ),
                  _PeerDetailRow(
                    label: l10n.easytierPeerPacketLoss,
                    value: _display(peer.packetLoss),
                  ),
                  _PeerDetailRow(
                    label: l10n.easytierPeerDownload,
                    value: _display(peer.download),
                  ),
                  _PeerDetailRow(
                    label: l10n.easytierPeerUpload,
                    value: _display(peer.upload),
                  ),
                  _PeerDetailRow(
                    label: l10n.easytierPeerProtocol,
                    value: _display(peer.protocol),
                  ),
                  _PeerDetailRow(
                    label: l10n.easytierPeerNatType,
                    value: _displayNatType(l10n, peer.natType),
                  ),
                  _PeerDetailRow(
                    label: l10n.easytierVersion,
                    value: _display(peer.version),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PeerDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _PeerDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
