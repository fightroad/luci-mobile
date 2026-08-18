class EasyTierPeer {
  final String ipv4;
  final String hostname;
  final String route;
  final String latency;
  final String packetLoss;
  final String download;
  final String upload;
  final String protocol;
  final String natType;
  final String version;

  const EasyTierPeer({
    this.ipv4 = '',
    this.hostname = '',
    this.route = '',
    this.latency = '',
    this.packetLoss = '',
    this.download = '',
    this.upload = '',
    this.protocol = '',
    this.natType = '',
    this.version = '',
  });

  bool get isLocal {
    final value = route.trim().toLowerCase();
    return value == 'local' ||
        value == '本机' ||
        value.contains('local machine');
  }

  factory EasyTierPeer.fromRow(Map<String, String> row) {
    String pick(List<String> keys) {
      for (final key in keys) {
        final value = row[key];
        if (value != null && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      return '';
    }

    return EasyTierPeer(
      ipv4: pick(const ['ipv4', 'virtualip', 'ip']),
      hostname: pick(const ['hostname', 'host']),
      route: pick(const ['route', 'conn']),
      latency: pick(const ['latency', 'rtt']),
      packetLoss: pick(const ['packetloss', 'loss']),
      download: pick(const ['download', 'rx']),
      upload: pick(const ['upload', 'tx']),
      protocol: pick(const ['protocol', 'proto']),
      natType: pick(const ['nattype', 'nat']),
      version: pick(const ['version']),
    );
  }
}

class EasyTierPeerListParseResult {
  final List<EasyTierPeer> peers;
  final String? error;

  const EasyTierPeerListParseResult({
    this.peers = const [],
    this.error,
  });
}

class EasyTierPeerParser {
  static final RegExp _separatorLine = RegExp(r'^\|[\s\-:|]+\|$');

  static EasyTierPeerListParseResult parsePeerList(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      return const EasyTierPeerListParseResult();
    }
    if (!text.contains('|')) {
      return EasyTierPeerListParseResult(error: text);
    }

    final rows = <List<String>>[];
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || _separatorLine.hasMatch(trimmed)) continue;
      final cells = _parsePipeRow(trimmed);
      if (cells.isNotEmpty) {
        rows.add(cells);
      }
    }

    if (rows.isEmpty) {
      return const EasyTierPeerListParseResult();
    }

    final headers = rows.first.map(_normalizeHeader).toList();
    if (!_looksLikePeerHeaders(headers)) {
      return EasyTierPeerListParseResult(error: text);
    }

    final peers = <EasyTierPeer>[];
    for (var i = 1; i < rows.length; i++) {
      final row = _rowToMap(headers, rows[i]);
      if (row.values.every((value) => value.trim().isEmpty)) continue;
      peers.add(EasyTierPeer.fromRow(row));
    }
    return EasyTierPeerListParseResult(peers: peers);
  }

  static List<String> _parsePipeRow(String line) {
    if (!line.startsWith('|')) return const [];
    final matches = RegExp(r'\|([^|]*)').allMatches(line);
    final cells = matches.map((m) => m.group(1)?.trim() ?? '').toList();
    if (cells.isNotEmpty && cells.last.isEmpty) {
      cells.removeLast();
    }
    return cells;
  }

  static String _normalizeHeader(String header) {
    final ascii = header
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]+'), '')
        .trim();
    if (ascii.contains('ipv4') ||
        ascii.contains('virtualip') ||
        (ascii.contains('虚拟') && ascii.contains('ip'))) {
      return 'ipv4';
    }
    if (ascii.contains('hostname') || ascii.contains('主机名')) {
      return 'hostname';
    }
    if (ascii.contains('route') || ascii.contains('路由')) {
      return 'route';
    }
    if (ascii.contains('latency') ||
        ascii.contains('delay') ||
        ascii.contains('延迟') ||
        ascii.contains('rtt')) {
      return 'latency';
    }
    if (ascii.contains('loss') || ascii.contains('丢包')) {
      return 'packetloss';
    }
    if (ascii.contains('download') ||
        ascii.contains('rx') ||
        ascii.contains('下载')) {
      return 'download';
    }
    if (ascii.contains('upload') ||
        ascii.contains('tx') ||
        ascii.contains('上传')) {
      return 'upload';
    }
    if (ascii.contains('protocol') ||
        ascii.contains('proto') ||
        ascii.contains('协议')) {
      return 'protocol';
    }
    if (ascii.contains('nat')) {
      return 'nattype';
    }
    if (ascii.contains('version') || ascii.contains('版本')) {
      return 'version';
    }
    return ascii;
  }

  static bool _looksLikePeerHeaders(List<String> headers) {
    final joined = headers.join(' ');
    return joined.contains('ipv4') ||
        joined.contains('hostname') ||
        joined.contains('route');
  }

  static Map<String, String> _rowToMap(
    List<String> headers,
    List<String> cells,
  ) {
    final map = <String, String>{};
    for (var i = 0; i < headers.length; i++) {
      map[headers[i]] = i < cells.length ? cells[i] : '';
    }
    return map;
  }
}
