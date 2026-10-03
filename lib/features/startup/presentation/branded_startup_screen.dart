import 'package:flutter/material.dart';

/// GüncelGündem Branded Startup
///
/// Native splash'tan sonra, uygulama yapılandırması / konum / ilk durum
/// hazırlanırken gösterilir. YAPAY BEKLEME YOKTUR: başlangıç tamamlandığı an
/// kabuk bir sonraki rotaya geçer.
///
/// Görsel: seçilmiş dünya temalı splash tasarımı (amblem + "Daha geniş bir
/// bakış." sloganı tasarımın içindedir). Üzerine hafif giriş (fade + scale),
/// amblem çevresinde yumuşak nabız ışıması ve gerçek, belirsiz ilerleme çubuğu
/// eklenir. Hareket azaltma tercihinde animasyonlar kapatılır.
class BrandedStartupScreen extends StatefulWidget {
  const BrandedStartupScreen({super.key});

  static const asset = 'assets/brand/startup_world.webp';

  // Kaynak görselin piksel geometrisi (863x1822) — cover yerleşiminde hizalama.
  static const Size artSize = Size(863, 1822);
  static const Offset emblemCenter = Offset(432, 782);
  static const double emblemRadius = 177;
  static const Rect progressBar = Rect.fromLTRB(268, 1692, 593, 1700);

  @override
  State<BrandedStartupScreen> createState() => _BrandedStartupScreenState();
}

class _BrandedStartupScreenState extends State<BrandedStartupScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _intro.value = 1;
      _progress.value = .5;
      return;
    }
    _intro.forward();
    _pulse.repeat(reverse: true);
    _progress.repeat();
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'GüncelGündem. Daha geniş bir bakış. Yükleniyor.',
      liveRegion: true,
      child: ColoredBox(
        color: const Color(0xff05080f),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            const art = BrandedStartupScreen.artSize;
            // BoxFit.cover eşlemesi: tasarım koordinatı → ekran koordinatı.
            final scale = (size.width / art.width) > (size.height / art.height)
                ? size.width / art.width
                : size.height / art.height;
            final dx = (size.width - art.width * scale) / 2;
            final dy = (size.height - art.height * scale) / 2;
            Offset map(Offset p) =>
                Offset(dx + p.dx * scale, dy + p.dy * scale);

            final center = map(BrandedStartupScreen.emblemCenter);
            final glowRadius = BrandedStartupScreen.emblemRadius * scale * 1.45;
            final bar = BrandedStartupScreen.progressBar;
            final barTopLeft = map(bar.topLeft);
            final barWidth = bar.width * scale;
            final barHeight = (bar.height * scale).clamp(3.0, 6.0);

            final intro = CurvedAnimation(
              parent: _intro,
              curve: Curves.easeOutCubic,
            );

            return Stack(
              fit: StackFit.expand,
              children: [
                FadeTransition(
                  opacity: intro,
                  child: ScaleTransition(
                    scale: Tween(begin: 1.05, end: 1.0).animate(intro),
                    child: ExcludeSemantics(
                      child: Image.asset(
                        BrandedStartupScreen.asset,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, _, _) => const _FallbackBrand(),
                      ),
                    ),
                  ),
                ),
                // Amblem çevresinde yumuşak kırmızı/beyaz nabız ışıması.
                Positioned(
                  left: center.dx - glowRadius,
                  top: center.dy - glowRadius,
                  width: glowRadius * 2,
                  height: glowRadius * 2,
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_pulse, _intro]),
                      builder: (_, _) => Opacity(
                        opacity:
                            _intro.value *
                            (0.10 +
                                0.22 *
                                    Curves.easeInOut.transform(_pulse.value)),
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Color(0x00000000),
                                Color(0x00000000),
                                Color(0xffff2a2a),
                                Color(0x00ff2a2a),
                              ],
                              stops: [0, .62, .72, 1],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Gerçek (belirsiz) ilerleme: tasarımdaki çubuğun yerini alır.
                Positioned(
                  left: barTopLeft.dx,
                  top: barTopLeft.dy + (bar.height * scale - barHeight) / 2,
                  width: barWidth,
                  height: barHeight,
                  child: FadeTransition(
                    opacity: intro,
                    child: _IndeterminateBar(animation: _progress),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _IndeterminateBar extends StatelessWidget {
  final Animation<double> animation;
  const _IndeterminateBar({required this.animation});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(99),
    child: ColoredBox(
      color: const Color(0xff3a3f4b),
      child: LayoutBuilder(
        builder: (context, c) => AnimatedBuilder(
          animation: animation,
          builder: (_, _) {
            final w = c.maxWidth * .45;
            final t = Curves.easeInOut.transform(animation.value);
            return Stack(
              children: [
                Positioned(
                  left: -w + (c.maxWidth + w) * t,
                  top: 0,
                  bottom: 0,
                  width: w,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(99)),
                      gradient: LinearGradient(
                        colors: [Color(0xffb3000b), Color(0xffff1a24)],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

/// Görsel çözülemezse: koyu zemin + orijinal amblem + slogan.
class _FallbackBrand extends StatelessWidget {
  const _FallbackBrand();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xff0b1423),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/brand/emblem_disc.png', width: 132, height: 132),
          const SizedBox(height: 24),
          const Text(
            'Daha geniş bir bakış.',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white,
              fontSize: 20,
            ),
          ),
        ],
      ),
    ),
  );
}
