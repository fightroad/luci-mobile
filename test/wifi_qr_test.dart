import 'package:flutter_test/flutter_test.dart';
import 'package:luci_mobile/utils/wifi_qr.dart';

void main() {
  group('WifiQrPayload', () {
    test('maps OpenWrt encryption to WIFI auth types', () {
      expect(WifiQrPayload.authenticationFromEncryption(null), 'nopass');
      expect(WifiQrPayload.authenticationFromEncryption('none'), 'nopass');
      expect(WifiQrPayload.authenticationFromEncryption('psk2'), 'WPA');
      expect(WifiQrPayload.authenticationFromEncryption('sae-mixed'), 'WPA');
      expect(WifiQrPayload.authenticationFromEncryption('wep'), 'WEP');
    });

    test('builds standard WIFI payload and escapes special characters', () {
      final payload = WifiQrPayload.fromOpenWrt(
        ssid: r'My;Net\Work',
        encryption: 'psk2',
        key: r'p@ss;word',
      );

      expect(payload.canGenerate, isTrue);
      expect(
        payload.toWifiString(),
        r'WIFI:T:WPA;S:My\;Net\\Work;P:p@ss\;word;;',
      );
    });

    test('open networks omit password field', () {
      final payload = WifiQrPayload.fromOpenWrt(
        ssid: 'Guest',
        encryption: 'none',
        key: 'ignored',
      );

      expect(payload.isOpen, isTrue);
      expect(payload.toWifiString(), 'WIFI:T:nopass;S:Guest;;');
    });

    test('secured networks without key cannot generate', () {
      final payload = WifiQrPayload.fromOpenWrt(
        ssid: 'Home',
        encryption: 'psk2',
        key: '',
      );

      expect(payload.canGenerate, isFalse);
    });
  });
}
