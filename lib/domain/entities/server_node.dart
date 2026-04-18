import 'package:equatable/equatable.dart';

enum ServerProtocol {
  vmess,
  vless,
  shadowsocks,
  trojan,
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
    );
  }

  String get configString {
    switch (protocol) {
      case ServerProtocol.vmess:
        return _buildVmessConfig();
      case ServerProtocol.vless:
        return _buildVlessConfig();
      case ServerProtocol.shadowsocks:
        return _buildShadowsocksConfig();
      case ServerProtocol.trojan:
        return _buildTrojanConfig();
    }
  }

  String _buildVmessConfig() {
    final Map<String, dynamic> vmess = {
      'v': '2',
      'ps': name,
      'add': address,
      'port': port,
      'id': uuid,
      'aid': alterId ?? 0,
      'net': network ?? 'tcp',
      'type': 'none',
      'host': host,
      'path': path,
      'tls': tls,
    };
    return vmess.entries
        .where((e) => e.value != null)
        .map((e) => '${e.key}=${e.value}')
        .join('\n');
  }

  String _buildVlessConfig() {
    return 'vless://$uuid@$address:$port?encryption=none&flow=xtls-rprx-direct&security=xtls&sni=$sni#$name';
  }

  String _buildShadowsocksConfig() {
    return 'ss://${_encodeBase64('$username:$password')}@$address:$port#$name';
  }

  String _buildTrojanConfig() {
    return 'trojan://$password@$address:$port?security=tls&sni=$sni#$name';
  }

  String _encodeBase64(String input) {
    final bytes = input.codeUnits;
    final base64Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final buffer = StringBuffer();
    for (var i = 0; i < bytes.length; i += 3) {
      final b1 = bytes[i];
      final b2 = i + 1 < bytes.length ? bytes[i + 1] : 0;
      final b3 = i + 2 < bytes.length ? bytes[i + 2] : 0;
      buffer.write(base64Chars[(b1 >> 2) & 0x3F]);
      buffer.write(base64Chars[((b1 << 4) | (b2 >> 4)) & 0x3F]);
      buffer.write(i + 1 < bytes.length ? base64Chars[((b2 << 2) | (b3 >> 6)) & 0x3F] : '=');
      buffer.write(i + 2 < bytes.length ? base64Chars[b3 & 0x3F] : '=');
    }
    return buffer.toString();
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
