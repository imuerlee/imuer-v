import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import '../../domain/entities/server_node.dart';

/// VPN 服务 - 通过平台通道控制实际的 VPN 核心
class VpnService {
  static const MethodChannel _methodChannel = MethodChannel('nebula_vpn/method');
  static const EventChannel _eventChannel = EventChannel('nebula_vpn/events');

  StreamSubscription? _eventSubscription;
  final _onEventController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get eventStream => _onEventController.stream;

  VpnService() {
    _setupEventChannel();
  }

  void _setupEventChannel() {
    _eventSubscription = _eventChannel
        .receiveBroadcastStream()
        .listen((event) {
      if (event is Map) {
        _onEventController.add(Map<String, dynamic>.from(event));
      }
    });
  }

  /// 启动 VPN 连接
  Future<bool> connect(ServerNode server) async {
    try {
      final config = server.toJson();
      print('VpnService.connect: config = $config');
      print('VpnService.connect: server = ${server.name}, ${server.address}, ${server.port}');
      
      if (Platform.isWindows) {
        // Windows: 调用 v2ray-core
        final result = await _methodChannel.invokeMethod<bool>('connect', {
          'config': config,
          'platform': 'windows',
        });
        print('VpnService.connect: Windows result = $result');
        return result ?? false;
      } else if (Platform.isAndroid) {
        // Android: 使用系统 VPN Service
        print('VpnService.connect: Calling Android method channel...');
        final result = await _methodChannel.invokeMethod<bool>('connect', {
          'config': config,
          'platform': 'android',
        });
        print('VpnService.connect: Android result = $result');
        return result ?? false;
      }
      
      return false;
    } on PlatformException catch (e) {
      print('VpnService.connect: PlatformException = ${e.code}, ${e.message}');
      // 区分不同类型的错误
      if (e.code == 'UNAVAILABLE') {
        // 服务未启动
        return false;
      } else if (e.code == 'PERMISSION_DENIED') {
        // 权限不足
        return false;
      } else if (e.code == 'CONFIG_ERROR') {
        // 配置错误
        return false;
      }
      return false;
    } catch (e) {
      print('VpnService.connect: Exception = $e');
      return false;
    }
  }

  /// 断开 VPN 连接
  Future<bool> disconnect() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('disconnect');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// 获取连接状态
  Future<Map<String, dynamic>> getStatus() async {
    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>('getStatus');
      if (result == null) {
        return {'error': 'Service not available'};
      }
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      // 详细记录错误信息
      final errorDetails = {
        'error': e.code,
        'message': e.message ?? 'Unknown platform error',
        'details': e.details,
      };
      return errorDetails;
    } catch (e) {
      return {
        'error': 'UnexpectedError',
        'message': e.toString(),
      };
    }
  }

  /// 测试延迟
  Future<int> testLatency(String host, int port) async {
    try {
      final stopwatch = Stopwatch()..start();
      final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      stopwatch.stop();
      await socket.close();
      return stopwatch.elapsedMilliseconds;
    } catch (e) {
      return -1;
    }
  }

  void dispose() {
    _eventSubscription?.cancel();
    _onEventController.close();
  }
}
