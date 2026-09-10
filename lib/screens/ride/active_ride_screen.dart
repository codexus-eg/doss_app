import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:doss_core/doss_core.dart' as core;
import 'package:doss_core/theme/app_theme.dart';
import 'package:doss_core/constants/constants.dart';
import 'package:doss_core/widgets/chat_screen.dart';
import 'package:doss_core/widgets/safeguard_widget.dart';
import '../../blocs/ride/ride_bloc.dart';

class ActiveRideScreen extends StatefulWidget {
  const ActiveRideScreen({super.key});
  @override
  State<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends State<ActiveRideScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapCtrl;
  Set<Marker>   _markers   = {};
  Set<Polyline> _polylines = {};

  // SafeGuard
  bool _guardActive    = false;
  bool _sosSent        = false;
  bool _sosConfirming  = false;
  Position? _myPos;
  StreamSubscription<Position>? _posSub;

  // Animations
  late AnimationController _statusCtrl;
  late Animation<double>   _statusAnim;
  late AnimationController _cardCtrl;

  @override
  void initState() {
    super.initState();
    _statusCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _statusAnim = CurvedAnimation(parent: _statusCtrl, curve: Curves.easeOut);
    _cardCtrl   = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _statusCtrl.forward();
    _cardCtrl.forward();
    _startLocation();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _statusCtrl.dispose();
    _cardCtrl.dispose();
    _mapCtrl?.dispose();
    SafeGuardService.instance.stopGuard();
    super.dispose();
  }

  Future<void> _startLocation() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) return;
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 8),
    ).listen((pos) {
      if (mounted) setState(() => _myPos = pos);
    });
  }

  void _updateMap(core.Ride ride, core.LatLng? driverLoc) {
    final markers   = <Marker>{};
    final polylines = <Polyline>{};

    markers.add(Marker(
      markerId: const MarkerId('pickup'),
      position: LatLng(ride.pickupLocation.lat, ride.pickupLocation.lng),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: const InfoWindow(title: 'Pickup'),
    ));
    markers.add(Marker(
      markerId: const MarkerId('dropoff'),
      position: LatLng(ride.dropoffLocation.lat, ride.dropoffLocation.lng),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: const InfoWindow(title: 'Drop-off'),
    ));

    if (driverLoc != null) {
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: LatLng(driverLoc.lat, driverLoc.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(title: ride.driver?.name ?? 'Driver'),
      ));
      final inRide = ride.status == core.RideStatus.inProgress;
      final dest = inRide
          ? LatLng(ride.dropoffLocation.lat, ride.dropoffLocation.lng)
          : LatLng(ride.pickupLocation.lat, ride.pickupLocation.lng);
      polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: [LatLng(driverLoc.lat, driverLoc.lng), dest],
        color: AppTheme.primary,
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ));
      _mapCtrl?.animateCamera(
          CameraUpdate.newLatLng(LatLng(driverLoc.lat, driverLoc.lng)));
    }
    if (mounted) setState(() { _markers = markers; _polylines = polylines; });
  }

  Future<void> _sendSOS(core.Ride ride) async {
    if (_sosSent) return;
    final lat = _myPos?.latitude  ?? ride.pickupLocation.lat;
    final lng = _myPos?.longitude ?? ride.pickupLocation.lng;
    setState(() { _sosSent = true; _sosConfirming = false; });
    await SafeGuardService.instance.dispatchSOS(
        rideId: ride.id, lat: lat, lng: lng);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          SizedBox(width: 10),
          Expanded(child: Text('SOS sent! Help is on the way.',
              style: TextStyle(fontWeight: FontWeight.w700))),
        ]),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 5),
      ));
    }
  }

  Future<void> _callDriver(core.Ride ride) async {
    final phone = ride.driver?.phone;
    if (phone == null) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _openChat(core.Ride ride) {
    final user = core.AuthService.instance.currentUser;
    if (user == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => RideChatScreen(
        rideId:          ride.id,
        currentUserId:   user.id,
        currentUserRole: 'rider',
        otherUserName:   ride.driver?.name ?? 'Driver',
      ),
    ));
  }

  void _openSafeGuard(core.Ride ride) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SafeGuardSheet(
        rideId:       ride.id,
        driverName:   ride.driver?.name ?? 'Driver',
        vehiclePlate: ride.driver?.vehiclePlate ?? '—',
        destination:  ride.dropoffAddress,
        lat:          _myPos?.latitude  ?? ride.pickupLocation.lat,
        lng:          _myPos?.longitude ?? ride.pickupLocation.lng,
      ),
    ).then((_) {
      setState(() => _guardActive =
          SafeGuardService.instance.isGuardActive);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<core.LanguageProvider>();
    final t    = lang.t;

    return BlocConsumer<RideBloc, RideState>(
      listener: (ctx, state) {
        if (state is RideCompleted) {
          SafeGuardService.instance.stopGuard();
          ctx.go('/ride-completed', extra: {'fareEgp': state.ride.fareEgp, 'isShuttle': state.ride.isShuttle});
        } else if (state is RideCancelledState) {
          SafeGuardService.instance.stopGuard();
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
            content: Text(state.reason),
            backgroundColor: AppTheme.warning,
            behavior: SnackBarBehavior.floating,
          ));
          ctx.go('/home');
        }
      },
      builder: (ctx, state) {
        core.Ride? ride;
        core.LatLng? driverLoc;

        if (state is RideAccepted)   { ride = state.ride; driverLoc = state.driverLocation; }
        if (state is RideInProgress) { ride = state.ride; driverLoc = state.driverLocation; }

        if (ride != null) {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => _updateMap(ride!, driverLoc));
        }

        final isInProgress = ride?.status == core.RideStatus.inProgress;
        final isArrived    = ride?.status == core.RideStatus.arrived;

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(children: [
            // ── Map ──────────────────────────────────────────────────────
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: ride != null
                    ? LatLng(ride.pickupLocation.lat, ride.pickupLocation.lng)
                    : const LatLng(AppConstants.defaultLat, AppConstants.defaultLng),
                zoom: AppConstants.defaultZoom,
              ),
              onMapCreated: (c) { _mapCtrl = c; },
              markers:   _markers,
              polylines: _polylines,
              myLocationEnabled:    true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled:  false,
              mapToolbarEnabled:    false,
              padding: const EdgeInsets.only(bottom: 260),
            ),

            // ── Status banner ─────────────────────────────────────────────
            SafeArea(child: Padding(
              padding: const EdgeInsets.all(16),
              child: FadeTransition(
                opacity: _statusAnim,
                child: _StatusBanner(
                    isInProgress: isInProgress,
                    isArrived:    isArrived,
                    t: t),
              ),
            )),

            // ── SafeGuard FAB ─────────────────────────────────────────────
            if (ride != null)
              Positioned(
                right: 16, bottom: 270,
                child: SafeGuardFAB(
                  active: _guardActive,
                  onTap:  () => _openSafeGuard(ride!),
                ),
              ),

            // ── SOS Confirm Overlay ───────────────────────────────────────
            if (_sosConfirming && ride != null)
              _SOSConfirmOverlay(
                onConfirm: () => _sendSOS(ride!),
                onCancel:  () => setState(() => _sosConfirming = false),
                t: t,
              ),

            // ── Active SOS banner ─────────────────────────────────────────
            if (_sosSent)
              Positioned(top: 90, left: 16, right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    color: AppTheme.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('SOS Active — Help is on the way!',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),

            // ── Driver card ───────────────────────────────────────────────
            if (ride != null)
              Positioned(bottom: 0, left: 0, right: 0,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                      parent: _cardCtrl, curve: Curves.easeOut)),
                  child: _DriverCard(
                    ride:    ride,
                    t:       t,
                    sosSent: _sosSent,
                    onCall:  () => _callDriver(ride!),
                    onChat:  () => _openChat(ride!),
                    onSOS:   () => setState(() => _sosConfirming = true),
                  ),
                ),
              ),
          ]),
        );
      },
    );
  }
}

// ─── Status Banner ─────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final bool isInProgress;
  final bool isArrived;
  final bool isShuttle;
  final String Function(String, String) t;

  const _StatusBanner({
    required this.isInProgress,
    required this.isArrived,
    this.isShuttle = false,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    final String label;

    if (isInProgress) {
      color = AppTheme.success;
      icon  = isShuttle ? Icons.airport_shuttle_rounded : Icons.directions_car_rounded;
      label = t('On the way to destination', 'في الطريق إلى الوجهة');
    } else if (isArrived) {
      color = AppTheme.warning;
      icon  = Icons.location_on_rounded;
      label = isShuttle
          ? t('Shuttle has arrived!', 'وصل الشاتل!')
          : t('Driver has arrived!', 'وصل السائق!');
    } else {
      color = AppTheme.primary;
      icon  = isShuttle ? Icons.airport_shuttle_rounded : Icons.access_time_rounded;
      label = isShuttle
          ? t('Shuttle is on the way', 'الشاتل في الطريق')
          : t('Driver is on the way', 'السائق في الطريق');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.92),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.3), blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 17),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white,
            fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    );
  }
}

// ─── Driver Card ───────────────────────────────────────────────────────────

class _DriverCard extends StatelessWidget {
  final core.Ride ride;
  final String Function(String, String) t;
  final bool sosSent;
  final VoidCallback onCall;
  final VoidCallback onChat;
  final VoidCallback onSOS;

  const _DriverCard({
    required this.ride, required this.t, required this.sosSent,
    required this.onCall, required this.onChat, required this.onSOS,
  });

  @override
  Widget build(BuildContext context) {
    final driver = ride.driver;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryMid,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5),
              blurRadius: 24, offset: const Offset(0, -4))
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),

        // Driver row
        Row(children: [
          Container(
            width: 52, height: 52,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF7B2FBE), Color(0xFFE91E8C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(
              driver?.name.isNotEmpty == true
                  ? driver!.name[0].toUpperCase() : 'D',
              style: const TextStyle(color: Colors.white,
                  fontSize: 22, fontWeight: FontWeight.w800),
            )),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(driver?.name ?? t('Your Driver', 'سائقك'),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700,
                    fontSize: 15)),
            const SizedBox(height: 3),
            Row(children: [
              const Icon(Icons.star_rounded,
                  color: Color(0xFFFFC107), size: 14),
              const SizedBox(width: 3),
              Text(driver?.rating?.toStringAsFixed(1) ?? '—',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(width: 10),
              const Icon(Icons.directions_car_outlined,
                  color: AppTheme.textMuted, size: 14),
              const SizedBox(width: 3),
              Text(driver?.vehiclePlate ?? '—',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ])),
          // Fare badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
            ),
            child: Text('EGP ${ride.fareEgp.toStringAsFixed(0)}',
                style: const TextStyle(color: AppTheme.primary,
                    fontWeight: FontWeight.w900, fontSize: 16)),
          ),
        ]),
        const SizedBox(height: 14),

        // Trip summary
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            _TripRow(icon: Icons.radio_button_checked_rounded,
                color: AppTheme.success, label: t('Pickup', 'الانطلاق'),
                value: ride.pickupAddress),
            const SizedBox(height: 6),
            _TripRow(icon: Icons.location_on_rounded,
                color: AppTheme.error, label: t('Destination', 'الوجهة'),
                value: ride.dropoffAddress),
          ]),
        ),
        const SizedBox(height: 14),

        // Action row: Call | Chat | SOS
        Row(children: [
          Expanded(child: _ActionBtn(
            icon: Icons.phone_outlined,
            label: t('Call', 'اتصال'),
            color: AppTheme.success,
            onTap: onCall,
          )),
          const SizedBox(width: 10),
          Expanded(child: _ActionBtn(
            icon: Icons.chat_bubble_outline_rounded,
            label: t('Chat', 'دردشة'),
            color: AppTheme.primary,
            onTap: onChat,
          )),
          const SizedBox(width: 10),
          Expanded(child: _ActionBtn(
            icon: Icons.warning_amber_rounded,
            label: 'SOS',
            color: AppTheme.error,
            filled: true,
            onTap: sosSent ? null : onSOS,
          )),
        ]),
      ]),
    );
  }
}

class _TripRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _TripRow({required this.icon, required this.color,
      required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: color, size: 15),
    const SizedBox(width: 8),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(
          color: AppTheme.textMuted, fontSize: 10)),
      Text(value, style: const TextStyle(
          color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
          maxLines: 1, overflow: TextOverflow.ellipsis),
    ])),
  ]);
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback? onTap;
  const _ActionBtn({required this.icon, required this.label,
      required this.color, this.filled = false, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: filled
            ? (onTap == null ? AppTheme.error.withOpacity(0.3) : color)
            : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: filled ? null : Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: filled ? Colors.white : color, size: 22),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(
            color: filled ? Colors.white : color,
            fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}

// ─── SOS Confirm Overlay ───────────────────────────────────────────────────

class _SOSConfirmOverlay extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final String Function(String, String) t;
  const _SOSConfirmOverlay({required this.onConfirm, required this.onCancel, required this.t});
  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.primaryMid,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.error.withOpacity(0.5)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 66, height: 66,
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: AppTheme.error, size: 38),
            ),
            const SizedBox(height: 16),
            Text(t('SOS Emergency', 'طوارئ SOS'),
                style: const TextStyle(color: Colors.white,
                    fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(
              t('This will alert DOSS support and share your live location.',
                  'سيتم إخطار دعم DOSS ومشاركة موقعك الحالي.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary,
                  fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 22),
            SizedBox(width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(t('SEND SOS', 'إرسال SOS'),
                    style: const TextStyle(fontWeight: FontWeight.w800,
                        fontSize: 16, letterSpacing: 1)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: onCancel,
                child: Text(t('Cancel', 'إلغاء'),
                    style: const TextStyle(color: AppTheme.textMuted))),
          ]),
        ),
      )),
    ),
  );
}
