// ════════════════════════════════════════════════════════════════════
// FILE: doss_rider/lib/screens/ride/booking_screen.dart
// FIX 1: pricing.estimateFare → pricing.estimate (correct endpoint)
// FIX 2: Must call maps.directions FIRST to get distanceKm/durationMin
// FIX 3: Response field 'fareEgp' → 'finalFare'
// FIX 4: Pass distanceKm + durationMinutes to RideRequest
// FIX 5: Governorate must be lowercase: 'cairo'|'giza'|'alexandria'
// ════════════════════════════════════════════════════════════════════
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:doss_core/doss_core.dart' as core;
import 'package:doss_core/theme/app_theme.dart';
import 'package:doss_core/constants/constants.dart';
import '../../blocs/ride/ride_bloc.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _dropoffCtrl = TextEditingController();

  LatLng? _pickupLatLng;
  LatLng? _dropoffLatLng;
  String _pickupAddress = 'Current Location';
  String _dropoffAddress = '';
  String _selectedGovernorate = 'cairo'; // FIX: always lowercase
  String _selectedVehicleType = 'car';

  // FIX: Separate fares for car and bike
  double? _carFare;
  double? _bikeFare;
  double _distanceKm = 0;
  double _durationMin = 0;
  String? _distanceText;
  String? _durationText;
  String? _polylineEncoded;

  bool _loadingFare = false;

  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  // Autocomplete state
  List<Map<String, String>> _predictions = [];
  bool _searchingDropoff = false;
  Timer? _debounce;
  bool _showDropoffSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
    _dropoffCtrl.addListener(_onDropoffChanged);
  }

  Future<void> _loadCurrentLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      if (!mounted) return;

      // Get address and governorate from reverse geocode
      try {
        final geo = await core.ApiClient.instance.query(
          'maps.reverseGeocode',
          input: {'lat': pos.latitude, 'lng': pos.longitude},
        );
        final addr = (geo['address'] as String?) ??
            (geo['shortAddress'] as String?) ??
            'Current Location';
        // Extract governorate from address
        final govRaw = addr.toLowerCase();
        String gov = 'cairo';
        if (govRaw.contains('giza') || govRaw.contains('جيزة')) gov = 'giza';
        if (govRaw.contains('alex') || govRaw.contains('إسكندرية')) {
          gov = 'alexandria';
        }
        if (mounted) {
          setState(() {
            _pickupLatLng = LatLng(pos.latitude, pos.longitude);
            _pickupAddress = addr;
            _selectedGovernorate = gov;
            _updateMarkers();
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _pickupLatLng = LatLng(pos.latitude, pos.longitude);
            _updateMarkers();
          });
        }
      }

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
            LatLng(pos.latitude, pos.longitude), AppConstants.defaultZoom),
      );
    } catch (_) {}
  }

  void _updateMarkers() {
    final markers = <Marker>{};
    if (_pickupLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: _pickupLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'Pickup', snippet: _pickupAddress),
      ));
    }
    if (_dropoffLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('dropoff'),
        position: _dropoffLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: 'Dropoff', snippet: _dropoffAddress),
      ));
    }
    setState(() => _markers = markers);
  }

  void _onDropoffChanged() {
    final text = _dropoffCtrl.text;
    _debounce?.cancel();
    if (text.isEmpty) {
      setState(() {
        _predictions = [];
        _showDropoffSuggestions = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _searchPlaces(text));
  }

  Future<void> _searchPlaces(String query) async {
    if (query.length < 2) return;
    setState(() => _searchingDropoff = true);
    try {
      final locationBias = _pickupLatLng != null
          ? '${_pickupLatLng!.latitude},${_pickupLatLng!.longitude}'
          : '30.0444,31.2357';

      // Auto-detect language
      final hasArabic = query.contains(RegExp(r'[\u0600-\u06FF]'));
      final result = await core.ApiClient.instance.query(
        'maps.autocomplete',
        input: {
          'input': query,
          'location': locationBias,
          'radius': 50000,
          'language': hasArabic ? 'ar' : 'en',
        },
      );
      if (mounted) {
        final preds = (result['predictions'] as List? ?? [])
            .map((p) => {
                  'description': (p['description'] as String?) ?? '',
                  'placeId': (p['placeId'] as String?) ?? '',
                  'mainText': (p['mainText'] as String?) ?? '',
                  'secondaryText': (p['secondaryText'] as String?) ?? '',
                })
            .toList();
        setState(() {
          _predictions = preds;
          _showDropoffSuggestions = preds.isNotEmpty;
          _searchingDropoff = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchingDropoff = false;
          _predictions = [];
          _showDropoffSuggestions = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Search unavailable: $e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _selectPlace(Map<String, String> prediction) async {
    final placeId = prediction['placeId'] ?? '';
    if (placeId.isEmpty) return;

    setState(() {
      _dropoffCtrl.text =
          prediction['mainText'] ?? prediction['description'] ?? '';
      _dropoffAddress = prediction['description'] ?? '';
      _showDropoffSuggestions = false;
      _predictions = [];
    });

    try {
      final details = await core.ApiClient.instance.query(
        'maps.placeDetails',
        input: {'placeId': placeId},
      );
      final lat = (details['lat'] as num?)?.toDouble() ?? 0;
      final lng = (details['lng'] as num?)?.toDouble() ?? 0;
      if (lat != 0 && lng != 0) {
        setState(() {
          _dropoffLatLng = LatLng(lat, lng);
          _dropoffAddress =
              (details['address'] as String?) ?? _dropoffAddress;
          _updateMarkers();
        });
        _fitMapBounds();
        await _getRouteAndFare();
      }
    } catch (_) {}
  }

  void _fitMapBounds() {
    if (_pickupLatLng == null || _dropoffLatLng == null) return;
    final bounds = LatLngBounds(
      southwest: LatLng(
        _pickupLatLng!.latitude < _dropoffLatLng!.latitude
            ? _pickupLatLng!.latitude
            : _dropoffLatLng!.latitude,
        _pickupLatLng!.longitude < _dropoffLatLng!.longitude
            ? _pickupLatLng!.longitude
            : _dropoffLatLng!.longitude,
      ),
      northeast: LatLng(
        _pickupLatLng!.latitude > _dropoffLatLng!.latitude
            ? _pickupLatLng!.latitude
            : _dropoffLatLng!.latitude,
        _pickupLatLng!.longitude > _dropoffLatLng!.longitude
            ? _pickupLatLng!.longitude
            : _dropoffLatLng!.longitude,
      ),
    );
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  // ─── FIXED: Get directions first, then estimate fare for both vehicle types
  Future<void> _getRouteAndFare() async {
    if (_pickupLatLng == null || _dropoffLatLng == null) return;
    setState(() => _loadingFare = true);

    try {
      // ── STEP 1: Get directions (distance + duration + polyline) ─────────
      // FIX: Must call maps.directions FIRST before pricing.estimate
      final directions = await core.ApiClient.instance.query(
        'maps.directions',
        input: {
          'originLat': _pickupLatLng!.latitude,
          'originLng': _pickupLatLng!.longitude,
          'destLat': _dropoffLatLng!.latitude,
          'destLng': _dropoffLatLng!.longitude,
        },
      );

      // FIX: backend returns distanceKm + durationMinutes (not distanceMeters)
      final distanceKm =
          (directions['distanceKm'] as num?)?.toDouble() ??
          (directions['distanceMeters'] as num? ?? 0).toDouble() / 1000;
      final durationMin =
          (directions['durationMinutes'] as num?)?.toDouble() ??
          (directions['durationSeconds'] as num? ?? 0).toDouble() / 60;

      _distanceKm = distanceKm;
      _durationMin = durationMin;
      _distanceText = directions['distanceText'] as String?;
      _durationText = directions['durationText'] as String?;
      _polylineEncoded = directions['polyline'] as String?;

      // Draw route polyline on map
      if (_polylineEncoded != null && _polylineEncoded!.isNotEmpty) {
        final points = _decodePolyline(_polylineEncoded!);
        setState(() {
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: points,
              color: AppTheme.accent,
              width: 5,
            ),
          };
        });
      }

      // ── STEP 2: Estimate fare for Car ────────────────────────────────────
      // FIX: pricing.estimateFare → pricing.estimate
      // FIX: governorate must be lowercase
      // FIX: response field is 'finalFare' not 'fareEgp'
      final carResult = await core.ApiClient.instance.query(
        'pricing.estimate',
        input: {
          'governorate': _selectedGovernorate.toLowerCase(),
          'vehicleType': 'car',
          'distanceKm': distanceKm,
          'durationMin': durationMin,
        },
      );
      final carFare =
          (carResult['finalFare'] as num?)?.toDouble();

      // ── STEP 3: Estimate fare for Bike ───────────────────────────────────
      final bikeResult = await core.ApiClient.instance.query(
        'pricing.estimate',
        input: {
          'governorate': _selectedGovernorate.toLowerCase(),
          'vehicleType': 'bike',
          'distanceKm': distanceKm,
          'durationMin': durationMin,
        },
      );
      final bikeFare =
          (bikeResult['finalFare'] as num?)?.toDouble();

      if (mounted) {
        setState(() {
          _carFare = carFare;
          _bikeFare = bikeFare;
          _loadingFare = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFare = false);
    }
  }

  // Kept for backward compat (called from map tap)
  Future<void> _estimateFare() => _getRouteAndFare();

  void _onMapTap(LatLng pos) {
    if (_dropoffLatLng == null) {
      setState(() {
        _dropoffLatLng = pos;
        _dropoffCtrl.text =
            '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
        _dropoffAddress = _dropoffCtrl.text;
        _showDropoffSuggestions = false;
        _updateMarkers();
      });
      _fitMapBounds();
      _estimateFare();
    }
  }

  void _requestRide() {
    if (_pickupLatLng == null || _dropoffLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please set both pickup and dropoff locations'),
        backgroundColor: AppTheme.warning,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final fare =
        _selectedVehicleType == 'car' ? _carFare : _bikeFare;
    if (fare == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please wait for fare estimate'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    // FIX: Pass distanceKm + durationMinutes to RideRequest
    context.read<RideBloc>().add(RideRequestSubmitted(
          core.RideRequest(
            pickupAddress: _pickupAddress,
            pickupLocation: core.LatLng(
              lat: _pickupLatLng!.latitude,
              lng: _pickupLatLng!.longitude,
            ),
            dropoffAddress:
                _dropoffAddress.isNotEmpty ? _dropoffAddress : _dropoffCtrl.text,
            dropoffLocation: core.LatLng(
              lat: _dropoffLatLng!.latitude,
              lng: _dropoffLatLng!.longitude,
            ),
            governorate: _selectedGovernorate.toLowerCase(),
            vehicleType: _selectedVehicleType,
            distanceKm: _distanceKm > 0 ? _distanceKm : null,
            durationMinutes: _durationMin > 0 ? _durationMin : null,
            estimatedFare: fare,
          ),
        ));
  }

  /// Decode Google encoded polyline to LatLng list
  List<LatLng> _decodePolyline(String encoded) {
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
      shift = 0;
      result = 0;
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

  @override
  void dispose() {
    _dropoffCtrl.removeListener(_onDropoffChanged);
    _dropoffCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentFare =
        _selectedVehicleType == 'car' ? _carFare : _bikeFare;

    return BlocListener<RideBloc, RideState>(
      listener: (context, state) {
        if (state is RideSearching) {
          context.go('/searching');
        } else if (state is RideError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ));
        }
      },
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          setState(() => _showDropoffSuggestions = false);
        },
        child: Scaffold(
          backgroundColor: AppTheme.primaryDark,
          body: Stack(
            children: [
              // ── Map ────────────────────────────────────────────────
              Positioned.fill(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _pickupLatLng ??
                        const LatLng(
                            AppConstants.defaultLat, AppConstants.defaultLng),
                    zoom: AppConstants.defaultZoom,
                  ),
                  onMapCreated: (c) {
                    _mapController = c;
                  },
                  markers: _markers,
                  polylines: _polylines,
                  onTap: _onMapTap,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                  padding: EdgeInsets.only(
                    top: 160,
                    bottom: (_pickupLatLng != null && _dropoffLatLng != null)
                        ? 280
                        : 0,
                  ),
                ),
              ),

              // ── Top Panel ──────────────────────────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: AppTheme.primaryDark,
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Back + Title
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios_new,
                                    color: AppTheme.textPrimary, size: 20),
                                onPressed: () => context.pop(),
                              ),
                              Text('Book a Ride',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        // Location row
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Connector dots
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Column(
                                  children: [
                                    Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                            color: AppTheme.success,
                                            shape: BoxShape.circle)),
                                    ...List.generate(
                                        3,
                                        (_) => Container(
                                            width: 2,
                                            height: 5,
                                            margin: const EdgeInsets.symmetric(
                                                vertical: 2),
                                            color: AppTheme.textMuted)),
                                    Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                            color: AppTheme.error,
                                            shape: BoxShape.circle)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Input fields
                              Expanded(
                                child: Column(
                                  children: [
                                    _LocationField(
                                      value: _pickupAddress,
                                      hint: 'Pickup location',
                                      readOnly: true,
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppTheme.surface,
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        border: Border.all(
                                            color: AppTheme.surfaceLight),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: _dropoffCtrl,
                                              style: const TextStyle(
                                                  color:
                                                      AppTheme.textPrimary,
                                                  fontSize: 14),
                                              decoration: const InputDecoration(
                                                hintText: 'Where to?',
                                                hintStyle: TextStyle(
                                                    color: AppTheme.textMuted,
                                                    fontSize: 14),
                                                border: InputBorder.none,
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 11),
                                              ),
                                            ),
                                          ),
                                          if (_searchingDropoff)
                                            const Padding(
                                              padding:
                                                  EdgeInsets.only(right: 10),
                                              child: SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color:
                                                            AppTheme.accent),
                                              ),
                                            )
                                          else if (_dropoffCtrl
                                              .text.isNotEmpty)
                                            GestureDetector(
                                              onTap: () => setState(() {
                                                _dropoffCtrl.clear();
                                                _dropoffLatLng = null;
                                                _dropoffAddress = '';
                                                _carFare = null;
                                                _bikeFare = null;
                                                _polylines = {};
                                                _updateMarkers();
                                              }),
                                              child: const Padding(
                                                padding: EdgeInsets.only(
                                                    right: 10),
                                                child: Icon(Icons.close,
                                                    color:
                                                        AppTheme.textMuted,
                                                    size: 16),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Autocomplete Dropdown ──────────────────────────────
              if (_showDropoffSuggestions && _predictions.isNotEmpty)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 130,
                  left: 16,
                  right: 16,
                  child: Material(
                    color: AppTheme.primaryMid,
                    borderRadius: BorderRadius.circular(14),
                    elevation: 8,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: _predictions.take(6).length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: AppTheme.divider),
                        itemBuilder: (_, i) {
                          final p = _predictions[i];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.location_on_outlined,
                                color: AppTheme.accent, size: 18),
                            title: Text(p['mainText'] ?? '',
                                style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                            subtitle: Text(p['secondaryText'] ?? '',
                                style: const TextStyle(
                                    color: AppTheme.textMuted, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            onTap: () => _selectPlace(p),
                          );
                        },
                      ),
                    ),
                  ),
                ),

              // ── Bottom Panel (shown when both locations set) ────────
              if (_pickupLatLng != null && _dropoffLatLng != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primaryMid,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(22)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, -4))
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                  color: AppTheme.divider,
                                  borderRadius: BorderRadius.circular(2))),
                        ),
                        const SizedBox(height: 12),

                        // Distance + Duration
                        if (_distanceText != null && _durationText != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.route_outlined,
                                  color: AppTheme.textSecondary, size: 16),
                              const SizedBox(width: 4),
                              Text(_distanceText!,
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                              const SizedBox(width: 16),
                              const Icon(Icons.access_time,
                                  color: AppTheme.textSecondary, size: 16),
                              const SizedBox(width: 4),
                              Text(_durationText!,
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                            ],
                          ),
                        const SizedBox(height: 14),

                        // Vehicle selector
                        if (_loadingFare)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: AppTheme.accent),
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: _VehicleCard(
                                  icon: Icons.directions_car_rounded,
                                  label: 'Car',
                                  fare: _carFare,
                                  selected: _selectedVehicleType == 'car',
                                  onTap: () => setState(
                                      () => _selectedVehicleType = 'car'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _VehicleCard(
                                  icon: Icons.two_wheeler_rounded,
                                  label: 'Bike',
                                  fare: _bikeFare,
                                  selected: _selectedVehicleType == 'bike',
                                  onTap: () => setState(
                                      () => _selectedVehicleType = 'bike'),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 10),

                        // Cash only indicator
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.payments_outlined,
                                color: AppTheme.success, size: 15),
                            SizedBox(width: 6),
                            Text('Cash Payment Only',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Confirm button
                        BlocBuilder<RideBloc, RideState>(
                          builder: (context, state) {
                            final isLoading = state is RideLoading;
                            return SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed:
                                    (isLoading || currentFare == null)
                                        ? null
                                        : _requestRide,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accent,
                                  foregroundColor: AppTheme.primaryDark,
                                  disabledBackgroundColor: AppTheme.surface,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14)),
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: AppTheme.primaryDark))
                                    : Text(
                                        currentFare != null
                                            ? 'Confirm Ride  •  EGP ${currentFare.toStringAsFixed(0)}'
                                            : 'Confirm Ride',
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700)),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _LocationField extends StatelessWidget {
  final String value;
  final String hint;
  final bool readOnly;

  const _LocationField({
    required this.value,
    required this.hint,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) => Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.surfaceLight),
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          value.isEmpty ? hint : value,
          style: TextStyle(
            color: value.isEmpty ? AppTheme.textMuted : AppTheme.textPrimary,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
}

class _VehicleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final double? fare;
  final bool selected;
  final VoidCallback onTap;

  const _VehicleCard({
    required this.icon,
    required this.label,
    required this.fare,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.accent.withOpacity(0.15)
                : AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.accent : AppTheme.surfaceLight,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon,
                  color:
                      selected ? AppTheme.accent : AppTheme.textMuted,
                  size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            color: selected
                                ? AppTheme.accent
                                : AppTheme.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    if (fare != null)
                      Text(
                        'EGP ${fare!.toStringAsFixed(0)}',
                        style: TextStyle(
                            color: selected
                                ? AppTheme.accent
                                : AppTheme.textMuted,
                            fontWeight: FontWeight.w800,
                            fontSize: 15),
                      ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle,
                    color: AppTheme.accent, size: 18),
            ],
          ),
        ),
      );
}
