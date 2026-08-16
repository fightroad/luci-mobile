import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'LuCI Mobile'**
  String get appTitle;

  /// Application subtitle
  ///
  /// In en, this message translates to:
  /// **'Connect to your OpenWrt router'**
  String get appSubtitle;

  /// Application tagline
  ///
  /// In en, this message translates to:
  /// **'Fast. Secure. Open Source.'**
  String get appTagline;

  /// Dashboard tab label
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// Clients tab label
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get clients;

  /// Interfaces tab label
  ///
  /// In en, this message translates to:
  /// **'Interfaces'**
  String get interfaces;

  /// More tab label
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Login button text
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get loginConnect;

  /// Router address input label
  ///
  /// In en, this message translates to:
  /// **'Router Address'**
  String get routerAddress;

  /// Router address helper text
  ///
  /// In en, this message translates to:
  /// **'e.g. 192.168.1.1, router.local:8080, https://192.168.1.1'**
  String get routerAddressHelper;

  /// Username input label
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// Username helper text
  ///
  /// In en, this message translates to:
  /// **'Default is usually root'**
  String get usernameHelper;

  /// Password input label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Password helper text
  ///
  /// In en, this message translates to:
  /// **'Your router password'**
  String get passwordHelper;

  /// Show password tooltip
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// Hide password tooltip
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// Router address validation error
  ///
  /// In en, this message translates to:
  /// **'Please enter the router address'**
  String get pleaseEnterRouterAddress;

  /// Username validation error
  ///
  /// In en, this message translates to:
  /// **'Please enter the username'**
  String get pleaseEnterUsername;

  /// Invalid address format error
  ///
  /// In en, this message translates to:
  /// **'Invalid address format'**
  String get invalidAddressFormat;

  /// Need help link text
  ///
  /// In en, this message translates to:
  /// **'Need help?'**
  String get needHelp;

  /// Version display text
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String version(String version);

  /// Reviewer mode activation dialog title
  ///
  /// In en, this message translates to:
  /// **'Activate Reviewer Mode?'**
  String get activateReviewerMode;

  /// Reviewer mode description
  ///
  /// In en, this message translates to:
  /// **'This will enable reviewer mode which bypasses authentication and provides mock data for app demonstration purposes.'**
  String get reviewerModeDescription;

  /// Reviewer mode confirmation instruction
  ///
  /// In en, this message translates to:
  /// **'To confirm, type \"REVIEWER\" below:'**
  String get reviewerModeConfirm;

  /// Reviewer mode confirmation input hint
  ///
  /// In en, this message translates to:
  /// **'Type REVIEWER'**
  String get typeReviewer;

  /// Cancel button text
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Activate button text
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get activate;

  /// Reviewer mode activation instruction
  ///
  /// In en, this message translates to:
  /// **'Hold to activate reviewer mode...'**
  String get holdToActivateReviewerMode;

  /// Error message when GitHub issues cannot be opened
  ///
  /// In en, this message translates to:
  /// **'Could not open GitHub issues'**
  String get couldNotOpenGitHubIssues;

  /// Select router dialog title
  ///
  /// In en, this message translates to:
  /// **'Select Router'**
  String get selectRouter;

  /// Connection failed error title
  ///
  /// In en, this message translates to:
  /// **'Connection Failed'**
  String get connectionFailed;

  /// Connection failed error message
  ///
  /// In en, this message translates to:
  /// **'Unable to connect to the router. Please check your network connection and router settings.'**
  String get connectionFailedMessage;

  /// Retry connection button
  ///
  /// In en, this message translates to:
  /// **'Retry Connection'**
  String get retryConnection;

  /// No data available title
  ///
  /// In en, this message translates to:
  /// **'No Data Available'**
  String get noDataAvailable;

  /// No data available message
  ///
  /// In en, this message translates to:
  /// **'Unable to fetch dashboard data. Pull down to refresh or tap the button below.'**
  String get noDataAvailableMessage;

  /// Fetch data button
  ///
  /// In en, this message translates to:
  /// **'Fetch Data'**
  String get fetchData;

  /// Switching router message
  ///
  /// In en, this message translates to:
  /// **'Switching router...'**
  String get switchingRouter;

  /// Collecting throughput data message
  ///
  /// In en, this message translates to:
  /// **'Collecting throughput data...'**
  String get collectingThroughputData;

  /// Throughput label
  ///
  /// In en, this message translates to:
  /// **'Throughput'**
  String get throughput;

  /// Throughput label with interface
  ///
  /// In en, this message translates to:
  /// **'Throughput - {interface}'**
  String throughputLabel(String interface);

  /// Model label
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get model;

  /// Version label
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get versionLabel;

  /// CPU load label
  ///
  /// In en, this message translates to:
  /// **'CPU Load'**
  String get cpuLoad;

  /// Memory label
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get memory;

  /// Uptime label
  ///
  /// In en, this message translates to:
  /// **'Uptime'**
  String get uptime;

  /// Failed to load clients error title
  ///
  /// In en, this message translates to:
  /// **'Failed to Load Clients'**
  String get failedToLoadClients;

  /// Failed to load clients error message
  ///
  /// In en, this message translates to:
  /// **'Could not connect to the router. Please check your network connection and the router\'s IP address.'**
  String get failedToLoadClientsMessage;

  /// Retry button
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Client search hint
  ///
  /// In en, this message translates to:
  /// **'Search by name, IP, MAC, vendor...'**
  String get searchClients;

  /// Clear search button tooltip
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// All label
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// Selected label
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get selected;

  /// No active clients found title
  ///
  /// In en, this message translates to:
  /// **'No Active Clients Found'**
  String get noActiveClientsFound;

  /// No active clients message
  ///
  /// In en, this message translates to:
  /// **'No clients are currently connected to the router. Pull down to refresh the list.'**
  String get noActiveClientsMessage;

  /// No matching clients title
  ///
  /// In en, this message translates to:
  /// **'No Matching Clients'**
  String get noMatchingClients;

  /// No matching clients message
  ///
  /// In en, this message translates to:
  /// **'No clients match your search criteria. Try a different search term.'**
  String get noMatchingClientsMessage;

  /// Wi-Fi label
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi'**
  String get wiFi;

  /// Wired label
  ///
  /// In en, this message translates to:
  /// **'Wired'**
  String get wired;

  /// Unknown label
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// IP Address label
  ///
  /// In en, this message translates to:
  /// **'IP Address'**
  String get ipAddress;

  /// IPv6 Address label
  ///
  /// In en, this message translates to:
  /// **'IPv6 Address'**
  String get ipv6Address;

  /// MAC Address label
  ///
  /// In en, this message translates to:
  /// **'MAC Address'**
  String get macAddress;

  /// Vendor label
  ///
  /// In en, this message translates to:
  /// **'Vendor'**
  String get vendor;

  /// DNS Name label
  ///
  /// In en, this message translates to:
  /// **'DNS Name'**
  String get dnsName;

  /// Lease time remaining label
  ///
  /// In en, this message translates to:
  /// **'Lease Time Remaining'**
  String get leaseTimeRemaining;

  /// Expired label
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expired;

  /// Copied to clipboard message
  ///
  /// In en, this message translates to:
  /// **'{label} copied to clipboard'**
  String copiedToClipboard(String label);

  /// Failed to load interfaces error title
  ///
  /// In en, this message translates to:
  /// **'Failed to Load Interfaces'**
  String get failedToLoadInterfaces;

  /// Failed to load interfaces error message
  ///
  /// In en, this message translates to:
  /// **'Could not connect to the router. Please check your network connection and router settings.'**
  String get failedToLoadInterfacesMessage;

  /// No interface data title
  ///
  /// In en, this message translates to:
  /// **'No Interface Data'**
  String get noInterfaceData;

  /// No interface data message
  ///
  /// In en, this message translates to:
  /// **'Unable to fetch interface information. Pull down to refresh or tap the button below.'**
  String get noInterfaceDataMessage;

  /// Wired interfaces section header
  ///
  /// In en, this message translates to:
  /// **'Wired'**
  String get wiredSection;

  /// Wireless interfaces section header
  ///
  /// In en, this message translates to:
  /// **'Wireless'**
  String get wirelessSection;

  /// Device label
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get device;

  /// Mode label
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get mode;

  /// Channel label
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get channel;

  /// Signal label
  ///
  /// In en, this message translates to:
  /// **'Signal'**
  String get signal;

  /// Network label
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get network;

  /// Gateway label
  ///
  /// In en, this message translates to:
  /// **'Gateway'**
  String get gateway;

  /// DNS label
  ///
  /// In en, this message translates to:
  /// **'DNS'**
  String get dns;

  /// Last handshake label
  ///
  /// In en, this message translates to:
  /// **'Last Handshake'**
  String get lastHandshake;

  /// Endpoint label
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get endpoint;

  /// Never label
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get never;

  /// Received label
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get received;

  /// Transmitted label
  ///
  /// In en, this message translates to:
  /// **'Transmitted'**
  String get transmitted;

  /// UP status label
  ///
  /// In en, this message translates to:
  /// **'UP'**
  String get up;

  /// DOWN status label
  ///
  /// In en, this message translates to:
  /// **'DOWN'**
  String get down;

  /// OFF status label
  ///
  /// In en, this message translates to:
  /// **'OFF'**
  String get off;

  /// Interface is up tooltip
  ///
  /// In en, this message translates to:
  /// **'Interface is up'**
  String get interfaceIsUp;

  /// Interface is down tooltip
  ///
  /// In en, this message translates to:
  /// **'Interface is down'**
  String get interfaceIsDown;

  /// Expand details tooltip
  ///
  /// In en, this message translates to:
  /// **'Expand details'**
  String get expandDetails;

  /// Collapse details tooltip
  ///
  /// In en, this message translates to:
  /// **'Collapse details'**
  String get collapseDetails;

  /// Theme section title
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// System default theme option
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemDefault;

  /// Light theme option
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// Dark theme option
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// Dashboard settings section title
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardSettings;

  /// Customize dashboard option
  ///
  /// In en, this message translates to:
  /// **'Customize Dashboard'**
  String get customizeDashboard;

  /// Customize dashboard subtitle
  ///
  /// In en, this message translates to:
  /// **'Configure interface visibility and throughput monitoring'**
  String get customizeDashboardSubtitle;

  /// Reviewer mode section title
  ///
  /// In en, this message translates to:
  /// **'Reviewer Mode'**
  String get reviewerMode;

  /// Reviewer mode active label
  ///
  /// In en, this message translates to:
  /// **'Reviewer Mode Active'**
  String get reviewerModeActive;

  /// Reviewer mode active subtitle
  ///
  /// In en, this message translates to:
  /// **'Mock data is being used for demonstration'**
  String get reviewerModeActiveSubtitle;

  /// Exit reviewer mode button
  ///
  /// In en, this message translates to:
  /// **'Exit Reviewer Mode'**
  String get exitReviewerMode;

  /// Exit reviewer mode dialog title
  ///
  /// In en, this message translates to:
  /// **'Exit Reviewer Mode?'**
  String get exitReviewerModeTitle;

  /// Exit reviewer mode dialog message
  ///
  /// In en, this message translates to:
  /// **'This will disable reviewer mode and return to normal authentication. You will need to log in with real router credentials.'**
  String get exitReviewerModeMessage;

  /// Exit button
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// Device management section header
  ///
  /// In en, this message translates to:
  /// **'Device Management'**
  String get deviceManagement;

  /// Reboot router option
  ///
  /// In en, this message translates to:
  /// **'Reboot Router'**
  String get rebootRouter;

  /// Reboot router subtitle
  ///
  /// In en, this message translates to:
  /// **'Perform a system restart'**
  String get rebootRouterSubtitle;

  /// Reboot router dialog title
  ///
  /// In en, this message translates to:
  /// **'Reboot Router?'**
  String get rebootRouterTitle;

  /// Reboot router dialog message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reboot the router?'**
  String get rebootRouterMessage;

  /// Reboot button
  ///
  /// In en, this message translates to:
  /// **'Reboot'**
  String get reboot;

  /// Rebooting message
  ///
  /// In en, this message translates to:
  /// **'Rebooting… Connection will be interrupted.'**
  String get rebooting;

  /// Reboot command sent message
  ///
  /// In en, this message translates to:
  /// **'Reboot command sent successfully.'**
  String get rebootCommandSent;

  /// Reboot command failed message
  ///
  /// In en, this message translates to:
  /// **'Failed to send reboot command.'**
  String get rebootCommandFailed;

  /// Application section header
  ///
  /// In en, this message translates to:
  /// **'Application'**
  String get application;

  /// Manage routers option
  ///
  /// In en, this message translates to:
  /// **'Manage Routers'**
  String get manageRouters;

  /// Manage routers subtitle
  ///
  /// In en, this message translates to:
  /// **'Edit or remove saved routers'**
  String get manageRoutersSubtitle;

  /// Settings subtitle
  ///
  /// In en, this message translates to:
  /// **'Configure app preferences'**
  String get settingsSubtitle;

  /// About option
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// About subtitle
  ///
  /// In en, this message translates to:
  /// **'App version and information'**
  String get aboutSubtitle;

  /// Logout option
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// Logout subtitle
  ///
  /// In en, this message translates to:
  /// **'End your session and sign out'**
  String get logoutSubtitle;

  /// Logout dialog title
  ///
  /// In en, this message translates to:
  /// **'Logout?'**
  String get logoutTitle;

  /// Logout dialog message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get logoutMessage;

  /// About dialog title
  ///
  /// In en, this message translates to:
  /// **'LuCI Mobile'**
  String get aboutDialogTitle;

  /// About dialog version
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutDialogVersion(String version);

  /// About dialog description
  ///
  /// In en, this message translates to:
  /// **'A mobile client for OpenWrt routers.'**
  String get aboutDialogDescription;

  /// About dialog open source message
  ///
  /// In en, this message translates to:
  /// **'Open source and free to use.'**
  String get aboutDialogOpenSource;

  /// GitHub repository link
  ///
  /// In en, this message translates to:
  /// **'GitHub Repository'**
  String get githubRepository;

  /// Error message when repository cannot be opened
  ///
  /// In en, this message translates to:
  /// **'Could not open repository'**
  String get couldNotOpenRepository;

  /// Close button
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Router back online message
  ///
  /// In en, this message translates to:
  /// **'Router is back online, reconnecting…'**
  String get routerBackOnline;

  /// Splash screen subtitle
  ///
  /// In en, this message translates to:
  /// **'OpenWrt Router Control'**
  String get openWrtRouterControl;

  /// Routers screen title
  ///
  /// In en, this message translates to:
  /// **'Routers'**
  String get routers;

  /// No routers added message
  ///
  /// In en, this message translates to:
  /// **'No routers added yet.'**
  String get noRoutersAdded;

  /// Remove router dialog title
  ///
  /// In en, this message translates to:
  /// **'Remove Router'**
  String get removeRouter;

  /// Remove router dialog message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove {routerLabel}?'**
  String removeRouterMessage(String routerLabel);

  /// Remove button
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// Add router button
  ///
  /// In en, this message translates to:
  /// **'Add Router'**
  String get addRouter;

  /// Required validation error
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// Router already exists error
  ///
  /// In en, this message translates to:
  /// **'Router already exists.'**
  String get routerAlreadyExists;

  /// Connecting message
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connecting;

  /// Add button
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Failed to connect error message
  ///
  /// In en, this message translates to:
  /// **'Failed to connect: Invalid credentials or host unreachable.'**
  String get failedToConnectInvalidCredentials;

  /// Failed to connect error with details
  ///
  /// In en, this message translates to:
  /// **'Failed to connect: {error}'**
  String failedToConnect(String error);

  /// Active label
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// Remove tooltip
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeTooltip;

  /// Dashboard settings screen title
  ///
  /// In en, this message translates to:
  /// **'Dashboard Settings'**
  String get dashboardSettingsTitle;

  /// No routers added for settings title
  ///
  /// In en, this message translates to:
  /// **'No Routers Added'**
  String get noRoutersAddedForSettings;

  /// No routers added for settings message
  ///
  /// In en, this message translates to:
  /// **'Add a router to customize its dashboard settings.'**
  String get noRoutersAddedForSettingsMessage;

  /// Throughput monitoring section title
  ///
  /// In en, this message translates to:
  /// **'Throughput Monitoring'**
  String get throughputMonitoring;

  /// Throughput monitoring subtitle
  ///
  /// In en, this message translates to:
  /// **'Configure which interfaces to monitor'**
  String get throughputMonitoringSubtitle;

  /// Show all interfaces option
  ///
  /// In en, this message translates to:
  /// **'Show All Interfaces'**
  String get showAllInterfaces;

  /// Wireless networks section title
  ///
  /// In en, this message translates to:
  /// **'Wireless Networks'**
  String get wirelessNetworks;

  /// Wireless networks subtitle
  ///
  /// In en, this message translates to:
  /// **'Choose which wireless networks to display'**
  String get wirelessNetworksSubtitle;

  /// Show all networks option
  ///
  /// In en, this message translates to:
  /// **'Show All Networks'**
  String get showAllNetworks;

  /// Network interfaces section title
  ///
  /// In en, this message translates to:
  /// **'Network Interfaces'**
  String get networkInterfaces;

  /// Network interfaces subtitle
  ///
  /// In en, this message translates to:
  /// **'Choose which wired/VPN interfaces to display'**
  String get networkInterfacesSubtitle;

  /// WAN description
  ///
  /// In en, this message translates to:
  /// **'Wide Area Network'**
  String get wideAreaNetwork;

  /// LAN description
  ///
  /// In en, this message translates to:
  /// **'Local Area Network'**
  String get localAreaNetwork;

  /// WireGuard VPN description
  ///
  /// In en, this message translates to:
  /// **'WireGuard VPN'**
  String get wireGuardVpn;

  /// OpenVPN description
  ///
  /// In en, this message translates to:
  /// **'OpenVPN'**
  String get openVpn;

  /// PPPoE connection description
  ///
  /// In en, this message translates to:
  /// **'PPPoE Connection'**
  String get pppoeConnection;

  /// Unable to load dashboard data error
  ///
  /// In en, this message translates to:
  /// **'Unable to load dashboard data. Please check your connection.'**
  String get unableToLoadDashboardData;

  /// Failed to load settings error
  ///
  /// In en, this message translates to:
  /// **'Failed to load settings: {error}'**
  String failedToLoadSettings(String error);

  /// Client is online tooltip
  ///
  /// In en, this message translates to:
  /// **'Client is online'**
  String get clientIsOnline;

  /// Unknown connection type tooltip
  ///
  /// In en, this message translates to:
  /// **'Unknown connection type'**
  String get unknownConnectionType;

  /// Last known hostname tooltip
  ///
  /// In en, this message translates to:
  /// **'Last known hostname (may be out of date)'**
  String get lastKnownHostname;

  /// Loading message
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Gateway IP label
  ///
  /// In en, this message translates to:
  /// **'Gateway IP'**
  String get gatewayIp;

  /// DNS Servers label
  ///
  /// In en, this message translates to:
  /// **'DNS Servers'**
  String get dnsServers;

  /// Copy button/tooltip
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// Refresh failed error message
  ///
  /// In en, this message translates to:
  /// **'Refresh failed: {error}'**
  String refreshFailed(String error);

  /// Pull down to refresh instruction
  ///
  /// In en, this message translates to:
  /// **'Pull down to refresh'**
  String get pullDownToRefresh;

  /// No items to display message
  ///
  /// In en, this message translates to:
  /// **'No items to display'**
  String get noItemsToDisplay;

  /// Router address input tooltip
  ///
  /// In en, this message translates to:
  /// **'Enter the IP address, hostname, or full URL of your router'**
  String get enterRouterAddressTooltip;

  /// Username input tooltip
  ///
  /// In en, this message translates to:
  /// **'Enter your router username'**
  String get enterRouterUsernameTooltip;

  /// Password input tooltip
  ///
  /// In en, this message translates to:
  /// **'Enter your router password'**
  String get enterRouterPasswordTooltip;

  /// GitHub issues link tooltip
  ///
  /// In en, this message translates to:
  /// **'Open GitHub issues for support'**
  String get openGitHubIssuesTooltip;

  /// Router icon semantic label
  ///
  /// In en, this message translates to:
  /// **'Router icon'**
  String get routerIcon;

  /// Client icon semantic label
  ///
  /// In en, this message translates to:
  /// **'Client icon'**
  String get clientIcon;

  /// Interface icon semantic label
  ///
  /// In en, this message translates to:
  /// **'Interface icon'**
  String get interfaceIcon;

  /// Unnamed interface/network label
  ///
  /// In en, this message translates to:
  /// **'Unnamed'**
  String get unnamed;

  /// Disabled status label
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// Channel abbreviation
  ///
  /// In en, this message translates to:
  /// **'Ch.'**
  String get channelShort;

  /// SSID label (technical term)
  ///
  /// In en, this message translates to:
  /// **'SSID'**
  String get ssid;

  /// Certificate warning dialog title
  ///
  /// In en, this message translates to:
  /// **'Certificate Warning'**
  String get certificateWarning;

  /// Certificate warning message
  ///
  /// In en, this message translates to:
  /// **'The certificate for {host} is not trusted by your device. This could indicate a security risk.'**
  String certificateWarningMessage(String host);

  /// Certificate warning message with port
  ///
  /// In en, this message translates to:
  /// **'The certificate for {host}:{port} is not trusted by your device. This could indicate a security risk.'**
  String certificateWarningMessageWithPort(String host, String port);

  /// Certificate warning info message
  ///
  /// In en, this message translates to:
  /// **'Only proceed if you trust this router and understand the security implications.'**
  String get certificateWarningInfo;

  /// Certificate details label
  ///
  /// In en, this message translates to:
  /// **'Certificate Details:'**
  String get certificateDetails;

  /// Certificate subject label
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get subject;

  /// Certificate issuer label
  ///
  /// In en, this message translates to:
  /// **'Issuer'**
  String get issuer;

  /// Certificate valid from label
  ///
  /// In en, this message translates to:
  /// **'Valid From'**
  String get validFrom;

  /// Certificate valid until label
  ///
  /// In en, this message translates to:
  /// **'Valid Until'**
  String get validUntil;

  /// Accept risk button
  ///
  /// In en, this message translates to:
  /// **'Accept Risk'**
  String get acceptRisk;

  /// Mobile connection type label
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get mobile;

  /// Inactive status for accessibility labels
  ///
  /// In en, this message translates to:
  /// **'inactive'**
  String get inactive;

  /// Back button tooltip
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
