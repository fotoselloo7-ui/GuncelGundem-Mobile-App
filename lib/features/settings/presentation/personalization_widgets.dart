import 'package:flutter/material.dart';

import '../../../app/bottom_nav_preferences.dart';
import '../../../data/models/category_model.dart';
import '../../../design/branding_state.dart';
import '../../home/presentation/home_widgets.dart';

/// Aktif ANA haber kategorileri — tamamen dinamik taksonomiden türetilir.
///
/// Kök (parent'sız) ve `news` içerik tipine sahip kategoriler; kök bilgisi
/// gelmezse tüm haber kategorilerine düşer. Hard-coded isim yoktur.
List<CategoryModel> mainNewsCategories(List<CategoryModel> all) {
  final news = all.where((c) => c.contentTypes.contains('news')).toList();
  final roots = news.where((c) => (c.parentId ?? '').isEmpty).toList();
  final result = roots.isNotEmpty ? roots : news;
  result.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  return result;
}

/// Kategori ilgi alanı çipleri (onboarding ve Tercihler ortak bileşeni).
class InterestChips extends StatelessWidget {
  final List<CategoryModel> categories;
  final List<String> selectedIds;
  final void Function(String id, bool selected) onToggle;
  final bool enabled;

  const InterestChips({
    super.key,
    required this.categories,
    required this.selectedIds,
    required this.onToggle,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final brand = BrandingState.instance;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final cat in categories)
          FilterChip(
            key: ValueKey('interest-${cat.id}'),
            label: Text(cat.name),
            selected: selectedIds.contains(cat.id),
            onSelected: enabled ? (v) => onToggle(cat.id, v) : null,
            showCheckmark: true,
            checkmarkColor: brand.primaryColor,
            selectedColor: brand.primaryColor.withValues(alpha: 0.12),
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              color: selectedIds.contains(cat.id)
                  ? brand.primaryColor
                  : homeNavy,
            ),
            side: BorderSide(
              color: selectedIds.contains(cat.id)
                  ? brand.primaryColor.withValues(alpha: 0.5)
                  : homeLine,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
      ],
    );
  }
}

/// Alt Menü Düzeni: slot 4 ve 5 için gerçek hedeflerden seçim.
/// Diğer slotta olan bir hedef seçilirse iki slot yer değiştirir.
class NavSlotPicker extends StatelessWidget {
  const NavSlotPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = BottomNavPreferences.instance;
    return ListenableBuilder(
      listenable: nav,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SlotRow(slotIndex: 3, title: '4. Sekme', current: nav.slot4),
          const SizedBox(height: 14),
          _SlotRow(slotIndex: 4, title: '5. Sekme', current: nav.slot5),
          const SizedBox(height: 10),
          const Text(
            'Ana Sayfa, Son Dakika ve Haber Gönder sabittir. Aynı öğe iki '
            'sekmede birden yer alamaz.',
            style: TextStyle(color: homeMuted, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  final int slotIndex;
  final String title;
  final NavDestination current;
  const _SlotRow({
    required this.slotIndex,
    required this.title,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final brand = BrandingState.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: homeNavy,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in NavDestination.values)
              ChoiceChip(
                key: ValueKey('nav-slot-$slotIndex-${d.key}'),
                avatar: Icon(
                  d.icon,
                  size: 18,
                  color: d == current ? Colors.white : homeNavy,
                ),
                label: Text(d.label),
                selected: d == current,
                showCheckmark: false,
                selectedColor: brand.primaryColor,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: d == current ? brand.primaryColor : homeLine,
                ),
                labelStyle: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: d == current ? Colors.white : homeNavy,
                ),
                onSelected: (_) =>
                    BottomNavPreferences.instance.setSlot(slotIndex, d),
              ),
          ],
        ),
      ],
    );
  }
}

/// Tercihler/onboarding ortak beyaz kart.
class PrefCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const PrefCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: homeLine),
    ),
    child: child,
  );
}

class PrefSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const PrefSectionTitle(this.title, {super.key, this.subtitle});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: homeNavy,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: const TextStyle(color: homeMuted, fontSize: 12.5),
          ),
        ],
      ],
    ),
  );
}
