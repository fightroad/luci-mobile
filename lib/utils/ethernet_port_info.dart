/// Resolves LuCI-style ethernet port details from dashboard RPC data.
class EthernetPortDetails {
  final String device;
  final List<String> networks;
  final int rxBytes;
  final int txBytes;

  const EthernetPortDetails({
    required this.device,
    required this.networks,
    required this.rxBytes,
    required this.txBytes,
  });

  factory EthernetPortDetails.resolve({
    required String device,
    Map<String, dynamic>? networkDevices,
    Map<String, dynamic>? interfaceDump,
  }) {
    final deviceInfo = lookupNetworkDevice(networkDevices, device);
    return EthernetPortDetails(
      device: device,
      networks: networksForPort(
        device: device,
        networkDevices: networkDevices,
        interfaceDump: interfaceDump,
      ),
      rxBytes: _statBytes(deviceInfo, 'rx_bytes'),
      txBytes: _statBytes(deviceInfo, 'tx_bytes'),
    );
  }

  /// Formats cumulative traffic like LuCI port tooltips (1024-based).
  static String formatTrafficBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KiB', 'MiB', 'GiB', 'TiB'];
    var value = bytes.toDouble();
    var i = 0;
    while (value >= 1024 && i < suffixes.length - 1) {
      value /= 1024;
      i++;
    }
    if (i == 0) return '${value.toInt()} ${suffixes[i]}';
    return '${value.toStringAsFixed(1)} ${suffixes[i]}';
  }
}

/// Case-insensitive lookup in luci-rpc.getNetworkDevices map.
dynamic lookupNetworkDevice(
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

/// Logical netifd interfaces that include [device] (direct or via bridge).
List<String> networksForPort({
  required String device,
  Map<String, dynamic>? networkDevices,
  Map<String, dynamic>? interfaceDump,
}) {
  final port = device.trim();
  if (port.isEmpty) return const [];

  final related = <String>{port.toLowerCase()};

  final portInfo = lookupNetworkDevice(networkDevices, port);
  if (portInfo is Map) {
    final master = portInfo['master']?.toString().trim();
    if (master != null && master.isNotEmpty) {
      related.add(master.toLowerCase());
    }
  }

  if (networkDevices != null) {
    for (final entry in networkDevices.entries) {
      final info = entry.value;
      if (info is! Map) continue;
      final ports = info['ports'];
      if (ports is! List) continue;
      final contains = ports.any(
        (p) => p.toString().trim().toLowerCase() == port.toLowerCase(),
      );
      if (contains) {
        related.add(entry.key.toLowerCase());
      }
    }
  }

  final interfaces = interfaceDump?['interface'];
  if (interfaces is! List) return const [];

  final names = <String>[];
  final seen = <String>{};
  for (final item in interfaces) {
    if (item is! Map) continue;
    final name = item['interface']?.toString().trim() ?? '';
    if (name.isEmpty || name == 'loopback' || name == 'lo') continue;

    final ifaceDevice = (item['device'] ?? '').toString().trim().toLowerCase();
    final l3Device = (item['l3_device'] ?? '').toString().trim().toLowerCase();

    if (related.contains(ifaceDevice) || related.contains(l3Device)) {
      if (seen.add(name)) names.add(name);
    }
  }

  names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return names;
}

int _statBytes(dynamic deviceInfo, String key) {
  if (deviceInfo is! Map) return 0;
  final stats = deviceInfo['stats'];
  if (stats is Map) {
    return _asInt(stats[key]) ?? 0;
  }
  return _asInt(deviceInfo[key]) ?? 0;
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value.toString());
}
