// ══════════════════════════════════════════════════════════════════════════════
// DOSS Shuttle Booking Screen
//
// Flow:
//   1. Rider sees all available routes grouped by city
//   2. Selects origin station → destinations shown automatically
//   3. Selects destination → fare, distance, ETA shown
//   4. Confirms booking → ShuttleRequest submitted via RideBloc
//
// Design: Royal Blue #0052FF on Pure Black
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:doss_core/doss_core.dart' hide LatLng;
import 'package:doss_core/theme/app_theme.dart';
import 'package:doss_core/constants/constants.dart';
import 'package:doss_core/services/maps_service.dart';
import 'package:doss_core/models/models.dart' as models;
import '../../blocs/ride/ride_bloc.dart';

class ShuttleBookingScreen extends StatefulWidget {
  const ShuttleBookingScreen({super.key});

  @override
  State<ShuttleBookingScreen> createState() => _ShuttleBookingScreenState();
}

class _ShuttleBookingScreenState extends State<ShuttleBookingScreen>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapCtrl;
  late TabController _govTabCtrl;

  // State
  String _selectedGov      = 'cairo'; // 'cairo' | 'giza' | 'alexandria'
  models.ShuttleStation? _origin;
  models.ShuttleStation? _destination;
  models.ShuttleRoute?   _selectedRoute;
  bool _confirming         = false;

  // Location
  Position? _myPos;

  static const _govs = [
    {'key': 'cairo',      'labelEn': 'Cairo',      'labelAr': 'القاهرة'},
    {'key': 'giza',       'labelEn': 'Giza',        'labelAr': 'الجيزة'},
    {'key': 'alexandria', 'labelEn': 'Alexandria',  'labelAr': 'الإسكندرية'},
  ];

  @override
  void initState() {
    super.initState();
    _govTabCtrl = TabController(length: _govs.length, vsync: this);
    _govTabCtrl.addListener(() {
      if (!_govTabCtrl.indexIsChanging) return;
      setState(() {
        _selectedGov = _govs[_govTabCtrl.index]['key']!;
        _origin      = null;
        _destination = null;
        _selectedRoute = null;
      });
    });
    _loadLocation();
  }

  @override
  void dispose() {
    _govTabCtrl.dispose();
    _mapCtrl?.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
      if (!mounted) return;
      setState(() => _myPos = pos);

      // Auto-detect governorate from GPS
      final zone = MapsService.serviceZoneLabel(pos.latitude, pos.longitude);
      final govIdx = _govs.indexWhere((g) => g['key'] == zone);
      if (govIdx >= 0) {
        _govTabCtrl.animateTo(govIdx);
        setState(() => _selectedGov = zone);
      }
    } catch (_) {}
  }

  List<models.ShuttleStation> get _stations =>
      MapsService.getStationsByGovernorate(_selectedGov);

  List<models.ShuttleRoute> get _routesFromOrigin =>
      _origin != null ? MapsService.getRoutesFromStation(_origin!.id) : [];

  void _selectOrigin(models.ShuttleStation station) {
    setState(() {
      _origin      = station;
      _destination = null;
      _selectedRoute = null;
    });
    _animateToStation(station);
  }

  void _selectDestination(models.ShuttleStation station) {
    final route = MapsService.findRoute(_origin!.id, station.id);
    setState(() {
      _destination   = station;
      _selectedRoute = route;
    });
    if (route != null) _animateToBothStations(route);
  }

  void _animateToStation(models.ShuttleStation s) {
    _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(
      LatLng(s.location.lat, s.location.lng), 14));
  }

  void _animateToBothStations(models.ShuttleRoute route) {
    _mapCtrl?.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(
          route.origin.location.lat < route.destination.location.lat
              ? route.origin.location.lat : route.destination.location.lat,
          route.origin.location.lng < route.destination.location.lng
              ? route.origin.location.lng : route.destination.location.lng,
        ),
        northeast: LatLng(
          route.origin.location.lat > route.destination.location.lat
              ? route.origin.location.lat : route.destination.location.lat,
          route.origin.location.lng > route.destination.location.lng
              ? route.origin.location.lng : route.destination.location.lng,
        ),
      ), 80,
    ));
  }

  Future<void> _confirmBooking() async {
    if (_selectedRoute == null) return;
    setState(() => _confirming = true);

    final route = _selectedRoute!;
    final request = ShuttleRequest(
      routeId:              route.routeId,
      originStationId:      route.origin.id,
      destinationStationId: route.destination.id,
      pickupAddress:        route.origin.nameEn,
      pickupLocation:       route.origin.location,
      dropoffAddress:       route.destination.nameEn,
      dropoffLocation:      route.destination.location,
      fareEgp:              route.fareEgp,
      governorate:          route.governorate,
      distanceKm:           route.distanceKm,
      durationMinutes:      route.durationMinutes.toDouble(),
    );

    context.read<RideBloc>().add(ShuttleRequestSubmitted(request));
  }

  Set<Marker> get _markers {
    final out = <Marker>{};
    for (final s in _stations) {
      final isOrigin = _origin?.id == s.id;
      final isDest   = _destination?.id == s.id;
      out.add(Marker(
        markerId: MarkerId(s.id),
        position: LatLng(s.location.lat, s.location.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isOrigin  ? BitmapDescriptor.hueBlue  :
          isDest    ? BitmapDescriptor.hueRed   :
                      BitmapDescriptor.hueViolet,
        ),
        infoWindow: InfoWindow(title: s.nameEn, snippet: s.area),
        onTap: () {
          if (_origin == null) {
            _selectOrigin(s);
          } else if (_destination == null && s.id != _origin?.id) {
            _selectDestination(s);
          }
        },
      ));
    }
    return out;
  }

  Set<Polyline> get _routePolylines {
    if (_selectedRoute == null) return {};
    return {
      Polyline(
        polylineId: const PolylineId('shuttle_route'),
        points: [
          LatLng(_selectedRoute!.origin.location.lat,
                 _selectedRoute!.origin.location.lng),
          LatLng(_selectedRoute!.destination.location.lat,
                 _selectedRoute!.destination.location.lng),
        ],
        color: AppTheme.primary,
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final t    = lang.t;
    final isAr = lang.isArabic;

    return BlocListener<RideBloc, RideState>(
      listener: (ctx, state) {
        if (state is RideSearching) ctx.go('/searching');
        if (state is RideError) {
          setState(() => _confirming = false);
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ));
        }
      },
      child: Directionality(
        textDirection: lang.textDirection,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(children: [
            // ── Map ────────────────────────────────────────────────────────
            Positioned.fill(
              child: GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: LatLng(30.0444, 31.2357), zoom: 11),
                onMapCreated: (c) {
                  _mapCtrl = c;
                },
                markers:   _markers,
                polylines: _routePolylines,
                zoomControlsEnabled:  false,
                mapToolbarEnabled:    false,
                myLocationEnabled:    _myPos != null,
                myLocationButtonEnabled: false,
                padding: const EdgeInsets.only(bottom: 360),
              ),
            ),

            // ── Top bar ────────────────────────────────────────────────────
            SafeArea(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                _BackBtn(onTap: () => context.pop()),
                const SizedBox(width: 12),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.airport_shuttle_rounded,
                        color: AppTheme.primary, size: 20),
                    const SizedBox(width: 6),
                    Text('DOSS Shuttle',
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w800, fontSize: 16)),
                  ]),
                  Text(t('Fixed routes • Low fares', 'خطوط ثابتة • أسعار منخفضة'),
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 11)),
                ])),
              ]),
            )),

            // ── Bottom sheet ───────────────────────────────────────────────
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _BottomSheet(
                govTabCtrl:    _govTabCtrl,
                govs:          _govs,
                stations:      _stations,
                routesFromOrigin: _routesFromOrigin,
                origin:        _origin,
                destination:   _destination,
                selectedRoute: _selectedRoute,
                confirming:    _confirming,
                isAr:          isAr,
                t:             t,
                onSelectOrigin:      _selectOrigin,
                onSelectDestination: _selectDestination,
                onConfirm:     _confirming ? null : _confirmBooking,
                onReset: () => setState(() {
                  _origin = null; _destination = null; _selectedRoute = null;
                }),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Bottom Sheet ─────────────────────────────────────────────────────────────

class _BottomSheet extends StatelessWidget {
  final TabController govTabCtrl;
  final List<Map<String, String>> govs;
  final List<models.ShuttleStation> stations;
  final List<models.ShuttleRoute>   routesFromOrigin;
  final models.ShuttleStation? origin;
  final models.ShuttleStation? destination;
  final models.ShuttleRoute?   selectedRoute;
  final bool confirming;
  final bool isAr;
  final String Function(String, String) t;
  final ValueChanged<models.ShuttleStation> onSelectOrigin;
  final ValueChanged<models.ShuttleStation> onSelectDestination;
  final VoidCallback? onConfirm;
  final VoidCallback onReset;

  const _BottomSheet({
    required this.govTabCtrl,
    required this.govs,
    required this.stations,
    required this.routesFromOrigin,
    required this.origin,
    required this.destination,
    required this.selectedRoute,
    required this.confirming,
    required this.isAr,
    required this.t,
    required this.onSelectOrigin,
    required this.onSelectDestination,
    required this.onConfirm,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryMid,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5),
              blurRadius: 24, offset: const Offset(0, -4))
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        const SizedBox(height: 12),
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 14),

        // If a route is selected → show confirm card
        if (selectedRoute != null)
          _RouteConfirmCard(
            route:     selectedRoute!,
            isAr:      isAr,
            t:         t,
            confirming: confirming,
            onConfirm: onConfirm,
            onReset:   onReset,
          )
        else ...[
          // City tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TabBar(
              controller: govTabCtrl,
              indicatorColor:   AppTheme.primary,
              labelColor:       AppTheme.primary,
              unselectedLabelColor: AppTheme.textMuted,
              indicatorSize:    TabBarIndicatorSize.label,
              tabs: govs.map((g) =>
                  Tab(text: isAr ? g['labelAr']! : g['labelEn']!)).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Selection breadcrumb
          if (origin != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _SelectionCrumb(
                origin:      origin,
                destination: destination,
                isAr:        isAr,
                t:           t,
                onReset:     onReset,
              ),
            ),

          // Station / destination list
          SizedBox(
            height: 220,
            child: origin == null
                ? _StationList(
                    stations:  stations,
                    isAr:      isAr,
                    t:         t,
                    onSelect:  onSelectOrigin,
                    label:     t('Choose pickup station', 'اختر محطة الانطلاق'),
                  )
                : _DestinationList(
                    routes:    routesFromOrigin,
                    isAr:      isAr,
                    t:         t,
                    onSelect:  onSelectDestination,
                    label:     t('Choose drop-off station', 'اختر محطة الوصول'),
                  ),
          ),
        ],

        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
      ]),
    );
  }
}

// ─── Station List ─────────────────────────────────────────────────────────────

class _StationList extends StatelessWidget {
  final List<models.ShuttleStation> stations;
  final bool isAr;
  final String Function(String, String) t;
  final ValueChanged<models.ShuttleStation> onSelect;
  final String label;

  const _StationList({
    required this.stations,
    required this.isAr,
    required this.t,
    required this.onSelect,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    if (stations.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.airport_shuttle_rounded,
              color: AppTheme.textMuted, size: 40),
          const SizedBox(height: 10),
          Text(t('No routes available in your area',
              'لا توجد خطوط متاحة في منطقتك'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
        ]),
      ));
    }

    // Group by area
    final areas = <String, List<models.ShuttleStation>>{};
    for (final s in stations) {
      areas.putIfAbsent(s.area, () => []).add(s);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(label, style: const TextStyle(
            color: AppTheme.textSecondary, fontSize: 12,
            fontWeight: FontWeight.w600)),
      ),
      const SizedBox(height: 6),
      Expanded(child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: areas.entries.map((entry) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(entry.key, style: const TextStyle(
                  color: AppTheme.textMuted, fontSize: 11,
                  fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            ),
            ...entry.value.map((s) => _StationTile(
                station: s, isAr: isAr, onTap: () => onSelect(s))),
          ],
        )).toList(),
      )),
    ]);
  }
}

class _StationTile extends StatelessWidget {
  final models.ShuttleStation station;
  final bool isAr;
  final VoidCallback onTap;

  const _StationTile({required this.station, required this.isAr, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.directions_bus_rounded,
              color: AppTheme.primary, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(
          station.name(isAr),
          style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.w500, fontSize: 13),
          maxLines: 1, overflow: TextOverflow.ellipsis,
        )),
        const Icon(Icons.chevron_right_rounded,
            color: AppTheme.textMuted, size: 18),
      ]),
    ),
  );
}

// ─── Destination List ─────────────────────────────────────────────────────────

class _DestinationList extends StatelessWidget {
  final List<models.ShuttleRoute> routes;
  final bool isAr;
  final String Function(String, String) t;
  final ValueChanged<models.ShuttleStation> onSelect;
  final String label;

  const _DestinationList({
    required this.routes,
    required this.isAr,
    required this.t,
    required this.onSelect,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    if (routes.isEmpty) {
      return Center(child: Text(
        t('No destinations from this station', 'لا توجد وجهات من هذه المحطة'),
        style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(label, style: const TextStyle(
            color: AppTheme.textSecondary, fontSize: 12,
            fontWeight: FontWeight.w600)),
      ),
      const SizedBox(height: 6),
      Expanded(child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: routes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final r = routes[i];
          return GestureDetector(
            onTap: () => onSelect(r.destination),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(children: [
                const Icon(Icons.location_on_rounded,
                    color: AppTheme.error, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.destination.name(isAr), style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('${r.distanceKm.toStringAsFixed(1)} km • ${r.durationMinutes} min',
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 11)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                  ),
                  child: Text('EGP ${r.fareEgp.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: AppTheme.primary, fontWeight: FontWeight.w800, fontSize: 14)),
                ),
              ]),
            ),
          );
        },
      )),
    ]);
  }
}

// ─── Selection Breadcrumb ─────────────────────────────────────────────────────

class _SelectionCrumb extends StatelessWidget {
  final models.ShuttleStation? origin;
  final models.ShuttleStation? destination;
  final bool isAr;
  final String Function(String, String) t;
  final VoidCallback onReset;

  const _SelectionCrumb({
    required this.origin, required this.destination,
    required this.isAr, required this.t, required this.onReset,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
    ),
    child: Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.radio_button_checked_rounded,
              color: AppTheme.success, size: 14),
          const SizedBox(width: 6),
          Text(origin?.name(isAr) ?? '',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
        ]),
        if (destination != null) ...[
          Container(margin: const EdgeInsets.only(left: 6),
              width: 1, height: 10, color: AppTheme.divider),
          Row(children: [
            const Icon(Icons.location_on_rounded,
                color: AppTheme.error, size: 14),
            const SizedBox(width: 6),
            Text(destination!.name(isAr), style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
          ]),
        ],
      ]),
      const Spacer(),
      GestureDetector(
        onTap: onReset,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.close_rounded, color: AppTheme.error, size: 16),
        ),
      ),
    ]),
  );
}

// ─── Route Confirm Card ───────────────────────────────────────────────────────

class _RouteConfirmCard extends StatelessWidget {
  final models.ShuttleRoute route;
  final bool isAr;
  final String Function(String, String) t;
  final bool confirming;
  final VoidCallback? onConfirm;
  final VoidCallback onReset;

  const _RouteConfirmCard({
    required this.route, required this.isAr, required this.t,
    required this.confirming, required this.onConfirm, required this.onReset,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      // Route display
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
        ),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.airport_shuttle_rounded,
                color: AppTheme.primary, size: 22),
            const SizedBox(width: 10),
            Text(t('Shuttle Route', 'خط الشاتل'),
                style: const TextStyle(
                    color: AppTheme.primary, fontWeight: FontWeight.w700,
                    fontSize: 14)),
            const Spacer(),
            GestureDetector(
              onTap: onReset,
              child: const Icon(Icons.edit_outlined,
                  color: AppTheme.textMuted, size: 16),
            ),
          ]),
          const SizedBox(height: 14),
          // Origin
          _InfoRow(
            icon: Icons.radio_button_checked_rounded,
            color: AppTheme.success,
            label: t('Pickup Station', 'محطة الانطلاق'),
            value: route.origin.name(isAr),
          ),
          const SizedBox(height: 6),
          // Destination
          _InfoRow(
            icon: Icons.location_on_rounded,
            color: AppTheme.error,
            label: t('Drop-off Station', 'محطة الوصول'),
            value: route.destination.name(isAr),
          ),
          const SizedBox(height: 10),
          // Stats row
          Row(children: [
            _StatBadge(Icons.straighten, '${route.distanceKm.toStringAsFixed(1)} km'),
            const SizedBox(width: 8),
            _StatBadge(Icons.access_time_rounded, '${route.durationMinutes} min'),
            const SizedBox(width: 8),
            _StatBadge(Icons.people_outline_rounded, t('14 seats', '14 مقعداً')),
          ]),
        ]),
      ),
      const SizedBox(height: 14),

      // Fare + confirm
      Row(children: [
        // Fare badge
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('Fixed Fare', 'سعر ثابت'),
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          Text('EGP ${route.fareEgp.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: AppTheme.primary, fontWeight: FontWeight.w900,
                  fontSize: 28)),
          Text(t('Cash only', 'نقدي فقط'),
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ]),
        const SizedBox(width: 16),
        // Confirm button
        Expanded(child: SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: confirming ? null : onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: confirming
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : Text(t('Confirm Shuttle', 'تأكيد الشاتل'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        )),
      ]),
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.color,
      required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: color, size: 15),
    const SizedBox(width: 8),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
      Text(value, style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13),
          maxLines: 1, overflow: TextOverflow.ellipsis),
    ])),
  ]);
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatBadge(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppTheme.primaryMid,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: AppTheme.textMuted, size: 12),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(
          color: AppTheme.textSecondary, fontSize: 11)),
    ]),
  );
}

class _BackBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _BackBtn({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: AppTheme.primaryMid.withOpacity(0.9),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.25), blurRadius: 8)],
      ),
      child: const Icon(Icons.arrow_back_ios_new_rounded,
          color: Colors.white, size: 18),
    ),
  );
}
