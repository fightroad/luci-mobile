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
  String get settings => '偏好设置';

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
  String version(String version) {
    return '版本 $version';
  }

  @override
  String get cancel => '取消';

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
  String get deviceInfo => '设备信息';

  @override
  String get hostname => '主机名';

  @override
  String get versionLabel => '版本';

  @override
  String get firmwareVersion => '固件版本';

  @override
  String get luciVersion => 'LuCI 版本';

  @override
  String get architecture => '架构';

  @override
  String get platform => '平台';

  @override
  String get kernel => '内核';

  @override
  String get cpuLoad => 'CPU 负载';

  @override
  String get memory => '内存';

  @override
  String get uptime => '运行时间';

  @override
  String get localTime => '本地时间';

  @override
  String get bootTime => '开机时间';

  @override
  String get storage => '存储';

  @override
  String get storageDevice => '设备';

  @override
  String get storageMount => '挂载点';

  @override
  String get lanIpv4 => 'LAN IP';

  @override
  String get lanIpv6 => 'LAN IPv6';

  @override
  String get ipAddressShort => 'IP 地址';

  @override
  String get wanIpv4 => 'WAN IPv4';

  @override
  String get wanIpv6 => 'WAN IPv6';

  @override
  String get onlineClients => 'Wi-Fi 在线';

  @override
  String get activeConnections => '连接数';

  @override
  String get temperature => '温度';

  @override
  String get memoryBuffered => '缓冲';

  @override
  String get memoryAvailable => '可用';

  @override
  String get memoryCached => '缓存';

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
  String get noActiveClientsFound => '无 Wi-Fi 客户端';

  @override
  String get noActiveClientsMessage => '当前没有设备连接 Wi-Fi。下拉刷新列表。';

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
  String get encryption => '加密';

  @override
  String get associatedClients => '关联数';

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
  String get notConnected => '未连接';

  @override
  String get connected => '已连接';

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
  String get customizeDashboardSubtitle => '配置无线网络显示和吞吐量监控';

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
  String get application => '应用管理';

  @override
  String get manageRouters => '管理路由器';

  @override
  String get manageRoutersSubtitle => '编辑或删除已保存的路由器';

  @override
  String get settingsSubtitle => '配置应用偏好设置';

  @override
  String get about => '关于应用';

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
  String get enterRouterAddressTooltip => '输入路由器的 IP 地址、主机名或完整 URL';

  @override
  String get enterRouterUsernameTooltip => '输入您的路由器用户名';

  @override
  String get enterRouterPasswordTooltip => '输入您的路由器密码';

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
  String get accessPoint => '接入点';

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

  @override
  String get plugins => '插件管理';

  @override
  String get passwall => 'PassWall';

  @override
  String get passwallSubtitle => '开关、节点与分流规则';

  @override
  String get passwallMain => '主设置';

  @override
  String get passwallEnabled => '启用 PassWall';

  @override
  String get passwallEnabledSubtitle => '透明代理总开关';

  @override
  String get passwallTcpNode => 'TCP 节点';

  @override
  String get passwallUdpNode => 'UDP 节点';

  @override
  String get passwallNodeClose => '关闭';

  @override
  String get passwallUdpSameAsTcp => '与 TCP 节点相同';

  @override
  String get passwallSaved => 'PassWall 设置已应用';

  @override
  String get passwallSaveFailed => '应用 PassWall 设置失败';

  @override
  String get passwallUnavailable => '无法使用 PassWall';

  @override
  String get passwallUnavailableMessage => '无法从路由器读取 PassWall 配置。';

  @override
  String get passwallApply => '应用';

  @override
  String get passwallRefresh => '刷新';

  @override
  String get passwallUpdateSubscribe => '更新订阅';

  @override
  String get passwallUpdateSubscribeTitle => '更新订阅？';

  @override
  String get passwallUpdateSubscribeMessage => '确定从全部订阅链接拉取最新节点吗？';

  @override
  String get passwallUpdateSubscribeSubtitle => '从全部订阅链接拉取最新节点';

  @override
  String get passwallUpdateSubscribeEmpty => '尚未配置订阅链接';

  @override
  String get passwallUpdateSubscribeStarted => '已开始更新订阅';

  @override
  String get passwallUpdateSubscribeFailed => '无法开始更新订阅';

  @override
  String get passwallTestConnect => '测试连通';

  @override
  String get passwallTestConnectSubtitle => '调用官方谷歌连接测试';

  @override
  String passwallTestConnectOk(String ms) {
    return '连接成功：$ms ms';
  }

  @override
  String get passwallTestConnectFailed => '连接失败';

  @override
  String get passwallLog => '日志';

  @override
  String get passwallLogSubtitle => '查看 PassWall 运行日志';

  @override
  String get passwallLogEmpty => '暂无日志';

  @override
  String get passwallLogFailed => '无法加载日志';

  @override
  String get passwallClearLog => '清空';

  @override
  String get passwallClearLogTitle => '清空日志？';

  @override
  String get passwallClearLogMessage => '确定清空 PassWall 运行日志吗？';

  @override
  String get passwallClearLogFailed => '清空日志失败';

  @override
  String get passwallRefreshLog => '刷新';

  @override
  String get passwallShuntRules => '分流规则';

  @override
  String get passwallShunt => '分流';

  @override
  String get passwallShuntDefault => '默认';

  @override
  String get passwallShuntDirect => '直连';

  @override
  String get passwallShuntBlackhole => '黑洞';

  @override
  String get easytier => 'EasyTier';

  @override
  String get easytierSubtitle => '开关、重启与状态查看';

  @override
  String get easytierQuickActions => '快捷操作';

  @override
  String get easytierCore => 'EasyTier Core';

  @override
  String get easytierCoreSubtitle => '启用或关闭 EasyTier 核心服务';

  @override
  String get easytierRestart => '重启';

  @override
  String get easytierRestartTitle => '重启 EasyTier？';

  @override
  String get easytierRestartMessage => '确定在路由器上重启 EasyTier 服务吗？';

  @override
  String get easytierRestartOk => 'EasyTier 已重启';

  @override
  String get easytierRestartFailed => '重启 EasyTier 失败';

  @override
  String get easytierEnableTitle => '启用 EasyTier？';

  @override
  String get easytierEnableMessage => '确定在路由器上启动 EasyTier 核心服务吗？';

  @override
  String get easytierEnableConfirm => '启用';

  @override
  String get easytierDisableTitle => '关闭 EasyTier？';

  @override
  String get easytierDisableMessage => '确定在路由器上关闭 EasyTier 核心服务吗？';

  @override
  String get easytierDisableConfirm => '关闭';

  @override
  String get easytierRefresh => '刷新';

  @override
  String get easytierStatus => '状态信息';

  @override
  String get easytierRunning => '运行中';

  @override
  String get easytierStopped => '已停止';

  @override
  String get easytierCpu => 'CPU';

  @override
  String get easytierMemory => '内存';

  @override
  String get easytierUptime => '运行时长';

  @override
  String get easytierVersion => '版本';

  @override
  String get easytierEnabledOk => 'EasyTier 已启用';

  @override
  String get easytierDisabledOk => 'EasyTier 已关闭';

  @override
  String get easytierToggleFailed => '切换 EasyTier 状态失败';

  @override
  String get easytierUnavailableMessage => '无法从路由器读取 EasyTier 状态。';

  @override
  String get easytierNodeList => '节点列表';

  @override
  String get easytierNodeListEmpty => '暂无网络节点';

  @override
  String get easytierNodeListStopped => '请先启动 EasyTier Core 查看节点';

  @override
  String get easytierLocalNode => '本机';

  @override
  String get easytierPeerPacketLoss => '丢包率';

  @override
  String get easytierPeerDownload => '下载';

  @override
  String get easytierPeerUpload => '上传';

  @override
  String get easytierPeerProtocol => '协议';

  @override
  String get easytierPeerNatType => 'NAT 类型';

  @override
  String get easytierNatUnknown => '未知';

  @override
  String get easytierNatSymmetric => '对称型';

  @override
  String get easytierNatRestricted => '受限型';

  @override
  String get easytierNatPortRestricted => '端口受限型';

  @override
  String get easytierNatAddressRestricted => '地址受限型';

  @override
  String get easytierNatFullCone => '全锥型';

  @override
  String get easytierNatNoPat => '无端口映射';
}
