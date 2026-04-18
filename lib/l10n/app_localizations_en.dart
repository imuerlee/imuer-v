// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'NebulaVPN';

  @override
  String get home => 'Home';

  @override
  String get servers => 'Servers';

  @override
  String get statistics => 'Statistics';

  @override
  String get settings => 'Settings';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get connecting => 'Connecting...';

  @override
  String get connected => 'Connected';

  @override
  String get disconnecting => 'Disconnecting...';

  @override
  String get error => 'Error';

  @override
  String get noServerSelected => 'No Server Selected';

  @override
  String get tapToSelectServer => 'Tap to select a server';

  @override
  String get uploadSpeed => 'Upload';

  @override
  String get downloadSpeed => 'Download';

  @override
  String get totalUpload => 'Total Upload';

  @override
  String get totalDownload => 'Total Download';

  @override
  String get currentLocation => 'Current Location';

  @override
  String get unknown => 'Unknown';

  @override
  String get serverList => 'Server List';

  @override
  String serversCount(int count) {
    return '$count servers';
  }

  @override
  String get testAll => 'Test All';

  @override
  String get qrCode => 'QR Code';

  @override
  String get clipboard => 'Clipboard';

  @override
  String get file => 'File';

  @override
  String get subscribe => 'Subscribe';

  @override
  String get addServer => 'Add Server';

  @override
  String get noServers => 'No Servers';

  @override
  String get addServerToGetStarted => 'Add a server to get started';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get copy => 'Copy';

  @override
  String get share => 'Share';

  @override
  String get serverName => 'Server Name';

  @override
  String get protocol => 'Protocol';

  @override
  String get address => 'Address';

  @override
  String get port => 'Port';

  @override
  String get uuid => 'UUID';

  @override
  String get security => 'Security';

  @override
  String get network => 'Network';

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
  String get none => 'None';

  @override
  String get host => 'Host';

  @override
  String get path => 'Path';

  @override
  String get sni => 'SNI';

  @override
  String get alpn => 'ALPN';

  @override
  String get fingerprint => 'Fingerprint';

  @override
  String get allowInsecure => 'Allow Insecure';

  @override
  String get flow => 'Flow';

  @override
  String get publicKey => 'Public Key';

  @override
  String get shortId => 'Short ID';

  @override
  String get password => 'Password';

  @override
  String get method => 'Method';

  @override
  String get plugin => 'Plugin';

  @override
  String get pluginOptions => 'Plugin Options';

  @override
  String get obfs => 'OBFS';

  @override
  String get obfsPassword => 'OBFS Password';

  @override
  String get mtu => 'MTU';

  @override
  String get privateKey => 'Private Key';

  @override
  String get peerPublicKey => 'Peer Public Key';

  @override
  String get presharedKey => 'Preshared Key';

  @override
  String get reserved => 'Reserved';

  @override
  String get speedLimitUp => 'Upload Speed Limit';

  @override
  String get speedLimitDown => 'Download Speed Limit';

  @override
  String get username => 'Username';

  @override
  String get authentication => 'Authentication';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get import => 'Import';

  @override
  String get export => 'Export';

  @override
  String get subscription => 'Subscription';

  @override
  String get subscriptionUrl => 'Subscription URL';

  @override
  String get enterSubscriptionUrl => 'Enter subscription URL';

  @override
  String get fetchSubscription => 'Fetch Subscription';

  @override
  String get noSubscriptionUrl => 'No subscription URL';

  @override
  String subscriptionSuccess(int count) {
    return 'Imported $count servers';
  }

  @override
  String get noValidServersFound => 'No valid servers found';

  @override
  String get scanQrCode => 'Scan QR Code';

  @override
  String get pointCameraAtQrCode => 'Point camera at QR code';

  @override
  String get importFromClipboard => 'Import from Clipboard';

  @override
  String get importFromFile => 'Import from File';

  @override
  String importSuccess(int count) {
    return 'Imported $count server(s)';
  }

  @override
  String get connection => 'Connection';

  @override
  String get autoConnect => 'Auto Connect';

  @override
  String get autoConnectDesc => 'Automatically connect on app launch';

  @override
  String get autoStart => 'Auto Start';

  @override
  String get autoStartDesc => 'Start VPN when device boots';

  @override
  String get killSwitch => 'Kill Switch';

  @override
  String get killSwitchDesc => 'Block internet if VPN disconnects';

  @override
  String get customDns => 'Custom DNS';

  @override
  String get dnsFallback => 'DNS Fallback';

  @override
  String get routing => 'Routing';

  @override
  String get routingMode => 'Routing Mode';

  @override
  String get geographicRouting => 'Geographic Routing';

  @override
  String get bypassLan => 'Bypass LAN';

  @override
  String get bypassLanDesc => 'Don\'t proxy local network';

  @override
  String get trafficStatistics => 'Traffic Statistics';

  @override
  String get thisWeek => 'This Week';

  @override
  String get dailyAverage => 'Daily Average';

  @override
  String get sessionStatistics => 'Session Statistics';

  @override
  String get connectionDuration => 'Connection Duration';

  @override
  String get speedHistory => 'Speed History';

  @override
  String get trafficOverview => 'Traffic Overview';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get licenses => 'Licenses';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get logs => 'Logs';

  @override
  String get clearLogs => 'Clear Logs';

  @override
  String get debugMode => 'Debug Mode';

  @override
  String get debugModeDesc => 'Enable debug logging';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get darkTheme => 'Dark Theme';

  @override
  String get lightTheme => 'Light Theme';

  @override
  String get systemDefault => 'System Default';

  @override
  String get notifications => 'Notifications';

  @override
  String get connectionNotification => 'Connection Notification';

  @override
  String get connectionNotificationDesc => 'Show notification when connected';

  @override
  String get advanced => 'Advanced';

  @override
  String get mux => 'Multiplexing';

  @override
  String get muxCount => 'Mux Count';

  @override
  String get xHttp => 'XHTTP';

  @override
  String get localDns => 'Local DNS';

  @override
  String get proxyPort => 'Proxy Port';

  @override
  String get tunImplementation => 'TUN Implementation';

  @override
  String get mixedPort => 'Mixed Port';

  @override
  String get enableDns => 'Enable DNS';

  @override
  String get enableDnsDesc => 'Enable custom DNS configuration';

  @override
  String get ipv6Support => 'IPv6 Support';

  @override
  String get ipv6SupportDesc => 'Enable IPv6 routing';

  @override
  String get routingGlobal => 'Global Proxy';

  @override
  String get primaryDns => 'Primary DNS';

  @override
  String get secondaryDns => 'Secondary DNS';

  @override
  String get subscriptionName => 'Subscription Name';

  @override
  String get preview => 'Preview';

  @override
  String get confirmImport => 'Import';
}
