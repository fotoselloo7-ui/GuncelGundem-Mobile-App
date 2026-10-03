import 'package:flutter/material.dart';

import '../../../data/models/live_module_model.dart';
import 'home_widgets.dart';

String liveUpdated(String? timestamp) {
  final date = DateTime.tryParse(timestamp ?? '')?.toLocal();
  if (date == null) return '';
  String two(int n) => '$n'.padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year} · ${two(date.hour)}:${two(date.minute)}';
}

String liveValue(double number, {int digits = 1}) {
  final parts = number.toStringAsFixed(digits).split('.');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]}.',
  );
  return parts.length == 1 ? whole : '$whole,${parts[1]}';
}

class HomeEarthquakeSection extends StatelessWidget {
  final LiveListModuleModel module;
  const HomeEarthquakeSection({super.key, required this.module});
  @override
  Widget build(BuildContext context) {
    final items = module.items
        .where((item) => liveNumber(item['magnitude']) != null)
        .take(3)
        .toList();
    if (!module.available || items.isEmpty) return const SizedBox.shrink();
    return HomeSection(
      key: const ValueKey('home-earthquakes'),
      title: 'Son Depremler',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: homeLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 54,
                      child: Text(
                        liveValue(liveNumber(item['magnitude'])!),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: homeNavy,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            liveText(item['location']) ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            liveUpdated(liveText(item['occurred_at'])),
                            style: const TextStyle(
                              fontSize: 10,
                              color: homeMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            _LiveModuleNote(module: module),
          ],
        ),
      ),
    );
  }
}

class CityLiveModules extends StatelessWidget {
  final LiveModulesModel? modules;
  final String locationId;
  const CityLiveModules({super.key, this.modules, required this.locationId});
  @override
  Widget build(BuildContext context) {
    final prayer = modules?.prayerTimes;
    final pharmacy = modules?.pharmacy;
    final prayerVisible =
        prayer != null &&
        prayer.available &&
        !prayer.stale &&
        prayer.locationId == locationId;
    final pharmacyVisible =
        pharmacy != null &&
        pharmacy.available &&
        !pharmacy.stale &&
        pharmacy.locationId == locationId;
    if (!prayerVisible && !pharmacyVisible) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (prayerVisible)
          HomeSection(
            key: const ValueKey('city-prayer'),
            title: 'Namaz Vakitleri',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (prayer.fallback == 'province')
                  Text(
                    '${prayer.cityName ?? ''} il merkezi hesabı',
                    style: const TextStyle(fontSize: 11, color: homeMuted),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in prayer.items)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: homeLine),
                        ),
                        child: Text(
                          '${liveText(item['name']) ?? ''}\n${liveText(item['time']) ?? ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                _LiveModuleNote(module: prayer),
              ],
            ),
          ),
        if (pharmacyVisible)
          HomeSection(
            key: const ValueKey('city-pharmacy'),
            title: 'Nöbetçi Eczaneler',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in pharmacy.items.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          liveText(item['name']) ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (liveText(item['address']) != null)
                          Text(
                            item['address'],
                            style: const TextStyle(fontSize: 12),
                          ),
                        if (liveText(item['phone']) != null)
                          Text(
                            item['phone'],
                            style: const TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                if (pharmacy.disclaimer != null)
                  Text(
                    pharmacy.disclaimer!,
                    style: const TextStyle(fontSize: 10, color: homeMuted),
                  ),
                _LiveModuleNote(module: pharmacy),
              ],
            ),
          ),
      ],
    );
  }
}

/// Canlı modül dipnot alanı.
///
/// Kaynak adı (AFAD, TCMB vb.), "Son güncelleme" ve "Çevrimdışı" etiketleri
/// kullanıcı isteği üzerine GİZLENDİ. Veriler siteden canlı çekilir; durum
/// bilgisi kullanıcıya ayrıca yazılmaz.
class _LiveModuleNote extends StatelessWidget {
  final LiveListModuleModel module;
  const _LiveModuleNote({required this.module});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class WeatherSummary extends StatelessWidget {
  final WeatherModuleModel weather;
  const WeatherSummary({super.key, required this.weather});
  @override
  Widget build(BuildContext context) {
    if (!weather.hasData) return const SizedBox.shrink();
    final icon = switch (weather.icon) {
      'sun' => Icons.wb_sunny_outlined,
      'moon' => Icons.nightlight_round,
      'cloud-rain' || 'cloud-showers' => Icons.water_drop_outlined,
      'snowflake' || 'snow' => Icons.ac_unit,
      'cloud-sun' || 'cloud-moon' => Icons.cloud_queue,
      _ => Icons.cloud_outlined,
    };
    return Column(
      key: const ValueKey('live-weather'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              '${liveValue(weather.temperature!)}°C',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Icon(icon, color: const Color(0xFFFFC857), size: 32),
            if (weather.condition != null)
              Text(
                weather.condition!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        if (weather.feelsLike != null)
          Text(
            'Hissedilen ${liveValue(weather.feelsLike!)}°C',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        if (weather.fallback == 'province')
          Text(
            '${weather.cityName ?? ''} il merkezi verisi',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        // Kaynak/"Son güncelleme"/"Çevrimdışı" etiketleri gizlendi.
      ],
    );
  }
}

class CityWeatherCard extends StatelessWidget {
  final WeatherModuleModel weather;
  const CityWeatherCard({super.key, required this.weather});
  @override
  Widget build(BuildContext context) => !weather.hasData
      ? const SizedBox.shrink()
      : Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: homeNavy,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                weather.districtName == null
                    ? weather.cityName ?? 'Hava Durumu'
                    : '${weather.districtName} / ${weather.cityName}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              WeatherSummary(weather: weather),
              // Kaynak adı etiketi gizlendi.
            ],
          ),
        );
}

class HomeMarketSection extends StatelessWidget {
  final MarketModuleModel market;
  const HomeMarketSection({super.key, required this.market});
  @override
  Widget build(BuildContext context) {
    if (!market.available || market.items.isEmpty) {
      return const SizedBox.shrink();
    }
    final items = market.items.take(5).toList();
    return HomeSection(
      key: const ValueKey('home-market'),
      title: market.title,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: items.map((item) {
              final digits = item.provider == 'tcmb_fx' ? 4 : 2;
              return Container(
                key: ValueKey('market-${item.code}'),
                width: 176,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: homeLine),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: homeNavy,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${liveValue(item.value!, digits: digits)}${item.currency == null ? '' : ' ${item.currency}'}',
                      style: const TextStyle(
                        color: homeNavy,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    if (item.unit != null)
                      Text(
                        '${item.provider == 'tcmb_fx' ? '${item.unit} ${item.code}' : item.unit}',
                        style: const TextStyle(
                          color: homeMuted,
                          fontSize: 10,
                          height: 1.5,
                        ),
                      ),
                    if (item.buy != null)
                      Text(
                        'Alış ${liveValue(item.buy!, digits: digits)}',
                        style: const TextStyle(
                          color: homeMuted,
                          fontSize: 10,
                          height: 1.5,
                        ),
                      ),
                    if (item.sell != null)
                      Text(
                        'Satış ${liveValue(item.sell!, digits: digits)}',
                        style: const TextStyle(
                          color: homeMuted,
                          fontSize: 10,
                          height: 1.5,
                        ),
                      ),
                    if (item.changePercent != null)
                      Text(
                        '%${liveValue(item.changePercent!, digits: 2)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: item.changePercent! > 0
                              ? const Color(0xFF17835C)
                              : item.changePercent! < 0
                              ? Theme.of(context).colorScheme.primary
                              : homeMuted,
                        ),
                      ),
                    // Kaynak/"Son güncelleme"/"Çevrimdışı" etiketleri gizlendi.
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
