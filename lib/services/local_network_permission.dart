import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Triggers the iOS Local Network privacy prompt via Bonjour.
class LocalNetworkPermission {
  static const _channel = MethodChannel('luci_mobile/local_network');
  static bool _requested = false;

  static Future<void> ensureRequested() async {
    if (kIsWeb || !Platform.isIOS || _requested) return;
    _requested = true;
    try {
      await _channel.invokeMethod<void>('triggerPermission');
      await Future<void>.delayed(const Duration(milliseconds: 1200));
    } catch (_) {}
  }
}
