import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:logger/logger.dart';
import '../models/models.dart';

enum SocketConnectionState { disconnected, connecting, connected, reconnecting }

class SocketService {
  static SocketService? _instance;
  static SocketService get instance {
    _instance ??= SocketService._internal();
    return _instance!;
  }
  SocketService._internal();

  io.Socket? _socket;
  final Logger _log = Logger();

  final _connCtrl        = StreamController<SocketConnectionState>.broadcast();
  final _rideStatusCtrl  = StreamController<Map<String, dynamic>>.broadcast();
  final _driverLocCtrl   = StreamController<Map<String, dynamic>>.broadcast();
  final _chatCtrl        = StreamController<Map<String, dynamic>>.broadcast();
  final _sosRespCtrl     = StreamController<Map<String, dynamic>>.broadcast();
  final _offerCtrl       = StreamController<RideOffer>.broadcast();
  final _hotZoneCtrl     = StreamController<HotZoneAlert>.broadcast();
  final _subExpiredCtrl  = StreamController<void>.broadcast();

  Stream<SocketConnectionState> get connectionState  => _connCtrl.stream;
  Stream<Map<String, dynamic>>  get onRideStatus     => _rideStatusCtrl.stream;
  Stream<Map<String, dynamic>>  get onDriverLocation => _driverLocCtrl.stream;
  Stream<Map<String, dynamic>>  get onChatMessage    => _chatCtrl.stream;
  Stream<Map<String, dynamic>>  get onSosResponse    => _sosRespCtrl.stream;
  Stream<RideOffer>             get onRideOffer      => _offerCtrl.stream;
  Stream<HotZoneAlert>          get onHotZone        => _hotZoneCtrl.stream;
  Stream<void>                  get onSubscriptionExpired => _subExpiredCtrl.stream;

  SocketConnectionState _state = SocketConnectionState.disconnected;
  SocketConnectionState get currentState => _state;
  bool get isConnected => _state == SocketConnectionState.connected;

  void _set(SocketConnectionState s) { _state = s; _connCtrl.add(s); }

  void connect({
    required String serverUrl,
    required String namespace,
    required String token,
  }) {
    if (_socket?.connected == true) return;
    _set(SocketConnectionState.connecting);
    _socket = io.io(
      '$serverUrl$namespace',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(999)
          .setReconnectionDelay(2000)
          .setExtraHeaders({'authorization': 'Bearer $token'})
          .setAuth({'token': token})
          .build(),
    );
    _socket!
      ..onConnect((_)        { _log.i('WS connected $namespace'); _set(SocketConnectionState.connected); })
      ..onDisconnect((_)     { _log.w('WS disconnected'); _set(SocketConnectionState.disconnected); })
      ..onReconnecting((_)   { _set(SocketConnectionState.reconnecting); })
      ..onError((e)          => _log.e('WS error', error: e))
      ..on('ride:status',    (d) { if (d is Map) _rideStatusCtrl.add(Map<String, dynamic>.from(d)); })
      ..on('driver:location',(d) { if (d is Map) _driverLocCtrl.add(Map<String, dynamic>.from(d)); })
      ..on('chat:message',   (d) { if (d is Map) _chatCtrl.add(Map<String, dynamic>.from(d)); })
      ..on('sos:response',   (d) { if (d is Map) _sosRespCtrl.add(Map<String, dynamic>.from(d)); })
      ..on('ride:offer',     (d) { if (d is Map) { try { _offerCtrl.add(RideOffer.fromJson(Map<String, dynamic>.from(d))); } catch(e) { _log.e('Offer parse', error:e); } } })
      ..on('hotzone:alert',  (d) { if (d is Map) { try { _hotZoneCtrl.add(HotZone.fromJson(Map<String, dynamic>.from(d))); } catch(e) { _log.e('HotZone parse', error:e); } } })
      ..on('subscription:expired', (_) => _subExpiredCtrl.add(null));
  }

  void emitLocation(double lat, double lng) =>
      _socket?.emit('driver:location', {'lat': lat, 'lng': lng});

  void emitChat({
    required String rideId,
    required String senderId,
    required String senderRole,
    required String text,
    String? audioUrl,
  }) =>
      _socket?.emit('chat:message', {
        'rideId': rideId,
        'senderId': senderId,
        'senderRole': senderRole,
        'text': text,
        if (audioUrl != null) 'audioUrl': audioUrl,
        'timestamp': DateTime.now().toIso8601String(),
      });

  void emitSOS({
    required String rideId,
    required String userId,
    required String userRole,
    required double lat,
    required double lng,
  }) =>
      _socket?.emit('sos:alert', {
        'rideId': rideId,
        'userId': userId,
        'userRole': userRole,
        'lat': lat,
        'lng': lng,
        'timestamp': DateTime.now().toIso8601String(),
      });

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _set(SocketConnectionState.disconnected);
  }
}
