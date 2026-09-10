// DOSS Core Models v6 — Rider + Driver + Shuttle

// ─── Vehicle / Ride Type ──────────────────────────────────────────────────────

enum VehicleType { car, bike, shuttle }

VehicleType vehicleTypeFromString(String s) {
  switch (s.toLowerCase()) {
    case 'bike':    return VehicleType.bike;
    case 'shuttle': return VehicleType.shuttle;
    default:        return VehicleType.car;
  }
}

String vehicleTypeToString(VehicleType t) {
  switch (t) {
    case VehicleType.car:     return 'car';
    case VehicleType.bike:    return 'bike';
    case VehicleType.shuttle: return 'shuttle';
  }
}

// ─── JSON number coercion ─────────────────────────────────────────────────────
//
// MySQL DECIMAL columns are serialised as JSON strings ("30.04440000", "56.35"),
// so every numeric field coming from the backend must be coerced rather than
// cast — `"56.35" as num` throws a TypeError at runtime.

double? asDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

double asDouble(dynamic v, [double fallback = 0]) =>
    asDoubleOrNull(v) ?? fallback;

int? asIntOrNull(dynamic v) => asDoubleOrNull(v)?.round();

int asInt(dynamic v, [int fallback = 0]) => asIntOrNull(v) ?? fallback;

// ─── User / Auth ──────────────────────────────────────────────────────────────

class AuthUser {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String role;
  final String token;
  final String? vehicleModel;
  final String? vehiclePlate;
  final String? governorate;
  final String? approvalStatus;
  final String? driverStatus;

  const AuthUser({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.role,
    required this.token,
    this.vehicleModel,
    this.vehiclePlate,
    this.governorate,
    this.approvalStatus,
    this.driverStatus,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: (json['userId'] ?? json['driverId'] ?? json['id'] ?? '') as String,
        name:  (json['name']  ?? '') as String,
        phone: (json['phone'] ?? '') as String,
        email: json['email'] as String?,
        role:  (json['entity'] ?? json['role'] ?? 'rider') as String,
        token: (json['token'] ?? '') as String,
        vehicleModel:   json['vehicleModel']   as String?,
        vehiclePlate:   json['vehiclePlate']   as String?,
        governorate:    json['governorate']    as String?,
        approvalStatus: json['approvalStatus'] as String?,
        driverStatus:   json['driverStatus']   as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'phone': phone, 'email': email,
        'role': role, 'token': token, 'vehicleModel': vehicleModel,
        'vehiclePlate': vehiclePlate, 'governorate': governorate,
        'approvalStatus': approvalStatus, 'driverStatus': driverStatus,
      };
}

// ─── Location ─────────────────────────────────────────────────────────────────

class LatLng {
  final double lat;
  final double lng;

  const LatLng({required this.lat, required this.lng});

  factory LatLng.fromJson(Map<String, dynamic> json) => LatLng(
        lat: asDouble(json['lat']),
        lng: asDouble(json['lng']),
      );

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};

  @override
  String toString() => 'LatLng($lat, $lng)';
}

// ─── Shuttle Station ──────────────────────────────────────────────────────────
//
// Fixed stations used for shuttle booking.
// Based on real Cairo/Alexandria routes (Uber Shuttle-equivalent).

class ShuttleStation {
  final String id;
  final String nameEn;
  final String nameAr;
  final LatLng location;
  final String governorate; // 'cairo' | 'giza' | 'alexandria'
  final String area;        // Display area label

  const ShuttleStation({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.location,
    required this.governorate,
    required this.area,
  });

  String name(bool isArabic) => isArabic ? nameAr : nameEn;

  factory ShuttleStation.fromJson(Map<String, dynamic> j) => ShuttleStation(
        id:          j['id']          as String,
        nameEn:      j['nameEn']      as String,
        nameAr:      j['nameAr']      as String,
        location:    LatLng.fromJson(j['location'] as Map<String, dynamic>),
        governorate: j['governorate'] as String,
        area:        j['area']        as String? ?? '',
      );
}

// ─── Shuttle Route ────────────────────────────────────────────────────────────
//
// A pre-defined station-to-station route with a fixed fare.
// Pricing modelled on Uber Shuttle Egypt rates (Cairo 2024).

class ShuttleRoute {
  final String routeId;
  final ShuttleStation origin;
  final ShuttleStation destination;
  final double fareEgp;       // Fixed fare
  final double distanceKm;
  final int durationMinutes;
  final String governorate;
  final bool isActive;

  const ShuttleRoute({
    required this.routeId,
    required this.origin,
    required this.destination,
    required this.fareEgp,
    required this.distanceKm,
    required this.durationMinutes,
    required this.governorate,
    this.isActive = true,
  });

  String get displayName => '${origin.nameEn} → ${destination.nameEn}';
  String displayNameAr() => '${origin.nameAr} ← ${destination.nameAr}';

  factory ShuttleRoute.fromJson(Map<String, dynamic> j) => ShuttleRoute(
        routeId:         j['routeId']         as String,
        origin:          ShuttleStation.fromJson(j['origin']      as Map<String, dynamic>),
        destination:     ShuttleStation.fromJson(j['destination'] as Map<String, dynamic>),
        fareEgp:         asDouble(j['fareEgp']),
        distanceKm:      asDouble(j['distanceKm']),
        durationMinutes: asInt(j['durationMinutes']),
        governorate:     j['governorate']      as String,
        isActive:        j['isActive']         as bool? ?? true,
      );
}

// ─── Shuttle Booking Request ──────────────────────────────────────────────────

class ShuttleRequest {
  final String routeId;
  final String originStationId;
  final String destinationStationId;
  final String pickupAddress;
  final LatLng  pickupLocation;
  final String  dropoffAddress;
  final LatLng  dropoffLocation;
  final double  fareEgp;
  final String  governorate;
  final double  distanceKm;
  final double  durationMinutes;

  const ShuttleRequest({
    required this.routeId,
    required this.originStationId,
    required this.destinationStationId,
    required this.pickupAddress,
    required this.pickupLocation,
    required this.dropoffAddress,
    required this.dropoffLocation,
    required this.fareEgp,
    required this.governorate,
    required this.distanceKm,
    required this.durationMinutes,
  });

  Map<String, dynamic> toJson() => {
        'routeId':              routeId,
        'originStationId':      originStationId,
        'destinationStationId': destinationStationId,
        'pickupLat':    pickupLocation.lat,
        'pickupLng':    pickupLocation.lng,
        'dropoffLat':   dropoffLocation.lat,
        'dropoffLng':   dropoffLocation.lng,
        'pickupAddress':  pickupAddress,
        'dropoffAddress': dropoffAddress,
        'governorate':  governorate.toLowerCase(),
        'vehicleType':  'shuttle',
        'fareEgp':      fareEgp,
        'distanceKm':   distanceKm,
        'durationMinutes': durationMinutes,
        'isShuttle':    true,
      };
}

// ─── Ride Status ──────────────────────────────────────────────────────────────

enum RideStatus {
  pending,
  searching,
  accepted,
  arrived,
  inProgress,
  completed,
  cancelled,
}

RideStatus rideStatusFromString(String s) {
  switch (s) {
    case 'pending':             return RideStatus.pending;
    case 'searching':           return RideStatus.searching;
    case 'dispatching':         return RideStatus.searching;
    case 'accepted':            return RideStatus.accepted;
    case 'driver_arrived':
    case 'arrived':             return RideStatus.arrived;
    case 'in_ride':
    case 'in_progress':         return RideStatus.inProgress;
    case 'completed':           return RideStatus.completed;
    case 'cancelled':
    case 'cancelled_by_rider':
    case 'cancelled_by_driver': return RideStatus.cancelled;
    default:                    return RideStatus.pending;
  }
}

String rideStatusToString(RideStatus s) {
  switch (s) {
    case RideStatus.pending:    return 'pending';
    case RideStatus.searching:  return 'searching';
    case RideStatus.accepted:   return 'accepted';
    case RideStatus.arrived:    return 'driver_arrived';
    case RideStatus.inProgress: return 'in_ride';
    case RideStatus.completed:  return 'completed';
    case RideStatus.cancelled:  return 'cancelled';
  }
}

// ─── Ride Request ─────────────────────────────────────────────────────────────

class RideRequest {
  final String pickupAddress;
  final LatLng pickupLocation;
  final String dropoffAddress;
  final LatLng dropoffLocation;
  final String governorate;
  final String vehicleType; // 'car' | 'bike' | 'shuttle'
  final double? distanceKm;
  final double? durationMinutes;
  final String? polyline;
  final double? estimatedFare;

  const RideRequest({
    required this.pickupAddress,
    required this.pickupLocation,
    required this.dropoffAddress,
    required this.dropoffLocation,
    required this.governorate,
    this.vehicleType = 'car',
    this.distanceKm,
    this.durationMinutes,
    this.polyline,
    this.estimatedFare,
  });

  Map<String, dynamic> toJson() => {
        'pickupLat':    pickupLocation.lat,
        'pickupLng':    pickupLocation.lng,
        'dropoffLat':   dropoffLocation.lat,
        'dropoffLng':   dropoffLocation.lng,
        'pickupAddress':  pickupAddress,
        'dropoffAddress': dropoffAddress,
        'governorate':  governorate.toLowerCase(),
        'vehicleType':  vehicleType,
        if (distanceKm != null) 'distanceKm': distanceKm,
        if (durationMinutes != null) 'durationMinutes': durationMinutes,
      };
}

// ─── Ride ─────────────────────────────────────────────────────────────────────

class Ride {
  final String id;
  final String riderId;
  final String? driverId;
  final String pickupAddress;
  final LatLng pickupLocation;
  final String dropoffAddress;
  final LatLng dropoffLocation;
  final RideStatus status;
  final double fareEgp;
  final String governorate;
  final DateTime createdAt;
  final DriverInfo? driver;
  final String? vehicleType;    // 'car' | 'bike' | 'shuttle'
  final double? distanceKm;
  final double? durationMinutes;
  final String? riderPhone;
  // Shuttle extras
  final String? shuttleRouteId;
  final String? originStationId;
  final String? destinationStationId;

  bool get isShuttle => vehicleType == 'shuttle';

  const Ride({
    required this.id,
    required this.riderId,
    this.driverId,
    required this.pickupAddress,
    required this.pickupLocation,
    required this.dropoffAddress,
    required this.dropoffLocation,
    required this.status,
    required this.fareEgp,
    required this.governorate,
    required this.createdAt,
    this.driver,
    this.vehicleType,
    this.distanceKm,
    this.durationMinutes,
    this.riderPhone,
    this.shuttleRouteId,
    this.originStationId,
    this.destinationStationId,
  });

  factory Ride.fromJson(Map<String, dynamic> json) {
    LatLng _parseLocation(String latKey, String lngKey, [String? objKey]) {
      if (objKey != null && json[objKey] is Map) {
        return LatLng.fromJson(json[objKey] as Map<String, dynamic>);
      }
      return LatLng(
        lat: asDouble(json[latKey]),
        lng: asDouble(json[lngKey]),
      );
    }

    return Ride(
      id:      json['id'] as String,
      riderId: (json['riderId'] ?? '') as String,
      driverId: json['driverId'] as String?,
      pickupAddress:  (json['pickupAddress']  ?? '') as String,
      pickupLocation:  _parseLocation('pickupLat',  'pickupLng',  'pickupLocation'),
      dropoffAddress: (json['dropoffAddress'] ?? '') as String,
      dropoffLocation: _parseLocation('dropoffLat', 'dropoffLng', 'dropoffLocation'),
      status:      rideStatusFromString((json['status'] ?? 'pending') as String),
      fareEgp:     asDouble(json['fareEgp'] ?? json['lockedFareEgp']),
      governorate: (json['governorate'] ?? 'cairo') as String,
      createdAt:   json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      driver: json['driver'] != null
          ? DriverInfo.fromJson(json['driver'] as Map<String, dynamic>)
          : null,
      vehicleType:           json['vehicleType']           as String?,
      distanceKm:  asDoubleOrNull(json['distanceKm'] ?? json['estimatedDistanceKm']),
      durationMinutes: asDoubleOrNull(json['durationMin'] ??
          json['durationMinutes'] ?? json['estimatedDurationMin']),
      riderPhone:            json['riderPhone']            as String?,
      shuttleRouteId:        json['shuttleRouteId']        as String?,
      originStationId:       json['originStationId']       as String?,
      destinationStationId:  json['destinationStationId']  as String?,
    );
  }
}

// ─── Driver Info ──────────────────────────────────────────────────────────────

class DriverInfo {
  final String id;
  final String name;
  final String phone;
  final String? vehicleMake;
  final String? vehicleModel;
  final String? vehiclePlate;
  final String? vehicleColor;
  final double? rating;
  final double? lat;
  final double? lng;

  const DriverInfo({
    required this.id,
    required this.name,
    required this.phone,
    this.vehicleMake,
    this.vehicleModel,
    this.vehiclePlate,
    this.vehicleColor,
    this.rating,
    this.lat,
    this.lng,
  });

  factory DriverInfo.fromJson(Map<String, dynamic> json) => DriverInfo(
        id:    (json['id']    ?? json['driverId'] ?? '') as String,
        name:  (json['name']  ?? '') as String,
        phone: (json['phone'] ?? '') as String,
        vehicleMake:  json['vehicleMake']  as String?,
        vehicleModel: json['vehicleModel'] as String?,
        vehiclePlate: json['vehiclePlate'] as String?,
        vehicleColor: json['vehicleColor'] as String?,
        rating: asDoubleOrNull(json['rating']),
        lat:    asDoubleOrNull(json['lat']),
        lng:    asDoubleOrNull(json['lng']),
      );
}

// ─── Ride Offer (Driver Side) ─────────────────────────────────────────────────

class RideOffer {
  final String offerId;
  final String rideId;
  final String pickupAddress;
  final LatLng pickupLocation;
  final String dropoffAddress;
  final LatLng dropoffLocation;
  final double fareEgp;
  final double distanceKm;
  final double? durationMinutes;
  final String governorate;
  final int    expiresInSeconds;
  final String vehicleType;       // 'car' | 'bike' | 'shuttle'
  // Shuttle extras
  final String? shuttleRouteId;
  final String? originStationName;
  final String? destinationStationName;
  // Rider info
  final String? riderPhone;
  final String? riderName;

  bool get isShuttle => vehicleType == 'shuttle';

  const RideOffer({
    required this.offerId,
    required this.rideId,
    required this.pickupAddress,
    required this.pickupLocation,
    required this.dropoffAddress,
    required this.dropoffLocation,
    required this.fareEgp,
    required this.distanceKm,
    this.durationMinutes,
    required this.governorate,
    required this.expiresInSeconds,
    this.vehicleType = 'car',
    this.shuttleRouteId,
    this.originStationName,
    this.destinationStationName,
    this.riderPhone,
    this.riderName,
  });

  double get pickupLat  => pickupLocation.lat;
  double get pickupLng  => pickupLocation.lng;
  double get dropoffLat => dropoffLocation.lat;
  double get dropoffLng => dropoffLocation.lng;
  double get tripDistanceKm => distanceKm;

  factory RideOffer.fromJson(Map<String, dynamic> json) {
    LatLng _loc(String latK, String lngK, [String? obj]) {
      if (obj != null && json[obj] is Map) {
        return LatLng.fromJson(json[obj] as Map<String, dynamic>);
      }
      return LatLng(
        lat: asDouble(json[latK]),
        lng: asDouble(json[lngK]),
      );
    }

    return RideOffer(
      offerId:  (json['offerId']  ?? json['rideId'] ?? '') as String,
      rideId:   (json['rideId']   ?? '') as String,
      pickupAddress:   (json['pickupAddress']  ?? '') as String,
      pickupLocation:  _loc('pickupLat',  'pickupLng',  'pickupLocation'),
      dropoffAddress:  (json['dropoffAddress'] ?? '') as String,
      dropoffLocation: _loc('dropoffLat', 'dropoffLng', 'dropoffLocation'),
      fareEgp:     asDouble(json['fareEgp'] ?? json['lockedFareEgp']),
      distanceKm:  asDouble(json['distanceKm'] ?? json['estimatedDistanceKm']),
      durationMinutes: asDoubleOrNull(json['durationMin'] ??
          json['durationMinutes'] ?? json['estimatedDurationMin']),
      governorate: (json['governorate']      ?? 'cairo') as String,
      expiresInSeconds: asInt(json['expiresInSeconds'], 30),
      vehicleType: (json['vehicleType'] ?? 'car') as String,
      shuttleRouteId:        json['shuttleRouteId']        as String?,
      originStationName:     json['originStationName']     as String?,
      destinationStationName: json['destinationStationName'] as String?,
      riderPhone:            json['riderPhone']            as String?,
      riderName:             json['riderName']             as String?,
    );
  }
}

// ─── Hot Zone ─────────────────────────────────────────────────────────────────

class HotZone {
  final String zoneId;
  final String governorate;
  final double lat;
  final double lng;
  final double avgRequests;
  final int hourOfDay;
  final String message;

  const HotZone({
    required this.zoneId,
    required this.governorate,
    required this.lat,
    required this.lng,
    required this.avgRequests,
    required this.hourOfDay,
    required this.message,
  });

  factory HotZone.fromJson(Map<String, dynamic> json) => HotZone(
        zoneId:      (json['zoneId']      ?? '') as String,
        governorate: (json['governorate'] ?? '') as String,
        lat:         asDouble(json['lat']),
        lng:         asDouble(json['lng']),
        avgRequests: asDouble(json['avgRequests']),
        hourOfDay:   asInt(json['hourOfDay']),
        message:     (json['message']     ?? 'High demand zone') as String,
      );
}

typedef HotZoneAlert = HotZone;

// ─── Driver Subscription ─────────────────────────────────────────────────────

class DriverSubscription {
  final String id;
  final String planName;
  final String status;
  final DateTime? expiresAt;
  final double priceEgp;

  const DriverSubscription({
    required this.id,
    required this.planName,
    required this.status,
    this.expiresAt,
    required this.priceEgp,
  });

  bool get isActive =>
      status == 'active' && (expiresAt?.isAfter(DateTime.now()) ?? false);

  factory DriverSubscription.fromJson(Map<String, dynamic> json) =>
      DriverSubscription(
        id:        (json['id']       ?? '') as String,
        planName:  (json['planName'] ?? 'Standard') as String,
        status:    (json['status']   ?? 'inactive') as String,
        expiresAt: json['expiresAt'] != null
            ? DateTime.tryParse(json['expiresAt'] as String)
            : null,
        priceEgp: asDouble(json['priceEgp']),
      );
}

// ─── Driver Daily Stats ───────────────────────────────────────────────────────

class DriverDailyStats {
  final int ridesCompleted;
  final int ridesAccepted;
  final int ridesCancelled;
  final int ridesOffered;
  final double dailyEarningsEgp;
  final int idleMinutes;
  final int onlineMinutes;
  final double cancellationRate;

  double get acceptanceRate =>
      ridesOffered > 0 ? ridesAccepted / ridesOffered : 1.0;

  const DriverDailyStats({
    required this.ridesCompleted,
    required this.ridesAccepted,
    required this.ridesCancelled,
    required this.ridesOffered,
    required this.dailyEarningsEgp,
    required this.idleMinutes,
    required this.onlineMinutes,
    this.cancellationRate = 0,
  });

  factory DriverDailyStats.fromJson(Map<String, dynamic> json) =>
      DriverDailyStats(
        ridesCompleted:  asInt(json['ridesCompleted']),
        ridesAccepted:   asInt(json['ridesAccepted']),
        ridesCancelled:  asInt(json['ridesCancelled']),
        ridesOffered:    asInt(json['ridesOffered']),
        dailyEarningsEgp:
            asDouble(json['dailyEarningsEgp'] ?? json['todayEarnings']),
        idleMinutes:     asInt(json['idleMinutes']),
        onlineMinutes:   asInt(json['onlineMinutes']),
        cancellationRate: asDouble(json['cancellationRate']),
      );

  static DriverDailyStats get empty => const DriverDailyStats(
        ridesCompleted: 0, ridesAccepted: 0, ridesCancelled: 0,
        ridesOffered: 0, dailyEarningsEgp: 0, idleMinutes: 0, onlineMinutes: 0);
}
