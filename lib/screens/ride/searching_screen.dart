import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:doss_core/doss_core.dart';
import '../../blocs/ride/ride_bloc.dart';

class SearchingScreen extends StatefulWidget {
  const SearchingScreen({super.key});

  @override
  State<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends State<SearchingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RideBloc, RideState>(
      listener: (context, state) {
        if (state is RideAccepted || state is RideInProgress) {
          context.go('/active-ride');
        } else if (state is RideCancelledState || state is RideInitial) {
          context.go('/home');
        } else if (state is RideError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.go('/home');
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.primaryDark,
        body: SafeArea(
          child: BlocBuilder<RideBloc, RideState>(
            builder: (context, state) {
              final ride = state is RideSearching ? state.ride : null;

              return Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated pulse ring
                    ScaleTransition(
                      scale: _pulseAnim,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.accent.withOpacity(0.12),
                          border: Border.all(
                            color: AppTheme.accent.withOpacity(0.4),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.accent.withOpacity(0.2),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.directions_car_rounded,
                                color: AppTheme.accent,
                                size: 48,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      (state is RideSearching && state.ride.isShuttle)
                          ? 'Finding your shuttle...'
                          : 'Finding your driver...',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Our smart dispatch is matching you with the best available driver nearby.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    // Ride details card
                    if (ride != null) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryMid,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            _RideDetailRow(
                              icon: Icons.radio_button_checked,
                              iconColor: AppTheme.success,
                              label: 'Pickup',
                              value: ride.pickupAddress,
                            ),
                            const Divider(color: AppTheme.divider, height: 24),
                            _RideDetailRow(
                              icon: Icons.location_on,
                              iconColor: AppTheme.error,
                              label: 'Dropoff',
                              value: ride.dropoffAddress,
                            ),
                            const Divider(color: AppTheme.divider, height: 24),
                            _RideDetailRow(
                              icon: Icons.payments_outlined,
                              iconColor: AppTheme.accent,
                              label: 'Fare',
                              value: 'EGP ${ride.fareEgp.toStringAsFixed(2)}',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                    // Cancel button
                    TextButton.icon(
                      onPressed: () {
                        if (ride != null) {
                          context.read<RideBloc>().add(RideCancelled(ride.id));
                        } else {
                          context.read<RideBloc>().add(RideReset());
                          context.go('/home');
                        }
                      },
                      icon: const Icon(Icons.close, color: AppTheme.error),
                      label: const Text(
                        'Cancel Ride',
                        style: TextStyle(color: AppTheme.error),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RideDetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _RideDetailRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}
