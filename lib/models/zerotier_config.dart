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

  static List<String> _stringList(dynamic value) {
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
}
