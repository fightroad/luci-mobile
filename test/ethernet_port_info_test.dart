import 'package:flutter_test/flutter_test.dart';
import 'package:luci_mobile/utils/ethernet_port_info.dart';

void main() {
  group('networksForPort', () {
    test('matches direct device and l3_device', () {
      final dump = {
        'interface': [
          {'interface': 'wan', 'device': 'eth1', 'l3_device': 'eth1'},
          {'interface': 'wan6', 'device': 'eth1', 'l3_device': 'eth1'},
          {'interface': 'lan', 'device': 'br-lan', 'l3_device': 'br-lan'},
        ],
      };

      expect(
        networksForPort(device: 'eth1', interfaceDump: dump),
        ['wan', 'wan6'],
      );
    });

    test('resolves bridge member via ports and master', () {
      final devices = {
        'lan1': {
          'name': 'lan1',
          'master': 'br-lan',
          'stats': {'rx_bytes': 100, 'tx_bytes': 200},
        },
        'br-lan': {
          'name': 'br-lan',
          'bridge': 1,
          'ports': ['lan1', 'lan2', 'wlan0'],
        },
      };
      final dump = {
        'interface': [
          {'interface': 'lan', 'device': 'br-lan', 'l3_device': 'br-lan'},
          {'interface': 'wan', 'device': 'eth1', 'l3_device': 'eth1'},
        ],
      };

      expect(
        networksForPort(
          device: 'lan1',
          networkDevices: devices,
          interfaceDump: dump,
        ),
        ['lan'],
      );
    });

    test('returns empty when port is not attached', () {
      final dump = {
        'interface': [
          {'interface': 'wan', 'device': 'eth1'},
        ],
      };
      expect(
        networksForPort(device: 'eth0', interfaceDump: dump),
        isEmpty,
      );
    });
  });

  group('EthernetPortDetails', () {
    test('reads cumulative traffic from stats', () {
      final details = EthernetPortDetails.resolve(
        device: 'wan',
        networkDevices: {
          'wan': {
            'stats': {
              'rx_bytes': 15132390932, // ~14.1 GiB
              'tx_bytes': 4831838208, // ~4.5 GiB
            },
          },
        },
        interfaceDump: {
          'interface': [
            {'interface': 'wan', 'device': 'wan'},
            {'interface': 'wan6', 'l3_device': 'wan'},
          ],
        },
      );

      expect(details.networks, ['wan', 'wan6']);
      expect(details.rxBytes, 15132390932);
      expect(details.txBytes, 4831838208);
      expect(EthernetPortDetails.formatTrafficBytes(details.txBytes), '4.5 GiB');
      expect(EthernetPortDetails.formatTrafficBytes(details.rxBytes), '14.1 GiB');
    });
  });
}
