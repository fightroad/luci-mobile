import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/design/luci_design_system.dart';
import 'package:luci_mobile/l10n/app_localizations.dart';
import 'package:luci_mobile/main.dart';
import 'package:luci_mobile/models/zerotier_config.dart';
import 'package:luci_mobile/utils/ethernet_port_info.dart';
import 'package:luci_mobile/widgets/luci_app_bar.dart';

class ZerotierScreen extends ConsumerStatefulWidget {
  const ZerotierScreen({super.key});

  @override
  ConsumerState<ZerotierScreen> createState() => _ZerotierScreenState();
}

class _ZerotierScreenState extends ConsumerState<ZerotierScreen> {
  bool _busy = false;
  ZerotierConfig? _draft;
  ZerotierConfig? _baseline;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    if (_busy) return;
    setState(() => _busy = true);
    final config = await ref
        .read(appStateProvider)
        .fetchZerotierConfig(context: context);
    if (!mounted) return;
    setState(() {
      _baseline = config;
      _draft = config;
      _busy = false;
    });
  }

  bool _isDirty() {
    final draft = _draft;
    final base = _baseline;
    if (draft == null || base == null) return false;
    if (draft.enabled != base.enabled) return true;
    if (draft.isLegacyFormat) return false;
    final baseBySection = {for (final n in base.networks) n.section: n};
    for (final network in draft.networks) {
      final before = baseBySection[network.section];
      if (before == null || before.enabled != network.enabled) return true;
    }
    return false;
  }

  void _updateDraft(ZerotierConfig Function(ZerotierConfig) update) {
    final current = _draft;
    if (current == null || _busy) return;
    setState(() => _draft = update(current));
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
      ),
    );
  }

  Future<void> _apply() async {
    final draft = _draft;
    final baseline = _baseline;
    if (draft == null || baseline == null || _busy) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    final ok = await ref
        .read(appStateProvider)
        .applyZerotierSettings(
          draft: draft,
          baseline: baseline,
          context: context,
        );
    if (!mounted) return;
    if (ok) {
      final refreshed = ref.read(appStateProvider).zerotierConfig;
      setState(() {
        _baseline = refreshed;
        _draft = refreshed;
        _busy = false;
      });
      _showToast(l10n.zerotierSaved, success: true);
    } else {
      setState(() => _busy = false);
      _showToast(l10n.zerotierSaveFailed, success: false);
    }
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = ref.watch(appStateProvider);
    final draft = _draft;
    final loading = appState.isZerotierLoading && draft == null;
    final dirty = draft != null && _baseline != null && _isDirty();
    final colorScheme = Theme.of(context).colorScheme;
    final running = appState.zerotierRunning;
    final interfaces = appState.zerotierInterfaces;

    return Scaffold(
      appBar: LuciAppBar(
        title: l10n.zerotier,
        showBack: true,
        actions: [
          TextButton(
            onPressed: _busy ? null : (dirty ? _apply : _reload),
            child: Text(
              dirty ? l10n.zerotierApply : l10n.zerotierRefresh,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: _busy
                    ? colorScheme.onSurface.withValues(alpha: 0.38)
                    : colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : draft == null
          ? LuciErrorDisplay(
              title: l10n.zerotierUnavailable,
              message:
                  appState.zerotierError ?? l10n.zerotierUnavailableMessage,
              actionLabel: l10n.retry,
              onAction: _reload,
            )
          : Column(
              children: [
                if (_busy) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      vertical: LuciSpacing.sm,
                    ),
                    children: [
                      LuciSectionHeader(l10n.zerotierStatus),
                      Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: LuciSpacing.md,
                          vertical: LuciSpacing.sm,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(LuciSpacing.md),
                          child: Row(
                            children: [
                              Icon(
                                running == true
                                    ? Icons.check_circle
                                    : running == false
                                    ? Icons.cancel
                                    : Icons.help_outline,
                                color: running == true
                                    ? Colors.green.shade700
                                    : running == false
                                    ? colorScheme.error
                                    : colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  running == true
                                      ? l10n.zerotierRunning
                                      : running == false
                                      ? l10n.zerotierStopped
                                      : l10n.zerotierRunningUnknown,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              if (draft.port != null && draft.port!.isNotEmpty)
                                Text(
                                  l10n.zerotierPortValue(draft.port!),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      LuciSectionHeader(l10n.zerotierMain),
                      Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: LuciSpacing.md,
                          vertical: LuciSpacing.sm,
                        ),
                        child: SwitchListTile(
                          title: Text(l10n.zerotierEnabled),
                          subtitle: Text(l10n.zerotierEnabledSubtitle),
                          value: draft.enabled,
                          onChanged: _busy
                              ? null
                              : (v) => _updateDraft(
                                  (c) => c.copyWith(enabled: v),
                                ),
                        ),
                      ),
                      LuciSectionHeader(l10n.zerotierNetworks),
                      if (draft.networks.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: LuciSpacing.lg,
                            vertical: LuciSpacing.md,
                          ),
                          child: Text(
                            l10n.zerotierNetworksEmpty,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        )
                      else
                        ...draft.networks.map((network) {
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: LuciSpacing.md,
                              vertical: LuciSpacing.sm,
                            ),
                            child: SwitchListTile(
                              title: Text(
                                network.id,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                draft.isLegacyFormat
                                    ? l10n.zerotierNetworkLegacyHint
                                    : l10n.zerotierNetworkSubtitle,
                              ),
                              value: network.enabled,
                              onChanged:
                                  _busy || draft.isLegacyFormat
                                  ? null
                                  : (v) => _updateDraft(
                                      (c) => c.withNetworkEnabled(
                                        network.section,
                                        v,
                                      ),
                                    ),
                            ),
                          );
                        }),
                      LuciSectionHeader(l10n.zerotierInterfaces),
                      if (interfaces.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            LuciSpacing.lg,
                            LuciSpacing.md,
                            LuciSpacing.lg,
                            LuciSpacing.lg,
                          ),
                          child: Text(
                            l10n.zerotierInterfacesEmpty,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        )
                      else
                        ...interfaces.map((iface) {
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: LuciSpacing.md,
                              vertical: LuciSpacing.sm,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(LuciSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    iface.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  _infoRow(
                                    context,
                                    l10n.macAddress,
                                    iface.mac ?? '—',
                                  ),
                                  _infoRow(
                                    context,
                                    l10n.ipv4Address,
                                    iface.ipv4 ?? '—',
                                  ),
                                  _infoRow(
                                    context,
                                    l10n.ipv6Address,
                                    iface.ipv6 ?? '—',
                                  ),
                                  _infoRow(
                                    context,
                                    l10n.zerotierInterfaceMtu,
                                    iface.mtu ?? '—',
                                  ),
                                  _infoRow(
                                    context,
                                    l10n.zerotierInterfaceDownload,
                                    EthernetPortDetails.formatTrafficBytes(
                                      iface.rxBytes,
                                    ),
                                  ),
                                  _infoRow(
                                    context,
                                    l10n.zerotierInterfaceUpload,
                                    EthernetPortDetails.formatTrafficBytes(
                                      iface.txBytes,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
