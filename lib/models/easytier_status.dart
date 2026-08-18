/// Runtime status from luci-app-easytier `api_status` endpoint.
class EasyTierStatus {
  final bool coreRunning;
  final bool coreEnabled;
  final String cpu;
  final String memory;
  final String uptime;
  final String version;

  const EasyTierStatus({
    required this.coreRunning,
    required this.coreEnabled,
    required this.cpu,
    required this.memory,
    required this.uptime,
    required this.version,
  });

  factory EasyTierStatus.fromJson(Map<String, dynamic> json) {
    bool readBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      final text = value?.toString().trim().toLowerCase();
      return text == '1' || text == 'true';
    }

    String readText(dynamic value) => value?.toString().trim() ?? '';

    return EasyTierStatus(
      coreRunning: readBool(json['crunning']),
      coreEnabled: readBool(json['cenabled']),
      cpu: readText(json['etcpu']),
      memory: readText(json['etram']),
      uptime: readText(json['etsta']),
      version: readText(json['ettag']),
    );
  }
}
