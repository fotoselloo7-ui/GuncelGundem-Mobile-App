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
            final stats = data['stats'] is Map
                ? Map<String, dynamic>.from(data['stats'] as Map)
                : const <String, dynamic>{};
            final ads = data['mobile_ads'] is Map
                ? Map<String, dynamic>.from(data['mobile_ads'] as Map)
                : const <String, dynamic>{};
            final contact = data['contact'] is Map
                ? Map<String, dynamic>.from(data['contact'] as Map)
                : const <String, dynamic>{};

            return RefreshIndicator(
              onRefresh: () async {
                setState(() => _future = _load());
                await _future;
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: homeNavy,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hikâyenizi Güncel Gündem’de yayınlayın',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'Özel haber, marka iş birliği ve sponsorlu içerik talepleriniz için doğrudan iletişime geçin.',
                          style: TextStyle(
                            color: Color(0xffcbd5e1),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: brand.primaryColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: () => _launch(
                            Uri(
                              scheme: 'mailto',
                              path: _text(contact['email']).isNotEmpty
                                  ? _text(contact['email'])
                                  : AppConfig.contactEmail,
                              queryParameters: const {
                                'subject': 'Özel Haber Yayınlatma Talebi',
                              },
                            ),
                          ),
                          icon: const Icon(Icons.campaign_rounded),
                          label: const Text('Özel Haber Yayınlat'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Güncel erişim',
                    style: TextStyle(
                      color: homeNavy,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
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
                    HomeMessage(
                      'İstatistikler şu anda yüklenemedi. İletişim kanallarını yine kullanabilirsiniz.',
                      icon: Icons.analytics_outlined,
                    )
                  else
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.55,
                      children: [
                        _MetricCard(
                          label: 'Son 30 Gün',
                          value: _number(stats['last_30_days']),
                        ),
                        _MetricCard(
                          label: 'Bu Ay',
                          value: _number(stats['this_month']),
                        ),
                        _MetricCard(
                          label: 'Bugün',
                          value: _number(stats['today']),
                        ),
                        _MetricCard(
                          label: 'Toplam',
                          value: _number(stats['all_time']),
                        ),
                      ],
                    ),
                  const SizedBox(height: 18),
                  const Text(
                    'Mobil reklam performansı',
                    style: TextStyle(
                      color: homeNavy,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: homeLine),
                    ),
                    child: Row(
                      children: [
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
                  const SizedBox(height: 18),
                  const Text(
                    'İletişim',
                    style: TextStyle(
                      color: homeNavy,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ContactButton(
                    icon: Icons.mail_outline_rounded,
                    label: 'E-posta',
                    value: _text(contact['email']).isNotEmpty
                        ? _text(contact['email'])
                        : AppConfig.contactEmail,
                    onTap: () => _launch(
                      Uri(
                        scheme: 'mailto',
                        path: _text(contact['email']).isNotEmpty
                            ? _text(contact['email'])
                            : AppConfig.contactEmail,
                        queryParameters: const {
                          'subject': 'Özel Haber & İş Birliği',
                        },
                      ),
                    ),
                  ),
                  if (_text(contact['instagram_url']).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _ContactButton(
                      icon: Icons.camera_alt_outlined,
                      label: 'Instagram',
                      value: 'Instagram’dan yaz',
                      onTap: () =>
                          _launch(Uri.parse(_text(contact['instagram_url']))),
                    ),
                  ],
                  if (_text(contact['whatsapp_url']).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _ContactButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'WhatsApp',
                      value: 'WhatsApp’tan yaz',
                      onTap: () =>
                          _launch(Uri.parse(_text(contact['whatsapp_url']))),
                    ),
                  ],
                  const SizedBox(height: 10),
                  const Text(
                    'Not: İstatistikler toplu erişim verileridir; kişisel ziyaretçi bilgisi gösterilmez.',
                    style: TextStyle(
                      color: homeMuted,
                      fontSize: 11,
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
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bağlantı açılamadı.')),
      );
    }
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: homeLine),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: homeNavy,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: homeMuted, fontSize: 11)),
      ],
    ),
  );
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
        style: const TextStyle(
          color: homeNavy,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(color: homeMuted, fontSize: 10.5),
      ),
    ],
  );
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 42, child: VerticalDivider(color: homeLine));
}

class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _ContactButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: homeLine),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: homeBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: homeNavy),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: homeNavy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(color: homeMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new_rounded, color: homeMuted, size: 18),
          ],
        ),
      ),
    ),
  );
}
