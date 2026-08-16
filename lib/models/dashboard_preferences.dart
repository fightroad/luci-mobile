class DashboardPreferences {
  static const Object _unset = Object();

  final Set<String> enabledWirelessInterfaces;
  final String? primaryThroughputInterface;
  final bool showAllThroughput;

  DashboardPreferences({
    Set<String>? enabledWirelessInterfaces,
    this.primaryThroughputInterface,
    this.showAllThroughput = true,
  }) : enabledWirelessInterfaces = enabledWirelessInterfaces ?? {};

  DashboardPreferences copyWith({
    Set<String>? enabledWirelessInterfaces,
    Object? primaryThroughputInterface = _unset,
    bool? showAllThroughput,
  }) {
    return DashboardPreferences(
      enabledWirelessInterfaces:
          enabledWirelessInterfaces ?? this.enabledWirelessInterfaces,
      primaryThroughputInterface: identical(primaryThroughputInterface, _unset)
          ? this.primaryThroughputInterface
          : primaryThroughputInterface as String?,
      showAllThroughput: showAllThroughput ?? this.showAllThroughput,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabledWirelessInterfaces': enabledWirelessInterfaces.toList(),
    'primaryThroughputInterface': primaryThroughputInterface,
    'showAllThroughput': showAllThroughput,
  };

  factory DashboardPreferences.fromJson(Map<String, dynamic> json) {
    return DashboardPreferences(
      enabledWirelessInterfaces: Set<String>.from(
        json['enabledWirelessInterfaces'] ?? [],
      ),
      primaryThroughputInterface: json['primaryThroughputInterface'],
      showAllThroughput: json['showAllThroughput'] ?? true,
    );
  }

  static DashboardPreferences get defaultPreferences => DashboardPreferences();
}
