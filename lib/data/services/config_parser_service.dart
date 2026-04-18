import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../domain/entities/server_node.dart';

class ConfigParserService {
  static const _uuid = Uuid();

  static List<ServerNode> parseConfig(String config) {
    final trimmed = config.trim();
    final lines = trimmed.split('\n');
    final servers = <ServerNode>[];

    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      try {
        if (trimmedLine.startsWith('vmess://')) {
          final server = _parseVmess(trimmedLine.substring(8));
          if (server != null) servers.add(server);
        } else if (trimmedLine.startsWith('vless://')) {
          final server = _parseVless(trimmedLine);
          if (server != null) servers.add(server);
        } else if (trimmedLine.startsWith('ss://')) {
          final server = _parseShadowsocks(trimmedLine);
          if (server != null) servers.add(server);
        } else if (trimmedLine.startsWith('ssr://')) {
          final server = _parseShadowsocksR(trimmedLine.substring(6));
          if (server != null) servers.add(server);
        } else if (trimmedLine.startsWith('trojan://')) {
          final server = _parseTrojan(trimmedLine);
          if (server != null) servers.add(server);
        } else if (trimmedLine.startsWith('wireguard://')) {
          final server = _parseWireGuard(trimmedLine.substring(13));
          if (server != null) servers.add(server);
        } else if (trimmedLine.startsWith('hysteria://')) {
          final server = _parseHysteria(trimmedLine);
          if (server != null) servers.add(server);
        } else if (trimmedLine.startsWith('hysteria2://')) {
          final server = _parseHysteria2(trimmedLine);
          if (server != null) servers.add(server);
        } else if (trimmedLine.startsWith('http://') || trimmedLine.startsWith('https://')) {
          final server = _parseHttp(trimmedLine);
          if (server != null) servers.add(server);
        } else if (trimmedLine.startsWith('socks5://') || trimmedLine.startsWith('socks://')) {
          final server = _parseSocks5(trimmedLine);
          if (server != null) servers.add(server);
        }
      } catch (_) {
        continue;
      }
    }

    return servers;
  }

  static ServerNode? _parseVmess(String config) {
    try {
      String jsonStr;
      try {
        jsonStr = utf8.decode(base64Decode(config));
      } catch (_) {
        jsonStr = utf8.decode(base64Decode(config.replaceAll('-', '+').replaceAll('_', '/')));
      }
      
      final Map<String, String> params = {};
      for (final line in jsonStr.split('\n')) {
        final idx = line.indexOf('=');
        if (idx > 0) {
          params[line.substring(0, idx)] = line.substring(idx + 1);
        }
      }

      return ServerNode(
        id: _uuid.v4(),
        name: params['ps'] ?? 'VMess Server',
        address: params['add'] ?? '',
        port: int.tryParse(params['port'] ?? '0') ?? 0,
        protocol: ServerProtocol.vmess,
        uuid: params['id'],
        alterId: int.tryParse(params['aid'] ?? '0'),
        security: params['scy'] ?? params['security'],
        network: params['net'],
        tls: params['tls'],
        host: params['host'],
        path: params['path'],
        sni: params['sni'] ?? params['peer'],
        alpn: params['alpn'],
        allowInsecure: params['allowInsecure'] == '1',
        country: _estimateCountry(params['add'] ?? ''),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  static ServerNode? _parseVless(String config) {
    try {
      final uri = Uri.parse(config);
      final fingerprint = uri.queryParameters['fp'];
      final publicKey = uri.queryParameters['publicKey'];

      return ServerNode(
        id: _uuid.v4(),
        name: uri.fragment.isNotEmpty ? Uri.decodeComponent(uri.fragment) : 'VLESS Server',
        address: uri.host,
        port: uri.port > 0 ? uri.port : 443,
        protocol: ServerProtocol.vless,
        uuid: uri.userInfo,
        tls: uri.queryParameters['security'] == 'reality' ? 'reality' : 'tls',
        sni: uri.queryParameters['sni'] ?? uri.queryParameters['host'],
        flow: uri.queryParameters['flow'],
        fingerprint: fingerprint,
        alpn: uri.queryParameters['alpn'],
        allowInsecure: uri.queryParameters['allowInsecure'] == '1',
        path: uri.queryParameters['path'],
        host: uri.queryParameters['host'],
        publicKey1: publicKey,
        shortId: uri.queryParameters['shortId'],
        country: _estimateCountry(uri.host),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  static ServerNode? _parseShadowsocks(String config) {
    try {
      String uriStr = config;
      String? plugin;
      String? pluginOpts;

      if (config.contains('?')) {
        final parts = config.split('?');
        uriStr = parts[0];
        final pluginStr = Uri.decodeComponent(parts[1].replaceFirst('plugin=', ''));
        if (pluginStr.contains(';')) {
          plugin = pluginStr.split(';')[0];
          pluginOpts = pluginStr.substring(plugin.length + 1);
        } else {
          plugin = pluginStr;
        }
      }

      uriStr = uriStr.substring(5);
      final atIndex = uriStr.indexOf('@');
      final colonIndex = uriStr.lastIndexOf(':');
      final hashIndex = uriStr.indexOf('#');
      
      String methodPassword;
      if (atIndex > 0) {
        methodPassword = utf8.decode(base64Decode(uriStr.substring(0, atIndex)));
      } else {
        methodPassword = utf8.decode(base64Decode(uriStr.substring(0, colonIndex)));
      }
      
      final mpParts = methodPassword.split(':');
      final method = mpParts[0];
      final password = mpParts.length > 1 ? mpParts[1] : '';

      String address = '', portStr = '', name = 'Shadowsocks Server';
      
      if (atIndex > 0) {
        final hostPart = uriStr.substring(atIndex + 1);
        if (hashIndex > 0) {
          address = hostPart.substring(0, colonIndex - atIndex - 1);
          portStr = hostPart.substring(colonIndex - atIndex, hashIndex - atIndex - 1);
          name = Uri.decodeComponent(hostPart.substring(hashIndex + 1));
        } else {
          address = hostPart.substring(0, colonIndex - atIndex - 1);
          portStr = hostPart.substring(colonIndex - atIndex);
        }
      } else {
        return null;
      }

      return ServerNode(
        id: _uuid.v4(),
        name: name,
        address: address,
        port: int.tryParse(portStr) ?? 0,
        protocol: ServerProtocol.ss,
        method: method,
        password: password,
        plugin: plugin,
        pluginOpts: pluginOpts,
        country: _estimateCountry(address),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  static ServerNode? _parseShadowsocksR(String config) {
    try {
      final jsonStr = utf8.decode(base64Decode(config.replaceAll('-', '+').replaceAll('_', '/')));
      final atIndex = jsonStr.indexOf('@');
      final colonIndex = jsonStr.lastIndexOf(':');
      final questionIndex = jsonStr.indexOf('?');
      
      if (atIndex < 0 || colonIndex < 0) return null;

      final methodPassword = jsonStr.substring(0, atIndex);
      final hostPort = jsonStr.substring(atIndex + 1, questionIndex > 0 ? questionIndex : jsonStr.length);
      final lastColon = hostPort.lastIndexOf(':');
      
      final address = hostPort.substring(0, lastColon);
      final port = int.tryParse(hostPort.substring(lastColon + 1)) ?? 0;
      
      final methodParts = methodPassword.split(':');
      final method = methodParts[0];
      final password = methodParts.length > 1 ? methodParts[1] : '';

      String? paramsStr;
      if (questionIndex > 0) {
        paramsStr = utf8.decode(base64Decode(jsonStr.substring(questionIndex + 1).replaceAll('-', '+').replaceAll('_', '/')));
        final paramParts = paramsStr.split(';');
        String? protocolParam, obfs, obfsParam;
        
        for (final p in paramParts) {
          if (p.startsWith('protocol=')) protocol = p.substring(9);
          if (p.startsWith('protocol_param=')) protocolParam = p.substring(16);
          if (p.startsWith('obfs=')) obfs = p.substring(5);
          if (p.startsWith('obfs_param=')) obfsParam = p.substring(11);
        }

        return ServerNode(
          id: _uuid.v4(),
          name: 'ShadowsocksR Server',
          address: address,
          port: port,
          protocol: ServerProtocol.ssr,
          method: method,
          password: password,
          protocolParam: protocolParam,
          obfs: obfs,
          obfsParam: obfsParam,
          country: _estimateCountry(address),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  static ServerNode? _parseTrojan(String config) {
    try {
      final uri = Uri.parse(config);
      final fingerprint = uri.queryParameters['fp'];
      final allowInsecure = uri.queryParameters['allowInsecure'];

      return ServerNode(
        id: _uuid.v4(),
        name: uri.fragment.isNotEmpty ? Uri.decodeComponent(uri.fragment) : 'Trojan Server',
        address: uri.host,
        port: uri.port > 0 ? uri.port : 443,
        protocol: ServerProtocol.trojan,
        password: uri.userInfo,
        sni: uri.queryParameters['sni'] ?? uri.queryParameters['host'],
        fingerprint: fingerprint,
        allowInsecure: allowInsecure == '1',
        alpn: uri.queryParameters['alpn'],
        path: uri.queryParameters['path'],
        host: uri.queryParameters['host'],
        country: _estimateCountry(uri.host),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  static ServerNode? _parseWireGuard(String config) {
    try {
      final lines = config.split('\n');
      String? privateKey, address, dns;
      String? peerPublicKey;
      String? presharedKey;
      int? mtu;
      String endpoint = '';
      int port = 51820;

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('PrivateKey = ')) {
          privateKey = trimmed.substring(13);
        } else if (trimmed.startsWith('Address = ')) {
          address = trimmed.substring(11);
        } else if (trimmed.startsWith('DNS = ')) {
          dns = trimmed.substring(6);
        } else if (trimmed.startsWith('PublicKey = ')) {
          peerPublicKey = trimmed.substring(12);
        } else if (trimmed.startsWith('PresharedKey = ')) {
          presharedKey = trimmed.substring(16);
        } else if (trimmed.startsWith('MTU = ')) {
          mtu = int.tryParse(trimmed.substring(5));
        } else if (trimmed.startsWith('Endpoint = ')) {
          final ep = trimmed.substring(12);
          final lastColon = ep.lastIndexOf(':');
          endpoint = ep.substring(0, lastColon);
          port = int.tryParse(ep.substring(lastColon + 1)) ?? 51820;
        }
      }

      return ServerNode(
        id: _uuid.v4(),
        name: 'WireGuard Server',
        address: endpoint,
        port: port,
        protocol: ServerProtocol.wireguard,
        username: address,
        privateKey: privateKey,
        peerPublicKey: peerPublicKey,
        presharedKey: presharedKey,
        mtu: mtu,
        host: dns,
        country: _estimateCountry(endpoint),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  static ServerNode? _parseHysteria(String config) {
    try {
      final lines = config.split('\n');
      String? server, auth;
      int? up, down;
      String? obfsPassword, sni;
      bool? insecure;

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('server = ')) {
          final addr = trimmed.substring(9);
          final lastColon = addr.lastIndexOf(':');
          server = addr.substring(0, lastColon);
        } else if (trimmed.startsWith('auth = ')) {
          auth = trimmed.substring(7);
        } else if (trimmed.startsWith('up = ')) {
          up = _parseSpeed(trimmed.substring(5));
        } else if (trimmed.startsWith('down = ')) {
          down = _parseSpeed(trimmed.substring(7));
        } else if (trimmed.startsWith('obfs = ')) {
          obfsPassword = trimmed.substring(7);
        } else if (trimmed.startsWith('sni = ')) {
          sni = trimmed.substring(6);
        } else if (trimmed.startsWith('allowInsecure = ')) {
          insecure = trimmed.substring(16) == 'true';
        }
      }

      String? username, password;
      if (auth != null && auth.contains(':')) {
        final parts = auth.split(':');
        username = parts[0];
        password = parts[1];
      } else {
        password = auth;
      }

      return ServerNode(
        id: _uuid.v4(),
        name: 'Hysteria Server',
        address: server ?? '',
        port: 443,
        protocol: ServerProtocol.hysteria,
        authUsername: username,
        authPassword: password,
        speedLimitUp: up,
        speedLimitDown: down,
        obfsPassword: obfsPassword,
        sni: sni,
        allowInsecure: insecure,
        country: _estimateCountry(server ?? ''),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  static ServerNode? _parseHysteria2(String config) {
    try {
      final uri = Uri.parse(config);
      final obfs = uri.queryParameters['obfs'];
      final up = uri.queryParameters['up'];
      final down = uri.queryParameters['down'];

      return ServerNode(
        id: _uuid.v4(),
        name: uri.fragment.isNotEmpty ? Uri.decodeComponent(uri.fragment) : 'Hysteria2 Server',
        address: uri.host,
        port: uri.port > 0 ? uri.port : 443,
        protocol: ServerProtocol.hysteria2,
        password: uri.userInfo,
        obfsPassword: obfs != null && obfs.contains(':') ? obfs.split(':')[1] : null,
        speedLimitUp: up != null ? _parseSpeed(up) : null,
        speedLimitDown: down != null ? _parseSpeed(down) : null,
        sni: uri.queryParameters['sni'],
        country: _estimateCountry(uri.host),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  static ServerNode? _parseHttp(String config) {
    try {
      final uri = Uri.parse(config);
      final hasAuth = uri.userInfo.isNotEmpty;

      return ServerNode(
        id: _uuid.v4(),
        name: 'HTTP Server',
        address: uri.host,
        port: uri.port > 0 ? uri.port : (uri.scheme == 'https' ? 443 : 80),
        protocol: ServerProtocol.http,
        auth: hasAuth,
        authUsername: hasAuth ? Uri.decodeComponent(uri.userInfo.split(':')[0]) : null,
        authPassword: hasAuth && uri.userInfo.contains(':') 
            ? Uri.decodeComponent(uri.userInfo.split(':')[1]) 
            : null,
        country: _estimateCountry(uri.host),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  static ServerNode? _parseSocks5(String config) {
    try {
      String uriStr = config;
      if (uriStr.startsWith('socks://')) {
        uriStr = 'socks5://${uriStr.substring(7)}';
      }
      final uri = Uri.parse(uriStr);
      final hasAuth = uri.userInfo.isNotEmpty;

      return ServerNode(
        id: _uuid.v4(),
        name: 'SOCKS5 Server',
        address: uri.host,
        port: uri.port > 0 ? uri.port : 1080,
        protocol: ServerProtocol.socks5,
        auth: hasAuth,
        authUsername: hasAuth ? Uri.decodeComponent(uri.userInfo.split(':')[0]) : null,
        authPassword: hasAuth && uri.userInfo.contains(':') 
            ? Uri.decodeComponent(uri.userInfo.split(':')[1]) 
            : null,
        country: _estimateCountry(uri.host),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  static int _parseSpeed(String speed) {
    final match = RegExp(r'(\d+)').firstMatch(speed);
    if (match != null) {
      return int.parse(match.group(1)!);
    }
    return 100;
  }

  static String _estimateCountry(String address) {
    final lower = address.toLowerCase();
    if (lower.contains('us') || lower.contains('usa') || lower.contains('united states')) return 'United States';
    if (lower.contains('uk') || lower.contains('gb') || lower.contains('united kingdom')) return 'United Kingdom';
    if (lower.contains('jp') || lower.contains('japan')) return 'Japan';
    if (lower.contains('sg') || lower.contains('singapore')) return 'Singapore';
    if (lower.contains('hk') || lower.contains('hong kong')) return 'Hong Kong';
    if (lower.contains('de') || lower.contains('germany')) return 'Germany';
    if (lower.contains('fr') || lower.contains('france')) return 'France';
    if (lower.contains('au') || lower.contains('australia')) return 'Australia';
    if (lower.contains('ca') || lower.contains('canada')) return 'Canada';
    if (lower.contains('nl') || lower.contains('netherlands')) return 'Netherlands';
    if (lower.contains('kr') || lower.contains('korea') || lower.contains('south korea')) return 'South Korea';
    if (lower.contains('tw') || lower.contains('taiwan')) return 'Taiwan';
    if (lower.contains('ru') || lower.contains('russia')) return 'Russia';
    if (lower.contains('in') || lower.contains('india')) return 'India';
    if (lower.contains('br') || lower.contains('brazil')) return 'Brazil';
    return 'Unknown';
  }

  static List<ServerNode> parseFromBase64(String base64Content) {
    try {
      final decoded = utf8.decode(base64Decode(base64Content.replaceAll('-', '+').replaceAll('_', '/')));
      return parseConfig(decoded);
    } catch (_) {
      return [];
    }
  }

  static List<ServerNode> parseFromFile(String content) {
    if (content.contains('vmess://') || 
        content.contains('vless://') || 
        content.contains('ss://') ||
        content.contains('ssr://') ||
        content.contains('trojan://') ||
        content.contains('hysteria') ||
        content.contains('wireguard://') ||
        content.contains('http://') ||
        content.contains('socks5://')) {
      return parseConfig(content);
    }
    
    try {
      final json = jsonDecode(content);
      if (json is List) {
        return json.map((item) => _serverNodeModelFromJson(item as Map<String, dynamic>)).toList();
      } else if (json is Map && json['servers'] != null) {
        return (json['servers'] as List)
            .map((item) => _serverNodeModelFromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    
    return [];
  }

  static ServerNode _serverNodeModelFromJson(Map<String, dynamic> json) {
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
      isActive: json['isActive'] == true || json['isActive'] == 1,
      groupId: json['groupId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
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
    );
  }
}
