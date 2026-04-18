class AppConstants {
  static const String appName = 'NebulaVPN';
  static const String appVersion = '1.0.0';
  
  static const int connectionTimeout = 30000;
  static const int receiveTimeout = 30000;
  
  static const String defaultDns = '8.8.8.8';
  
  static const List<String> defaultDnsServers = [
    '8.8.8.8',
    '8.8.4.4',
    '1.1.1.1',
  ];
  
  static const String dbName = 'nebula_vpn.db';
  static const int dbVersion = 1;
  
  static const String prefVpnEnabled = 'vpn_enabled';
  static const String prefAutoConnect = 'auto_connect';
  static const String prefAutoStart = 'auto_start';
  static const String prefKillSwitch = 'kill_switch';
  static const String prefSelectedServer = 'selected_server';
  static const String prefTotalUpload = 'total_upload';
  static const String prefTotalDownload = 'total_download';
  static const String prefCustomDns = 'custom_dns';
  static const String prefDnsFallback = 'dns_fallback';
  static const String prefEnableDns = 'enable_dns';
  static const String prefIpv6Support = 'ipv6_support';
  static const String prefMuxEnabled = 'mux_enabled';
  static const String prefMuxCount = 'mux_count';
  static const String prefRoutingMode = 'routing_mode';
  static const String prefBypassLan = 'bypass_lan';
  static const String prefDebugMode = 'debug_mode';
}
