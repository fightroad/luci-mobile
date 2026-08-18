import 'package:flutter_test/flutter_test.dart';
import 'package:luci_mobile/models/easytier_peer.dart';

void main() {
  test('parses easytier-cli peer table columns', () {
    const raw = '''
| ipv4 | hostname | cost | lat(ms) | loss | rx | tx | tunnel | NAT | version |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 10.126.126.3/24 | Redmi_AX6 | Local | * | * | * | * | * | * | 2.6.4 |
| 10.126.126.1/24 | YHEasytier | p2p | 3.76 | 0.0% | 31.39 MB | 1.86 GB | tcp | Port Restricted | 2.6.4 |
''';

    final result = EasyTierPeerParser.parsePeerList(raw);
    expect(result.error, isNull);
    expect(result.peers.length, 2);
    expect(result.peers.first.hostname, 'Redmi_AX6');
    expect(result.peers.first.isLocal, isTrue);
    expect(result.peers.last.hostname, 'YHEasytier');
    expect(result.peers.last.latency, '3.76');
    expect(result.peers.last.packetLoss, '0.0%');
    expect(result.peers.last.download, '31.39 MB');
    expect(result.peers.last.upload, '1.86 GB');
    expect(result.peers.last.protocol, 'tcp');
    expect(result.peers.last.route, 'p2p');
    expect(result.peers.last.natType, 'Port Restricted');
    expect(result.peers.first.latency, '*');
    expect(result.peers.first.protocol, '*');
  });

  test('returns error for non-table output', () {
    const raw = 'Error: Program not running! Please start the program and refresh';
    final result = EasyTierPeerParser.parsePeerList(raw);
    expect(result.peers, isEmpty);
    expect(result.error, raw);
  });
}
