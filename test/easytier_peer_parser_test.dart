import 'package:flutter_test/flutter_test.dart';
import 'package:luci_mobile/models/easytier_peer.dart';

void main() {
  test('parses standard peer markdown table', () {
    const raw = '''
| Virtual IP | Hostname | Route | Latency | Loss | Rx | Tx | Proto | NAT | Version |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 10.126.126.3/24 | Redmi_AX6 | Local | - | - | - | - | - | - | 2.6.4 |
| 10.126.126.1/24 | YHEasytier | P2P | 3.76 ms | 0.0% | 31.39 MB | 1.86 GB | tcp | Port Restricted | 2.6.4 |
''';

    final result = EasyTierPeerParser.parsePeerList(raw);
    expect(result.error, isNull);
    expect(result.peers.length, 2);
    expect(result.peers.first.hostname, 'Redmi_AX6');
    expect(result.peers.first.isLocal, isTrue);
    expect(result.peers.last.hostname, 'YHEasytier');
    expect(result.peers.last.latency, '3.76 ms');
    expect(result.peers.last.protocol, 'tcp');
  });

  test('returns error for non-table output', () {
    const raw = 'Error: Program not running! Please start the program and refresh';
    final result = EasyTierPeerParser.parsePeerList(raw);
    expect(result.peers, isEmpty);
    expect(result.error, raw);
  });
}
