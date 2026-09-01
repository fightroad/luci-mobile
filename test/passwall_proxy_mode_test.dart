import 'package:flutter_test/flutter_test.dart';
import 'package:luci_mobile/models/passwall_config.dart';

/// Matches LuCI proxy.htm switch_*_mode() UCI combinations.
void main() {
  group('PasswallProxyMode.fromGlobalUci', () {
    test('GFW list mode', () {
      expect(
        PasswallProxyMode.fromGlobalUci(
          useGfwList: true,
          chnList: '0',
          tcpProxyMode: 'disable',
          udpProxyMode: 'disable',
        ),
        PasswallProxyMode.gfwList,
      );
    });

    test('Not China list / chnroute mode', () {
      expect(
        PasswallProxyMode.fromGlobalUci(
          useGfwList: true,
          chnList: 'direct',
          tcpProxyMode: 'proxy',
          udpProxyMode: 'proxy',
        ),
        PasswallProxyMode.notChinaList,
      );
    });

    test('China list / returnhome mode', () {
      expect(
        PasswallProxyMode.fromGlobalUci(
          useGfwList: false,
          chnList: 'proxy',
          tcpProxyMode: 'disable',
          udpProxyMode: 'disable',
        ),
        PasswallProxyMode.returnHome,
      );
    });

    test('global proxy mode', () {
      expect(
        PasswallProxyMode.fromGlobalUci(
          useGfwList: false,
          chnList: '0',
          tcpProxyMode: 'proxy',
          udpProxyMode: 'proxy',
        ),
        PasswallProxyMode.global,
      );
    });
  });

  group('PasswallProxyMode.toGlobalUci', () {
    test('round-trips all LuCI presets', () {
      for (final mode in PasswallProxyMode.values) {
        final uci = mode.toGlobalUci();
        expect(
          PasswallProxyMode.fromGlobalUci(
            useGfwList: uci['use_gfw_list'] == '1',
            chnList: uci['chn_list']!,
            tcpProxyMode: uci['tcp_proxy_mode']!,
            udpProxyMode: uci['udp_proxy_mode']!,
          ),
          mode,
        );
      }
    });
  });
}
