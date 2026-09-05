import 'package:flutter_test/flutter_test.dart';
import 'package:luci_mobile/models/zerotier_config.dart';

void main() {
  group('ZerotierConfig.fromUciValues', () {
    test('parses modern global + network sections', () {
      final config = ZerotierConfig.fromUciValues({
        'global': {
          '.type': 'zerotier',
          '.name': 'global',
          'enabled': '1',
          'port': '9993',
        },
        'earth': {
          '.type': 'network',
          'id': '8056c2e21c000001',
          'enabled': '1',
        },
        'office': {
          '.type': 'network',
          'id': 'a09bfccf1c000001',
          'enabled': '0',
        },
      });

      expect(config.globalSection, 'global');
      expect(config.enabled, isTrue);
      expect(config.port, '9993');
      expect(config.isLegacyFormat, isFalse);
      expect(config.networks, hasLength(2));
      expect(config.networks.first.id, '8056c2e21c000001');
      expect(config.networks.first.enabled, isTrue);
      expect(config.networks.last.enabled, isFalse);
    });

    test('parses legacy join list sections', () {
      final config = ZerotierConfig.fromUciValues({
        'openwrt_network': {
          '.type': 'zerotier',
          'enabled': '1',
          'join': ['8ad5123ed69d6f69'],
        },
      });

      expect(config.enabled, isTrue);
      expect(config.networks, hasLength(1));
      expect(config.networks.single.id, '8ad5123ed69d6f69');
      expect(config.isLegacyFormat, isTrue);
    });

    test('withNetworkEnabled updates draft only', () {
      final base = ZerotierConfig.fromUciValues({
        'global': {'.type': 'zerotier', 'enabled': '1'},
        'n1': {'.type': 'network', 'id': 'abc', 'enabled': '1'},
      });
      final draft = base.withNetworkEnabled('n1', false);
      expect(draft.networks.single.enabled, isFalse);
      expect(base.networks.single.enabled, isTrue);
    });
  });

  group('ZerotierInterface', () {
    test('fromNetworkDevices filters zt* and maps fields', () {
      final list = ZerotierInterface.fromNetworkDevices({
        'br-lan': {
          'mac': 'aa:bb:cc:dd:ee:ff',
          'ipaddrs': ['192.168.1.1'],
        },
        'ztabcdef123': {
          'mac': '11:22:33:44:55:66',
          'mtu': 2800,
          'ipaddrs': ['10.147.20.5/24'],
          'ip6addrs': ['fd00::1/64'],
          'stats': {'rx_bytes': 2048, 'tx_bytes': 1024},
        },
      });

      expect(list, hasLength(1));
      final iface = list.single;
      expect(iface.name, 'ztabcdef123');
      expect(iface.mac, '11:22:33:44:55:66');
      expect(iface.ipv4, '10.147.20.5');
      expect(iface.ipv6, 'fd00::1');
      expect(iface.mtu, '2800');
      expect(iface.rxBytes, 2048);
      expect(iface.txBytes, 1024);
    });

    test('fromNetworkDevices extracts address from map entries', () {
      final list = ZerotierInterface.fromNetworkDevices({
        'ztw4lpwzq7': {
          'mac': 'DE:25:6D:13:43:BB',
          'mtu': 2800,
          'ipaddrs': [
            {
              'address': '10.11.12.1',
              'netmask': '255.255.255.0',
              'broadcast': '10.11.12.255',
            },
          ],
          'ip6addrs': [
            {
              'address': 'fe80::dc25:6dff:fe13:43bb',
              'netmask': 'ffff:ffff:ffff:ffff::',
            },
          ],
          'stats': {'rx_bytes': 100, 'tx_bytes': 50},
        },
      });

      expect(list.single.ipv4, '10.11.12.1');
      expect(list.single.ipv6, 'fe80::dc25:6dff:fe13:43bb');
    });
  });
}
