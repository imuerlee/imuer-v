// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '星云VPN';

  @override
  String get home => '首页';

  @override
  String get servers => '服务器';

  @override
  String get statistics => '统计';

  @override
  String get settings => '设置';

  @override
  String get disconnected => '未连接';

  @override
  String get connecting => '连接中...';

  @override
  String get connected => '已连接';

  @override
  String get disconnecting => '断开中...';

  @override
  String get error => '错误';

  @override
  String get noServerSelected => '未选择服务器';

  @override
  String get tapToSelectServer => '点击选择服务器';

  @override
  String get uploadSpeed => '上传';

  @override
  String get downloadSpeed => '下载';

  @override
  String get totalUpload => '总上传';

  @override
  String get totalDownload => '总下载';

  @override
  String get currentLocation => '当前位置';

  @override
  String get unknown => '未知';

  @override
  String get serverList => '服务器列表';

  @override
  String serversCount(int count) {
    return '$count 个服务器';
  }

  @override
  String get testAll => '测试全部';

  @override
  String get qrCode => '二维码';

  @override
  String get clipboard => '剪贴板';

  @override
  String get file => '文件';

  @override
  String get subscribe => '订阅';

  @override
  String get addServer => '添加服务器';

  @override
  String get noServers => '暂无服务器';

  @override
  String get addServerToGetStarted => '添加服务器以开始使用';

  @override
  String get delete => '删除';

  @override
  String get edit => '编辑';

  @override
  String get copy => '复制';

  @override
  String get share => '分享';

  @override
  String get serverName => '服务器名称';

  @override
  String get protocol => '协议';

  @override
  String get address => '地址';

  @override
  String get port => '端口';

  @override
  String get uuid => 'UUID';

  @override
  String get security => '加密方式';

  @override
  String get network => '网络';

  @override
  String get tcp => 'TCP';

  @override
  String get udp => 'UDP';

  @override
  String get ws => 'WebSocket';

  @override
  String get grpc => 'gRPC';

  @override
  String get tls => 'TLS';

  @override
  String get reality => 'Reality';

  @override
  String get none => '无';

  @override
  String get host => '主机';

  @override
  String get path => '路径';

  @override
  String get sni => 'SNI';

  @override
  String get alpn => 'ALPN';

  @override
  String get fingerprint => '指纹';

  @override
  String get allowInsecure => '允许不安全';

  @override
  String get flow => '流控';

  @override
  String get publicKey => '公钥';

  @override
  String get shortId => 'Short ID';

  @override
  String get password => '密码';

  @override
  String get method => '加密方式';

  @override
  String get plugin => '插件';

  @override
  String get pluginOptions => '插件参数';

  @override
  String get obfs => '混淆';

  @override
  String get obfsPassword => '混淆密码';

  @override
  String get mtu => 'MTU';

  @override
  String get privateKey => '私钥';

  @override
  String get peerPublicKey => 'Peer 公钥';

  @override
  String get presharedKey => '预共享密钥';

  @override
  String get reserved => '保留字段';

  @override
  String get speedLimitUp => '上传限速';

  @override
  String get speedLimitDown => '下载限速';

  @override
  String get username => '用户名';

  @override
  String get authentication => '认证';

  @override
  String get save => '保存';

  @override
  String get cancel => '取消';

  @override
  String get import => '导入';

  @override
  String get export => '导出';

  @override
  String get subscription => '订阅';

  @override
  String get subscriptionUrl => '订阅地址';

  @override
  String get enterSubscriptionUrl => '输入订阅地址';

  @override
  String get fetchSubscription => '获取订阅';

  @override
  String get noSubscriptionUrl => '无订阅地址';

  @override
  String subscriptionSuccess(int count) {
    return '已导入 $count 个服务器';
  }

  @override
  String get noValidServersFound => '未找到有效服务器';

  @override
  String get scanQrCode => '扫描二维码';

  @override
  String get pointCameraAtQrCode => '将摄像头对准二维码';

  @override
  String get importFromClipboard => '从剪贴板导入';

  @override
  String get importFromFile => '从文件导入';

  @override
  String importSuccess(int count) {
    return '已导入 $count 个服务器';
  }

  @override
  String get connection => '连接';

  @override
  String get autoConnect => '自动连接';

  @override
  String get autoConnectDesc => '启动时自动连接';

  @override
  String get autoStart => '开机启动';

  @override
  String get autoStartDesc => '设备启动时启动VPN';

  @override
  String get killSwitch => '终止开关';

  @override
  String get killSwitchDesc => 'VPN断开时阻止网络';

  @override
  String get customDns => '自定义DNS';

  @override
  String get dnsFallback => '备用DNS';

  @override
  String get routing => '路由';

  @override
  String get routingMode => '路由模式';

  @override
  String get geographicRouting => '地理路由';

  @override
  String get bypassLan => '绕过局域网';

  @override
  String get bypassLanDesc => '不代理本地网络';

  @override
  String get trafficStatistics => '流量统计';

  @override
  String get thisWeek => '本周';

  @override
  String get dailyAverage => '日均';

  @override
  String get sessionStatistics => '会话统计';

  @override
  String get connectionDuration => '连接时长';

  @override
  String get speedHistory => '速度历史';

  @override
  String get trafficOverview => '流量概览';

  @override
  String get about => '关于';

  @override
  String get version => '版本';

  @override
  String get licenses => '开源许可';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get logs => '日志';

  @override
  String get clearLogs => '清除日志';

  @override
  String get debugMode => '调试模式';

  @override
  String get debugModeDesc => '启用调试日志';

  @override
  String get language => '语言';

  @override
  String get theme => '主题';

  @override
  String get darkTheme => '深色主题';

  @override
  String get lightTheme => '浅色主题';

  @override
  String get systemDefault => '跟随系统';

  @override
  String get notifications => '通知';

  @override
  String get connectionNotification => '连接通知';

  @override
  String get connectionNotificationDesc => '连接时显示通知';

  @override
  String get advanced => '高级';

  @override
  String get mux => '多路复用';

  @override
  String get muxCount => 'Mux 数量';

  @override
  String get xHttp => 'XHTTP';

  @override
  String get localDns => '本地DNS';

  @override
  String get proxyPort => '代理端口';

  @override
  String get tunImplementation => 'TUN 实现';

  @override
  String get mixedPort => '混合端口';

  @override
  String get enableDns => '启用DNS';

  @override
  String get enableDnsDesc => '启用自定义DNS配置';

  @override
  String get ipv6Support => 'IPv6 支持';

  @override
  String get ipv6SupportDesc => '启用IPv6路由';

  @override
  String get routingGlobal => '全局代理';

  @override
  String get primaryDns => '主 DNS';

  @override
  String get secondaryDns => '备用 DNS';

  @override
  String get subscriptionName => '订阅名称';

  @override
  String get preview => '预览';

  @override
  String get confirmImport => '确认导入';
}
