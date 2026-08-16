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

  void _discard() {
    final base = _baseline;
    if (base == null) return;
    setState(() => _draft = base);
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
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(appStateProvider).applyPasswallSettings(
      globalValues: globalValues.isEmpty ? null : globalValues,
      nodeUpdates: nodeUpdates.isEmpty ? null : nodeUpdates,
      restart: true,
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

    messenger.showSnackBar(
      SnackBar(content: Text(ok ? l10n.passwallSaved : l10n.passwallSaveFailed)),
    );
  }

  Future<void> _restart() async {
    if (_busy || _isDirty()) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(appStateProvider)
        .restartPasswall(context: context);
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? l10n.passwallRestarted : l10n.passwallRestartFailed),
      ),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = ref.watch(appStateProvider);
    final draft = _draft;
    final loading = appState.isPasswallLoading && draft == null;
    final dirty = draft != null && _baseline != null && _isDirty();

    return Scaffold(
      appBar: LuciAppBar(title: l10n.passwall, showBack: true),
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
                  child: RefreshIndicator(
                    onRefresh: () async {
                      if (dirty) return;
                      await _reload();
                    },
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
                              _NodeDropdown(
                                title: l10n.passwallTcpNode,
                                value: draft.tcpNode,
                                nodes: draft.nodes,
                                allowEmpty: true,
                                emptyLabel: l10n.passwallNodeClose,
                                enabled: !_busy,
                                onChanged: (id) => _updateDraft(
                                  (c) => c.copyWith(tcpNode: id),
                                ),
                              ),
                              const Divider(height: 1),
                              _NodeDropdown(
                                title: l10n.passwallUdpNode,
                                value: draft.udpNode,
                                nodes: draft.nodes,
                                allowEmpty: true,
                                emptyLabel: l10n.passwallNodeClose,
                                allowTcpAlias: true,
                                tcpAliasLabel: l10n.passwallUdpSameAsTcp,
                                enabled: !_busy,
                                onChanged: (id) => _updateDraft(
                                  (c) => c.copyWith(udpNode: id),
                                ),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                title: Text(l10n.passwallRestart),
                                subtitle: Text(l10n.passwallRestartSubtitle),
                                trailing: const Icon(Icons.refresh),
                                enabled: !_busy && !dirty,
                                onTap: dirty ? null : _restart,
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
                                for (var i = 0;
                                    i < draft.shuntRules.length;
                                    i++) ...[
                                  if (i > 0) const Divider(height: 1),
                                  _ShuntRuleDropdown(
                                    title: draft.shuntRules[i].isDefault
                                        ? l10n.passwallShuntDefault
                                        : draft.shuntRules[i].remarks,
                                    value: draft.shuntAssignment(
                                      draft.shuntRules[i].option,
                                    ),
                                    specialLabels: _shuntValueLabels(l10n),
                                    nodes: draft.selectableNodes,
                                    enabled: !_busy,
                                    onChanged: (v) => _updateDraft(
                                      (c) => c.withShuntAssignment(
                                        draft.shuntRules[i].option,
                                        v,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        Padding(
                          padding: const EdgeInsets.all(LuciSpacing.md),
                          child: Text(
                            l10n.passwallFooterHint,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                        if (dirty) const SizedBox(height: 72),
                      ],
                    ),
                  ),
                ),
                if (dirty)
                  SafeArea(
                    top: false,
                    child: Material(
                      elevation: 8,
                      color: Theme.of(context).colorScheme.surface,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          LuciSpacing.md,
                          LuciSpacing.sm,
                          LuciSpacing.md,
                          LuciSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _busy ? null : _discard,
                                child: Text(l10n.passwallDiscard),
                              ),
                            ),
                            const SizedBox(width: LuciSpacing.sm),
                            Expanded(
                              flex: 2,
                              child: FilledButton(
                                onPressed: _busy ? null : _apply,
                                child: Text(l10n.passwallApply),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ShuntRuleDropdown extends StatelessWidget {
  final String title;
  final String value;
  final Map<String, String> specialLabels;
  final List<PasswallNode> nodes;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _ShuntRuleDropdown({
    required this.title,
    required this.value,
    required this.specialLabels,
    required this.nodes,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ids = <String>{...specialLabels.keys, ...nodes.map((n) => n.id)};
    if (value.isNotEmpty && !ids.contains(value)) ids.add(value);
    final effective = ids.contains(value) ? value : '';

    return ListTile(
      title: Text(title),
      subtitle: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: effective,
          onChanged: enabled
              ? (v) {
                  if (v != null) onChanged(v);
                }
              : null,
          items: [
            ...specialLabels.entries.map(
              (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
            ),
            ...nodes.map(
              (n) => DropdownMenuItem(value: n.id, child: Text(n.label)),
            ),
            if (value.isNotEmpty &&
                !specialLabels.containsKey(value) &&
                !nodes.any((n) => n.id == value))
              DropdownMenuItem(value: value, child: Text(value)),
          ],
        ),
      ),
    );
  }
}

class _NodeDropdown extends StatelessWidget {
  final String title;
  final String value;
  final List<PasswallNode> nodes;
  final bool allowEmpty;
  final String emptyLabel;
  final bool allowTcpAlias;
  final String? tcpAliasLabel;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _NodeDropdown({
    required this.title,
    required this.value,
    required this.nodes,
    required this.allowEmpty,
    required this.emptyLabel,
    this.allowTcpAlias = false,
    this.tcpAliasLabel,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ids = <String>{};
    if (allowEmpty) ids.add('');
    if (allowTcpAlias) ids.add('tcp');
    for (final n in nodes) {
      ids.add(n.id);
    }
    if (value.isNotEmpty && !ids.contains(value)) {
      ids.add(value);
    }

    final effective = ids.contains(value) ? value : (allowEmpty ? '' : ids.first);

    return ListTile(
      title: Text(title),
      subtitle: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: effective,
          onChanged: enabled
              ? (v) {
                  if (v != null) onChanged(v);
                }
              : null,
          items: [
            if (allowEmpty)
              DropdownMenuItem(value: '', child: Text(emptyLabel)),
            if (allowTcpAlias && tcpAliasLabel != null)
              DropdownMenuItem(value: 'tcp', child: Text(tcpAliasLabel!)),
            ...nodes.map(
              (n) => DropdownMenuItem(value: n.id, child: Text(n.label)),
            ),
            if (value.isNotEmpty &&
                value != 'tcp' &&
                !nodes.any((n) => n.id == value))
              DropdownMenuItem(value: value, child: Text(value)),
          ],
        ),
      ),
    );
  }
}
