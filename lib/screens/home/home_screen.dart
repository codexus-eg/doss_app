import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:doss_core/doss_core.dart' hide LatLng;
import 'package:doss_core/theme/app_theme.dart';
import 'package:doss_core/constants/constants.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/ride/ride_bloc.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? _mapCtrl;
  LatLng _center = const LatLng(AppConstants.defaultLat, AppConstants.defaultLng);

  @override
  void initState() {
    super.initState();
    _locateUser();
    context.read<RideBloc>().add(ActiveRideRequested());
  }

  @override
  void dispose() { _mapCtrl?.dispose(); super.dispose(); }

  Future<void> _locateUser() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      if (!mounted) return;
      setState(() => _center = LatLng(pos.latitude, pos.longitude));
      _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(_center, 14));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final t    = lang.t;
    final user = (context.watch<AuthBloc>().state as AuthAuthenticated?)?.user;

    return BlocListener<RideBloc, RideState>(
      listener: (ctx, state) {
        if (state is RideSearching)  ctx.go('/searching');
        if (state is RideAccepted  || state is RideInProgress) ctx.go('/active-ride');
        if (state is RideCompleted) ctx.go('/ride-completed',
            extra: {'fareEgp': (state as RideCompleted).ride.fareEgp});
      },
      child: Directionality(
        textDirection: lang.textDirection,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SizedBox.expand(child: Stack(children: [
            // ── Map ────────────────────────────────────────────────────────
            Positioned.fill(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: _center, zoom: 14),
                onMapCreated: (c) { _mapCtrl = c; },
                myLocationEnabled:    true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled:  false,
                mapToolbarEnabled:    false,
                compassEnabled:       false,
                padding: const EdgeInsets.only(bottom: 315),
              ),
            ),

            // ── Top bar ────────────────────────────────────────────────────
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(children: [
                  const DossLogo(size: 30),
                  const Spacer(),
                  _TopBtn(icon: Icons.notifications_none_rounded, onTap: () {}),
                  const SizedBox(width: 8),
                  _TopBtn(icon: Icons.person_outline_rounded,
                      onTap: () => context.push('/profile')),
                ]),
              )),
            ),

            // ── My Location FAB ────────────────────────────────────────────
            Positioned(
              right: 16, bottom: 326,
              child: _TopBtn(
                icon: Icons.my_location_rounded,
                onTap: () => _mapCtrl?.animateCamera(
                    CameraUpdate.newLatLngZoom(_center, 14)),
              ),
            ),

            // ── Bottom card ────────────────────────────────────────────────
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryMid,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 24, offset: const Offset(0, -4))],
                ),
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(child: Container(width: 40, height: 4,
                        decoration: BoxDecoration(color: AppTheme.divider,
                            borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 14),

                    // Greeting
                    Text(
                      '${t("Hello", "مرحباً")}، ${user?.name.split(" ").first ?? t("Rider", "راكب")} 👋',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t('Where are you going?', 'إلى أين تريد الذهاب؟'),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 20,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 14),

                    // Search bar
                    GestureDetector(
                      onTap: () => context.push('/booking'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Row(children: [
                          const Icon(Icons.search_rounded,
                              color: AppTheme.primary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Text(
                            t('Search destination...', 'ابحث عن وجهتك...'),
                            style: const TextStyle(
                                color: AppTheme.textMuted, fontSize: 14),
                          )),
                          _CashBadge(t: t),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── 3 Vehicle Type Cards: Car | Bike | Shuttle ──────────
                    Row(children: [
                      _VehicleCard(
                        icon: Icons.directions_car_rounded,
                        label: t('Car', 'سيارة'),
                        price: t('From 25 EGP', 'من 25 ج'),
                        color: AppTheme.primary,
                        onTap: () => context.push('/booking'),
                      ),
                      const SizedBox(width: 8),
                      _VehicleCard(
                        icon: Icons.two_wheeler_rounded,
                        label: t('Bike', 'دراجة'),
                        price: t('From 15 EGP', 'من 15 ج'),
                        color: const Color(0xFF00BCD4),
                        onTap: () => context.push('/booking'),
                      ),
                      const SizedBox(width: 8),
                      // ── SHUTTLE CARD ──────────────────────────────────────
                      _ShuttleCard(
                        label:    t('Shuttle', 'شاتل'),
                        tagline:  t('Fixed routes', 'خطوط ثابتة'),
                        price:    t('From 8 EGP', 'من 8 ج'),
                        onTap:    () => context.push('/shuttle'),
                      ),
                    ]),

                    SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
                  ],
                ),
              ),
            ),
          ])),
        ),
      ),
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _TopBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _TopBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 42, height: 42,
      decoration: BoxDecoration(
        color: AppTheme.primaryMid.withOpacity(0.92),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.25), blurRadius: 8)],
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );
}

class _CashBadge extends StatelessWidget {
  final String Function(String, String) t;
  const _CashBadge({required this.t});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppTheme.primary.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.payments_outlined, color: AppTheme.primary, size: 13),
      const SizedBox(width: 3),
      Text(t('Cash', 'نقدي'), style: const TextStyle(
          color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _VehicleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String price;
  final Color color;
  final VoidCallback onTap;
  const _VehicleCard({required this.icon, required this.label,
      required this.price, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(height: 5),
        Text(label, style: TextStyle(
            color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        Text(price, style: TextStyle(
            color: color.withOpacity(0.7), fontSize: 10)),
      ]),
    ),
  ));
}

/// SHUTTLE CARD — distinct design with bus icon + "Shuttle" badge
class _ShuttleCard extends StatelessWidget {
  final String label;
  final String tagline;
  final String price;
  final VoidCallback onTap;
  const _ShuttleCard({required this.label, required this.tagline,
      required this.price, required this.onTap});

  static const _color = Color(0xFFFF6B00); // Orange — distinct from car/bike

  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _color.withOpacity(0.35), width: 1.5),
      ),
      child: Column(children: [
        const Icon(Icons.airport_shuttle_rounded, color: _color, size: 24),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(
            color: _color, fontWeight: FontWeight.w700, fontSize: 12)),
        Text(tagline, style: TextStyle(
            color: _color.withOpacity(0.75), fontSize: 9,
            fontWeight: FontWeight.w500)),
        Text(price, style: TextStyle(
            color: _color.withOpacity(0.7), fontSize: 10)),
      ]),
    ),
  ));
}
