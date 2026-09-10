import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:doss_core/doss_core.dart';
import '../../blocs/auth/auth_bloc.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final t    = lang.t;
    final user = (context.watch<AuthBloc>().state as AuthAuthenticated?)?.user;

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          title: Text(t('Profile', 'الملف الشخصي'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Avatar + name
            Center(child: Column(children: [
              Container(
                width: 88, height: 88,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF7B2FBE), Color(0xFFE91E8C)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(child: Text(
                  user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800),
                )),
              ),
              const SizedBox(height: 14),
              Text(user?.name ?? '',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(user?.phone ?? '',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            ])),
            const SizedBox(height: 30),

            _SectionLabel(t('Settings', 'الإعدادات')),
            const SizedBox(height: 8),

            // Language
            _Tile(
              icon: Icons.language_rounded,
              label: t('Language', 'اللغة'),
              trailing: GestureDetector(
                onTap: () => lang.toggle(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(lang.isArabic ? 'AR 🇸🇦' : 'EN 🇬🇧',
                        style: const TextStyle(
                            color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 12)),
                    const SizedBox(width: 4),
                    const Icon(Icons.swap_horiz_rounded, color: AppTheme.primary, size: 15),
                  ]),
                ),
              ),
            ),
            _Tile(
              icon: Icons.history_rounded,
              label: t('Ride History', 'سجل الرحلات'),
              onTap: () => context.push('/history'),
            ),
            _Tile(
              icon: Icons.help_outline_rounded,
              label: t('Help & Support', 'المساعدة والدعم'),
              onTap: () {},
            ),
            _Tile(
              icon: Icons.privacy_tip_outlined,
              label: t('Privacy Policy', 'سياسة الخصوصية'),
              onTap: () {},
            ),
            const SizedBox(height: 20),

            _SectionLabel(t('Account', 'الحساب')),
            const SizedBox(height: 8),

            _Tile(
              icon: Icons.verified_user_outlined,
              label: t('Identity Verification', 'التحقق من الهوية'),
              onTap: () => context.push('/kyc'),
            ),
            _Tile(
              icon: Icons.logout_rounded,
              label: t('Sign Out', 'تسجيل الخروج'),
              iconColor: AppTheme.error,
              labelColor: AppTheme.error,
              onTap: () => _confirmSignOut(context, t),
            ),
            const SizedBox(height: 30),

            Center(child: Text('DOSS v1.0.0',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12))),
          ],
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context, String Function(String, String) t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primaryMid,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(t('Sign Out', 'تسجيل الخروج'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          t('Are you sure you want to sign out?', 'هل أنت متأكد من تسجيل الخروج؟'),
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('Cancel', 'إلغاء')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthBloc>().add(AuthLogoutRequested());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(t('Sign Out', 'خروج')),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel(this.title);
  @override
  Widget build(BuildContext context) => Text(title,
      style: const TextStyle(
          color: AppTheme.textMuted, fontSize: 11,
          fontWeight: FontWeight.w600, letterSpacing: 0.8));
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? labelColor;
  const _Tile({
    required this.icon, required this.label,
    this.trailing, this.onTap, this.iconColor, this.labelColor,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryMid,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Icon(icon, color: iconColor ?? AppTheme.primary, size: 22),
        const SizedBox(width: 14),
        Expanded(child: Text(label,
            style: TextStyle(
                color: labelColor ?? Colors.white,
                fontSize: 15, fontWeight: FontWeight.w500))),
        trailing ?? (onTap != null
            ? const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20)
            : const SizedBox.shrink()),
      ]),
    ),
  );
}
