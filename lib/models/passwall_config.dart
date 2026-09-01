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

  bool get isBalancing => protocol == '_balancing';

  bool get isUrltest => protocol == '_urltest';

  bool get isIface => protocol == '_iface';

  /// Display label. [shunt] is localized (e.g. "Shunt" / "分流").
  String label({
    String shunt = 'Shunt',
    String balancing = 'Load balancing',
    String urltest = 'URL test',
    String iface = 'Interface',
  }) {
    final name = remarks.trim().isEmpty ? id : remarks.trim();
    final typeLabel = (type == null || type!.isEmpty) ? '' : type!;
    if (isShunt) {
      return typeLabel.isEmpty ? '$shunt: [$name]' : '$typeLabel $shunt: [$name]';
    }
    if (isBalancing) {
      return '$balancing: [$name]';
    }
    if (isUrltest) {
      return '$urltest: [$name]';
    }
    if (isIface) {
      return '$iface: [$name]';
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

/// Preset transparent-proxy modes from LuCI `global/proxy.htm`.
enum PasswallProxyMode {
  gfwList,
  /// LuCI `switch_chnroute_mode` — "Not China List" / 中国列表以外.
  notChinaList,
  /// LuCI `switch_returnhome_mode` — "China List" / 中国列表.
  returnHome,
  global;

  Map<String, String> toGlobalUci() {
    switch (this) {
      case PasswallProxyMode.gfwList:
        return const {
          'use_gfw_list': '1',
          'chn_list': '0',
          'tcp_proxy_mode': 'disable',
          'udp_proxy_mode': 'disable',
        };
      case PasswallProxyMode.notChinaList:
        return const {
          'use_gfw_list': '1',
          'chn_list': 'direct',
          'tcp_proxy_mode': 'proxy',
          'udp_proxy_mode': 'proxy',
        };
      case PasswallProxyMode.returnHome:
        return const {
          'use_gfw_list': '0',
          'chn_list': 'proxy',
          'tcp_proxy_mode': 'disable',
          'udp_proxy_mode': 'disable',
        };
      case PasswallProxyMode.global:
        return const {
          'use_gfw_list': '0',
          'chn_list': '0',
          'tcp_proxy_mode': 'proxy',
          'udp_proxy_mode': 'proxy',
        };
    }
  }

  static PasswallProxyMode? fromGlobalUci({
    required bool useGfwList,
    required String chnList,
    required String tcpProxyMode,
    required String udpProxyMode,
  }) {
    final tcp = tcpProxyMode == 'disable' ? 'disable' : 'proxy';
    final udp = udpProxyMode == 'disable' ? 'disable' : 'proxy';
    if (useGfwList &&
        chnList == '0' &&
        tcp == 'disable' &&
        udp == 'disable') {
      return PasswallProxyMode.gfwList;
    }
    if (useGfwList &&
        chnList == 'direct' &&
        tcp == 'proxy' &&
        udp == 'proxy') {
      return PasswallProxyMode.notChinaList;
    }
    if (!useGfwList &&
        chnList == 'proxy' &&
        tcp == 'disable' &&
        udp == 'disable') {
      return PasswallProxyMode.returnHome;
    }
    if (!useGfwList &&
        chnList == '0' &&
        tcp == 'proxy' &&
        udp == 'proxy') {
      return PasswallProxyMode.global;
    }
    return null;
  }
}

extension PasswallProxyModeLabels on PasswallProxyMode {
  String label({
    String gfwList = 'GFW list',
    String notChinaList = 'Outside China list',
    String returnHome = 'China list',
    String global = 'Global proxy',
  }) {
    switch (this) {
      case PasswallProxyMode.gfwList:
        return gfwList;
      case PasswallProxyMode.notChinaList:
        return notChinaList;
      case PasswallProxyMode.returnHome:
        return returnHome;
      case PasswallProxyMode.global:
        return global;
    }
  }
}

/// Enabled Socks listener usable as a shunt rule target (`Socks_<section>`).
class PasswallSocksTarget {
  final String id;
  final String port;

  const PasswallSocksTarget({
    required this.id,
    required this.port,
  });

  String label({String socksConfig = 'Socks', String portLabel = 'Port'}) {
    final portText = port.trim().isEmpty ? '?' : port.trim();
    return '$socksConfig [$portText $portLabel]';
  }
}

class PasswallConfig {
  final String globalSection;
  final bool enabled;
  /// Selected proxy node id (`node` in global UCI section).
  final String node;
  final bool useGfwList;
  final String chnList;
  final String tcpProxyMode;
  final String udpProxyMode;
  final List<PasswallNode> nodes;
  final List<PasswallShuntRule> allShuntRules;
  final List<PasswallSubscribe> subscriptions;
  final List<PasswallSocksTarget> socksShuntTargets;

  const PasswallConfig({
    required this.globalSection,
    required this.enabled,
    required this.node,
    required this.useGfwList,
    required this.chnList,
    required this.tcpProxyMode,
    required this.udpProxyMode,
    required this.nodes,
    required this.allShuntRules,
    this.subscriptions = const [],
    this.socksShuntTargets = const [],
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

  PasswallNode? get selectedNodeInfo => nodeById(node);

  bool get isShunt => selectedNodeInfo?.isShunt == true;

  PasswallProxyMode? get proxyMode => PasswallProxyMode.fromGlobalUci(
    useGfwList: useGfwList,
    chnList: chnList,
    tcpProxyMode: tcpProxyMode,
    udpProxyMode: udpProxyMode,
  );

  bool proxyModeFieldsMatch(PasswallConfig other) {
    return useGfwList == other.useGfwList &&
        chnList == other.chnList &&
        tcpProxyMode == other.tcpProxyMode &&
        udpProxyMode == other.udpProxyMode;
  }

  Map<String, String> proxyModeGlobalUci() => {
    'use_gfw_list': useGfwList ? '1' : '0',
    'chn_list': chnList,
    'tcp_proxy_mode': tcpProxyMode,
    'udp_proxy_mode': udpProxyMode,
  };

  PasswallConfig withProxyMode(PasswallProxyMode mode) {
    final values = mode.toGlobalUci();
    return copyWith(
      useGfwList: values['use_gfw_list'] == '1',
      chnList: values['chn_list']!,
      tcpProxyMode: values['tcp_proxy_mode']!,
      udpProxyMode: values['udp_proxy_mode']!,
    );
  }

  /// Nodes selectable as shunt rule targets (excludes other shunt nodes).
  List<PasswallNode> get shuntTargetNodes =>
      nodes.where((n) => !n.isShunt).toList();

  PasswallSocksTarget? socksTargetById(String id) {
    for (final target in socksShuntTargets) {
      if (target.id == id) return target;
    }
    return null;
  }

  /// Rules visible for the currently selected shunt node.
  List<PasswallShuntRule> get shuntRules {
    final selected = selectedNodeInfo;
    if (selected == null || !selected.isShunt) return const [];
    final group = selected.shuntGroup.toLowerCase();
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
    final selected = selectedNodeInfo;
    if (selected == null || !selected.isShunt) return '';
    final raw = selected.options[option] ?? '';
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

  static String _proxyModeValue(dynamic value) {
    final s = _str(value, 'proxy');
    return s == 'disable' ? 'disable' : 'proxy';
  }

  /// Parses LuCI `uci.get` payload for config `passwall`.
  factory PasswallConfig.fromUciValues(Map values) {
    String? globalId;
    Map<String, dynamic>? global;
    final nodes = <PasswallNode>[];
    final allShuntRules = <PasswallShuntRule>[];
    final subscriptions = <PasswallSubscribe>[];
    final socksShuntTargets = <PasswallSocksTarget>[];

    values.forEach((key, raw) {
      if (raw is! Map) return;
      final section = Map<String, dynamic>.from(raw);
      final type = _str(section['.type']);
      final id = key.toString();
      if (type == 'global' && global == null) {
        globalId = id;
        global = section;
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
      } else if (type == 'socks' && _flag(section['enabled'])) {
        final boundNode = _str(section['node']);
        if (boundNode.isNotEmpty) {
          socksShuntTargets.add(
            PasswallSocksTarget(
              id: 'Socks_$id',
              port: _str(section['port']),
            ),
          );
        }
      }
    });

    final g = global ?? <String, dynamic>{};
    return PasswallConfig(
      globalSection: globalId ?? '@global[0]',
      enabled: _flag(g['enabled']),
      node: _str(g['node']),
      useGfwList: _flag(g['use_gfw_list'], defaultValue: true),
      chnList: _str(g['chn_list'], 'direct'),
      tcpProxyMode: _proxyModeValue(g['tcp_proxy_mode']),
      udpProxyMode: _proxyModeValue(g['udp_proxy_mode']),
      nodes: nodes,
      allShuntRules: allShuntRules,
      subscriptions: subscriptions,
      socksShuntTargets: socksShuntTargets,
    );
  }

  PasswallConfig copyWith({
    bool? enabled,
    String? node,
    bool? useGfwList,
    String? chnList,
    String? tcpProxyMode,
    String? udpProxyMode,
    List<PasswallNode>? nodes,
  }) {
    return PasswallConfig(
      globalSection: globalSection,
      enabled: enabled ?? this.enabled,
      node: node ?? this.node,
      useGfwList: useGfwList ?? this.useGfwList,
      chnList: chnList ?? this.chnList,
      tcpProxyMode: tcpProxyMode ?? this.tcpProxyMode,
      udpProxyMode: udpProxyMode ?? this.udpProxyMode,
      nodes: nodes ?? this.nodes,
      allShuntRules: allShuntRules,
      subscriptions: subscriptions,
      socksShuntTargets: socksShuntTargets,
    );
  }

  PasswallConfig withShuntAssignment(String option, String value) {
    final selected = selectedNodeInfo;
    if (selected == null || !selected.isShunt) return this;
    final nextNodes = nodes.map((n) {
      if (n.id != selected.id) return n;
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
