import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/design/luci_design_system.dart';
import 'package:luci_mobile/l10n/app_localizations.dart';
import 'package:luci_mobile/main.dart';
import 'package:luci_mobile/models/passwall_config.dart';
import 'package:luci_mobile/widgets/luci_app_bar.dart';

class PasswallScreen extends ConsumerStatefulWidget {
  const PasswallScreen({super.key});

  @override
  ConsumerState<PasswallScreen> createState() => _PasswallScreenState();
}

class _PasswallScreenState extends ConsumerState<PasswallScreen> {
  bool _busy = false;
  PasswallConfig? _draft;
  PasswallConfig? _baseline;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    final config = await ref
        .read(appStateProvider)
        .fetchPasswallConfig(context: context);
    if (!mounted) return;
    setState(() {
      _baseline = config;
      _draft = config;
    });
  }

  bool _isDirty() {
    final draft = _draft;
    final base = _baseline;
    if (draft == null || base == null) return false;
    if (draft.enabled != base.enabled) return true;
    if (draft.tcpNode != base.tcpNode) return true;
    if (draft.udpNode != base.udpNode) return true;
    for (final node in draft.nodes.where((n) => n.isShunt)) {
      if (draft.changedShuntOptions(base, node.id).isNotEmpty) return true;
    }
    return false;
  }

  void _updateDraft(PasswallConfig Function(PasswallConfig) update) {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _apply() async {
    final draft = _draft;
    final base = _baseline;
    if (_busy || draft == null || base == null || !_isDirty()) return;

    final globalValues = <String, String>{};
    if (draft.enabled != base.enabled) {
      globalValues['enabled'] = draft.enabled ? '1' : '0';
    }
    if (draft.tcpNode != base.tcpNode) {
      globalValues['tcp_node'] = draft.tcpNode;
    }
    if (draft.udpNode != base.udpNode) {
      globalValues['udp_node'] = draft.udpNode;
    }

    final nodeUpdates = <String, Map<String, String>>{};
    for (final node in draft.nodes.where((n) => n.isShunt)) {
      final changed = draft.changedShuntOptions(base, node.id);
      if (changed.isNotEmpty) {
        nodeUpdates[node.id] = changed;
      }
    }

    if (globalValues.isEmpty && nodeUpdates.isEmpty) return;

    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context)!;
    final ok = await ref.read(appStateProvider).applyPasswallSettings(
      globalValues: globalValues.isEmpty ? null : globalValues,
      nodeUpdates: nodeUpdates.isEmpty ? null : nodeUpdates,
      context: context,
    );
    if (!mounted) return;

    if (ok) {
      final refreshed = ref.read(appStateProvider).passwallConfig;
      setState(() {
        _busy = false;
        _baseline = refreshed;
        _draft = refreshed;
      });
    } else {
      setState(() => _busy = false);
    }

    _showToast(
      ok ? l10n.passwallSaved : l10n.passwallSaveFailed,
      success: ok,
    );
  }

  Future<void> _updateSubscriptions() async {
    final draft = _draft;
    if (_busy || draft == null || !draft.hasSubscriptions) return;

    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context)!;
    final ok = await ref
        .read(appStateProvider)
        .updatePasswallSubscriptions(context: context);
    if (!mounted) return;
    setState(() => _busy = false);
    _showToast(
      ok
          ? l10n.passwallUpdateSubscribeStarted
          : l10n.passwallUpdateSubscribeFailed,
      success: ok,
    );
  }

  Map<String, String> _shuntValueLabels(AppLocalizations l10n) {
    return {
      '': l10n.passwallNodeClose,
      '_default': l10n.passwallShuntDefault,
      '_direct': l10n.passwallShuntDirect,
      '_blackhole': l10n.passwallShuntBlackhole,
    };
  }

  String _nodeLabel(PasswallNode node, AppLocalizations l10n) {
    return node.label(shunt: l10n.passwallShunt);
  }

  String _labelForValue({
    required String value,
    required List<PasswallNode> nodes,
    required AppLocalizations l10n,
    Map<String, String>? specialLabels,
    String? emptyLabel,
    String? tcpAliasLabel,
  }) {
    if (specialLabels != null && specialLabels.containsKey(value)) {
      return specialLabels[value]!;
    }
    if (value.isEmpty) return emptyLabel ?? value;
    if (value == 'tcp') return tcpAliasLabel ?? value;
    for (final n in nodes) {
      if (n.id == value) return _nodeLabel(n, l10n);
    }
    return value;
  }

  Future<void> _pickOption({
    required String title,
    required String currentValue,
    required List<_SheetOption> options,
    required ValueChanged<String> onSelected,
  }) async {
    if (_busy || options.isEmpty) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (context) {
        final maxHeight = MediaQuery.of(context).size.height * 0.7;
        final colorScheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 4,
                      ),
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Divider(height: 16),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final isSelected = option.value == currentValue;
                    return ListTile(
                      title: Text(
                        option.label,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle,
                              color: colorScheme.primary,
                            )
                          : null,
                      selected: isSelected,
                      onTap: () => Navigator.of(context).pop(option.value),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    if (selected != null && selected != currentValue) {
      onSelected(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = ref.watch(appStateProvider);
    final draft = _draft;
    final loading = appState.isPasswallLoading && draft == null;
    final dirty = draft != null && _baseline != null && _isDirty();
    final shuntLabels = _shuntValueLabels(l10n);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: LuciAppBar(
        title: l10n.passwall,
        showBack: true,
        actions: dirty
            ? [
                TextButton(
                  onPressed: _busy ? null : _apply,
                  child: Text(
                    l10n.passwallApply,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _busy
                          ? colorScheme.onSurface.withValues(alpha: 0.38)
                          : colorScheme.primary,
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : draft == null
          ? LuciErrorDisplay(
              title: l10n.passwallUnavailable,
              message: appState.passwallError ?? l10n.passwallUnavailableMessage,
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
                      LuciSectionHeader(l10n.passwallMain),
                      Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: LuciSpacing.md,
                          vertical: LuciSpacing.sm,
                        ),
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: Text(l10n.passwallEnabled),
                              subtitle: Text(l10n.passwallEnabledSubtitle),
                              value: draft.enabled,
                              onChanged: _busy
                                  ? null
                                  : (v) => _updateDraft(
                                      (c) => c.copyWith(enabled: v),
                                    ),
                            ),
                            const Divider(height: 1),
                            _SelectTile(
                              title: l10n.passwallTcpNode,
                              valueLabel: _labelForValue(
                                value: draft.tcpNode,
                                nodes: draft.nodes,
                                l10n: l10n,
                                emptyLabel: l10n.passwallNodeClose,
                              ),
                              enabled: !_busy,
                              onTap: () => _pickOption(
                                title: l10n.passwallTcpNode,
                                currentValue: draft.tcpNode,
                                options: [
                                  _SheetOption('', l10n.passwallNodeClose),
                                  ...draft.nodes.map(
                                    (n) => _SheetOption(
                                      n.id,
                                      _nodeLabel(n, l10n),
                                    ),
                                  ),
                                ],
                                onSelected: (id) => _updateDraft(
                                  (c) => c.copyWith(tcpNode: id),
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            _SelectTile(
                              title: l10n.passwallUdpNode,
                              valueLabel: _labelForValue(
                                value: draft.udpNode,
                                nodes: draft.nodes,
                                l10n: l10n,
                                emptyLabel: l10n.passwallNodeClose,
                                tcpAliasLabel: l10n.passwallUdpSameAsTcp,
                              ),
                              enabled: !_busy,
                              onTap: () => _pickOption(
                                title: l10n.passwallUdpNode,
                                currentValue: draft.udpNode,
                                options: [
                                  _SheetOption('', l10n.passwallNodeClose),
                                  _SheetOption(
                                    'tcp',
                                    l10n.passwallUdpSameAsTcp,
                                  ),
                                  ...draft.nodes.map(
                                    (n) => _SheetOption(
                                      n.id,
                                      _nodeLabel(n, l10n),
                                    ),
                                  ),
                                ],
                                onSelected: (id) => _updateDraft(
                                  (c) => c.copyWith(udpNode: id),
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              title: Text(l10n.passwallUpdateSubscribe),
                              subtitle: Text(
                                draft.hasSubscriptions
                                    ? l10n.passwallUpdateSubscribeSubtitle
                                    : l10n.passwallUpdateSubscribeEmpty,
                              ),
                              trailing: const Icon(Icons.sync),
                              enabled: !_busy && draft.hasSubscriptions,
                              onTap: (!_busy && draft.hasSubscriptions)
                                  ? _updateSubscriptions
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      if (draft.tcpIsShunt) ...[
                        LuciSectionHeader(l10n.passwallShuntRules),
                        Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: LuciSpacing.md,
                            vertical: LuciSpacing.sm,
                          ),
                          child: Column(
                            children: [
                              for (final entry
                                  in draft.shuntRules.asMap().entries) ...[
                                if (entry.key > 0) const Divider(height: 1),
                                _SelectTile(
                                  title: entry.value.isDefault
                                      ? l10n.passwallShuntDefault
                                      : entry.value.remarks,
                                  valueLabel: _labelForValue(
                                    value: draft.shuntAssignment(
                                      entry.value.option,
                                    ),
                                    nodes: draft.selectableNodes,
                                    l10n: l10n,
                                    specialLabels: shuntLabels,
                                  ),
                                  enabled: !_busy,
                                  onTap: () {
                                    final rule = entry.value;
                                    final value = draft.shuntAssignment(
                                      rule.option,
                                    );
                                    _pickOption(
                                      title: rule.isDefault
                                          ? l10n.passwallShuntDefault
                                          : rule.remarks,
                                      currentValue: value,
                                      options: [
                                        ...shuntLabels.entries.map(
                                          (e) =>
                                              _SheetOption(e.key, e.value),
                                        ),
                                        ...draft.selectableNodes.map(
                                          (n) => _SheetOption(
                                            n.id,
                                            _nodeLabel(n, l10n),
                                          ),
                                        ),
                                      ],
                                      onSelected: (v) => _updateDraft(
                                        (c) => c.withShuntAssignment(
                                          rule.option,
                                          v,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _SheetOption {
  final String value;
  final String label;
  const _SheetOption(this.value, this.label);
}

class _SelectTile extends StatelessWidget {
  final String title;
  final String valueLabel;
  final bool enabled;
  final VoidCallback onTap;

  const _SelectTile({
    required this.title,
    required this.valueLabel,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      title: Text(title),
      subtitle: Text(
        valueLabel,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: enabled
              ? colorScheme.onSurface
              : colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
      trailing: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: enabled
            ? colorScheme.onSurfaceVariant
            : colorScheme.onSurface.withValues(alpha: 0.4),
      ),
      enabled: enabled,
      onTap: enabled ? onTap : null,
    );
  }
}
