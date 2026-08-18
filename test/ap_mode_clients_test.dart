import 'package:flutter_test/flutter_test.dart';
import 'package:luci_mobile/models/client.dart';

/// Wi-Fi online clients: assoclist membership, enriched by DHCP then host hints.

void main() {
  group('Client.fromWirelessStation', () {
    test('creates a client from just a MAC address', () {
      final client = Client.fromWirelessStation('AA:BB:CC:DD:EE:FF');

      expect(client.macAddress, 'AA:BB:CC:DD:EE:FF');
      expect(client.connectionType, ConnectionType.wireless);
      expect(client.ipAddress, 'N/A');
      expect(client.hostname, 'Unknown');
    });

    test('handles lowercase MAC address', () {
      final client = Client.fromWirelessStation('aa:bb:cc:dd:ee:ff');

      expect(client.macAddress, 'aa:bb:cc:dd:ee:ff');
      expect(client.connectionType, ConnectionType.wireless);
    });

    test('has no lease time or active time', () {
      final client = Client.fromWirelessStation('AA:BB:CC:DD:EE:FF');

      expect(client.leaseTime, isNull);
      expect(client.activeTime, isNull);
      expect(client.expiresAt, isNull);
    });
  });

  group('Wi-Fi online client list', () {
    test('wireless MACs not in DHCP produce fallback clients', () {
      final dhcpLeases = <Map<String, dynamic>>[];
      final wirelessMacs = {'AA:BB:CC:11:22:33', 'AA:BB:CC:44:55:66'};

      final clients = _buildWifiOnlineClientList(
        dhcpLeases: dhcpLeases,
        wirelessMacs: wirelessMacs,
      );

      expect(clients, hasLength(2));
      expect(clients.every((c) => c.connectionType == ConnectionType.wireless), isTrue);
      expect(
        clients.map((c) => c.macAddress.toUpperCase()).toSet(),
        wirelessMacs,
      );
    });

    test('wireless MACs with DHCP lease use lease details', () {
      final dhcpLeases = <Map<String, dynamic>>[
        {
          'macaddr': 'aa:bb:cc:11:22:33',
          'ipaddr': '192.168.1.100',
          'hostname': 'iPhone-John',
          'expires': 3600,
        },
      ];
      final wirelessMacs = {'AA:BB:CC:11:22:33'};

      final clients = _buildWifiOnlineClientList(
        dhcpLeases: dhcpLeases,
        wirelessMacs: wirelessMacs,
      );

      expect(clients, hasLength(1));
      expect(clients.first.hostname, 'iPhone-John');
      expect(clients.first.ipAddress, '192.168.1.100');
      expect(clients.first.connectionType, ConnectionType.wireless);
    });

    test('DHCP-only wired clients are excluded', () {
      final dhcpLeases = <Map<String, dynamic>>[
        {
          'macaddr': 'aa:bb:cc:11:22:33',
          'ipaddr': '192.168.1.100',
          'hostname': 'iPhone-John',
        },
        {
          'macaddr': 'dd:ee:ff:11:22:33',
          'ipaddr': '192.168.1.200',
          'hostname': 'Desktop-PC',
        },
      ];
      final wirelessMacs = {'AA:BB:CC:11:22:33'};

      final clients = _buildWifiOnlineClientList(
        dhcpLeases: dhcpLeases,
        wirelessMacs: wirelessMacs,
      );

      expect(clients, hasLength(1));
      expect(clients.first.hostname, 'iPhone-John');
    });

    test('static IP wireless clients use host hints when no DHCP lease', () {
      final wirelessMacs = {'AA:BB:CC:99:88:77'};
      final hostHints = {
        'AA:BB:CC:99:88:77': {
          'name': 'Static-Phone',
          'ipaddrs': ['192.168.1.50'],
          'ip6addrs': ['fe80::1'],
        },
      };

      final clients = _buildWifiOnlineClientList(
        dhcpLeases: const [],
        wirelessMacs: wirelessMacs,
        hostHintsByMac: hostHints,
      );

      expect(clients, hasLength(1));
      expect(clients.first.hostname, 'Static-Phone');
      expect(clients.first.ipAddress, '192.168.1.50');
      expect(clients.first.ipv6Addresses, ['fe80::1']);
    });

    test('empty wireless returns no clients even if DHCP has leases', () {
      final dhcpLeases = <Map<String, dynamic>>[
        {
          'macaddr': 'dd:ee:ff:11:22:33',
          'ipaddr': '192.168.1.200',
          'hostname': 'Desktop-PC',
        },
      ];

      final clients = _buildWifiOnlineClientList(
        dhcpLeases: dhcpLeases,
        wirelessMacs: {},
      );

      expect(clients, isEmpty);
    });
  });
}

List<Client> _buildWifiOnlineClientList({
  required List<Map<String, dynamic>> dhcpLeases,
  required Set<String> wirelessMacs,
  Map<String, Map<String, dynamic>> hostHintsByMac = const {},
}) {
  final wifiByMac = <String, String>{};
  for (final mac in wirelessMacs) {
    final normalized = mac.toUpperCase().replaceAll('-', ':');
    wifiByMac[normalized] = 'TestSSID';
  }

  final leaseByMac = <String, Map<String, dynamic>>{};
  for (final lease in dhcpLeases) {
    final mac = (lease['macaddr']?.toString() ?? '').toUpperCase().replaceAll('-', ':');
    if (mac.isNotEmpty) {
      leaseByMac[mac] = lease;
    }
  }

  final clients = <Client>[];
  for (final entry in wifiByMac.entries) {
    final mac = entry.key;
    final accessPoint = entry.value;
    final lease = leaseByMac[mac];
    final hint = hostHintsByMac[mac];

    Client client;
    if (lease != null) {
      client = Client.fromLease(lease).copyWith(
        connectionType: ConnectionType.wireless,
        accessPoint: accessPoint,
      );
    } else {
      client = Client.fromWirelessStation(mac, accessPoint: accessPoint);
      if (hint != null) {
        final ip = (hint['ipaddrs'] is List && (hint['ipaddrs'] as List).isNotEmpty)
            ? hint['ipaddrs'][0].toString()
            : null;
        final name = hint['name']?.toString().trim();
        final ipv6 = hint['ip6addrs'] is List
            ? (hint['ip6addrs'] as List).map((e) => e.toString()).toList()
            : null;
        client = client.copyWith(
          ipAddress: ip ?? client.ipAddress,
          hostname: (name != null && name.isNotEmpty) ? name : client.hostname,
          ipv6Addresses: ipv6 ?? client.ipv6Addresses,
        );
      }
    }

    clients.add(client);
  }

  clients.sort(
    (a, b) => a.hostname.toLowerCase().compareTo(b.hostname.toLowerCase()),
  );
  return clients;
}
