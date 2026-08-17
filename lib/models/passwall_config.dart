/// Snapshot of common [luci-app-passwall](https://github.com/Openwrt-Passwall/openwrt-passwall) settings.
class PasswallNode {
  final String id;
  final String remarks;
  final String? type;
  final String? protocol;
  final String shuntGroup;
  /// Raw UCI options used when this node is a shunt target.
  final Map<String, String> options;

  const PasswallNode({
    required this.id,
    required this.remarks,
    this.type,
    this.protocol,
    this.shuntGroup = '',
    this.options = const {},
  });

  bool get isShunt => protocol == '_shunt';

  /// Display label. [shunt] is localized (e.g. "Shunt" / "分流").
  String label({String shunt = 'Shunt'}) {
    final name = remarks.trim().isEmpty ? id : remarks.trim();
    final typeLabel = (type == null || type!.isEmpty) ? '' : type!;
    if (isShunt) {
      return typeLabel.isEmpty ? '$shunt: [$name]' : '$typeLabel $shunt: [$name]';
    }
    if (typeLabel.isEmpty) return name;
    final proto = (protocol == null || protocol!.isEmpty) ? '' : ' $protocol';
    return '$typeLabel$proto: [$name]';
  }
}

class PasswallShuntRule {
  final String remarks;
  final String group;
  /// UCI option on the shunt node (`Ads`, `Direct`, or `default_node`).
  final String option;

  const PasswallShuntRule({
    required this.remarks,
    this.group = '',
    required this.option,
  });

  bool get isDefault => option == 'default_node';
}

class PasswallSubscribe {
  final String id;
  final String remark;
  final String url;

  const PasswallSubscribe({
    required this.id,
    required this.remark,
    required this.url,
  });

  bool get hasUrl => url.trim().isNotEmpty;
}

class PasswallConfig {
  final String globalSection;
  /// UCI section id for `global_subscribe` (used by older CBI subscribe-all).
  final String? globalSubscribeSection;
  final bool enabled;
  final String tcpNode;
  final String udpNode;
  final List<PasswallNode> nodes;
  final List<PasswallShuntRule> allShuntRules;
  final List<PasswallSubscribe> subscriptions;

  const PasswallConfig({
    required this.globalSection,
    this.globalSubscribeSection,
    required this.enabled,
    required this.tcpNode,
    required this.udpNode,
    required this.nodes,
    required this.allShuntRules,
    this.subscriptions = const [],
  });

  bool get hasSubscriptions =>
      subscriptions.any((s) => s.hasUrl);

  PasswallNode? nodeById(String id) {
    if (id.isEmpty) return null;
    for (final n in nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  PasswallNode? get tcpNodeInfo => nodeById(tcpNode);

  bool get tcpIsShunt => tcpNodeInfo?.isShunt == true;

  List<PasswallNode> get selectableNodes =>
      nodes.where((n) => !n.isShunt).toList();

  /// Rules visible for the currently selected TCP shunt node.
  List<PasswallShuntRule> get shuntRules {
    final tcp = tcpNodeInfo;
    if (tcp == null || !tcp.isShunt) return const [];
    final group = tcp.shuntGroup.toLowerCase();
    final rules = allShuntRules
        .where((r) => r.group.toLowerCase() == group)
        .toList();
    return [
      ...rules,
      const PasswallShuntRule(
        remarks: 'Default',
        option: 'default_node',
      ),
    ];
  }

  String shuntAssignment(String option) {
    final tcp = tcpNodeInfo;
    if (tcp == null || !tcp.isShunt) return '';
    final raw = tcp.options[option] ?? '';
    if (raw.isNotEmpty) return raw;
    return option == 'default_node' ? '_direct' : '';
  }

  /// Changed shunt rule options for [nodeId] compared to [baseline].
  Map<String, String> changedShuntOptions(
    PasswallConfig baseline,
    String nodeId,
  ) {
    final draftNode = nodeById(nodeId);
    final baseNode = baseline.nodeById(nodeId);
    if (draftNode == null || baseNode == null || !draftNode.isShunt) {
      return const {};
    }
    final changed = <String, String>{};
    final options = <String>{
      'default_node',
      ...allShuntRules
          .where(
            (r) => r.group.toLowerCase() == draftNode.shuntGroup.toLowerCase(),
          )
          .map((r) => r.option),
    };
    for (final option in options) {
      final fallback = option == 'default_node' ? '_direct' : '';
      final dVal = draftNode.options[option] ?? fallback;
      final bVal = baseNode.options[option] ?? fallback;
      if (dVal != bVal) changed[option] = dVal;
    }
    return changed;
  }

  static String _str(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    return value.toString();
  }

  static bool _flag(dynamic value, {bool defaultValue = false}) {
    final s = _str(value);
    if (s.isEmpty) return defaultValue;
    return s == '1' || s.toLowerCase() == 'true';
  }

  /// Parses LuCI `uci.get` payload for config `passwall`.
  factory PasswallConfig.fromUciValues(Map values) {
    String? globalId;
    String? globalSubscribeId;
    Map<String, dynamic>? global;
    final nodes = <PasswallNode>[];
    final allShuntRules = <PasswallShuntRule>[];
    final subscriptions = <PasswallSubscribe>[];

    values.forEach((key, raw) {
      if (raw is! Map) return;
      final section = Map<String, dynamic>.from(raw);
      final type = _str(section['.type']);
      final id = key.toString();
      if (type == 'global' && global == null) {
        globalId = id;
        global = section;
      } else if (type == 'global_subscribe' && globalSubscribeId == null) {
        globalSubscribeId = id;
      } else if (type == 'nodes') {
        final protocol = _str(section['protocol']);
        final options = <String, String>{};
        if (protocol == '_shunt') {
          section.forEach((k, v) {
            final name = k.toString();
            if (name.startsWith('.')) return;
            options[name] = _str(v);
          });
        }
        nodes.add(
          PasswallNode(
            id: id,
            remarks: _str(section['remarks'], id),
            type: _str(section['type']).isEmpty ? null : _str(section['type']),
            protocol: protocol.isEmpty ? null : protocol,
            shuntGroup: _str(section['shunt_group']),
            options: options,
          ),
        );
      } else if (type == 'shunt_rules') {
        allShuntRules.add(
          PasswallShuntRule(
            remarks: _str(section['remarks'], id),
            group: _str(section['group']),
            option: id,
          ),
        );
      } else if (type == 'subscribe_list') {
        subscriptions.add(
          PasswallSubscribe(
            id: id,
            remark: _str(section['remark'], id),
            url: _str(section['url']),
          ),
        );
      }
    });

    final g = global ?? <String, dynamic>{};
    return PasswallConfig(
      globalSection: globalId ?? '@global[0]',
      globalSubscribeSection: globalSubscribeId,
      enabled: _flag(g['enabled']),
      tcpNode: _str(g['tcp_node']),
      udpNode: _str(g['udp_node']),
      nodes: nodes,
      allShuntRules: allShuntRules,
      subscriptions: subscriptions,
    );
  }

  PasswallConfig copyWith({
    bool? enabled,
    String? tcpNode,
    String? udpNode,
    List<PasswallNode>? nodes,
  }) {
    return PasswallConfig(
      globalSection: globalSection,
      globalSubscribeSection: globalSubscribeSection,
      enabled: enabled ?? this.enabled,
      tcpNode: tcpNode ?? this.tcpNode,
      udpNode: udpNode ?? this.udpNode,
      nodes: nodes ?? this.nodes,
      allShuntRules: allShuntRules,
      subscriptions: subscriptions,
    );
  }

  PasswallConfig withShuntAssignment(String option, String value) {
    final tcp = tcpNodeInfo;
    if (tcp == null || !tcp.isShunt) return this;
    final nextNodes = nodes.map((n) {
      if (n.id != tcp.id) return n;
      final opts = Map<String, String>.from(n.options);
      opts[option] = value;
      return PasswallNode(
        id: n.id,
        remarks: n.remarks,
        type: n.type,
        protocol: n.protocol,
        shuntGroup: n.shuntGroup,
        options: opts,
      );
    }).toList();
    return copyWith(nodes: nextNodes);
  }
}
