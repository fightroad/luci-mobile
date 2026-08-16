// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'LuCI Mobile';

  @override
  String get appSubtitle => '连接到您的 OpenWrt 路由器';

  @override
  String get appTagline => '快速、安全、开源';

  @override
  String get dashboard => '仪表板';

  @override
  String get clients => '客户端';

  @override
  String get interfaces => '接口';

  @override
  String get more => '更多';

  @override
  String get settings => '设置';

  @override
  String get loginConnect => '连接';

  @override
  String get routerAddress => '路由器地址';

  @override
  String get routerAddressHelper =>
      '例如：192.168.1.1、router.local:8080、https://192.168.1.1';

  @override
  String get username => '用户名';

  @override
  String get usernameHelper => '默认为 root';

  @override
  String get password => '密码';

  @override
  String get passwordHelper => '您的路由器密码';

  @override
  String get showPassword => '显示密码';

  @override
  String get hidePassword => '隐藏密码';

  @override
  String get pleaseEnterRouterAddress => '请输入路由器地址';

  @override
  String get pleaseEnterUsername => '请输入用户名';

  @override
  String get invalidAddressFormat => '地址格式无效';

  @override
  String get needHelp => '需要帮助？';

  @override
  String version(String version) {
    return '版本 $version';
  }

  @override
  String get activateReviewerMode => '激活审核模式？';

  @override
  String get reviewerModeDescription => '这将启用审核模式，绕过身份验证并提供用于演示的模拟数据。';

  @override
  String get reviewerModeConfirm => '要确认，请在下方输入 \"REVIEWER\"：';

  @override
  String get typeReviewer => '输入 REVIEWER';

  @override
  String get cancel => '取消';

  @override
  String get activate => '激活';

  @override
  String get holdToActivateReviewerMode => '长按以激活审核模式...';

  @override
  String get couldNotOpenGitHubIssues => '无法打开 GitHub Issues';

  @override
  String get selectRouter => '选择路由器';

  @override
  String get connectionFailed => '连接失败';

  @override
  String get connectionFailedMessage => '无法连接到路由器。请检查您的网络连接和路由器设置。';

  @override
  String get retryConnection => '重试连接';

  @override
  String get noDataAvailable => '无可用数据';

  @override
  String get noDataAvailableMessage => '无法获取仪表板数据。下拉刷新或点击下方按钮。';

  @override
  String get fetchData => '获取数据';

  @override
  String get switchingRouter => '正在切换路由器...';

  @override
  String get collectingThroughputData => '正在收集吞吐量数据...';

  @override
  String get throughput => '吞吐量';

  @override
  String throughputLabel(String interface) {
    return '吞吐量 - $interface';
  }

  @override
  String get model => '型号';

  @override
  String get versionLabel => '版本';

  @override
  String get cpuLoad => 'CPU 负载';

  @override
  String get memory => '内存';

  @override
  String get uptime => '运行时间';

  @override
  String get failedToLoadClients => '加载客户端失败';

  @override
  String get failedToLoadClientsMessage => '无法连接到路由器。请检查您的网络连接和路由器的 IP 地址。';

  @override
  String get retry => '重试';

  @override
  String get searchClients => '按名称、IP、MAC、厂商搜索...';

  @override
  String get clearSearch => '清除搜索';

  @override
  String get all => '全部';

  @override
  String get selected => '已选择';

  @override
  String get noActiveClientsFound => '未找到活动客户端';

  @override
  String get noActiveClientsMessage => '当前没有客户端连接到路由器。下拉刷新列表。';

  @override
  String get noMatchingClients => '未找到匹配的客户端';

  @override
  String get noMatchingClientsMessage => '没有客户端匹配您的搜索条件。请尝试其他搜索词。';

  @override
  String get wiFi => 'Wi-Fi';

  @override
  String get wired => '有线';

  @override
  String get unknown => '未知';

  @override
  String get ipAddress => 'IP 地址';

  @override
  String get ipv6Address => 'IPv6 地址';

  @override
  String get macAddress => 'MAC 地址';

  @override
  String get vendor => '厂商';

  @override
  String get dnsName => 'DNS 名称';

  @override
  String get leaseTimeRemaining => '剩余租约时间';

  @override
  String get expired => '已过期';

  @override
  String copiedToClipboard(String label) {
    return '$label 已复制到剪贴板';
  }

  @override
  String get failedToLoadInterfaces => '加载接口失败';

  @override
  String get failedToLoadInterfacesMessage => '无法连接到路由器。请检查您的网络连接和路由器设置。';

  @override
  String get noInterfaceData => '无接口数据';

  @override
  String get noInterfaceDataMessage => '无法获取接口信息。下拉刷新或点击下方按钮。';

  @override
  String get wiredSection => '有线';

  @override
  String get wirelessSection => '无线';

  @override
  String get device => '设备';

  @override
  String get mode => '模式';

  @override
  String get channel => '信道';

  @override
  String get signal => '信号';

  @override
  String get network => '网络';

  @override
  String get gateway => '网关';

  @override
  String get dns => 'DNS';

  @override
  String get lastHandshake => '最后握手';

  @override
  String get endpoint => '端点';

  @override
  String get never => '从未';

  @override
  String get received => '接收';

  @override
  String get transmitted => '发送';

  @override
  String get up => '启用';

  @override
  String get down => '禁用';

  @override
  String get off => '关闭';

  @override
  String get interfaceIsUp => '接口已启用';

  @override
  String get interfaceIsDown => '接口已禁用';

  @override
  String get expandDetails => '展开详情';

  @override
  String get collapseDetails => '折叠详情';

  @override
  String get theme => '主题';

  @override
  String get systemDefault => '跟随系统';

  @override
  String get light => '浅色';

  @override
  String get dark => '深色';

  @override
  String get dashboardSettings => '仪表板';

  @override
  String get customizeDashboard => '自定义仪表板';

  @override
  String get customizeDashboardSubtitle => '配置接口可见性和吞吐量监控';

  @override
  String get reviewerMode => '审核模式';

  @override
  String get reviewerModeActive => '审核模式已激活';

  @override
  String get reviewerModeActiveSubtitle => '正在使用模拟数据进行演示';

  @override
  String get exitReviewerMode => '退出审核模式';

  @override
  String get exitReviewerModeTitle => '退出审核模式？';

  @override
  String get exitReviewerModeMessage => '这将禁用审核模式并返回正常身份验证。您需要使用真实的路由器凭据登录。';

  @override
  String get exit => '退出';

  @override
  String get deviceManagement => '设备管理';

  @override
  String get rebootRouter => '重启路由器';

  @override
  String get rebootRouterSubtitle => '执行系统重启';

  @override
  String get rebootRouterTitle => '重启路由器？';

  @override
  String get rebootRouterMessage => '您确定要重启路由器吗？';

  @override
  String get reboot => '重启';

  @override
  String get rebooting => '正在重启…连接将中断。';

  @override
  String get rebootCommandSent => '重启命令已成功发送。';

  @override
  String get rebootCommandFailed => '发送重启命令失败。';

  @override
  String get application => '应用';

  @override
  String get manageRouters => '管理路由器';

  @override
  String get manageRoutersSubtitle => '编辑或删除已保存的路由器';

  @override
  String get settingsSubtitle => '配置应用偏好设置';

  @override
  String get about => '关于';

  @override
  String get aboutSubtitle => '应用版本和信息';

  @override
  String get logout => '退出登录';

  @override
  String get logoutSubtitle => '结束会话并退出登录';

  @override
  String get logoutTitle => '退出登录？';

  @override
  String get logoutMessage => '您确定要退出登录吗？';

  @override
  String get aboutDialogTitle => 'LuCI Mobile';

  @override
  String aboutDialogVersion(String version) {
    return '版本 $version';
  }

  @override
  String get aboutDialogDescription => '适用于 OpenWrt 路由器的移动客户端。';

  @override
  String get aboutDialogOpenSource => '开源且免费使用。';

  @override
  String get githubRepository => 'GitHub 仓库';

  @override
  String get couldNotOpenRepository => '无法打开仓库';

  @override
  String get close => '关闭';

  @override
  String get routerBackOnline => '路由器已重新上线，正在重新连接…';

  @override
  String get openWrtRouterControl => 'OpenWrt 路由器控制';

  @override
  String get routers => '路由器';

  @override
  String get noRoutersAdded => '尚未添加路由器。';

  @override
  String get removeRouter => '删除路由器';

  @override
  String removeRouterMessage(String routerLabel) {
    return '您确定要删除 $routerLabel 吗？';
  }

  @override
  String get remove => '删除';

  @override
  String get addRouter => '添加路由器';

  @override
  String get required => '必填';

  @override
  String get routerAlreadyExists => '路由器已存在。';

  @override
  String get connecting => '正在连接...';

  @override
  String get add => '添加';

  @override
  String get failedToConnectInvalidCredentials => '连接失败：凭据无效或主机无法访问。';

  @override
  String failedToConnect(String error) {
    return '连接失败：$error';
  }

  @override
  String get active => '活动';

  @override
  String get removeTooltip => '删除';

  @override
  String get dashboardSettingsTitle => '仪表板设置';

  @override
  String get noRoutersAddedForSettings => '未添加路由器';

  @override
  String get noRoutersAddedForSettingsMessage => '添加路由器以自定义其仪表板设置。';

  @override
  String get throughputMonitoring => '吞吐量监控';

  @override
  String get throughputMonitoringSubtitle => '配置要监控的接口';

  @override
  String get showAllInterfaces => '显示所有接口';

  @override
  String get wirelessNetworks => '无线网络';

  @override
  String get wirelessNetworksSubtitle => '选择要显示的无线网络';

  @override
  String get showAllNetworks => '显示所有网络';

  @override
  String get networkInterfaces => '网络接口';

  @override
  String get networkInterfacesSubtitle => '选择要显示的有线/VPN 接口';

  @override
  String get wideAreaNetwork => '广域网';

  @override
  String get localAreaNetwork => '局域网';

  @override
  String get wireGuardVpn => 'WireGuard VPN';

  @override
  String get openVpn => 'OpenVPN';

  @override
  String get pppoeConnection => 'PPPoE 连接';

  @override
  String get unableToLoadDashboardData => '无法加载仪表板数据。请检查您的连接。';

  @override
  String failedToLoadSettings(String error) {
    return '加载设置失败：$error';
  }

  @override
  String get clientIsOnline => '客户端在线';

  @override
  String get unknownConnectionType => '未知连接类型';

  @override
  String get lastKnownHostname => '最后已知主机名（可能已过期）';

  @override
  String get loading => '加载中...';

  @override
  String get gatewayIp => '网关 IP';

  @override
  String get dnsServers => 'DNS 服务器';

  @override
  String get copy => '复制';

  @override
  String refreshFailed(String error) {
    return '刷新失败：$error';
  }

  @override
  String get pullDownToRefresh => '下拉刷新';

  @override
  String get noItemsToDisplay => '无项目显示';

  @override
  String get enterRouterAddressTooltip => '输入路由器的 IP 地址、主机名或完整 URL';

  @override
  String get enterRouterUsernameTooltip => '输入您的路由器用户名';

  @override
  String get enterRouterPasswordTooltip => '输入您的路由器密码';

  @override
  String get openGitHubIssuesTooltip => '打开 GitHub Issues 获取支持';

  @override
  String get routerIcon => '路由器图标';

  @override
  String get clientIcon => '客户端图标';

  @override
  String get interfaceIcon => '接口图标';

  @override
  String get unnamed => '未命名';

  @override
  String get disabled => '已禁用';

  @override
  String get channelShort => '信道';

  @override
  String get ssid => 'SSID';

  @override
  String get certificateWarning => '证书警告';

  @override
  String certificateWarningMessage(String host) {
    return '设备不信任 $host 的证书。这可能表示存在安全风险。';
  }

  @override
  String certificateWarningMessageWithPort(String host, String port) {
    return '设备不信任 $host:$port 的证书。这可能表示存在安全风险。';
  }

  @override
  String get certificateWarningInfo => '只有在您信任此路由器并了解安全风险的情况下才继续。';

  @override
  String get certificateDetails => '证书详情：';

  @override
  String get subject => '主题';

  @override
  String get issuer => '颁发者';

  @override
  String get validFrom => '有效期起';

  @override
  String get validUntil => '有效期至';

  @override
  String get acceptRisk => '接受风险';

  @override
  String get mobile => '移动网络';

  @override
  String get inactive => '非活动';

  @override
  String get back => '返回';
}
