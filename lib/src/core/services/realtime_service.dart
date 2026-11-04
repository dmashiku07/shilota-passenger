import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../features/account/domain/account_models.dart';
import '../config/app_config.dart';
import '../storage/session_storage.dart';
import '../storage/storage_providers.dart';

final activeCallRoomProvider = StateProvider<String?>((ref) => null);

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  final service = RealtimeService(
    sessionStorage: ref.watch(sessionStorageProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

class RealtimeService {
  RealtimeService({
    required this.sessionStorage,
  });

  final SessionStorage sessionStorage;
  io.Socket? _socket;
  bool _connecting = false;
  Completer<void>? _connectCompleter;
  Timer? _reconnectTimer;
  bool _disposed = false;

  final _incomingCallController =
      StreamController<IncomingCallEvent>.broadcast();
  final _incomingChatController = StreamController<RideChatMessage>.broadcast();
  final _callEndedController = StreamController<String>.broadcast();
  final _callReadyController = StreamController<String>.broadcast();
  final _rtcMessageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _byeController = StreamController<String>.broadcast();
  final _driverLocationController =
      StreamController<DriverLocationUpdate>.broadcast();
  final Set<String> _joinedCallRooms = <String>{};
  final Set<String> _readyCallRooms = <String>{};
  final Set<String> _watchedRideLocations = <String>{};
  final List<Map<String, dynamic>> _pendingRtcMessages =
      <Map<String, dynamic>>[];

  Stream<IncomingCallEvent> get incomingCalls => _incomingCallController.stream;
  Stream<RideChatMessage> get incomingChats => _incomingChatController.stream;
  Stream<String> get callEnded => _callEndedController.stream;
  Stream<String> get callReady => _callReadyController.stream;
  Stream<Map<String, dynamic>> get rtcMessages => _rtcMessageController.stream;
  Stream<String> get callBye => _byeController.stream;
  Stream<DriverLocationUpdate> get driverLocations =>
      _driverLocationController.stream;

  io.Socket? get socket => _socket;

  Future<void> connect() async {
    if (_socket?.connected == true) {
      return;
    }
    if (_connecting) {
      return _connectCompleter?.future.timeout(const Duration(seconds: 20));
    }
    final userId = sessionStorage.userId?.toString().trim() ?? '';
    if (userId.isEmpty) {
      return;
    }
    _connecting = true;
    final connectCompleter = Completer<void>();
    _connectCompleter = connectCompleter;
    final socketOptions = io.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .enableForceNew()
        .disableMultiplex()
        // Engine.IO 3 in socket_io_client 1.0.2 loses the explicit HTTPS
        // port during its built-in reconnect and retries against port 0.
        // Recreate the socket ourselves instead.
        .disableReconnection()
        .setTimeout(20000)
        .setQuery(<String, dynamic>{
          'user_id': userId,
          'user_type': 'user',
        })
        .build()
      ..['hostname'] = Uri.parse(AppConfig.socketUrl).host
      ..['secure'] = true
      ..['port'] = 443
      // Engine.IO 3 rebuilds transport options during reconnect. Pinning the
      // transport itself prevents its URI parser from falling back to port 0.
      ..['transportOptions'] = <String, dynamic>{
        'websocket': <String, dynamic>{
          'hostname': 'shilota.tz',
          'secure': true,
          'port': 443,
        },
      };
    final socket = io.io(AppConfig.socketUrl, socketOptions);

    socket.onConnect((_) {
      debugPrint('Realtime socket connected: ${socket.id}');
      socket.emit('register-user', <String, dynamic>{
        'user_id': userId,
        'user_type': 'user',
      });
      for (final roomId in _joinedCallRooms) {
        socket.emit('join-call', <String, dynamic>{
          'room_id': roomId,
          'user_id': userId,
        });
      }
      for (final roomId in _readyCallRooms) {
        socket.emit('ready-call', <String, dynamic>{
          'room_id': roomId,
          'user_id': userId,
        });
      }
      for (final message in List<Map<String, dynamic>>.from(
        _pendingRtcMessages,
      )) {
        socket.emit('rtcmessage', message);
      }
      _pendingRtcMessages.clear();
      for (final rideId in _watchedRideLocations) {
        _emitRideLocationWatch(socket, rideId);
      }
      _connecting = false;
      if (!connectCompleter.isCompleted) {
        connectCompleter.complete();
      }
    });
    socket.onConnectError((dynamic error) {
      debugPrint('Realtime socket connect error: $error');
      _connecting = false;
      if (identical(_socket, socket)) {
        _socket = null;
      }
      socket.dispose();
      if (!connectCompleter.isCompleted) {
        connectCompleter.completeError(
          StateError('Unable to connect call signaling: $error'),
        );
      }
      _scheduleReconnect();
    });
    socket.onError((dynamic error) {
      debugPrint('Realtime socket error: $error');
    });
    socket.on('incoming-call', (payload) {
      final mapped = _asMap(payload);
      if (mapped.isEmpty) {
        return;
      }
      _incomingCallController.add(IncomingCallEvent.fromJson(mapped));
    });
    socket.on('incoming-chat', (payload) {
      final mapped = _asMap(payload);
      if (mapped.isEmpty) {
        return;
      }
      _incomingChatController.add(RideChatMessage.fromJson(mapped));
    });
    socket.on('end-call', (payload) {
      final mapped = _asMap(payload);
      final roomId = mapped['room_id']?.toString() ?? '';
      if (roomId.isNotEmpty) {
        _callEndedController.add(roomId);
      }
    });
    socket.on('call-ready', (payload) {
      final roomId = _asMap(payload)['room_id']?.toString() ?? '';
      if (roomId.isNotEmpty) {
        _callReadyController.add(roomId);
      }
    });
    socket.on('rtcmessage', (payload) {
      final mapped = _asMap(payload);
      if (mapped.isNotEmpty) {
        _rtcMessageController.add(mapped);
      }
    });
    socket.on('bye', (payload) {
      final mapped = _asMap(payload);
      final roomId =
          payload is String ? payload : mapped['room_id']?.toString() ?? '';
      if (roomId.isNotEmpty) {
        _joinedCallRooms.remove(roomId);
        _byeController.add(roomId);
      }
    });
    socket.on('ride-driver-location', (payload) {
      final update = DriverLocationUpdate.fromJson(_asMap(payload));
      if (update != null) {
        _driverLocationController.add(update);
      }
    });
    socket.onDisconnect((_) {
      if (identical(_socket, socket)) {
        _socket = null;
      }
      _connecting = false;
      _scheduleReconnect();
    });
    _socket = socket;
    socket.connect();
    await connectCompleter.future.timeout(const Duration(seconds: 20));
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnectTimer?.isActive == true) {
      return;
    }
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      if (!_disposed) {
        unawaited(connect().catchError((_) {}));
      }
    });
  }

  void joinCall(String roomId) {
    _joinedCallRooms.add(roomId);
    _socket?.emit('join-call', <String, dynamic>{
      'room_id': roomId,
      'user_id': sessionStorage.userId,
    });
  }

  void readyCall(String roomId) {
    _readyCallRooms.add(roomId);
    _socket?.emit('ready-call', <String, dynamic>{
      'room_id': roomId,
      'user_id': sessionStorage.userId,
    });
  }

  void sendRtcMessage(Map<String, dynamic> payload) {
    final socket = _socket;
    if (socket?.connected == true) {
      socket?.emit('rtcmessage', payload);
    } else {
      if (_pendingRtcMessages.length >= 100) {
        _pendingRtcMessages.removeAt(0);
      }
      _pendingRtcMessages.add(Map<String, dynamic>.from(payload));
      _scheduleReconnect();
    }
  }

  void sendBye(String roomId) {
    _joinedCallRooms.remove(roomId);
    _readyCallRooms.remove(roomId);
    _socket?.emit('bye', <String, dynamic>{
      'room_id': roomId,
    });
  }

  void watchRideLocation(String rideId) {
    final normalizedRideId = rideId.trim();
    if (normalizedRideId.isEmpty) {
      return;
    }
    _watchedRideLocations.add(normalizedRideId);
    final socket = _socket;
    if (socket?.connected == true) {
      _emitRideLocationWatch(socket!, normalizedRideId);
    }
  }

  void unwatchRideLocation(String rideId) {
    final normalizedRideId = rideId.trim();
    if (normalizedRideId.isEmpty) {
      return;
    }
    _watchedRideLocations.remove(normalizedRideId);
    _socket?.emit('unwatch-ride-location', <String, dynamic>{
      'ride_id': normalizedRideId,
      'auth_token': sessionStorage.token,
    });
  }

  void _emitRideLocationWatch(io.Socket socket, String rideId) {
    final token = sessionStorage.token?.trim() ?? '';
    if (token.isEmpty) {
      return;
    }
    socket.emit('watch-ride-location', <String, dynamic>{
      'ride_id': rideId,
      'auth_token': token,
    });
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, dynamic entryValue) {
        return MapEntry(key.toString(), entryValue);
      });
    }
    return <String, dynamic>{};
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    _connecting = false;
    _connectCompleter = null;
    _incomingCallController.close();
    _incomingChatController.close();
    _callEndedController.close();
    _callReadyController.close();
    _rtcMessageController.close();
    _byeController.close();
    _driverLocationController.close();
  }
}

class DriverLocationUpdate {
  const DriverLocationUpdate({
    required this.rideId,
    required this.latitude,
    required this.longitude,
  });

  final String rideId;
  final double latitude;
  final double longitude;

  static DriverLocationUpdate? fromJson(Map<String, dynamic> json) {
    final rideId = json['ride_id']?.toString().trim() ?? '';
    final latitude = double.tryParse(json['lat']?.toString() ?? '');
    final longitude = double.tryParse(json['lng']?.toString() ?? '');
    if (rideId.isEmpty || latitude == null || longitude == null) {
      return null;
    }
    return DriverLocationUpdate(
      rideId: rideId,
      latitude: latitude,
      longitude: longitude,
    );
  }
}
