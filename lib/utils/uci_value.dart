// Shared helpers for parsing LuCI UCI / luci-rpc wireless payloads.

String uciString(dynamic value, [String fallback = '']) {
  if (value is String) {
    return value.isEmpty ? fallback : value;
  }
  if (value is List) {
    return value.isNotEmpty ? value.first.toString() : fallback;
  }
  final text = value?.toString();
  if (text == null || text.isEmpty) return fallback;
  return text;
}

String normalizeInterfaceKey(String? value) {
  return (value ?? '').trim().toLowerCase();
}

// Stable scroll target for dashboard long-press → interfaces tab.
// Matches `wirelessInterfaceKey` when SSID is present.
String wirelessInterfaceScrollTarget({
  required String ssid,
  required String radioName,
  String? ifname,
  String? section,
}) {
  final ssidNorm = ssid.trim();
  final radioNorm = radioName.trim();
  if (ssidNorm.isNotEmpty && radioNorm.isNotEmpty) {
    return '${ssidNorm.toLowerCase()}__${radioNorm.toLowerCase()}';
  }
  if (ssidNorm.isNotEmpty) {
    return ssidNorm.toLowerCase();
  }
  final ifnameNorm = (ifname ?? '').trim();
  if (ifnameNorm.isNotEmpty) {
    return ifnameNorm.toLowerCase();
  }
  final sectionNorm = (section ?? '').trim();
  if (sectionNorm.isNotEmpty) {
    return sectionNorm.toLowerCase();
  }
  return radioNorm.toLowerCase();
}

bool wirelessInterfaceMatchesTarget({
  required String target,
  required String keyStr,
  required String ssid,
  required String deviceName,
  required String name,
  required String ifname,
  required String section,
}) {
  final normalizedTarget = normalizeInterfaceKey(target);
  if (normalizedTarget.isEmpty) return false;

  for (final candidate in [
    keyStr,
    ssid,
    deviceName,
    name,
    ifname,
    section,
  ]) {
    if (normalizeInterfaceKey(candidate) == normalizedTarget) {
      return true;
    }
  }
  return false;
}

String wirelessInterfaceKey({
  required String ssid,
  required String radioName,
  String? deviceName,
  String? name,
}) {
  final radio = radioName.trim();
  final ssidTrimmed = ssid.trim();

  if (ssidTrimmed.isEmpty) {
    final device = (deviceName ?? '').trim();
    if (device.isNotEmpty && device != radio) {
      return '${ssidTrimmed.toLowerCase()}__${device.toLowerCase()}';
    }
    final interfaceName = (name ?? '').trim();
    if (interfaceName.isNotEmpty && interfaceName != radio) {
      return '${ssidTrimmed.toLowerCase()}__${interfaceName.toLowerCase()}';
    }
    return '${ssidTrimmed.toLowerCase()}__${radio.toLowerCase()}';
  }

  return '${ssidTrimmed.toLowerCase()}__${radio.toLowerCase()}';
}

String resolveWirelessSsid(Map<dynamic, dynamic> iwinfo, Map<dynamic, dynamic> config) {
  final fromIwinfo = uciString(iwinfo['ssid']);
  if (fromIwinfo.isNotEmpty) return fromIwinfo;
  return uciString(config['ssid']);
}
