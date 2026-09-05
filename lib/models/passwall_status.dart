/// Runtime flags from Passwall LuCI CGI `index_status`.
///
/// Official status.htm polls this every 5s and maps:
/// - `tcp_status` / `udp_status` / `dns_mode_status` → RUNNING / NOT RUNNING
class PasswallIndexStatus {
  final bool tcpRunning;
  final bool udpRunning;
  final bool dnsRunning;

  const PasswallIndexStatus({
    required this.tcpRunning,
    required this.udpRunning,
    required this.dnsRunning,
  });

  factory PasswallIndexStatus.fromJson(Map<String, dynamic> json) {
    return PasswallIndexStatus(
      tcpRunning: _truthy(json['tcp_status']),
      udpRunning: _truthy(json['udp_status']),
      dnsRunning: _truthy(json['dns_mode_status']),
    );
  }

  /// LuCI treats missing/false the same as NOT RUNNING.
  static bool _truthy(dynamic value) {
    if (value == true || value == 1 || value == '1') return true;
    if (value is String) {
      final t = value.trim().toLowerCase();
      return t == 'true' || t == 'yes' || t == 'on';
    }
    return false;
  }
}
