/// Builds the standard Wi-Fi QR payload used by camera apps / system scanners.
///
/// Format: `WIFI:T:<auth>;S:<ssid>;P:<password>;H:<hidden>;;`
class WifiQrPayload {
  final String ssid;
  final String authentication;
  final String password;
  final bool hidden;

  const WifiQrPayload({
    required this.ssid,
    required this.authentication,
    this.password = '',
    this.hidden = false,
  });

  /// Maps OpenWrt `encryption` values to WIFI QR auth types.
  static String authenticationFromEncryption(String? encryption) {
    final value = (encryption ?? '').trim().toLowerCase();
    if (value.isEmpty ||
        value == 'none' ||
        value == 'open' ||
        value == 'owe') {
      return 'nopass';
    }
    if (value.contains('wep')) {
      return 'WEP';
    }
    // psk / psk2 / sae / mixed / etc. — phones expect "WPA" for WPA2/WPA3 PSK.
    return 'WPA';
  }

  factory WifiQrPayload.fromOpenWrt({
    required String ssid,
    String? encryption,
    String? key,
    bool hidden = false,
  }) {
    final auth = authenticationFromEncryption(encryption);
    return WifiQrPayload(
      ssid: ssid,
      authentication: auth,
      password: auth == 'nopass' ? '' : (key ?? ''),
      hidden: hidden,
    );
  }

  bool get isOpen => authentication == 'nopass';

  bool get canGenerate {
    final name = ssid.trim();
    if (name.isEmpty) return false;
    if (isOpen) return true;
    return password.isNotEmpty;
  }

  /// Escapes `\ ; , "` per the WIFI QR convention.
  static String escape(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll(';', r'\;')
        .replaceAll(',', r'\,')
        .replaceAll('"', r'\"');
  }

  String toWifiString() {
    final buffer = StringBuffer('WIFI:T:')
      ..write(authentication)
      ..write(';S:')
      ..write(escape(ssid));
    if (!isOpen) {
      buffer
        ..write(';P:')
        ..write(escape(password));
    }
    if (hidden) {
      buffer.write(';H:true');
    }
    buffer.write(';;');
    return buffer.toString();
  }
}
