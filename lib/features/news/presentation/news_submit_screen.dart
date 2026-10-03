import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../data/models/location_model.dart';
import '../../../data/models/news_tip_model.dart';
import '../../../data/repositories/device_repository.dart';
import '../../../data/repositories/taxonomy_repository.dart';
import '../../../design/branding_state.dart';
import '../../../services/api_service.dart';
import '../../home/presentation/home_city.dart';
import '../../home/presentation/home_widgets.dart';
import 'news_navigation.dart';

/// Haber Gönder — okur haber ihbarı formu.
///
/// Gönderim POST /api/mobile/v1/news-tips ile mevcut "Sizden Gelenler"
/// moderasyon kuyruğuna düşer; ASLA otomatik yayınlanmaz.
class NewsSubmitScreen extends StatefulWidget {
  final ApiService? api;
  final DeviceRepository? device;
  final TaxonomyRepository? taxonomy;
  const NewsSubmitScreen({super.key, this.api, this.device, this.taxonomy});

  @override
  State<NewsSubmitScreen> createState() => _NewsSubmitScreenState();
}

class _NewsSubmitScreenState extends State<NewsSubmitScreen> {
  late final _api = widget.api ?? ApiService();
  late final _device = widget.device ?? DeviceRepository();
  late final _taxonomy = widget.taxonomy ?? TaxonomyRepository();

  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();

  List<LocationProvinceModel> _provinces = const [];
  String? _locationId;
  String? _locationLabel;
  bool _consent = false;
  bool _sending = false;
  String? _error;
  NewsTipReceipt? _receipt;
  final _picker = ImagePicker();
  XFile? _photo;

  @override
  void initState() {
    super.initState();
    _prefillLocation();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  /// Varsayılan konum: uygulamanın tek canonical şehir seçimi (Şehrim).
  Future<void> _prefillLocation() async {
    try {
      final prefs = await _device.getPreferences();
      final provinces = await _taxonomy.getLocations();
      final city = HomeCity.resolve(prefs.locationIds, provinces);
      if (!mounted) return;
      setState(() {
        _provinces = provinces;
        if (city != null) {
          _locationId = city.location.id;
          _locationLabel = city.label;
        }
      });
    } catch (_) {
      // Konum opsiyoneldir; taksonomi yüklenemezse form yine çalışır.
    }
  }

  Future<void> _pickLocation() async {
    if (_provinces.isEmpty) {
      try {
        final provinces = await _taxonomy.getLocationsResilient();
        if (mounted) setState(() => _provinces = provinces);
      } catch (_) {}
    }
    if (!mounted) return;
    final picked = await showModalBottomSheet<_LocationChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _ProvincePickerSheet(provinces: _provinces),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _locationId = picked.id;
      _locationLabel = picked.label;
    });
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2048,
      );
      if (picked != null && mounted) {
        setState(() {
          _photo = picked;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Fotoğraf eklenemedi. Tekrar deneyin.');
      }
    }
  }

  Future<void> _choosePhotoSource() async {
    FocusScope.of(context).unfocus();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('tip-photo-camera'),
              leading: const Icon(Icons.photo_camera_rounded, color: homeNavy),
              title: const Text('Kamera'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              key: const ValueKey('tip-photo-gallery'),
              leading: const Icon(Icons.photo_library_rounded, color: homeNavy),
              title: const Text('Galeri'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source != null) await _pickPhoto(source);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_form.currentState?.validate() ?? false)) return;
    if (!_consent) {
      setState(() => _error = 'Göndermek için onay kutusunu işaretleyin.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final response = await _api.submitNewsTip(
        NewsTipRequest(
          title: _title.text,
          description: _description.text,
          locationId: _locationId,
          contactName: _name.text,
          contactPhone: _phone.text,
          contactEmail: _email.text,
          consent: _consent,
          photoPath: _photo?.path,
        ),
      );
      final receipt = response.data;
      if (!mounted) return;
      setState(() {
        _receipt = receipt != null && receipt.reference.isNotEmpty
            ? receipt
            : null;
        if (_receipt == null) {
          _error = 'Gönderim doğrulanamadı. Lütfen tekrar deneyin.';
        }
      });
    } on AppException catch (e) {
      if (mounted) {
        setState(
          () => _error = e is NetworkException || e is TimeoutException
              ? 'Bağlantı kurulamadı. İnternetinizi kontrol edip tekrar deneyin.'
              : e.message,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Gönderim tamamlanamadı. Lütfen tekrar deneyin.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _reset() {
    _title.clear();
    _description.clear();
    setState(() {
      _receipt = null;
      _consent = false;
      _error = null;
      _photo = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final brand = BrandingState.instance;
    return Theme(
      data: homeTheme(brand),
      child: Scaffold(
        appBar: HomeBrandHeader(
          brand: brand,
          allowBack: true,
          onSearch: () => NewsNavigation.openSearch(context),
          onNotifications: () => NewsNavigation.openNotifications(context),
        ),
        bottomNavigationBar: HomeBottomBar(
          selected: 2,
          onSelect: (i) {
            if (i != 2) NewsNavigation.handleBottom(context, i);
          },
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: _receipt != null
              ? _SuccessView(
                  receipt: _receipt!,
                  onNew: _reset,
                  onHome: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                )
              : _buildForm(brand),
        ),
      ),
    );
  }

  Widget _buildForm(BrandingState brand) {
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: homeNavy,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: brand.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Haber Gönder',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Gördüğünüz gelişmeyi bize iletin. Editörlerimiz inceler; '
                        'onaylanmadan yayınlanmaz.',
                        style: TextStyle(color: Color(0xffc7d2e0), height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _Field(
            fieldKey: const ValueKey('tip-title'),
            controller: _title,
            label: 'Başlık',
            hint: 'Kısaca ne oldu?',
            maxLength: 200,
            validator: (v) => (v ?? '').trim().length < 5
                ? 'Başlık en az 5 karakter olmalı.'
                : null,
          ),
          _Field(
            fieldKey: const ValueKey('tip-description'),
            controller: _description,
            label: 'Açıklama',
            hint: 'Ne, nerede, ne zaman? Bildiğiniz ayrıntıları yazın.',
            maxLines: 6,
            maxLength: 10000,
            validator: (v) => (v ?? '').trim().length < 20
                ? 'Açıklama en az 20 karakter olmalı.'
                : null,
          ),
          _SectionTitle('Konum (opsiyonel)'),
          Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: homeLine),
            ),
            child: ListTile(
              key: const ValueKey('tip-location'),
              minTileHeight: 56,
              leading: const Icon(Icons.location_on_outlined, color: homeNavy),
              title: Text(
                _locationLabel ?? 'Konum eklenmedi',
                style: const TextStyle(
                  color: homeNavy,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text('Değiştirmek için dokunun'),
              trailing: _locationId == null
                  ? const Icon(Icons.chevron_right)
                  : IconButton(
                      tooltip: 'Konumu kaldır',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() {
                        _locationId = null;
                        _locationLabel = null;
                      }),
                    ),
              onTap: _pickLocation,
            ),
          ),
          const SizedBox(height: 18),
          _SectionTitle('Fotoğraf (opsiyonel)'),
          _PhotoPicker(
            key: const ValueKey('tip-photo'),
            photo: _photo,
            onPick: _choosePhotoSource,
            onRemove: () => setState(() => _photo = null),
          ),
          const SizedBox(height: 18),
          _SectionTitle('İletişim (opsiyonel, gizli tutulur)'),
          _Field(
            controller: _name,
            label: 'Ad Soyad',
            maxLength: 120,
            textInputAction: TextInputAction.next,
          ),
          _Field(
            controller: _phone,
            label: 'Telefon',
            keyboardType: TextInputType.phone,
            maxLength: 32,
            textInputAction: TextInputAction.next,
          ),
          _Field(
            controller: _email,
            label: 'E-posta',
            keyboardType: TextInputType.emailAddress,
            maxLength: 190,
            validator: (v) {
              final value = (v ?? '').trim();
              if (value.isEmpty) return null;
              return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)
                  ? null
                  : 'Geçerli bir e-posta girin.';
            },
          ),
          CheckboxListTile(
            key: const ValueKey('tip-consent'),
            value: _consent,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: brand.primaryColor,
            onChanged: _sending
                ? null
                : (v) => setState(() {
                    _consent = v ?? false;
                    if (_consent) _error = null;
                  }),
            title: Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  color: homeMuted,
                  height: 1.4,
                ),
                children: [
                  const TextSpan(
                    text:
                        'Gönderdiğim bilgilerin GüncelGündem editörlerince incelenmesini ve '
                        'haber amaçlı kullanılmasını kabul ediyorum. İletişim bilgilerim '
                        'yayınlanmaz. ',
                  ),
                  TextSpan(
                    text: 'KVKK',
                    style: TextStyle(
                      color: brand.primaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                    recognizer: _tapRecognizer(AppConfig.kvkkUrl),
                  ),
                  const TextSpan(text: ' · '),
                  TextSpan(
                    text: 'Gizlilik',
                    style: TextStyle(
                      color: brand.primaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                    recognizer: _tapRecognizer(AppConfig.privacyUrl),
                  ),
                ],
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                key: const ValueKey('tip-error'),
                style: TextStyle(
                  color: brand.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const ValueKey('tip-submit'),
            style: FilledButton.styleFrom(
              backgroundColor: brand.primaryColor,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _sending ? null : _submit,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(_sending ? 'Gönderiliyor…' : 'Gönder'),
          ),
        ],
      ),
    );
  }
}

TapGestureRecognizer _tapRecognizer(String url) =>
    TapGestureRecognizer()
      ..onTap = () {
        final uri = Uri.tryParse(url);
        if (uri != null) {
          launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          ).catchError((Object _) => false);
        }
      };

class _PhotoPicker extends StatelessWidget {
  final XFile? photo;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  const _PhotoPicker({
    super.key,
    required this.photo,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (photo == null) {
      return OutlinedButton.icon(
        key: const ValueKey('tip-photo-add'),
        onPressed: onPick,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Fotoğraf Ekle'),
        style: OutlinedButton.styleFrom(
          foregroundColor: homeNavy,
          minimumSize: const Size.fromHeight(56),
          side: const BorderSide(color: homeLine),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: homeLine),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(photo!.path),
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 72,
                height: 72,
                color: homeBackground,
                child: const Icon(Icons.broken_image, color: homeMuted),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fotoğraf eklendi',
                  style: TextStyle(
                    color: homeNavy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Gönderimden önce editör inceleyecek.',
                  style: TextStyle(color: homeMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('tip-photo-remove'),
            tooltip: 'Fotoğrafı kaldır',
            icon: const Icon(Icons.close_rounded),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final Key? fieldKey;
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;

  const _Field({
    this.fieldKey,
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      key: fieldKey,
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        counterText: '',
        alignLabelWithHint: maxLines > 1,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: homeLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: homeLine),
        ),
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
    child: Text(
      text,
      style: const TextStyle(
        color: homeNavy,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
    ),
  );
}

class _LocationChoice {
  final String id;
  final String label;
  const _LocationChoice(this.id, this.label);
}

class _ProvincePickerSheet extends StatefulWidget {
  final List<LocationProvinceModel> provinces;
  const _ProvincePickerSheet({required this.provinces});
  @override
  State<_ProvincePickerSheet> createState() => _ProvincePickerSheetState();
}

class _ProvincePickerSheetState extends State<_ProvincePickerSheet> {
  final _query = TextEditingController();
  LocationProvinceModel? _province;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    final province = _province;
    final items = province == null
        ? widget.provinces
              .where((p) => q.isEmpty || p.name.toLowerCase().contains(q))
              .map((p) => (id: p.id, name: p.name))
              .toList()
        : province.districts
              .where((d) => q.isEmpty || d.name.toLowerCase().contains(q))
              .map((d) => (id: d.id, name: d.name))
              .toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  if (province != null)
                    IconButton(
                      tooltip: 'İl seçimine dön',
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => setState(() {
                        _province = null;
                        _query.clear();
                      }),
                    ),
                  Expanded(
                    child: Text(
                      province?.name ?? 'İl seçin',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: homeNavy,
                      ),
                    ),
                  ),
                  if (province != null)
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context)
                              .pop(_LocationChoice(province.id, province.name)),
                      child: const Text('İl geneli'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _query,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: province == null ? 'İl ara' : 'İlçe ara',
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: widget.provinces.isEmpty
                  ? const Center(
                      child: HomeMessage('Konumlar şu an yüklenemedi.'),
                    )
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (_, i) => ListTile(
                        title: Text(items[i].name),
                        trailing: province == null
                            ? const Icon(Icons.chevron_right)
                            : null,
                        onTap: () {
                          if (province == null) {
                            final selected = widget.provinces.firstWhere(
                              (p) => p.id == items[i].id,
                            );
                            if (selected.districts.isEmpty) {
                              Navigator.of(context).pop(
                                _LocationChoice(selected.id, selected.name),
                              );
                            } else {
                              setState(() {
                                _province = selected;
                                _query.clear();
                              });
                            }
                          } else {
                            Navigator.of(context).pop(
                              _LocationChoice(
                                items[i].id,
                                '${items[i].name} / ${province.name}',
                              ),
                            );
                          }
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final NewsTipReceipt receipt;
  final VoidCallback onNew;
  final VoidCallback onHome;
  const _SuccessView({
    required this.receipt,
    required this.onNew,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final brand = BrandingState.instance;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              color: Color(0xffe8f6ee),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xff15803d),
              size: 42,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          receipt.duplicate ? 'Bu bilgi bize zaten ulaştı' : 'Teşekkürler!',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: homeNavy,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Gönderiniz editörlerimizin inceleme kuyruğuna alındı. '
          'Doğrulanmadan yayınlanmaz.',
          textAlign: TextAlign.center,
          style: TextStyle(color: homeMuted, height: 1.5),
        ),
        const SizedBox(height: 18),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: homeLine),
            ),
            child: SelectableText(
              'Takip No: ${receipt.reference}',
              key: const ValueKey('tip-reference'),
              style: const TextStyle(
                color: homeNavy,
                fontWeight: FontWeight.w700,
                letterSpacing: .5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: brand.primaryColor,
            minimumSize: const Size.fromHeight(50),
          ),
          onPressed: onHome,
          child: const Text('Ana Sayfaya Dön'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: homeNavy,
            minimumSize: const Size.fromHeight(50),
          ),
          onPressed: onNew,
          child: const Text('Yeni Haber Gönder'),
        ),
      ],
    );
  }
}
