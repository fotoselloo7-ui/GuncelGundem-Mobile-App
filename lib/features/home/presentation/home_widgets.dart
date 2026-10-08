import 'package:flutter/material.dart';

import '../../../app/bottom_nav_preferences.dart';
import '../../../design/branding_state.dart';

import '../../news/presentation/widgets/cached_image_widget.dart';

const homeNavy = Color(0xff142239);
const homeMuted = Color(0xff64748b);
const homeLine = Color(0xffe5e9ef);
const homeBackground = Color(0xfff5f7fa);

ThemeData homeTheme(BrandingState brand) => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  fontFamily: 'Poppins',
  colorScheme: ColorScheme.light(
    primary: brand.primaryColor,
    secondary: brand.secondaryColor,
    surface: Colors.white,
  ),
  scaffoldBackgroundColor: homeBackground,
);

/// Exact 6C-B header language shared by the new news routes.
class HomeBrandHeader extends StatelessWidget implements PreferredSizeWidget {
  final BrandingState brand;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final VoidCallback? onContact;
  final bool allowBack;
  const HomeBrandHeader({
    super.key,
    required this.brand,
    required this.onSearch,
    required this.onNotifications,
    this.onContact,
    this.allowBack = false,
  });
  @override
  Size get preferredSize => const Size.fromHeight(64);
  @override
  Widget build(BuildContext context) => AppBar(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.white,
    elevation: 0,
    toolbarHeight: 64,
    automaticallyImplyLeading: allowBack,
    titleSpacing: 16,
    iconTheme: const IconThemeData(color: homeNavy),
    shape: const Border(bottom: BorderSide(color: homeLine)),
    title: Semantics(
      label: brand.siteName,
      image: true,
      child: SizedBox(
        height: 38,
        child: CachedImageWidget(
          imageUrl: brand.logoMobileUrl ?? brand.logoUrl,
          height: 38,
          fit: BoxFit.contain,
          fallbackWidget: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              brand.shortName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: homeNavy,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    ),
    actions: [
      IconButton(
        tooltip: 'Ara',
        onPressed: onSearch,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: const Icon(Icons.search_rounded, color: homeNavy),
      ),
      IconButton(
        tooltip: 'Bildirimler',
        onPressed: onNotifications,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: const Icon(Icons.notifications_none_rounded, color: homeNavy),
      ),
      if (onContact != null)
        IconButton(
          key: const ValueKey('header-contact'),
          tooltip: 'Bize Ulaşın',
          onPressed: onContact,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(Icons.contact_support_outlined, color: homeNavy),
        ),
      const SizedBox(width: 4),
    ],
  );
}

String homeDate(DateTime? value) {
  if (value == null) return '';
  final date = value.toLocal();
  const months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class HomeSection extends StatelessWidget {
  final String title;
  final Widget child;
  final String? eyebrow;
  final String? actionLabel;
  final VoidCallback? onAction;
  const HomeSection({
    super.key,
    required this.title,
    required this.child,
    this.eyebrow,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 5),
        ],
        Row(
          crossAxisAlignment: onAction == null
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.newspaper_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: homeNavy,
                ),
              ),
            ),
            if (onAction != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 112),
                child: TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  child: Text(
                    actionLabel ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class HomeMessage extends StatelessWidget {
  final String text;
  final IconData icon;
  const HomeMessage(
    this.text, {
    super.key,
    this.icon = Icons.newspaper_outlined,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: homeLine),
    ),
    child: Row(
      children: [
        Icon(icon, size: 22, color: homeMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: homeMuted, height: 1.5),
          ),
        ),
      ],
    ),
  );
}

class HomeCover extends StatelessWidget {
  final String? url;
  final bool video;
  final double? width;
  final double? height;
  const HomeCover({
    super.key,
    this.url,
    this.video = false,
    this.width,
    this.height,
  });
  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      CachedImageWidget(
        imageUrl: url,
        width: width,
        height: height,
        fallbackWidget: Container(
          width: width,
          height: height,
          color: const Color(0xffeaf0f5),
          child: const Center(
            child: Icon(
              Icons.image_outlined,
              color: Color(0xff94a3b8),
              size: 32,
            ),
          ),
        ),
      ),
      if (video)
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: homeNavy,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            size: 26,
            color: Colors.white,
          ),
        ),
    ],
  );
}

/// Shared visual composition only. News and blog remain separate domain models.
enum HomeCardStyle { standard, hero, mini, editorial }

class HomeArticleCard extends StatelessWidget {
  final String title;
  final String summary;
  final String? coverUrl;
  final String? category;
  final DateTime? date;
  final int? readingTime;
  final bool compact;
  final bool video;
  final VoidCallback? onTap;
  final HomeCardStyle style;
  final Widget? cover;
  final Color? badgeColor;
  const HomeArticleCard({
    super.key,
    required this.title,
    this.summary = '',
    this.coverUrl,
    this.category,
    this.date,
    this.readingTime,
    this.compact = false,
    this.video = false,
    this.onTap,
    this.style = HomeCardStyle.standard,
    this.cover,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final label = category?.trim() ?? '';
    final meta = [
      homeDate(date),
      if ((readingTime ?? 0) > 0) '$readingTime dk okuma',
    ].where((s) => s.isNotEmpty).join(' · ');
    final overlay =
        style == HomeCardStyle.hero || style == HomeCardStyle.editorial;
    final mini = style == HomeCardStyle.mini;
    final image =
        cover ??
        HomeCover(
          url: coverUrl,
          width: double.infinity,
          height: double.infinity,
          video: video,
        );
    if (style == HomeCardStyle.editorial) {
      return Material(
        color: const Color(0xff0b1423),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withAlpha(35)),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    image,
                    if (label.isNotEmpty)
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 8,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  badgeColor ??
                                  Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                height: 1.2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    title,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (overlay) {
      final hero = style == HomeCardStyle.hero;
      return Material(
        color: homeNavy,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(hero ? 14 : 12),
          side: BorderSide(color: Colors.white.withAlpha(35)),
        ),
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              image,
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x18142239),
                      Color(0xdd0b1423),
                      Color(0xff0b1423),
                    ],
                    stops: [0, .55, 1],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  hero ? 16 : 12,
                  16,
                  hero ? 48 : 12,
                  hero ? 38 : 12,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (label.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              badgeColor ??
                              Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      maxLines: hero ? 4 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: hero ? 23 : 14,
                        height: hero ? 1.2 : 1.3,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.4,
                      ),
                    ),
                    if (hero && summary.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xffd6dbe3),
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                    if (hero && meta.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xffd6dbe3),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: .3,
            ),
          ),
          const SizedBox(height: 5),
        ],
        Text(
          title,
          maxLines: compact ? 3 : 4,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: homeNavy,
            fontSize: mini
                ? 12
                : compact
                ? 14
                : 21,
            fontWeight: FontWeight.w700,
            height: compact ? 1.3 : 1.35,
            letterSpacing: -.3,
          ),
        ),
        if (!compact && !mini && summary.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, height: 1.6, color: homeMuted),
          ),
        ],
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            meta,
            style: const TextStyle(fontSize: 10, height: 1.5, color: homeMuted),
          ),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: homeLine),
        ),
        child: InkWell(
          onTap: onTap,
          child: compact && !mini
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: HomeCover(
                          url: coverUrl,
                          width: 72,
                          height: 72,
                          video: video,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: texts),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(aspectRatio: mini ? 1.5 : 16 / 9, child: image),
                    Padding(
                      padding: EdgeInsets.all(mini ? 8 : 16),
                      child: texts,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class HomeBottomBar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const HomeBottomBar({
    super.key,
    required this.selected,
    required this.onSelect,
  });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: BottomNavPreferences.instance,
    builder: (context, _) => _buildBar(context),
  );

  Widget _buildBar(BuildContext context) {
    // İlk 3 slot sabit; slot 4-5 kullanıcı tercihidir (Alt Menü Düzeni).
    final nav = BottomNavPreferences.instance;
    final labels = [
      'Ana Sayfa',
      'Son Dakika',
      'Haber Gönder',
      nav.slot4.label,
      nav.slot5.label,
    ];
    final icons = [
      Icons.home_outlined,
      Icons.bolt_outlined,
      Icons.add_rounded,
      nav.slot4.icon,
      nav.slot5.icon,
    ];
    final scaler = MediaQuery.textScalerOf(context);
    var labelHeight = scaler.scale(10.5) * 1.4;
    final largeText = scaler.scale(10.5) > 15;
    if (largeText) {
      final padding = MediaQuery.paddingOf(context);
      final width =
          (MediaQuery.sizeOf(context).width - padding.left - padding.right) /
              5 -
          4;
      for (var i = 0; i < labels.length; i++) {
        final painter = TextPainter(
          text: TextSpan(
            text: labels[i],
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10.5,
              height: 1.4,
              fontWeight: i == selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
          textDirection: Directionality.of(context),
          textScaler: scaler,
        )..layout(maxWidth: width);
        if (painter.height + 1 > labelHeight) labelHeight = painter.height + 1;
        painter.dispose();
      }
    }
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: homeNavy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(labels.length, (i) {
            final color = i == selected
                ? Theme.of(context).colorScheme.primary
                : const Color(0xffd6dbe3);
            return Expanded(
              child: Semantics(
                selected: i == selected,
                button: true,
                label: labels[i],
                hint: i >= 3 ? 'Alt menüyü düzenlemek için basılı tutun' : null,
                child: InkWell(
                  key: ValueKey('home-nav-$i'),
                  onTap: () => onSelect(i),
                  onLongPress: i >= 3
                      ? () => Navigator.of(context).pushNamed('/tercihler')
                      : null,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 64,
                      minWidth: 48,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 8,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (i == 2)
                            Transform.translate(
                              offset: const Offset(0, -6),
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: homeNavy, width: 2),
                                ),
                                child: const Icon(
                                  Icons.add_rounded,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              height: 42,
                              child: Icon(icons[i], color: color, size: 26),
                            ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: labelHeight,
                            child: Text(
                              labels[i],
                              maxLines: largeText ? null : 2,
                              overflow: largeText
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10.5,
                                height: 1.4,
                                color: color,
                                fontWeight: i == selected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
