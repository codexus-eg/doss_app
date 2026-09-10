import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:doss_core/doss_core.dart';

/// Max accepted image size — mirrors the 5MB limit enforced by
/// `riders.uploadKycDocument` on the server.
const int _maxUploadBytes = 5 * 1024 * 1024;

// ─── Light surface palette (v3 brand on a light screen) ─────────────────────
const Color _bg = Color(0xFFF4F7FA);
const Color _cardBg = Color(0xFFFFFFFF);
const Color _textDark = AppTheme.navyDeep;
const Color _textMuted = Color(0xFF6B7A88);
const Color _border = Color(0xFFE2E8EE);
const Color _action = AppTheme.brandBlue;

class _KycItem {
  /// Matches the `documentType` enum accepted by `riders.uploadKycDocument`.
  final String docType;
  final String titleEn;
  final String titleAr;
  final String hintEn;
  final String hintAr;
  final IconData icon;
  final bool selfieCamera;
  File? file;
  String? url;
  bool uploading = false;
  String? error;
  _KycItem({
    required this.docType,
    required this.titleEn,
    required this.titleAr,
    required this.hintEn,
    required this.hintAr,
    required this.icon,
    this.selfieCamera = false,
  });

  bool get done => url != null && url!.isNotEmpty;
}

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});
  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _picker = ImagePicker();

  bool _loading = true;
  String _kycStatus = 'pending';
  String? _loadError;

  final List<_KycItem> _items = [
    _KycItem(
      docType: 'selfie',
      titleEn: 'Selfie',
      titleAr: 'صورة شخصية',
      hintEn: 'Face the camera in good lighting, no sunglasses or hat.',
      hintAr: 'واجه الكاميرا في إضاءة جيدة، بدون نظارة شمس أو قبعة.',
      icon: Icons.person_outline_rounded,
      selfieCamera: true,
    ),
    _KycItem(
      docType: 'national_id_front',
      titleEn: 'National ID — Front',
      titleAr: 'بطاقة الرقم القومي — الوجه',
      hintEn: 'All four corners visible, text readable, no glare.',
      hintAr: 'الأركان الأربعة ظاهرة، النص واضح، بدون انعكاس.',
      icon: Icons.badge_outlined,
    ),
    _KycItem(
      docType: 'national_id_back',
      titleEn: 'National ID — Back',
      titleAr: 'بطاقة الرقم القومي — الظهر',
      hintEn: 'All four corners visible, text readable, no glare.',
      hintAr: 'الأركان الأربعة ظاهرة، النص واضح، بدون انعكاس.',
      icon: Icons.badge_outlined,
    ),
  ];

  bool get _allUploaded => _items.every((i) => i.done);

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  /// Pulls anything the rider already uploaded so returning users see their
  /// real progress instead of an empty form.
  Future<void> _loadStatus() async {
    try {
      final res = await ApiClient.instance.query('riders.getKycStatus');
      if (!mounted) return;
      setState(() {
        _kycStatus = (res['kycStatus'] as String?) ?? 'pending';
        _items[0].url = res['selfieUrl'] as String?;
        _items[1].url = res['idFrontUrl'] as String?;
        _items[2].url = res['idBackUrl'] as String?;
        _loading = false;
        _loadError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _loadError = e.message; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _loadError = 'network'; });
    }
  }

  Future<void> _pick(_KycItem item) async {
    if (item.uploading) return;
    final t = context.read<LanguageProvider>().t;
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: _cardBg,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(
                    color: _border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: _action),
              title: Text(t('Take Photo', 'التقاط صورة'),
                  style: const TextStyle(
                      color: _textDark, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: _action),
              title: Text(t('Choose from Gallery', 'اختيار من المعرض'),
                  style: const TextStyle(
                      color: _textDark, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      );
      if (source == null) return;

      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
        preferredCameraDevice:
            item.selfieCamera ? CameraDevice.front : CameraDevice.rear,
      );
      if (picked == null) return;
      if (!mounted) return;
      setState(() { item.file = File(picked.path); item.error = null; });
      await _upload(item);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        item.uploading = false;
        item.error = t('Could not open camera/gallery. Allow permission and try again.',
            'تعذر فتح الكاميرا/المعرض. اسمح بالإذن وحاول مرة أخرى.');
      });
    }
  }

  Future<void> _upload(_KycItem item) async {
    final file = item.file;
    if (file == null) return;
    final t = context.read<LanguageProvider>().t;

    setState(() { item.uploading = true; item.error = null; });
    try {
      final bytes = await file.readAsBytes();

      if (bytes.length > _maxUploadBytes) {
        if (!mounted) return;
        setState(() {
          item.uploading = false;
          item.error = t('Image is larger than 5MB. Please retake it.',
              'حجم الصورة أكبر من 5 ميجابايت. من فضلك أعد التقاطها.');
        });
        return;
      }

      final isPng = file.path.toLowerCase().endsWith('.png');

      final res = await ApiClient.instance.mutate(
        'riders.uploadKycDocument',
        input: {
          'documentType': item.docType,
          'imageBase64': base64Encode(bytes),
          'mimeType': isPng ? 'image/png' : 'image/jpeg',
        },
      );

      if (!mounted) return;
      final url = res['url'] as String?;
      if (url != null && url.isNotEmpty) {
        setState(() {
          item.url = url;
          item.uploading = false;
          item.error = null;
          _kycStatus = (res['kycStatus'] as String?) ?? 'pending';
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${t(item.titleEn, item.titleAr)} — ${t('uploaded', 'تم الرفع')} ✓'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      } else {
        setState(() {
          item.uploading = false;
          item.error = t('Upload failed. Please try again.',
              'فشل الرفع. من فضلك حاول مرة أخرى.');
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { item.uploading = false; item.error = e.message; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        item.uploading = false;
        item.error = t('Network error. Check your connection.',
            'خطأ في الشبكة. تحقق من اتصالك.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final t = lang.t;

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: AppTheme.navyDeep,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(t('Identity Verification', 'التحقق من الهوية'),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)),
          centerTitle: true,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _action))
            : Column(children: [
                // Brand header band — DossLogo on brand navy for contrast.
                Container(
                  width: double.infinity,
                  color: AppTheme.navyDeep,
                  padding: const EdgeInsets.only(bottom: 22),
                  child: Column(children: [
                    const DossLogo(size: 34),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        t('Verify your identity to keep every DOSS ride safe. It takes about a minute.',
                          'وثّق هويتك للحفاظ على أمان كل رحلة مع دوس. الأمر يستغرق دقيقة تقريباً.'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Color(0xFFA8B3BD), fontSize: 13, height: 1.5),
                      ),
                    ),
                  ]),
                ),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    children: [
                      _StatusBanner(
                        status: _kycStatus,
                        allUploaded: _allUploaded,
                        uploadedCount: _items.where((i) => i.done).length,
                        total: _items.length,
                        t: t,
                      ),
                      if (_loadError != null) ...[
                        const SizedBox(height: 12),
                        _RetryLoadRow(t: t, onRetry: () {
                          setState(() { _loading = true; _loadError = null; });
                          _loadStatus();
                        }),
                      ],
                      const SizedBox(height: 18),

                      ..._items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _KycCard(
                          item: item,
                          t: t,
                          onTap: () => _pick(item),
                        ),
                      )),

                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.lock_outline_rounded,
                            color: _textMuted, size: 15),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          t('Your documents are encrypted and used only to verify your identity.',
                            'وثائقك مشفّرة وتُستخدم فقط للتحقق من هويتك.'),
                          style: const TextStyle(
                              color: _textMuted, fontSize: 12, height: 1.4),
                        )),
                      ]),
                    ],
                  ),
                ),

                // Done button — every upload is already persisted server-side,
                // so this just closes the flow once all three are stored.
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      20, 4, 20, MediaQuery.of(context).padding.bottom + 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _allUploaded ? () => context.pop() : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _action,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFDCE3EA),
                        disabledForegroundColor: _textMuted,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        _allUploaded
                            ? t('Done', 'تم')
                            : t('Upload all 3 documents to continue',
                                'ارفع الوثائق الثلاث للمتابعة'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ]),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String status;
  final bool allUploaded;
  final int uploadedCount;
  final int total;
  final String Function(String, String) t;
  const _StatusBanner({
    required this.status,
    required this.allUploaded,
    required this.uploadedCount,
    required this.total,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final IconData icon;
    late final String title;
    late final String body;

    if (status == 'approved') {
      color = AppTheme.success;
      icon = Icons.verified_rounded;
      title = t('Verified', 'تم التحقق');
      body = t('Your identity has been approved.', 'تم اعتماد هويتك.');
    } else if (status == 'rejected') {
      color = AppTheme.error;
      icon = Icons.error_outline_rounded;
      title = t('Rejected', 'مرفوض');
      body = t('Your documents were rejected. Please upload clearer photos.',
          'تم رفض وثائقك. من فضلك ارفع صوراً أوضح.');
    } else if (allUploaded) {
      color = AppTheme.warning;
      icon = Icons.hourglass_top_rounded;
      title = t('Under review', 'قيد المراجعة');
      body = t('We received your documents. Review usually takes up to 24 hours.',
          'استلمنا وثائقك. المراجعة تستغرق عادة حتى ٢٤ ساعة.');
    } else {
      color = _action;
      icon = Icons.pending_actions_rounded;
      title = t('Action needed', 'مطلوب إجراء');
      body = t('$uploadedCount of $total documents uploaded.',
          'تم رفع $uploadedCount من $total وثائق.');
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 3),
          Text(body,
              style: const TextStyle(
                  color: _textMuted, fontSize: 12.5, height: 1.4)),
        ])),
      ]),
    );
  }
}

class _RetryLoadRow extends StatelessWidget {
  final String Function(String, String) t;
  final VoidCallback onRetry;
  const _RetryLoadRow({required this.t, required this.onRetry});

  @override
  Widget build(BuildContext context) => Row(children: [
    const Icon(Icons.cloud_off_rounded, color: _textMuted, size: 16),
    const SizedBox(width: 8),
    Expanded(child: Text(
      t("Couldn't load your saved documents.", 'تعذر تحميل وثائقك المحفوظة.'),
      style: const TextStyle(color: _textMuted, fontSize: 12),
    )),
    TextButton(
      onPressed: onRetry,
      child: Text(t('Retry', 'إعادة'),
          style: const TextStyle(color: _action, fontWeight: FontWeight.w700)),
    ),
  ]);
}

class _KycCard extends StatelessWidget {
  final _KycItem item;
  final String Function(String, String) t;
  final VoidCallback onTap;
  const _KycCard({required this.item, required this.t, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final done = item.done;
    final hasError = item.error != null;

    return GestureDetector(
      onTap: item.uploading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasError
                ? AppTheme.error.withOpacity(0.55)
                : done
                    ? AppTheme.success.withOpacity(0.55)
                    : _border,
            width: (done || hasError) ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          // Thumbnail / placeholder
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: done
                  ? AppTheme.success.withOpacity(0.08)
                  : _action.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: item.file != null
                ? Image.file(item.file!, fit: BoxFit.cover)
                : done
                    ? Image.network(
                        item.url!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.check_circle_rounded,
                            color: AppTheme.success, size: 26),
                      )
                    : Icon(item.icon, color: _action, size: 26),
          ),
          const SizedBox(width: 14),

          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t(item.titleEn, item.titleAr),
                style: const TextStyle(
                    color: _textDark, fontWeight: FontWeight.w700, fontSize: 14.5)),
            const SizedBox(height: 4),
            Text(
              hasError
                  ? item.error!
                  : item.uploading
                      ? t('Uploading...', 'جاري الرفع...')
                      : done
                          ? t('Uploaded ✓', 'تم الرفع ✓')
                          : t(item.hintEn, item.hintAr),
              style: TextStyle(
                color: hasError
                    ? AppTheme.error
                    : done
                        ? AppTheme.success
                        : _textMuted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ])),
          const SizedBox(width: 10),

          if (item.uploading)
            const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: _action))
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _action.withOpacity(0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                hasError
                    ? t('Retry', 'إعادة')
                    : done
                        ? t('Replace', 'تغيير')
                        : t('Upload', 'رفع'),
                style: const TextStyle(
                    color: _action, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
        ]),
      ),
    );
  }
}
