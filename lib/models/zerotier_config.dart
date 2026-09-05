/// Snapshot of a live ZeroTier `zt*` adapter (LuCI Interface page fields).
class ZerotierInterface {
  final String name;
  final String? mac;
  final String? ipv4;
  final String? ipv6;
  final String? mtu;
  final int rxBytes;
  final int txBytes;

  const ZerotierInterface({
    required this.name,
    this.mac,
    this.ipv4,
    this.ipv6,
    this.mtu,
    this.rxBytes = 0,
    this.txBytes = 0,
  });

  static final RegExp _ztName = RegExp(r'^zt[a-z0-9]+$', caseSensitive: false);

  /// Builds interface rows from `luci-rpc.getNetworkDevices`.
  static List<ZerotierInterface> fromNetworkDevices(Map devices) {
    final list = <ZerotierInterface>[];
    for (final entry in devices.entries) {
      final name = entry.key.toString().trim();
      if (!_ztName.hasMatch(name)) continue;
      final info = entry.value;
      if (info is! Map) continue;

      final link = info['link'] is Map ? info['link'] as Map : null;
      final mac = _firstNonEmpty([
        info['mac'],
        info['macaddr'],
        link?['mac'],
        link?['macaddr'],
      ]);
      final mtu = _emptyToNull((info['mtu'] ?? link?['mtu'])?.toString());
      final ipv4 = _firstAddress(info['ipaddrs']);
      final ipv6 = _firstAddress(info['ip6addrs']);

      list.add(
        ZerotierInterface(
          name: name,
          mac: mac,
          ipv4: ipv4,
          ipv6: ipv6,
          mtu: mtu,
          rxBytes: _statBytes(info, 'rx_bytes'),
          txBytes: _statBytes(info, 'tx_bytes'),
        ),
      );
    }
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  static String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  /// LuCI may return `"10.0.0.1/24"` or `{address, netmask, …}` — keep address only.
  static String? _firstAddress(dynamic value) {
    if (value is! List) return null;
    for (final item in value) {
      final address = _extractAddress(item);
      if (address != null) return address;
    }
    return null;
  }

  static String? _extractAddress(dynamic item) {
    if (item is Map) {
      final raw = item['address']?.toString().trim() ?? '';
      if (raw.isEmpty) return null;
      return raw.split('/').first.trim();
    }
    final text = item?.toString().trim() ?? '';
    if (text.isEmpty || text.startsWith('{')) return null;
    return text.split('/').first.trim();
  }

  static String? _emptyToNull(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static int _statBytes(Map info, String key) {
    final stats = info['stats'];
    if (stats is Map) {
      return _asInt(stats[key]) ?? 0;
    }
    return _asInt(info[key]) ?? 0;
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }
}

/// Snapshot of OpenWrt / ImmortalWrt `luci-app-zerotier` UCI (`config zerotier`).
///
/// Modern layout:
/// ```
/// config zerotier 'global'
///   option enabled '1'
/// config network 'earth'
///   option id '…'
///   option enabled '1'
/// ```
///
/// Legacy layout (type `zerotier` + `list join`) is also parsed for display.
class ZerotierNetwork {
  final String section;
  final String id;
  final bool enabled;

  const ZerotierNetwork({
    required this.section,
    required this.id,
    this.enabled = true,
  });

  ZerotierNetwork copyWith({bool? enabled}) {
    return ZerotierNetwork(
      section: section,
      id: id,
      enabled: enabled ?? this.enabled,
    );
  }
}

class ZerotierConfig {
  final String globalSection;
  final bool enabled;
  final String? port;
  final List<ZerotierNetwork> networks;
  final bool isLegacyFormat;

  const ZerotierConfig({
    required this.globalSection,
    required this.enabled,
    this.port,
    this.networks = const [],
    this.isLegacyFormat = false,
  });

  ZerotierConfig copyWith({
    bool? enabled,
    List<ZerotierNetwork>? networks,
  }) {
    return ZerotierConfig(
      globalSection: globalSection,
      enabled: enabled ?? this.enabled,
      port: port,
      networks: networks ?? this.networks,
      isLegacyFormat: isLegacyFormat,
    );
  }

  ZerotierConfig withNetworkEnabled(String section, bool enabled) {
    return copyWith(
      networks: [
        for (final n in networks)
          if (n.section == section) n.copyWith(enabled: enabled) else n,
      ],
    );
  }

  factory ZerotierConfig.fromUciValues(Map values) {
    String? globalSection;
    var enabled = false;
    String? port;
    final networks = <ZerotierNetwork>[];
    var legacy = false;

    values.forEach((key, raw) {
      if (raw is! Map) return;
      final section = key.toString();
      final type = _str(raw['.type']);

      if (type == 'network') {
        final id = _str(raw['id']);
        if (id.isEmpty) return;
        networks.add(
          ZerotierNetwork(
            section: section,
            id: id,
            enabled: _flag(raw['enabled'], defaultValue: true),
          ),
        );
        return;
      }

      if (type != 'zerotier') return;

      // Modern global section.
      if (section == 'global' || _str(raw['.name']) == 'global') {
        globalSection = section;
        enabled = _flag(raw['enabled']);
        final p = _str(raw['port']);
        port = p.isEmpty ? null : p;
        return;
      }

      // Legacy: config zerotier 'foo' with list join.
      final joins = _stringList(raw['join']);
      if (joins.isEmpty) return;
      legacy = true;
      final sectionEnabled = _flag(raw['enabled']);
      if (sectionEnabled) enabled = true;
      globalSection ??= section;
      for (final id in joins) {
        if (id.isEmpty) continue;
        networks.add(
          ZerotierNetwork(
            section: section,
            id: id,
            enabled: sectionEnabled,
          ),
        );
      }
    });

    networks.sort((a, b) => a.id.toLowerCase().compareTo(b.id.toLowerCase()));

    return ZerotierConfig(
      globalSection: globalSection ?? 'global',
      enabled: enabled,
      port: port,
      networks: networks,
      isLegacyFormat: legacy && globalSection != 'global',
    );
  }

  static String _str(dynamic value) => value?.toString().trim() ?? '';

  static bool _flag(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    final text = value.toString().trim().toLowerCase();
    if (text.isEmpty) return defaultValue;
    return text == '1' || text == 'true' || text == 'yes' || text == 'on';
  }
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  if (value is String && value.trim().isNotEmpty) {
    return [value.trim()];
  }
  return const [];
}
