import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../design/branding_state.dart';
import '../../home/presentation/home_widgets.dart';

class PartnershipScreen extends StatefulWidget {
  const PartnershipScreen({super.key});

  @override
  State<PartnershipScreen> createState() => _PartnershipScreenState();
}

class _PartnershipScreenState extends State<PartnershipScreen> {
  final _client = ApiClient();
  late Future<Map<String, dynamic>> _future = _load();

  Future<Map<String, dynamic>> _load() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.partnership,
      fromDataJson: (data) => data is Map<String, dynamic>
          ? data
          : const <String, dynamic>{},
    );
    return response.data ?? const <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    final brand = BrandingState.instance;
    return Theme(
      data: homeTheme(brand),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          toolbarHeight: 64,
          iconTheme: const IconThemeData(color: homeNavy),
          shape: const Border(bottom: BorderSide(color: homeLine)),
          title: const Text(
            'Özel Haber & İş Birliği',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: homeNavy,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            final data = snapshot.data ?? const <String, dynamic>{};
            final stats = _map(data['stats']);
            final audience = _map(data['audience']);
            final ads = _map(data['mobile_ads']);
            final contact = _map(data['contact']);
            final ui = _map(data['ui']);

            final headline = _text(ui['headline']).isNotEmpty
                ? _text(ui['headline'])
                : 'Hikâyenizi Güncel Gündem’de yayınlayın';
            final description = _text(ui['description']).isNotEmpty
                ? _text(ui['description'])
                : 'Özel haber, marka iş birliği ve sponsorlu içerik talepleriniz için doğrudan iletişime geçin.';
            final ctaLabel = _text(ui['cta_label']).isNotEmpty
                ? _text(ui['cta_label'])
                : 'Özel Haber Yayınlat';
            final showStats = ui['show_stats'] != false;
            final showAdStats = ui['show_ad_stats'] != false;

            final email = _text(contact['email']).isNotEmpty
                ? _text(contact['email'])
                : AppConfig.contactEmail;
            final instagram = _text(contact['instagram_url']);
            final whatsapp = _text(contact['whatsapp_url']);
            final emailEnabled = contact['email_enabled'] != false;
            final instagramEnabled =
                contact['instagram_enabled'] != false && instagram.isNotEmpty;
            final whatsappEnabled =
                contact['whatsapp_enabled'] != false && whatsapp.isNotEmpty;

            Future<void> primaryAction() async {
              final preferred = _text(ui['primary_channel']).toLowerCase();
              if (preferred == 'instagram' && instagramEnabled) {
                await _launch(Uri.parse(instagram));
                return;
              }
              if (preferred == 'email' && emailEnabled) {
                await _launch(
                  Uri(
                    scheme: 'mailto',
                    path: email,
                    queryParameters: const {
                      'subject': 'Özel Haber Yayınlatma Talebi',
                    },
                  ),
                );
                return;
              }
              if (whatsappEnabled) {
                await _launch(Uri.parse(whatsapp));
                return;
              }
              if (instagramEnabled) {
                await _launch(Uri.parse(instagram));
                return;
              }
              await _launch(
                Uri(
                  scheme: 'mailto',
                  path: email,
                  queryParameters: const {
                    'subject': 'Özel Haber Yayınlatma Talebi',
                  },
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                setState(() => _future = _load());
                await _future;
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                children: [
                  _HeroCard(
                    headline: headline,
                    description: description,
                    ctaLabel: ctaLabel,
                    onTap: primaryAction,
                  ),
                  if (showStats) ...[
                    const SizedBox(height: 22),
                    _SectionHeading(
                      title: 'Güncel erişim',
                      subtitle: 'Gerçek site ve mobil erişim verileri',
                    ),
                    const SizedBox(height: 10),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(28),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (snapshot.hasError)
                      const HomeMessage(
                        'İstatistikler şu anda yüklenemedi. İletişim kanallarını yine kullanabilirsiniz.',
                        icon: Icons.analytics_outlined,
                      )
                    else ...[
                      _ReachHighlight(
                        value: _number(stats['last_30_days']),
                        label: 'Son 30 günde görüntülenme',
                        secondary:
                            '${_number(stats['this_month'])} bu ay · ${_number(stats['today'])} bugün',
                      ),
                      const SizedBox(height: 10),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.82,
                        children: [
                          _AudienceCard(
                            icon: Icons.people_alt_outlined,
                            label: 'Şu an sitede',
                            value: _number(audience['live_visitors']),
                          ),
                          _AudienceCard(
                            icon: Icons.phone_android_rounded,
                            label: 'Kayıtlı mobil cihaz',
                            value: _number(audience['registered_devices']),
                          ),
                          _AudienceCard(
                            icon: Icons.notifications_active_outlined,
                            label: 'Aktif bildirim cihazı',
                            value: _number(audience['active_push_devices']),
                          ),
                          _AudienceCard(
                            icon: Icons.person_search_outlined,
                            label: 'Bugün tekil ziyaretçi',
                            value: _number(audience['unique_today']),
                          ),
                        ],
                      ),
                    ],
                  ],
                  if (showAdStats) ...[
                    const SizedBox(height: 22),
                    _SectionHeading(
                      title: 'Mobil reklam performansı',
                      subtitle: 'Yayındaki kampanyaların toplam mobil sonucu',
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: homeLine),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _MiniStat(
                              label: 'Aktif',
                              value: _number(ads['active_campaigns']),
                            ),
                          ),
                          const _Divider(),
                          Expanded(
                            child: _MiniStat(
                              label: 'Gösterim',
                              value: _number(ads['impressions']),
                            ),
                          ),
                          const _Divider(),
                          Expanded(
                            child: _MiniStat(
                              label: 'Tıklama',
                              value: _number(ads['clicks']),
                            ),
                          ),
                          const _Divider(),
                          Expanded(
                            child: _MiniStat(
                              label: 'CTR',
                              value: '%${_decimal(ads['ctr'])}',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  const _SectionHeading(
                    title: 'İletişim',
                    subtitle: 'Size uygun kanaldan doğrudan ulaşın',
                  ),
                  const SizedBox(height: 10),
                  if (!emailEnabled &&
                      !instagramEnabled &&
                      !whatsappEnabled)
                    const HomeMessage(
                      'İletişim kanalları şu anda güncelleniyor.',
                      icon: Icons.support_agent_rounded,
                    )
                  else
                    Column(
                      children: [
                        if (whatsappEnabled)
                          _ContactButton(
                            icon: Icons.chat_bubble_outline_rounded,
                            label: 'WhatsApp',
                            value: 'Hızlıca mesaj gönder',
                            emphasized: true,
                            onTap: () => _launch(Uri.parse(whatsapp)),
                          ),
                        if (whatsappEnabled &&
                            (instagramEnabled || emailEnabled))
                          const SizedBox(height: 8),
                        if (instagramEnabled)
                          _ContactButton(
                            icon: Icons.camera_alt_outlined,
                            label: 'Instagram',
                            value: 'Instagram’dan yaz',
                            onTap: () => _launch(Uri.parse(instagram)),
                          ),
                        if (instagramEnabled && emailEnabled)
                          const SizedBox(height: 8),
                        if (emailEnabled)
                          _ContactButton(
                            icon: Icons.mail_outline_rounded,
                            label: 'E-posta',
                            value: email,
                            onTap: () => _launch(
                              Uri(
                                scheme: 'mailto',
                                path: email,
                                queryParameters: const {
                                  'subject': 'Özel Haber & İş Birliği',
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'Erişim değerleri toplu istatistiklerdir; kişisel ziyaretçi bilgisi gösterilmez.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: homeMuted,
                      fontSize: 10.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};

  static String _text(dynamic value) => value?.toString().trim() ?? '';

  static String _number(dynamic value) {
    final number = int.tryParse(value?.toString() ?? '') ?? 0;
    final raw = number.toString();
    final out = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) out.write('.');
      out.write(raw[i]);
    }
    return out.toString();
  }

  static String _decimal(dynamic value) {
    final number = double.tryParse(value?.toString() ?? '') ?? 0;
    return number.toStringAsFixed(2).replaceAll('.', ',');
  }

  Future<void> _launch(Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) _showLaunchError();
    } catch (_) {
      if (mounted) _showLaunchError();
    }
  }

  void _showLaunchError() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Bağlantı açılamadı.')),
      );
  }
}

class _HeroCard extends StatelessWidget {
  final String headline;
  final String description;
  final String ctaLabel;
  final Future<void> Function() onTap;

  const _HeroCard({
    required this.headline,
    required this.description,
    required this.ctaLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brand = BrandingState.instance;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: homeNavy,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: homeNavy.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'ÖZEL HABER · MARKA İŞ BİRLİĞİ',
              style: TextStyle(
                color: Color(0xffe2e8f0),
                fontSize: 9.5,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 11),
          Text(
            headline,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              height: 1.28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xffcbd5e1),
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: brand.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: onTap,
              icon: const Icon(Icons.campaign_rounded, size: 19),
              label: Text(
                ctaLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeading({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: homeNavy,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        subtitle,
        style: const TextStyle(
          color: homeMuted,
          fontSize: 11.5,
          height: 1.4,
        ),
      ),
    ],
  );
}

class _ReachHighlight extends StatelessWidget {
  final String value;
  final String label;
  final String secondary;

  const _ReachHighlight({
    required this.value,
    required this.label,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final brand = BrandingState.instance;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: brand.primaryColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: brand.primaryColor.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: brand.primaryColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: homeNavy,
                    fontSize: 24,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    color: homeNavy,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  secondary,
                  style: const TextStyle(
                    color: homeMuted,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AudienceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AudienceCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final brand = BrandingState.instance;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: homeLine),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: brand.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: brand.primaryColor),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  style: const TextStyle(
                    color: homeNavy,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: homeMuted,
                    fontSize: 9.7,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        maxLines: 1,
        style: const TextStyle(
          color: homeNavy,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        style: const TextStyle(color: homeMuted, fontSize: 9.5),
      ),
    ],
  );
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 40, child: VerticalDivider(color: homeLine));
}

class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool emphasized;

  const _ContactButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final brand = BrandingState.instance;
    return Material(
      color: emphasized
          ? brand.primaryColor.withValues(alpha: 0.055)
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: emphasized
              ? brand.primaryColor.withValues(alpha: 0.20)
              : homeLine,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: emphasized
                      ? brand.primaryColor
                      : homeBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: emphasized ? Colors.white : homeNavy,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: homeNavy,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: homeMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: homeMuted,
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
