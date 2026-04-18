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
      final response = await _dio.head(
        url,
        options: Options(
          headers: {
            'User-Agent': 'ClashForAndroid/2.5.12',
          },
        ),
      );

      final upload = response.headers.value('upload');
      final download = response.headers.value('download');
      final total = response.headers.value('total');
      final expire = response.headers.value('expire');

      return SubscriptionInfo(
        upload: upload != null ? int.tryParse(upload) : null,
        download: download != null ? int.tryParse(download) : null,
        total: total != null ? int.tryParse(total) : null,
        expire: expire != null ? DateTime.tryParse(expire) : null,
      );
    } catch (_) {
      return null;
    }
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
