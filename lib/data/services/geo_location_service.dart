import 'dart:convert';
import 'package:dio/dio.dart';
import '../../domain/entities/server_node.dart';

class GeoLocationService {
  static final Dio _dio = Dio();
  static final Map<String, _GeoCache> _cache = {};
  static const _cacheDuration = Duration(hours: 24);

  Future<ServerNode> lookupServerLocation(ServerNode server) async {
    if (server.address.isEmpty) {
      return server;
    }

    if (_isIpAddress(server.address)) {
      return _lookupIpAddress(server);
    } else {
      return _lookupDomain(server);
    }
  }

  bool _isIpAddress(String address) {
    final ipv4Regex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    final ipv6Regex = RegExp(r'^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$');
    return ipv4Regex.hasMatch(address) || ipv6Regex.hasMatch(address);
  }

  Future<ServerNode> _lookupIpAddress(ServerNode server) async {
    final cached = _getCached(server.address);
    if (cached != null) {
      return _applyGeoData(server, cached);
    }

    try {
      final response = await _dio.get(
        'http://ip-api.com/json/${server.address}',
        options: Options(
          responseType: ResponseType.json,
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final geoData = _GeoData.fromApiResponse(data);
        _cache[server.address] = _GeoCache(geoData, DateTime.now());
        return _applyGeoData(server, geoData);
      }
    } catch (e) {
      // Fall back to domain lookup
    }

    return _lookupDomain(server);
  }

  Future<ServerNode> _lookupDomain(ServerNode server) async {
    final cached = _getCached(server.address);
    if (cached != null) {
      return _applyGeoData(server, cached);
    }

    try {
      final response = await _dio.get(
        'https://ipapi.co/json/',
        queryParameters: {'hostname': server.address},
        options: Options(
          responseType: ResponseType.json,
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final geoData = _GeoData.fromIpApiResponse(data);
        _cache[server.address] = _GeoCache(geoData, DateTime.now());
        return _applyGeoData(server, geoData);
      }
    } catch (e) {
      // Continue with fallback
    }

    return _applyFallbackCountry(server);
  }

  _GeoData? _getCached(String address) {
    final cached = _cache[address];
    if (cached != null) {
      if (DateTime.now().difference(cached.timestamp) < _cacheDuration) {
        return cached.data;
      }
      _cache.remove(address);
    }
    return null;
  }

  ServerNode _applyGeoData(ServerNode server, _GeoData data) {
    return server.copyWith(
      country: data.country,
      city: data.city,
      latitude: data.latitude,
      longitude: data.longitude,
    );
  }

  ServerNode _applyFallbackCountry(ServerNode server) {
    final country = _fallbackCountryLookup(server.address);
    if (country != null && country != 'Unknown') {
      return server.copyWith(country: country);
    }
    return server;
  }

  String _fallbackCountryLookup(String address) {
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

  static void clearCache() {
    _cache.clear();
  }
}

class _GeoData {
  final String country;
  final String city;
  final double? latitude;
  final double? longitude;

  _GeoData({
    required this.country,
    required this.city,
    this.latitude,
    this.longitude,
  });

  factory _GeoData.fromApiResponse(Map<String, dynamic> data) {
    return _GeoData(
      country: data['country'] as String? ?? 'Unknown',
      city: data['city'] as String? ?? '',
      latitude: (data['lat'] as num?)?.toDouble(),
      longitude: (data['lon'] as num?)?.toDouble(),
    );
  }

  factory _GeoData.fromIpApiResponse(Map<String, dynamic> data) {
    return _GeoData(
      country: data['country_name'] as String? ?? 'Unknown',
      city: data['city'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
    );
  }
}

class _GeoCache {
  final _GeoData data;
  final DateTime timestamp;

  _GeoCache(this.data, this.timestamp);
}
