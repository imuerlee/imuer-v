import 'dart:convert';
import 'package:equatable/equatable.dart';

enum ServerProtocol {
  vmess,
  vless,
  ss,
  ssr,
  trojan,
  wireguard,
  hysteria,
  hysteria2,
  http,
  socks5,
}

enum TLSSecurity {
  none,
  tls,
 reality,
}

enum QUICSecurity {
  none,
  aes128gcm,
  aes256gcm,
  chacha20poly1305,
}

class ServerNode extends Equatable {
  final String id;
  final String name;
  final String address;
  final int port;
  final ServerProtocol protocol;
  final String? username;
  final String? password;
  final String? uuid;
  final int? alterId;
  final String? security;
  final String? network;
  final String? tls;
  final String? host;
  final String? path;
  final String? sni;
  final String? alpn;
  final String? country;
  final String? city;
  final double? latitude;
  final double? longitude;
  final int? latency;
  final int? downloadSpeed;
  final bool isActive;
  final String? groupId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // VLESS specific
  final String? flow;

  // Shadowsocks specific
  final String? method;
  final String? plugin;
  final String? pluginOpts;

  // ShadowsocksR specific
  final String? protocolParam;
  final String? obfs;
  final String? obfsParam;

  // WireGuard specific
  final String? publicKey;
  final String? privateKey;
  final String? peerPublicKey;
  final String? presharedKey;
  final int? mtu;
  final String? reserved;

  // Hysteria specific
  final String? obfsPassword;
  final int? speedLimit;
  final int? speedLimitUp;
  final int? speedLimitDown;

  // HTTP/SOCKS specific
  final bool? auth;
  final String? authUsername;
  final String? authPassword;

  // TLS specific
  final bool? allowInsecure;
  final String? fingerprint;
  final bool? verifyHostname;
  final String? publicKey1;
  final String? shortId;

  // Subscription specific
  final String? subscriptionUrl;
  final int? subscriptionUpload;
  final int? subscriptionDownload;
  final int? subscriptionTotal;
  final DateTime? subscriptionExpire;

  const ServerNode({
    required this.id,
    required this.name,
    required this.address,
    required this.port,
    required this.protocol,
    this.username,
    this.password,
    this.uuid,
    this.alterId,
    this.security,
    this.network,
    this.tls,
    this.host,
    this.path,
    this.sni,
    this.alpn,
    this.country,
    this.city,
    this.latitude,
    this.longitude,
    this.latency,
    this.downloadSpeed,
    this.isActive = true,
    this.groupId,
    required this.createdAt,
    required this.updatedAt,
    this.flow,
    this.method,
    this.plugin,
    this.pluginOpts,
    this.protocolParam,
    this.obfs,
    this.obfsParam,
    this.publicKey,
    this.privateKey,
    this.peerPublicKey,
    this.presharedKey,
    this.mtu,
    this.reserved,
    this.obfsPassword,
    this.speedLimit,
    this.speedLimitUp,
    this.speedLimitDown,
    this.auth,
    this.authUsername,
    this.authPassword,
    this.allowInsecure,
    this.fingerprint,
    this.verifyHostname,
    this.publicKey1,
    this.shortId,
    this.subscriptionUrl,
    this.subscriptionUpload,
    this.subscriptionDownload,
    this.subscriptionTotal,
    this.subscriptionExpire,
  });

  ServerNode copyWith({
    String? id,
    String? name,
    String? address,
    int? port,
    ServerProtocol? protocol,
    String? username,
    String? password,
    String? uuid,
    int? alterId,
    String? security,
    String? network,
    String? tls,
    String? host,
    String? path,
    String? sni,
    String? alpn,
    String? country,
    String? city,
    double? latitude,
    double? longitude,
    int? latency,
    int? downloadSpeed,
    bool? isActive,
    String? groupId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? flow,
    String? method,
    String? plugin,
    String? pluginOpts,
    String? protocolParam,
    String? obfs,
    String? obfsParam,
    String? publicKey,
    String? privateKey,
    String? peerPublicKey,
    String? presharedKey,
    int? mtu,
    String? reserved,
    String? obfsPassword,
    int? speedLimit,
    int? speedLimitUp,
    int? speedLimitDown,
    bool? auth,
    String? authUsername,
    String? authPassword,
    bool? allowInsecure,
    String? fingerprint,
    bool? verifyHostname,
    String? publicKey1,
    String? shortId,
    String? subscriptionUrl,
    int? subscriptionUpload,
    int? subscriptionDownload,
    int? subscriptionTotal,
    DateTime? subscriptionExpire,
  }) {
    return ServerNode(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      port: port ?? this.port,
      protocol: protocol ?? this.protocol,
      username: username ?? this.username,
      password: password ?? this.password,
      uuid: uuid ?? this.uuid,
      alterId: alterId ?? this.alterId,
      security: security ?? this.security,
      network: network ?? this.network,
      tls: tls ?? this.tls,
      host: host ?? this.host,
      path: path ?? this.path,
      sni: sni ?? this.sni,
      alpn: alpn ?? this.alpn,
      country: country ?? this.country,
      city: city ?? this.city,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      latency: latency ?? this.latency,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      isActive: isActive ?? this.isActive,
      groupId: groupId ?? this.groupId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      flow: flow ?? this.flow,
      method: method ?? this.method,
      plugin: plugin ?? this.plugin,
      pluginOpts: pluginOpts ?? this.pluginOpts,
      protocolParam: protocolParam ?? this.protocolParam,
      obfs: obfs ?? this.obfs,
      obfsParam: obfsParam ?? this.obfsParam,
      publicKey: publicKey ?? this.publicKey,
      privateKey: privateKey ?? this.privateKey,
      peerPublicKey: peerPublicKey ?? this.peerPublicKey,
      presharedKey: presharedKey ?? this.presharedKey,
      mtu: mtu ?? this.mtu,
      reserved: reserved ?? this.reserved,
      obfsPassword: obfsPassword ?? this.obfsPassword,
      speedLimit: speedLimit ?? this.speedLimit,
      speedLimitUp: speedLimitUp ?? this.speedLimitUp,
      speedLimitDown: speedLimitDown ?? this.speedLimitDown,
      auth: auth ?? this.auth,
      authUsername: authUsername ?? this.authUsername,
      authPassword: authPassword ?? this.authPassword,
      allowInsecure: allowInsecure ?? this.allowInsecure,
      fingerprint: fingerprint ?? this.fingerprint,
      verifyHostname: verifyHostname ?? this.verifyHostname,
      publicKey1: publicKey1 ?? this.publicKey1,
      shortId: shortId ?? this.shortId,
      subscriptionUrl: subscriptionUrl ?? this.subscriptionUrl,
      subscriptionUpload: subscriptionUpload ?? this.subscriptionUpload,
      subscriptionDownload: subscriptionDownload ?? this.subscriptionDownload,
      subscriptionTotal: subscriptionTotal ?? this.subscriptionTotal,
      subscriptionExpire: subscriptionExpire ?? this.subscriptionExpire,
    );
  }

  String get configString {
    switch (protocol) {
      case ServerProtocol.vmess:
        return _buildVmessConfig();
      case ServerProtocol.vless:
        return _buildVlessConfig();
      case ServerProtocol.ss:
        return _buildShadowsocksConfig();
      case ServerProtocol.ssr:
        return _buildShadowsocksRConfig();
      case ServerProtocol.trojan:
        return _buildTrojanConfig();
      case ServerProtocol.wireguard:
        return _buildWireGuardConfig();
      case ServerProtocol.hysteria:
        return _buildHysteriaConfig();
      case ServerProtocol.hysteria2:
        return _buildHysteria2Config();
      case ServerProtocol.http:
        return _buildHttpConfig();
      case ServerProtocol.socks5:
        return _buildSocks5Config();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'port': port,
      'protocol': protocol.name,
      'username': username,
      'password': password,
      'uuid': uuid,
      'alterId': alterId,
      'security': security,
      'network': network,
      'tls': tls,
      'host': host,
      'path': path,
      'sni': sni,
      'alpn': alpn,
      'country': country,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
      'latency': latency,
      'downloadSpeed': downloadSpeed,
      'isActive': isActive,
      'groupId': groupId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'flow': flow,
      'method': method,
      'plugin': plugin,
      'pluginOpts': pluginOpts,
      'protocolParam': protocolParam,
      'obfs': obfs,
      'obfsParam': obfsParam,
      'publicKey': publicKey,
      'privateKey': privateKey,
      'peerPublicKey': peerPublicKey,
      'presharedKey': presharedKey,
      'mtu': mtu,
      'reserved': reserved,
      'obfsPassword': obfsPassword,
      'speedLimit': speedLimit,
      'speedLimitUp': speedLimitUp,
      'speedLimitDown': speedLimitDown,
      'auth': auth,
      'authUsername': authUsername,
      'authPassword': authPassword,
      'allowInsecure': allowInsecure,
      'fingerprint': fingerprint,
      'verifyHostname': verifyHostname,
      'publicKey1': publicKey1,
      'shortId': shortId,
      'subscriptionUrl': subscriptionUrl,
      'subscriptionDownload': subscriptionDownload,
      'subscriptionUpload': subscriptionUpload,
      'subscriptionTotal': subscriptionTotal,
      'subscriptionExpire': subscriptionExpire?.toIso8601String(),
    };
  }

  factory ServerNode.fromJson(Map<String, dynamic> json) {
    return ServerNode(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      port: json['port'] as int,
      protocol: ServerProtocol.values.firstWhere(
        (e) => e.name == json['protocol'],
        orElse: () => ServerProtocol.vmess,
      ),
      username: json['username'] as String?,
      password: json['password'] as String?,
      uuid: json['uuid'] as String?,
      alterId: json['alterId'] as int?,
      security: json['security'] as String?,
      network: json['network'] as String?,
      tls: json['tls'] as String?,
      host: json['host'] as String?,
      path: json['path'] as String?,
      sni: json['sni'] as String?,
      alpn: json['alpn'] as String?,
      country: json['country'] as String?,
      city: json['city'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      latency: json['latency'] as int?,
      downloadSpeed: json['downloadSpeed'] as int?,
      isActive: json['isActive'] == true,
      groupId: json['groupId'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now(),
      flow: json['flow'] as String?,
      method: json['method'] as String?,
      plugin: json['plugin'] as String?,
      pluginOpts: json['pluginOpts'] as String?,
      protocolParam: json['protocolParam'] as String?,
      obfs: json['obfs'] as String?,
      obfsParam: json['obfsParam'] as String?,
      publicKey: json['publicKey'] as String?,
      privateKey: json['privateKey'] as String?,
      peerPublicKey: json['peerPublicKey'] as String?,
      presharedKey: json['presharedKey'] as String?,
      mtu: json['mtu'] as int?,
      reserved: json['reserved'] as String?,
      obfsPassword: json['obfsPassword'] as String?,
      speedLimit: json['speedLimit'] as int?,
      speedLimitUp: json['speedLimitUp'] as int?,
      speedLimitDown: json['speedLimitDown'] as int?,
      auth: json['auth'] as bool?,
      authUsername: json['authUsername'] as String?,
      authPassword: json['authPassword'] as String?,
      allowInsecure: json['allowInsecure'] as bool?,
      fingerprint: json['fingerprint'] as String?,
      verifyHostname: json['verifyHostname'] as bool?,
      publicKey1: json['publicKey1'] as String?,
      shortId: json['shortId'] as String?,
      subscriptionUrl: json['subscriptionUrl'] as String?,
      subscriptionDownload: json['subscriptionDownload'] as int?,
      subscriptionUpload: json['subscriptionUpload'] as int?,
      subscriptionTotal: json['subscriptionTotal'] as int?,
      subscriptionExpire: json['subscriptionExpire'] != null
          ? DateTime.tryParse(json['subscriptionExpire'] as String)
          : null,
    );
  }

  String _buildVmessConfig() {
    final Map<String, dynamic> vmess = {
      'v': '2',
      'ps': name,
      'add': address,
      'port': port,
      'id': uuid ?? '',
      'aid': alterId ?? 0,
      'net': network ?? 'tcp',
      'type': 'none',
      'host': host,
      'path': path,
      'tls': tls,
      'sni': sni,
      'alpn': alpn,
      'allowInsecure': allowInsecure == true ? '1' : null,
      'peer': sni,
    };
    final jsonStr = vmess.entries
        .where((e) => e.value != null && e.value.toString().isNotEmpty)
        .map((e) => '${e.key}=${e.value}')
        .join('\n');
    final payload = base64Encode(utf8.encode(jsonStr));
    return 'vmess://$payload';
  }

  String _buildVlessConfig() {
    final params = <String, String>{
      'encryption': 'none',
      'flow': flow ?? 'xtls-rprx-direct',
      'security': tls == 'tls' ? 'tls' : (tls == 'reality' ? 'reality' : 'none'),
      'sni': sni ?? host ?? address,
      'fp': fingerprint ?? '',
      'alpn': alpn ?? '',
      'allowInsecure': allowInsecure == true ? '1' : '0',
      'publicKey': publicKey1 ?? '',
      'shortId': shortId ?? '',
      'path': path ?? '',
      'host': host ?? '',
    };
    params.removeWhere((key, value) => value.isEmpty);
    final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    return 'vless://$uuid@$address:$port?$query#$name';
  }

  String _buildShadowsocksConfig() {
    final pluginPart = (plugin != null && plugin!.isNotEmpty)
        ? '?plugin=${Uri.encodeComponent('$plugin$pluginOpts')}'
        : '';
    final userInfo = '$method:$password';
    return 'ss://${base64Encode(utf8.encode(userInfo))}@$address:$port$pluginPart#$name';
  }

  String _buildShadowsocksRConfig() {
    final params = [
      'protocol=$protocol',
      'protocol_param=${protocolParam ?? ''}',
      'obfs=$obfs',
      'obfs_param=${obfsParam ?? ''}',
    ].join(';');
    final userInfo = '$method:$password';
    final base64Params = base64Encode(utf8.encode(params));
    return 'ssr://${base64Encode(utf8.encode('$userInfo@$address:$port'))}/?$base64Params';
  }

  String _buildTrojanConfig() {
    final params = <String, String>{
      'sni': sni ?? host ?? address,
      'fp': fingerprint ?? '',
      'allowInsecure': allowInsecure == true ? '1' : '0',
      'alpn': alpn ?? '',
      'path': path ?? '',
      'host': host ?? '',
    };
    params.removeWhere((key, value) => value.isEmpty);
    final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    return 'trojan://$password@$address:$port?$query#$name';
  }

  String _buildWireGuardConfig() {
    return '''[Interface]
PrivateKey = $privateKey
Address = $username/24
MTU = ${mtu ?? 1420}
DNS = ${host ?? '1.1.1.1'}

[Peer]
PublicKey = $peerPublicKey
PresharedKey = ${presharedKey ?? ''}
AllowedIPs = 0.0.0.0/0
Endpoint = $address:$port
PersistentKeepalive = 25''';
  }

  String _buildHysteriaConfig() {
    final authStr = auth == true ? '$authUsername:$authPassword' : password ?? '';
    return '''server = $address:$port
auth = $authStr
up = ${speedLimitUp ?? '100 Mbps'}
down = ${speedLimitDown ?? '100 Mbps'}
obfs = $obfsPassword
allowInsecure = ${allowInsecure == true ? 'true' : 'false'}
sni = ${sni ?? host ?? address}
insecure_port = 0''';
  }

  String _buildHysteria2Config() {
    final params = <String, String?>{
      'sni': sni ?? host ?? address,
      'obfs': obfsPassword != null ? 'salamander:$obfsPassword' : null,
      'up': speedLimitUp != null ? '$speedLimitUp Mbps' : null,
      'down': speedLimitDown != null ? '$speedLimitDown Mbps' : null,
    };
    params.removeWhere((key, value) => value == null || value.isEmpty);
    final query = params.entries.where((e) => e.value != null).map((e) => '${e.key}=${e.value}').join('&');
    return 'hysteria2://$password@$address:$port?$query#$name';
  }

  String _buildHttpConfig() {
    final authPart = (auth == true && authUsername != null)
        ? '${Uri.encodeComponent(authUsername!)}:${Uri.encodeComponent(authPassword ?? '')}@'
        : '';
    return 'http://$authPart$address:$port';
  }

  String _buildSocks5Config() {
    final authPart = (auth == true && authUsername != null)
        ? '${Uri.encodeComponent(authUsername!)}:${Uri.encodeComponent(authPassword ?? '')}@'
        : '';
    return 'socks5://$authPart$address:$port';
  }

  @override
  List<Object?> get props => [
        id,
        name,
        address,
        port,
        protocol,
        uuid,
        latency,
        downloadSpeed,
        isActive,
      ];
}
