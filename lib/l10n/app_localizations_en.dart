// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'LuCI Mobile';

  @override
  String get appSubtitle => 'Connect to your OpenWrt router';

  @override
  String get appTagline => 'Fast. Secure. Open Source.';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get clients => 'Clients';

  @override
  String get interfaces => 'Interfaces';

  @override
  String get more => 'More';

  @override
  String get settings => 'Settings';

  @override
  String get loginConnect => 'Connect';

  @override
  String get routerAddress => 'Router Address';

  @override
  String get routerAddressHelper =>
      'e.g. 192.168.1.1, router.local:8080, https://192.168.1.1';

  @override
  String get username => 'Username';

  @override
  String get usernameHelper => 'Default is usually root';

  @override
  String get password => 'Password';

  @override
  String get passwordHelper => 'Your router password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get pleaseEnterRouterAddress => 'Please enter the router address';

  @override
  String get pleaseEnterUsername => 'Please enter the username';

  @override
  String get invalidAddressFormat => 'Invalid address format';

  @override
  String get needHelp => 'Need help?';

  @override
  String version(String version) {
    return 'Version $version';
  }

  @override
  String get activateReviewerMode => 'Activate Reviewer Mode?';

  @override
  String get reviewerModeDescription =>
      'This will enable reviewer mode which bypasses authentication and provides mock data for app demonstration purposes.';

  @override
  String get reviewerModeConfirm => 'To confirm, type \"REVIEWER\" below:';

  @override
  String get typeReviewer => 'Type REVIEWER';

  @override
  String get cancel => 'Cancel';

  @override
  String get activate => 'Activate';

  @override
  String get holdToActivateReviewerMode => 'Hold to activate reviewer mode...';

  @override
  String get couldNotOpenGitHubIssues => 'Could not open GitHub issues';

  @override
  String get selectRouter => 'Select Router';

  @override
  String get connectionFailed => 'Connection Failed';

  @override
  String get connectionFailedMessage =>
      'Unable to connect to the router. Please check your network connection and router settings.';

  @override
  String get retryConnection => 'Retry Connection';

  @override
  String get noDataAvailable => 'No Data Available';

  @override
  String get noDataAvailableMessage =>
      'Unable to fetch dashboard data. Pull down to refresh or tap the button below.';

  @override
  String get fetchData => 'Fetch Data';

  @override
  String get switchingRouter => 'Switching router...';

  @override
  String get collectingThroughputData => 'Collecting throughput data...';

  @override
  String get throughput => 'Throughput';

  @override
  String throughputLabel(String interface) {
    return 'Throughput - $interface';
  }

  @override
  String get model => 'Model';

  @override
  String get versionLabel => 'Version';

  @override
  String get cpuLoad => 'CPU Load';

  @override
  String get memory => 'Memory';

  @override
  String get uptime => 'Uptime';

  @override
  String get failedToLoadClients => 'Failed to Load Clients';

  @override
  String get failedToLoadClientsMessage =>
      'Could not connect to the router. Please check your network connection and the router\'s IP address.';

  @override
  String get retry => 'Retry';

  @override
  String get searchClients => 'Search by name, IP, MAC, vendor...';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get all => 'All';

  @override
  String get selected => 'Selected';

  @override
  String get noActiveClientsFound => 'No Active Clients Found';

  @override
  String get noActiveClientsMessage =>
      'No clients are currently connected to the router. Pull down to refresh the list.';

  @override
  String get noMatchingClients => 'No Matching Clients';

  @override
  String get noMatchingClientsMessage =>
      'No clients match your search criteria. Try a different search term.';

  @override
  String get wiFi => 'Wi-Fi';

  @override
  String get wired => 'Wired';

  @override
  String get unknown => 'Unknown';

  @override
  String get ipAddress => 'IP Address';

  @override
  String get ipv6Address => 'IPv6 Address';

  @override
  String get macAddress => 'MAC Address';

  @override
  String get vendor => 'Vendor';

  @override
  String get dnsName => 'DNS Name';

  @override
  String get leaseTimeRemaining => 'Lease Time Remaining';

  @override
  String get expired => 'Expired';

  @override
  String copiedToClipboard(String label) {
    return '$label copied to clipboard';
  }

  @override
  String get failedToLoadInterfaces => 'Failed to Load Interfaces';

  @override
  String get failedToLoadInterfacesMessage =>
      'Could not connect to the router. Please check your network connection and router settings.';

  @override
  String get noInterfaceData => 'No Interface Data';

  @override
  String get noInterfaceDataMessage =>
      'Unable to fetch interface information. Pull down to refresh or tap the button below.';

  @override
  String get wiredSection => 'Wired';

  @override
  String get wirelessSection => 'Wireless';

  @override
  String get device => 'Device';

  @override
  String get mode => 'Mode';

  @override
  String get channel => 'Channel';

  @override
  String get signal => 'Signal';

  @override
  String get network => 'Network';

  @override
  String get gateway => 'Gateway';

  @override
  String get dns => 'DNS';

  @override
  String get lastHandshake => 'Last Handshake';

  @override
  String get endpoint => 'Endpoint';

  @override
  String get never => 'Never';

  @override
  String get received => 'Received';

  @override
  String get transmitted => 'Transmitted';

  @override
  String get up => 'UP';

  @override
  String get down => 'DOWN';

  @override
  String get off => 'OFF';

  @override
  String get interfaceIsUp => 'Interface is up';

  @override
  String get interfaceIsDown => 'Interface is down';

  @override
  String get expandDetails => 'Expand details';

  @override
  String get collapseDetails => 'Collapse details';

  @override
  String get theme => 'Theme';

  @override
  String get systemDefault => 'System Default';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get dashboardSettings => 'Dashboard';

  @override
  String get customizeDashboard => 'Customize Dashboard';

  @override
  String get customizeDashboardSubtitle =>
      'Configure interface visibility and throughput monitoring';

  @override
  String get reviewerMode => 'Reviewer Mode';

  @override
  String get reviewerModeActive => 'Reviewer Mode Active';

  @override
  String get reviewerModeActiveSubtitle =>
      'Mock data is being used for demonstration';

  @override
  String get exitReviewerMode => 'Exit Reviewer Mode';

  @override
  String get exitReviewerModeTitle => 'Exit Reviewer Mode?';

  @override
  String get exitReviewerModeMessage =>
      'This will disable reviewer mode and return to normal authentication. You will need to log in with real router credentials.';

  @override
  String get exit => 'Exit';

  @override
  String get deviceManagement => 'Device Management';

  @override
  String get rebootRouter => 'Reboot Router';

  @override
  String get rebootRouterSubtitle => 'Perform a system restart';

  @override
  String get rebootRouterTitle => 'Reboot Router?';

  @override
  String get rebootRouterMessage =>
      'Are you sure you want to reboot the router?';

  @override
  String get reboot => 'Reboot';

  @override
  String get rebooting => 'Rebooting… Connection will be interrupted.';

  @override
  String get rebootCommandSent => 'Reboot command sent successfully.';

  @override
  String get rebootCommandFailed => 'Failed to send reboot command.';

  @override
  String get application => 'Application';

  @override
  String get manageRouters => 'Manage Routers';

  @override
  String get manageRoutersSubtitle => 'Edit or remove saved routers';

  @override
  String get settingsSubtitle => 'Configure app preferences';

  @override
  String get about => 'About';

  @override
  String get aboutSubtitle => 'App version and information';

  @override
  String get logout => 'Logout';

  @override
  String get logoutSubtitle => 'End your session and sign out';

  @override
  String get logoutTitle => 'Logout?';

  @override
  String get logoutMessage => 'Are you sure you want to logout?';

  @override
  String get aboutDialogTitle => 'LuCI Mobile';

  @override
  String aboutDialogVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutDialogDescription => 'A mobile client for OpenWrt routers.';

  @override
  String get aboutDialogOpenSource => 'Open source and free to use.';

  @override
  String get githubRepository => 'GitHub Repository';

  @override
  String get couldNotOpenRepository => 'Could not open repository';

  @override
  String get close => 'Close';

  @override
  String get routerBackOnline => 'Router is back online, reconnecting…';

  @override
  String get openWrtRouterControl => 'OpenWrt Router Control';

  @override
  String get routers => 'Routers';

  @override
  String get noRoutersAdded => 'No routers added yet.';

  @override
  String get removeRouter => 'Remove Router';

  @override
  String removeRouterMessage(String routerLabel) {
    return 'Are you sure you want to remove $routerLabel?';
  }

  @override
  String get remove => 'Remove';

  @override
  String get addRouter => 'Add Router';

  @override
  String get required => 'Required';

  @override
  String get routerAlreadyExists => 'Router already exists.';

  @override
  String get connecting => 'Connecting...';

  @override
  String get add => 'Add';

  @override
  String get failedToConnectInvalidCredentials =>
      'Failed to connect: Invalid credentials or host unreachable.';

  @override
  String failedToConnect(String error) {
    return 'Failed to connect: $error';
  }

  @override
  String get active => 'Active';

  @override
  String get removeTooltip => 'Remove';

  @override
  String get dashboardSettingsTitle => 'Dashboard Settings';

  @override
  String get noRoutersAddedForSettings => 'No Routers Added';

  @override
  String get noRoutersAddedForSettingsMessage =>
      'Add a router to customize its dashboard settings.';

  @override
  String get throughputMonitoring => 'Throughput Monitoring';

  @override
  String get throughputMonitoringSubtitle =>
      'Configure which interfaces to monitor';

  @override
  String get showAllInterfaces => 'Show All Interfaces';

  @override
  String get wirelessNetworks => 'Wireless Networks';

  @override
  String get wirelessNetworksSubtitle =>
      'Choose which wireless networks to display';

  @override
  String get showAllNetworks => 'Show All Networks';

  @override
  String get networkInterfaces => 'Network Interfaces';

  @override
  String get networkInterfacesSubtitle =>
      'Choose which wired/VPN interfaces to display';

  @override
  String get wideAreaNetwork => 'Wide Area Network';

  @override
  String get localAreaNetwork => 'Local Area Network';

  @override
  String get wireGuardVpn => 'WireGuard VPN';

  @override
  String get openVpn => 'OpenVPN';

  @override
  String get pppoeConnection => 'PPPoE Connection';

  @override
  String get unableToLoadDashboardData =>
      'Unable to load dashboard data. Please check your connection.';

  @override
  String failedToLoadSettings(String error) {
    return 'Failed to load settings: $error';
  }

  @override
  String get clientIsOnline => 'Client is online';

  @override
  String get unknownConnectionType => 'Unknown connection type';

  @override
  String get lastKnownHostname => 'Last known hostname (may be out of date)';

  @override
  String get loading => 'Loading...';

  @override
  String get gatewayIp => 'Gateway IP';

  @override
  String get dnsServers => 'DNS Servers';

  @override
  String get copy => 'Copy';

  @override
  String refreshFailed(String error) {
    return 'Refresh failed: $error';
  }

  @override
  String get pullDownToRefresh => 'Pull down to refresh';

  @override
  String get noItemsToDisplay => 'No items to display';

  @override
  String get enterRouterAddressTooltip =>
      'Enter the IP address, hostname, or full URL of your router';

  @override
  String get enterRouterUsernameTooltip => 'Enter your router username';

  @override
  String get enterRouterPasswordTooltip => 'Enter your router password';

  @override
  String get openGitHubIssuesTooltip => 'Open GitHub issues for support';

  @override
  String get routerIcon => 'Router icon';

  @override
  String get clientIcon => 'Client icon';

  @override
  String get interfaceIcon => 'Interface icon';

  @override
  String get unnamed => 'Unnamed';

  @override
  String get disabled => 'Disabled';

  @override
  String get channelShort => 'Ch.';

  @override
  String get ssid => 'SSID';

  @override
  String get certificateWarning => 'Certificate Warning';

  @override
  String certificateWarningMessage(String host) {
    return 'The certificate for $host is not trusted by your device. This could indicate a security risk.';
  }

  @override
  String certificateWarningMessageWithPort(String host, String port) {
    return 'The certificate for $host:$port is not trusted by your device. This could indicate a security risk.';
  }

  @override
  String get certificateWarningInfo =>
      'Only proceed if you trust this router and understand the security implications.';

  @override
  String get certificateDetails => 'Certificate Details:';

  @override
  String get subject => 'Subject';

  @override
  String get issuer => 'Issuer';

  @override
  String get validFrom => 'Valid From';

  @override
  String get validUntil => 'Valid Until';

  @override
  String get acceptRisk => 'Accept Risk';

  @override
  String get mobile => 'Mobile';

  @override
  String get inactive => 'inactive';

  @override
  String get back => 'Back';
}
