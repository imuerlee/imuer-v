import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/server_node.dart';
import 'config_parser_service.dart';

class SubscriptionService {
  static const String _subscriptionUrlKey = 'subscription_url';
  static const String _subscriptionNameKey = 'subscription_name';
  static const String _subscriptionServersKey = 'subscription_servers';

  final Dio _dio;
  final SharedPreferences _prefs;

  SubscriptionService({
    required SharedPreferences prefs,
    Dio? dio,
  })  : _prefs = prefs,
        _dio = dio ?? Dio();

  Future<String?> getSubscriptionUrl() async {
    return _prefs.getString(_subscriptionUrlKey);
  }

  Future<void> setSubscriptionUrl(String url) async {
    await _prefs.setString(_subscriptionUrlKey, url);
  }

  Future<String?> getSubscriptionName() async {
    return _prefs.getString(_subscriptionNameKey);
  }

  Future<void> setSubscriptionName(String name) async {
    await _prefs.setString(_subscriptionNameKey, name);
  }

  Future<void> clearSubscriptionUrl() async {
    await _prefs.remove(_subscriptionUrlKey);
    await _prefs.remove(_subscriptionNameKey);
  }

  Future<List<ServerNode>> fetchSubscriptionServers(String? customUrl) async {
    final url = customUrl ?? await getSubscriptionUrl();
    if (url == null || url.isEmpty) {
      throw Exception('No subscription URL configured');
    }

    try {
      final response = await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'User-Agent': 'ClashForAndroid/2.5.12',
          },
        ),
      );

      final content = response.data.toString();
      String decodedContent;

      try {
        decodedContent = utf8.decode(base64Decode(content));
      } catch (_) {
        try {
          decodedContent = utf8.decode(base64Decode(content.replaceAll('-', '+').replaceAll('_', '/')));
        } catch (_) {
          decodedContent = content;
        }
      }

      final servers = ConfigParserService.parseConfig(decodedContent);
      await _saveSubscriptionServers(servers);
      return servers;
    } on DioException catch (e) {
      throw Exception('Failed to fetch subscription: ${e.message}');
    }
  }

  Future<List<ServerNode>> getSavedSubscriptionServers() async {
    final jsonStr = _prefs.getString(_subscriptionServersKey);
    if (jsonStr == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList.map((json) => ConfigParserService.parseFromFile(jsonEncode(json)).first).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveSubscriptionServers(List<ServerNode> servers) async {
    final jsonList = servers.map((s) => s.toJson()).toList();
    await _prefs.setString(_subscriptionServersKey, jsonEncode(jsonList));
  }

  Future<void> clearSavedServers() async {
    await _prefs.remove(_subscriptionServersKey);
  }

  Future<SubscriptionInfo?> getSubscriptionInfo(String url) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'User-Agent': 'ClashForAndroid/2.5.12',
            'Accept-Encoding': 'identity',
          },
          receiveTimeout: const Duration(seconds: 10),
        ),
        queryParameters: {'_': DateTime.now().millisecondsSinceEpoch.toString()},
      );

      final headers = response.headers;
      
      int? upload;
      int? download;
      int? total;
      DateTime? expire;

      final uploadStr = headers.value('upload') ?? headers.value('X-Upload') ?? headers.value('x-upload');
      final downloadStr = headers.value('download') ?? headers.value('X-Download') ?? headers.value('x-download');
      final totalStr = headers.value('total') ?? headers.value('X-Total') ?? headers.value('x-total');
      final expireStr = headers.value('expire') ?? headers.value('X-Expire') ?? headers.value('x-expire') 
                      ?? headers.value('subscription-expire') ?? headers.value('X-Subscription-Expire');

      if (uploadStr != null) {
        upload = _parseBytesValue(uploadStr);
      }
      if (downloadStr != null) {
        download = _parseBytesValue(downloadStr);
      }
      if (totalStr != null) {
        total = _parseBytesValue(totalStr);
      }
      if (expireStr != null) {
        expire = _parseExpireValue(expireStr);
      }

      if (upload != null || download != null || total != null || expire != null) {
        return SubscriptionInfo(
          upload: upload,
          download: download,
          total: total,
          expire: expire,
        );
      }

      final contentLength = response.data.toString().length;
      if (contentLength > 0) {
        return SubscriptionInfo(
          download: contentLength,
          total: contentLength,
        );
      }
      
      return null;
    } catch (_) {
      return null;
    }
  }

  int? _parseBytesValue(String value) {
    final match = RegExp(r'^(\d+(?:\.\d+)?)\s*([KMGT]?B?)?$', caseSensitive: false).firstMatch(value);
    if (match != null) {
      final num = double.tryParse(match.group(1)!);
      if (num != null) {
        final unit = (match.group(2) ?? 'B').toUpperCase();
        int multiplier = 1;
        switch (unit) {
          case 'K':
          case 'KB':
            multiplier = 1024;
            break;
          case 'M':
          case 'MB':
            multiplier = 1024 * 1024;
            break;
          case 'G':
          case 'GB':
            multiplier = 1024 * 1024 * 1024;
            break;
          case 'T':
          case 'TB':
            multiplier = 1024 * 1024 * 1024 * 1024;
            break;
        }
        return (num * multiplier).round();
      }
    }
    return int.tryParse(value);
  }

  DateTime? _parseExpireValue(String value) {
    final timestamp = int.tryParse(value);
    if (timestamp != null) {
      if (timestamp > 1e12) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else {
        return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      }
    }
    
    final isoDate = DateTime.tryParse(value);
    if (isoDate != null) {
      return isoDate;
    }
    
    final durationMatch = RegExp(r'^(\d+)\s*(hour|day|week|month)s?$', caseSensitive: false).firstMatch(value);
    if (durationMatch != null) {
      final amount = int.tryParse(durationMatch.group(1)!);
      final unit = durationMatch.group(2)!.toLowerCase();
      if (amount != null) {
        final now = DateTime.now();
        switch (unit) {
          case 'hour':
            return now.add(Duration(hours: amount));
          case 'day':
            return now.add(Duration(days: amount));
          case 'week':
            return now.add(Duration(days: amount * 7));
          case 'month':
            return DateTime(now.year, now.month + amount, now.day);
        }
      }
    }
    
    return null;
  }
}

class SubscriptionInfo {
  final int? upload;
  final int? download;
  final int? total;
  final DateTime? expire;

  SubscriptionInfo({
    this.upload,
    this.download,
    this.total,
    this.expire,
  });

  int get used => (upload ?? 0) + (download ?? 0);
  int? get remaining => total != null ? total! - used : null;
  bool get isExpired => expire != null && expire!.isBefore(DateTime.now());
}
