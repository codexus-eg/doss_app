import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:doss_core/doss_core.dart';
import 'package:doss_core/theme/app_theme.dart';
import '../../blocs/ride/ride_bloc.dart';

class RideCompletedScreen extends StatefulWidget {
  final double fareEgp;
  final bool   isShuttle;
  const RideCompletedScreen({super.key, required this.fareEgp, this.isShuttle = false});
  @override
  State<RideCompletedScreen> createState() => _RideCompletedScreenState();
}

class _RideCompletedScreenState extends State<RideCompletedScreen>
    with TickerProviderStateMixin {
  late AnimationController _checkCtrl;
  late AnimationController _cardCtrl;
  late Animation<double> _scale;
  late Animation<double> _fade;
  late Animation<double> _cardSlide;

  int  _rating    = 0;
  int  _tip       = 0;
  bool _submitted = false;

  static const _tips = [0, 5, 10, 15];

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _cardCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _scale     = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut));
    _fade      = CurvedAnimation(parent: _checkCtrl, curve: Curves.easeIn);
    _cardSlide = Tween<double>(begin: 50, end: 0).animate(
        CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 150), () {
      _checkCtrl.forward();
      Future.delayed(const Duration(milliseconds: 500), () => _cardCtrl.forward());
    });
  }

  @override
  void dispose() { _checkCtrl.dispose(); _cardCtrl.dispose(); super.dispose(); }

  Future<void> _submitRating() async {
    if (_rating == 0) return;
    setState(() => _submitted = true);
    try {
      await ApiClient.instance.mutate('rides.submitRating',
          input: {'rating': _rating, 'tip': _tip});
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) _goHome();
  }

  void _goHome() {
    context.read<RideBloc>().add(RideReset());
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final t    = lang.t;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const SizedBox(height: 28),

          // Animated checkmark
          AnimatedBuilder(animation: _checkCtrl, builder: (_, __) =>
            FadeTransition(opacity: _fade, child: ScaleTransition(scale: _scale,
              child: Stack(alignment: Alignment.center, children: [
                Container(width: 110, height: 110, decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.1), shape: BoxShape.circle)),
                Container(width: 80, height: 80, decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.18), shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, color: AppTheme.success, size: 44)),
              ]),
            )),
          ),
          const SizedBox(height: 16),

          // Shuttle badge (if applicable)
          if (widget.isShuttle)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B00).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFF6B00).withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.airport_shuttle_rounded,
                    color: Color(0xFFFF6B00), size: 14),
                const SizedBox(width: 5),
                Text(t('DOSS Shuttle', 'DOSS شاتل'),
                    style: const TextStyle(
                        color: Color(0xFFFF6B00), fontWeight: FontWeight.w700, fontSize: 12)),
              ]),
            ),

          Text(
            widget.isShuttle
                ? t('Shuttle Completed!', 'انتهى الشاتل!')
                : t('Ride Completed!', 'انتهت الرحلة!'),
            style: const TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),

          // Card
          AnimatedBuilder(animation: _cardCtrl, builder: (_, __) =>
            Transform.translate(offset: Offset(0, _cardSlide.value),
              child: Opacity(opacity: _cardCtrl.value.clamp(0, 1),
                child: Column(children: [
                  const SizedBox(height: 14),

                  // Fare
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryMid,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                    ),
                    child: Column(children: [
                      Text(t('Total Fare', 'إجمالي الأجرة'),
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13)),
                      const SizedBox(height: 8),
                      Text('EGP ${widget.fareEgp.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: AppTheme.primary, fontSize: 44,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.payments_outlined,
                            color: AppTheme.textMuted, size: 14),
                        const SizedBox(width: 4),
                        Text(t('Cash Payment', 'دفع نقدي'),
                            style: const TextStyle(
                                color: AppTheme.textMuted, fontSize: 12)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 22),

                  if (!_submitted) ...[
                    Text(
                      widget.isShuttle
                          ? t('Rate your shuttle driver', 'قيّم سائق الشاتل')
                          : t('Rate your driver', 'قيّم سائقك'),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    RatingWidget(starSize: 42, onRatingChanged: (r) =>
                        setState(() => _rating = r)),
                    const SizedBox(height: 20),

                    // Tip
                    if (!widget.isShuttle) ...[
                      Text(t('Add tip (optional)', 'إضافة إكرامية (اختياري)'),
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13)),
                      const SizedBox(height: 10),
                      Row(mainAxisAlignment: MainAxisAlignment.center,
                          children: _tips.map((tip) {
                        final sel = _tip == tip;
                        return GestureDetector(
                          onTap: () => setState(() => _tip = tip),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppTheme.primary.withOpacity(0.15)
                                  : AppTheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: sel ? AppTheme.primary : AppTheme.divider,
                                width: sel ? 2 : 1,
                              ),
                            ),
                            child: Text(
                              tip == 0 ? t('No tip', 'بدون') : '+EGP $tip',
                              style: TextStyle(
                                color: sel ? AppTheme.primary : AppTheme.textSecondary,
                                fontWeight: FontWeight.w600, fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }).toList()),
                      const SizedBox(height: 20),
                    ],

                    SizedBox(width: double.infinity, height: 54,
                      child: ElevatedButton(
                        onPressed: _rating > 0 ? _submitRating : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppTheme.surface,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(t('Submit Rating', 'إرسال التقييم'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(onPressed: _goHome,
                        child: Text(t('Skip', 'تخطي'),
                            style: const TextStyle(
                                color: AppTheme.textMuted, fontSize: 14))),
                  ] else ...[
                    const SizedBox(height: 16),
                    const Icon(Icons.favorite_rounded, color: AppTheme.error, size: 36),
                    const SizedBox(height: 8),
                    Text(t('Thank you!', 'شكراً!'), style: const TextStyle(
                        color: AppTheme.success, fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                ]),
              ),
            ),
          ),
        ]),
      )),
    );
  }
}
