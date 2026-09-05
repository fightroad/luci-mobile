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
}
