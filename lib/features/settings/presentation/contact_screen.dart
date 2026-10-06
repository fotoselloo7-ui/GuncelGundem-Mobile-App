import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_config.dart';
import '../../../design/branding_state.dart';
import '../../home/presentation/home_widgets.dart';
import 'personalization_widgets.dart';

/// Google Play Haberler ve Dergiler politikasıyla uyumlu, uygulama içinde
/// kolayca bulunabilen yayıncı/geliştirici iletişim ekranı.
///
/// Mevcut Tercihler tasarım dilini (Poppins, beyaz kartlar, 16 px radius,
/// homeNavy/homeMuted/homeLine) aynen kullanır; Android ve iOS ortak Flutter
/// kodundan aynı ekranı gösterir.
class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

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
            'Bize Ulaşın',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: homeNavy,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              const PrefSectionTitle(
                'İletişim',
                subtitle:
                    'Güncel Gündem ve mobil uygulamayla ilgili her konuda bize ulaşabilirsiniz.',
              ),
              PrefCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: brand.primaryColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.newspaper_rounded,
                        color: brand.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Güncel Gündem',
                            style: TextStyle(
                              color: homeNavy,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Yayıncı / Geliştirici',
                            style: TextStyle(
                              color: homeMuted,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            AppConfig.publisherName,
                            style: TextStyle(
                              color: homeNavy,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const PrefSectionTitle('İletişim Bilgileri'),
              PrefCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _ContactTile(
                      key: ValueKey('contact-email'),
                      icon: Icons.mail_outline_rounded,
                      title: 'E-posta',
                      value: AppConfig.contactEmail,
                      onTap: () => _launch(
                        context,
                        Uri(
                          scheme: 'mailto',
                          path: AppConfig.contactEmail,
                          queryParameters: const {
                            'subject': 'Güncel Gündem Mobil Uygulama',
                          },
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: homeLine),
                    _ContactTile(
                      key: ValueKey('contact-web'),
                      icon: Icons.language_rounded,
                      title: 'Web Sitesi',
                      value: AppConfig.contactWebsiteUrl,
                      onTap: () => _launch(
                        context,
                        Uri.parse(AppConfig.contactWebsiteUrl),
                      ),
                    ),
                    const Divider(height: 1, color: homeLine),
                    _ContactTile(
                      key: ValueKey('contact-page'),
                      icon: Icons.support_agent_rounded,
                      title: 'İletişim Sayfası',
                      value: AppConfig.contactUrl,
                      onTap: () => _launch(
                        context,
                        Uri.parse(AppConfig.contactUrl),
                      ),
                    ),
                  ],
                ),
              ),
              const PrefSectionTitle('Destek'),
              const PrefCard(
                child: Text(
                  'Görüş, öneri, hata bildirimi, içerik düzeltme veya mobil '
                  'uygulamayla ilgili destek talepleriniz için yukarıdaki '
                  'iletişim kanallarını kullanabilirsiniz.',
                  style: TextStyle(
                    color: homeNavy,
                    fontSize: 13,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _launch(BuildContext context, Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        _showError(context);
      }
    } catch (_) {
      if (context.mounted) {
        _showError(context);
      }
    }
  }

  static void _showError(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Bağlantı açılamadı.')),
      );
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _ContactTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$title: $value',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
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
                    title,
                    style: const TextStyle(
                      color: homeNavy,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: homeMuted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new_rounded, color: homeMuted, size: 20),
          ],
        ),
      ),
    ),
  );
}
