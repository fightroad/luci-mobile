import 'package:flutter_test/flutter_test.dart';
import 'package:luci_mobile/models/passwall_status.dart';

void main() {
  group('PasswallIndexStatus.fromJson', () {
    test('maps official index_status fields', () {
      final status = PasswallIndexStatus.fromJson({
        'tcp_status': true,
        'udp_status': false,
        'dns_mode_status': true,
        'haproxy_status': '0',
      });
      expect(status.tcpRunning, isTrue);
      expect(status.udpRunning, isFalse);
      expect(status.dnsRunning, isTrue);
    });

    test('missing tcp/udp keys mean not running', () {
      final status = PasswallIndexStatus.fromJson({
        'dns_mode_status': true,
      });
      expect(status.tcpRunning, isFalse);
      expect(status.udpRunning, isFalse);
      expect(status.dnsRunning, isTrue);
    });
  });
}
