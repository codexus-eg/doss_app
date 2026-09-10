// ══════════════════════════════════════════════════════════════════════════════
// DOSS Maps Service v6
// - All searches restricted to Egypt (country:eg) via backend proxy
// - Street-level precision via types=geocode
// - Shuttle: station catalog + static route resolution
// ══════════════════════════════════════════════════════════════════════════════
import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import '../models/models.dart' as models;
import '../constants/constants.dart';
import 'api_client.dart';

// ─── Place Prediction ─────────────────────────────────────────────────────────

class PlacePrediction {
  final String description;
  final String placeId;
  final String mainText;
  final String secondaryText;
  final String? addressType;

  const PlacePrediction({
    required this.description,
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    this.addressType,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> j) => PlacePrediction(
        description:   j['description']   as String? ?? '',
        placeId:       j['placeId']       as String? ?? '',
        mainText:      j['mainText']      as String? ?? j['description'] as String? ?? '',
        secondaryText: j['secondaryText'] as String? ?? '',
        addressType:   j['addressType']   as String?,
      );
}

// ─── Place Details ────────────────────────────────────────────────────────────

class PlaceDetails {
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String? governorate;

  const PlaceDetails({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    this.governorate,
  });
}

// ─── Route Result ─────────────────────────────────────────────────────────────

class RouteResult {
  final double distanceKm;
  final double durationMinutes;
  final String distanceText;
  final String durationText;
  final String polyline;
  final List<LatLng> points;

  const RouteResult({
    required this.distanceKm,
    required this.durationMinutes,
    required this.distanceText,
    required this.durationText,
    required this.polyline,
    required this.points,
  });
}

// ─── Reverse Geocode ──────────────────────────────────────────────────────────

class ReverseGeocodeResult {
  final String address;
  final String shortAddress;
  final String governorate;

  const ReverseGeocodeResult({
    required this.address,
    required this.shortAddress,
    required this.governorate,
  });
}

// ─── Maps Service ─────────────────────────────────────────────────────────────

class MapsService {
  MapsService._();
  static final MapsService instance = MapsService._();

  // ── Autocomplete ──────────────────────────────────────────────────────────
  Future<List<PlacePrediction>> autocomplete(
    String query, {
    double? lat,
    double? lng,
    int radiusMeters = 50000,
  }) async {
    if (query.trim().length < 2) return [];
    try {
      final isArabic = _containsArabic(query);
      final result   = await ApiClient.instance.query(
        'maps.autocomplete',
        input: {
          'input':    query.trim(),
          if (lat != null && lng != null) 'location': '$lat,$lng',
          'radius':   radiusMeters,
          'language': isArabic ? 'ar' : 'en',
        },
      );
      return (result['predictions'] as List? ?? [])
          .map((p) => PlacePrediction.fromJson(p as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Place Details ─────────────────────────────────────────────────────────
  Future<PlaceDetails?> getPlaceDetails(
    String placeId, {
    bool preferArabic = false,
  }) async {
    try {
      final result = await ApiClient.instance.query(
        'maps.placeDetails',
        input: {'placeId': placeId, 'language': preferArabic ? 'ar' : 'en'},
      );
      return PlaceDetails(
        name:        result['name']    as String? ?? '',
        address:     result['address'] as String? ?? '',
        lat:         (result['lat']    as num?)?.toDouble() ?? 0,
        lng:         (result['lng']    as num?)?.toDouble() ?? 0,
        governorate: _governorateFromAddress(result['address'] as String? ?? ''),
      );
    } catch (_) {
      return null;
    }
  }

  // ── Directions ────────────────────────────────────────────────────────────
  Future<RouteResult?> getDirections({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String mode = 'driving',
  }) async {
    try {
      final result = await ApiClient.instance.query(
        'maps.directions',
        input: {
          'originLat': originLat,
          'originLng': originLng,
          'destLat':   destLat,
          'destLng':   destLng,
          'mode':      mode,
        },
      );
      final distanceKm = (result['distanceKm'] as num?)?.toDouble() ??
          (result['distanceMeters'] as num? ?? 0).toDouble() / 1000;
      final durationMin = (result['durationMinutes'] as num?)?.toDouble() ??
          (result['durationSeconds'] as num? ?? 0).toDouble() / 60;
      final polyline = result['polyline'] as String? ?? '';

      return RouteResult(
        distanceKm:      distanceKm,
        durationMinutes: durationMin,
        distanceText:    result['distanceText'] as String? ?? '${distanceKm.toStringAsFixed(1)} km',
        durationText:    result['durationText'] as String? ?? '${durationMin.toStringAsFixed(0)} min',
        polyline:        polyline,
        points:          decodePolyline(polyline),
      );
    } catch (_) {
      return null;
    }
  }

  // ── Reverse Geocode ───────────────────────────────────────────────────────
  Future<ReverseGeocodeResult?> reverseGeocode({
    required double lat,
    required double lng,
    bool preferArabic = false,
  }) async {
    try {
      final result = await ApiClient.instance.query(
        'maps.reverseGeocode',
        input: {'lat': lat, 'lng': lng, 'language': preferArabic ? 'ar' : 'en'},
      );
      final address = result['address'] as String? ?? result['shortAddress'] as String? ?? '';
      return ReverseGeocodeResult(
        address:      address,
        shortAddress: result['shortAddress'] as String? ?? address,
        governorate:  _governorateFromAddress(address),
      );
    } catch (_) {
      return null;
    }
  }

  // ── Shuttle Station Resolution ────────────────────────────────────────────
  //
  // Returns the full ShuttleStation catalog from constants (seed data).
  // Backend API can override this list via shuttle.getStations.
  //
  static List<models.ShuttleStation> getAllStations() {
    return AppConstants.shuttleStations
        .map((s) => models.ShuttleStation(
              id:          s['id']          as String,
              nameEn:      s['nameEn']      as String,
              nameAr:      s['nameAr']      as String,
              location:    models.LatLng(
                lat: (s['location'] as Map)['lat'] as double,
                lng: (s['location'] as Map)['lng'] as double,
              ),
              governorate: s['governorate'] as String,
              area:        s['area']        as String? ?? '',
            ))
        .toList();
  }

  static List<models.ShuttleStation> getStationsByGovernorate(String gov) {
    return getAllStations()
        .where((s) => s.governorate.toLowerCase() == gov.toLowerCase())
        .toList();
  }

  // ── Shuttle Route Resolution ──────────────────────────────────────────────
  //
  // Builds ShuttleRoute objects from constants by resolving station IDs.
  // Optionally filtered by governorate.
  //
  static List<models.ShuttleRoute> getShuttleRoutes({String? governorate}) {
    final stations = {for (var s in getAllStations()) s.id: s};

    return AppConstants.shuttleRoutes
        .where((r) =>
            governorate == null ||
            (r['governorate'] as String).toLowerCase() ==
                governorate.toLowerCase())
        .map((r) {
          final origin = stations[r['origin']];
          final dest   = stations[r['destination']];
          if (origin == null || dest == null) return null;
          return models.ShuttleRoute(
            routeId:         r['routeId']         as String,
            origin:          origin,
            destination:     dest,
            fareEgp:         (r['fareEgp']         as num).toDouble(),
            distanceKm:      (r['distanceKm']      as num).toDouble(),
            durationMinutes: (r['durationMinutes'] as num).toInt(),
            governorate:     r['governorate']      as String,
          );
        })
        .whereType<models.ShuttleRoute>()
        .toList();
  }

  static List<models.ShuttleRoute> getRoutesFromStation(String originStationId) {
    return getShuttleRoutes()
        .where((r) => r.origin.id == originStationId)
        .toList();
  }

  static List<models.ShuttleRoute> getRoutesToStation(String destStationId) {
    return getShuttleRoutes()
        .where((r) => r.destination.id == destStationId)
        .toList();
  }

  // Find a specific route between two stations
  static models.ShuttleRoute? findRoute(String originId, String destId) {
    try {
      return getShuttleRoutes().firstWhere(
        (r) => r.origin.id == originId && r.destination.id == destId,
      );
    } catch (_) {
      return null;
    }
  }

  // Find nearest station to a given coordinate
  static models.ShuttleStation? nearestStation(double lat, double lng,
      {String? governorate, double maxDistanceKm = 5.0}) {
    final stations = governorate != null
        ? getStationsByGovernorate(governorate)
        : getAllStations();

    models.ShuttleStation? nearest;
    double minDist = double.infinity;

    for (final s in stations) {
      final d = _haversineKm(lat, lng, s.location.lat, s.location.lng);
      if (d < minDist && d <= maxDistanceKm) {
        minDist  = d;
        nearest  = s;
      }
    }
    return nearest;
  }

  // ── Polyline Decoder ──────────────────────────────────────────────────────
  static List<LatLng> decodePolyline(String encoded) {
    if (encoded.isEmpty) return [];
    final points = <LatLng>[];
    int index = 0;
    int lat = 0, lng = 0;
    while (index < encoded.length) {
      int shift = 0, result = 0, b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      shift = 0; result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _containsArabic(String text) =>
      text.contains(RegExp(r'[\u0600-\u06FF]'));

  String _governorateFromAddress(String address) {
    final lower = address.toLowerCase();
    if (lower.contains('giza')       || lower.contains('الجيزة')       ||
        lower.contains('6th of oct') || lower.contains('6 أكتوبر')     ||
        lower.contains('sheikh zayed')) return 'giza';
    if (lower.contains('alex')       || lower.contains('إسكندرية')     ||
        lower.contains('اسكندرية')) return 'alexandria';
    return 'cairo';
  }

  static double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
              math.cos(_rad(lat1)) * math.cos(_rad(lat2)) *
              math.sin(dLng / 2) * math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double deg) => deg * math.pi / 180;

  static bool isInServiceZone(double lat, double lng) {
    const cairoMinLat = 29.8; const cairoMaxLat = 30.4;
    const cairoMinLng = 31.0; const cairoMaxLng = 31.8;
    const gizaMinLat  = 29.7; const gizaMaxLat  = 30.2;
    const gizaMinLng  = 30.7; const gizaMaxLng  = 31.3;
    const alexMinLat  = 30.9; const alexMaxLat  = 31.4;
    const alexMinLng  = 29.6; const alexMaxLng  = 30.2;
    return (lat >= cairoMinLat && lat <= cairoMaxLat && lng >= cairoMinLng && lng <= cairoMaxLng) ||
           (lat >= gizaMinLat  && lat <= gizaMaxLat  && lng >= gizaMinLng  && lng <= gizaMaxLng)  ||
           (lat >= alexMinLat  && lat <= alexMaxLat  && lng >= alexMinLng  && lng <= alexMaxLng);
  }

  static String serviceZoneLabel(double lat, double lng) {
    const cairoMinLat = 29.8; const cairoMaxLat = 30.4;
    const cairoMinLng = 31.0; const cairoMaxLng = 31.8;
    const alexMinLat  = 30.9; const alexMaxLat  = 31.4;
    const alexMinLng  = 29.6; const alexMaxLng  = 30.2;
    if (lat >= cairoMinLat && lat <= cairoMaxLat && lng >= cairoMinLng && lng <= cairoMaxLng) return 'cairo';
    if (lat >= alexMinLat  && lat <= alexMaxLat  && lng >= alexMinLng  && lng <= alexMaxLng) return 'alexandria';
    return 'giza';
  }
}
