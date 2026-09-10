import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:doss_core/doss_core.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class RideEvent extends Equatable {
  const RideEvent();
  @override List<Object?> get props => [];
}

class RideRequestSubmitted extends RideEvent {
  final RideRequest request;
  const RideRequestSubmitted(this.request);
  @override List<Object?> get props => [request];
}

/// Shuttle-specific booking event
class ShuttleRequestSubmitted extends RideEvent {
  final ShuttleRequest request;
  const ShuttleRequestSubmitted(this.request);
  @override List<Object?> get props => [request];
}

class RideCancelled extends RideEvent {
  final String rideId;
  const RideCancelled(this.rideId);
  @override List<Object?> get props => [rideId];
}

class RideStatusUpdated extends RideEvent {
  final Map<String, dynamic> payload;
  const RideStatusUpdated(this.payload);
  @override List<Object?> get props => [payload];
}

class DriverLocationUpdated extends RideEvent {
  final double lat;
  final double lng;
  const DriverLocationUpdated(this.lat, this.lng);
  @override List<Object?> get props => [lat, lng];
}

class RideHistoryRequested extends RideEvent {}
class ActiveRideRequested   extends RideEvent {}
class RideReset             extends RideEvent {}

// ─── States ───────────────────────────────────────────────────────────────────

abstract class RideState extends Equatable {
  const RideState();
  @override List<Object?> get props => [];
}

class RideInitial    extends RideState {}
class RideLoading    extends RideState {}

class RideSearching extends RideState {
  final Ride ride;
  const RideSearching(this.ride);
  @override List<Object?> get props => [ride];
}

class RideAccepted extends RideState {
  final Ride ride;
  final LatLng? driverLocation;
  const RideAccepted(this.ride, {this.driverLocation});
  @override List<Object?> get props => [ride, driverLocation];
}

class RideInProgress extends RideState {
  final Ride ride;
  final LatLng? driverLocation;
  const RideInProgress(this.ride, {this.driverLocation});
  @override List<Object?> get props => [ride, driverLocation];
}

class RideCompleted extends RideState {
  final Ride ride;
  const RideCompleted(this.ride);
  @override List<Object?> get props => [ride];
}

class RideCancelledState extends RideState {
  final String reason;
  const RideCancelledState(this.reason);
  @override List<Object?> get props => [reason];
}

class RideError extends RideState {
  final String message;
  const RideError(this.message);
  @override List<Object?> get props => [message];
}

class RideHistoryLoaded extends RideState {
  final List<Ride> rides;
  const RideHistoryLoaded(this.rides);
  @override List<Object?> get props => [rides];
}

// ─── BLoC ─────────────────────────────────────────────────────────────────────

class RideBloc extends Bloc<RideEvent, RideState> {
  StreamSubscription? _statusSub;
  StreamSubscription? _locationSub;

  RideBloc() : super(RideInitial()) {
    on<RideRequestSubmitted>(_onRequest);
    on<ShuttleRequestSubmitted>(_onShuttleRequest);
    on<RideCancelled>(_onCancel);
    on<RideStatusUpdated>(_onStatusUpdate);
    on<DriverLocationUpdated>(_onDriverLocation);
    on<RideHistoryRequested>(_onHistory);
    on<ActiveRideRequested>(_onActiveRide);
    on<RideReset>(_onReset);

    _statusSub = SocketService.instance.onRideStatus.listen(
        (p) => add(RideStatusUpdated(p)));
    _locationSub = SocketService.instance.onDriverLocation.listen((p) {
      final lat = (p['lat'] as num?)?.toDouble();
      final lng = (p['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) add(DriverLocationUpdated(lat, lng));
    });
  }

  // ── Standard ride request ──────────────────────────────────────────────────
  Future<void> _onRequest(
      RideRequestSubmitted event, Emitter<RideState> emit) async {
    emit(RideLoading());
    try {
      final result = await ApiClient.instance.mutate(
          'rides.requestRide', input: event.request.toJson());
      final rideId = result['rideId'] as String? ?? '';
      final fare   = asDouble(result['lockedFareEgp'] ?? result['fareEgp'],
          event.request.estimatedFare ?? 0);
      emit(RideSearching(Ride(
        id: rideId,
        riderId:        AuthService.instance.currentUser?.id ?? '',
        pickupAddress:  event.request.pickupAddress,
        pickupLocation: event.request.pickupLocation,
        dropoffAddress: event.request.dropoffAddress,
        dropoffLocation:event.request.dropoffLocation,
        status:         RideStatus.searching,
        fareEgp:        fare,
        governorate:    event.request.governorate,
        createdAt:      DateTime.now(),
        vehicleType:    event.request.vehicleType,
        distanceKm:     event.request.distanceKm,
        durationMinutes:event.request.durationMinutes,
      )));
    } catch (e) {
      emit(RideError(_parseError(e)));
    }
  }

  // ── Shuttle ride request ───────────────────────────────────────────────────
  Future<void> _onShuttleRequest(
      ShuttleRequestSubmitted event, Emitter<RideState> emit) async {
    emit(RideLoading());
    try {
      // Backend endpoint: rides.requestRide with vehicleType='shuttle' + routeId
      final result = await ApiClient.instance.mutate(
          'rides.requestRide', input: event.request.toJson());
      final rideId = result['rideId'] as String? ?? '';
      final fare   = asDouble(result['lockedFareEgp'] ?? result['fareEgp'],
          event.request.fareEgp);

      emit(RideSearching(Ride(
        id: rideId,
        riderId:          AuthService.instance.currentUser?.id ?? '',
        pickupAddress:    event.request.pickupAddress,
        pickupLocation:   event.request.pickupLocation,
        dropoffAddress:   event.request.dropoffAddress,
        dropoffLocation:  event.request.dropoffLocation,
        status:           RideStatus.searching,
        fareEgp:          fare,
        governorate:      event.request.governorate,
        createdAt:        DateTime.now(),
        vehicleType:      'shuttle',
        distanceKm:       event.request.distanceKm,
        durationMinutes:  event.request.durationMinutes,
        shuttleRouteId:       event.request.routeId,
        originStationId:      event.request.originStationId,
        destinationStationId: event.request.destinationStationId,
      )));
    } catch (e) {
      emit(RideError(_parseError(e)));
    }
  }

  Future<void> _onCancel(
      RideCancelled event, Emitter<RideState> emit) async {
    try {
      await ApiClient.instance.mutate(
          'rides.cancelRide', input: {'rideId': event.rideId});
      emit(const RideCancelledState('Ride cancelled by rider.'));
    } catch (e) {
      emit(RideError(_parseError(e)));
    }
  }

  void _onStatusUpdate(
      RideStatusUpdated event, Emitter<RideState> emit) {
    final payload   = event.payload;
    final status    = rideStatusFromString(payload['status'] as String? ?? '');
    final fareEgp   = asDoubleOrNull(payload['fareEgp']);

    Ride? currentRide;
    if (state is RideSearching)  currentRide = (state as RideSearching).ride;
    if (state is RideAccepted)   currentRide = (state as RideAccepted).ride;
    if (state is RideInProgress) currentRide = (state as RideInProgress).ride;
    if (currentRide == null) return;

    final driverJson = payload['driver'] as Map<String, dynamic>?;
    final updatedRide = Ride(
      id:             currentRide.id,
      riderId:        currentRide.riderId,
      driverId:       payload['driverId'] as String? ?? currentRide.driverId,
      pickupAddress:  currentRide.pickupAddress,
      pickupLocation: currentRide.pickupLocation,
      dropoffAddress: currentRide.dropoffAddress,
      dropoffLocation:currentRide.dropoffLocation,
      status:         status,
      fareEgp:        fareEgp ?? currentRide.fareEgp,
      governorate:    currentRide.governorate,
      createdAt:      currentRide.createdAt,
      driver:         driverJson != null
          ? DriverInfo.fromJson(driverJson) : currentRide.driver,
      vehicleType:    currentRide.vehicleType,
      shuttleRouteId: currentRide.shuttleRouteId,
    );

    switch (status) {
      case RideStatus.accepted:
      case RideStatus.arrived:
        emit(RideAccepted(updatedRide));
        break;
      case RideStatus.inProgress:
        emit(RideInProgress(updatedRide));
        break;
      case RideStatus.completed:
        emit(RideCompleted(updatedRide));
        break;
      case RideStatus.cancelled:
        emit(const RideCancelledState('Ride was cancelled.'));
        break;
      default: break;
    }
  }

  void _onDriverLocation(
      DriverLocationUpdated event, Emitter<RideState> emit) {
    final loc = LatLng(lat: event.lat, lng: event.lng);
    if (state is RideAccepted) {
      emit(RideAccepted((state as RideAccepted).ride, driverLocation: loc));
    } else if (state is RideInProgress) {
      emit(RideInProgress((state as RideInProgress).ride, driverLocation: loc));
    }
  }

  Future<void> _onHistory(
      RideHistoryRequested event, Emitter<RideState> emit) async {
    emit(RideLoading());
    try {
      // rides.myRides scopes to the JWT identity and returns { rides: [...] };
      // rides.getRiderHistory returns a bare array, which does not survive
      // the tRPC map unwrapping.
      final result = await ApiClient.instance.query('rides.myRides');
      final rides = (result['rides'] as List? ?? [])
          .map((r) => Ride.fromJson(r as Map<String, dynamic>))
          .toList();
      emit(RideHistoryLoaded(rides));
    } catch (e) {
      emit(RideError(_parseError(e)));
    }
  }

  Future<void> _onActiveRide(
      ActiveRideRequested event, Emitter<RideState> emit) async {
    try {
      final result = await ApiClient.instance.query('rides.activeRide');
      final activeRideJson = result['ride'] as Map<String, dynamic>?;
      if (activeRideJson == null || activeRideJson.isEmpty) return;
      final ride = Ride.fromJson(activeRideJson);
      switch (ride.status) {
        case RideStatus.searching:   emit(RideSearching(ride));  break;
        case RideStatus.accepted:
        case RideStatus.arrived:     emit(RideAccepted(ride));   break;
        case RideStatus.inProgress:  emit(RideInProgress(ride)); break;
        default: break;
      }
    } catch (_) {}
  }

  void _onReset(RideReset event, Emitter<RideState> emit) {
    emit(RideInitial());
  }

  String _parseError(Object e) {
    // An expired DOSS JWT (24h lifetime) surfaces as 401 on every authenticated
    // call, so it needs a message the rider can act on rather than the raw
    // "Rider authentication required" from the server.
    if (e is ApiException && e.isUnauthorized) {
      return 'Your session has expired. Please sign in again.';
    }
    final msg = e.toString();
    if (msg.contains('subscription') || msg.contains('403')) {
      return 'Please activate a subscription to request rides.';
    }
    if (msg.contains('SocketException')) return 'No internet connection.';
    if (e is ApiException) return e.message;
    return 'Something went wrong. Please try again.';
  }

  @override
  Future<void> close() {
    _statusSub?.cancel();
    _locationSub?.cancel();
    return super.close();
  }
}
