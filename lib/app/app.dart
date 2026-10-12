import 'dart:async';

import 'package:flutter/material.dart';

import '../data/models/news_model.dart';
import '../data/models/push_notification_model.dart';
import '../design/app_theme.dart';
import 'app_config.dart';
import '../design/branding_state.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/startup/presentation/branded_startup_screen.dart';
import '../features/news/presentation/news_navigation.dart';
import '../features/blog/presentation/blog_navigation.dart';
import '../services/deep_link_service.dart';
import '../services/firebase_push_coordinator.dart';
import 'app_startup.dart';

/// GüncelGündem Mobil Uygulama Kök Bileşeni (Technical Foundation)
class GuncelGundemApp extends StatefulWidget {
  final AppStartupCoordinator startupCoordinator;
  final DeepLinkService? deepLinkService;

  const GuncelGundemApp({
    super.key,
    required this.startupCoordinator,
    this.deepLinkService,
  });

  @override
  State<GuncelGundemApp> createState() => _GuncelGundemAppState();
}

class _GuncelGundemAppState extends State<GuncelGundemApp>
    with WidgetsBindingObserver {
  // Deep link ve push intent'leri için ortak navigator anahtarı.
  final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _messenger =
      GlobalKey<ScaffoldMessengerState>();
  final FirebasePushCoordinator _push = FirebasePushCoordinator.instance;
  late final DeepLinkService _deepLinks =
      widget.deepLinkService ?? DeepLinkService();
  StreamSubscription<DeepLinkIntent>? _linkSubscription;
  StreamSubscription<PendingNotificationIntent>? _pushSubscription;
  StreamSubscription<PushNotificationPayload>? _foregroundSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bindDeepLinks();
    _bindPush();
  }

  Future<void> _bindDeepLinks() async {
    _linkSubscription = _deepLinks.onLink.listen(_dispatch);
    // Cold-start: shell Home'u mount edene kadar frame sonrası dispatch et.
    final initial = await _deepLinks.initialize();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _dispatch(initial));
    }
  }

  void _bindPush() {
    _pushSubscription = _push.onNotificationClicked.listen(_dispatchPush);
    _foregroundSubscription = _push.onForegroundNotification.listen(
      _showForegroundNotification,
    );
    unawaited(_push.start());
  }

  void _dispatchPush(PendingNotificationIntent intent) {
    final slug = intent.slug;
    final target = DeepLinkService.parse(intent.url) ??
        (slug != null && slug.isNotEmpty
            ? DeepLinkIntent(DeepLinkTarget.news, slug: slug)
            : null);
    if (target == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _dispatch(target);
    });
  }

  void _showForegroundNotification(PushNotificationPayload payload) {
    final messenger = _messenger.currentState;
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          payload.body.isEmpty
              ? payload.title
              : '${payload.title}\\n${payload.body}',
        ),
        action: SnackBarAction(
          label: 'Aç',
          onPressed: () => unawaited(_push.openForegroundPayload(payload)),
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_push.syncToken());
    }
  }

  void _dispatch(DeepLinkIntent intent) {
    final navigator = _navigator.currentState;
    final context = navigator?.context;
    if (navigator == null || context == null) return;
    switch (intent.target) {
      case DeepLinkTarget.news:
        if (intent.slug != null && intent.slug!.isNotEmpty) {
          NewsNavigation.openArticle(
            context,
            NewsModel(
              id: '',
              slug: intent.slug!,
              title: '',
              summary: '',
              readingTime: 0,
            ),
          );
        }
      case DeepLinkTarget.blog:
        if (intent.slug != null && intent.slug!.isNotEmpty) {
          BlogNavigation.openIdentifier(context, intent.slug!);
        } else {
          // Kategori biçimli blog bağlantısı: makale yerine Bilgi Köşesi dizini.
          navigator.pushNamed(BlogNavigation.index);
        }
      case DeepLinkTarget.home:
        navigator.popUntil((route) => route.isFirst);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    _pushSubscription?.cancel();
    _foregroundSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: BrandingState.instance,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: _navigator,
          scaffoldMessengerKey: _messenger,
          title: BrandingState.instance.siteName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,
          onGenerateRoute: (settings) =>
              BlogNavigation.generate(settings) ??
              NewsNavigation.generate(settings),
          home: TechnicalCoreShell(
            startupCoordinator: widget.startupCoordinator,
          ),
        );
      },
    );
  }
}

/// Keeps startup gates intact and shows Home only after successful startup.
class TechnicalCoreShell extends StatefulWidget {
  final AppStartupCoordinator startupCoordinator;

  const TechnicalCoreShell({super.key, required this.startupCoordinator});

  @override
  State<TechnicalCoreShell> createState() => _TechnicalCoreShellState();
}

/// Akış: Native Splash → Branded Startup (gerçek başlatma süresince) →
/// ilk kurulumsa Onboarding → Home. Yapay bekleme yoktur.
class _TechnicalCoreShellState extends State<TechnicalCoreShell> {
  late Future<StartupState> _startupFuture;
  bool _onboardingCompleted = false;

  @override
  void initState() {
    super.initState();
    _startupFuture = widget.startupCoordinator.start();
  }

  Future<void> _completeOnboarding() async {
    await widget.startupCoordinator.markOnboardingCompleted();
    unawaited(FirebasePushCoordinator.instance.syncToken());
    if (mounted) setState(() => _onboardingCompleted = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff05080f),
      body: FutureBuilder<StartupState>(
        future: _startupFuture,
        builder: (context, snapshot) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: _buildStage(context, snapshot),
        ),
      ),
    );
  }

  Widget _buildStage(
    BuildContext context,
    AsyncSnapshot<StartupState> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const BrandedStartupScreen(key: ValueKey('stage-startup'));
    }
    // Son savunma: koordinatör normalde throw etmez; etse bile uygulama
    // bundled default ile Home'a geçer. "Başlatma Hatası" ekranı YOK.
    final state =
        snapshot.data ??
        StartupReady(
          config: AppConfig.bundledDefaultConfig(),
          needsOnboarding: false,
        );
    return KeyedSubtree(
      key: ValueKey('stage-${state.runtimeType}-$_onboardingCompleted'),
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: _buildResult(context, state),
      ),
    );
  }

  Widget _buildResult(BuildContext context, StartupState state) {
    if (state is StartupMaintenance) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.build_circle_outlined,
                size: 64,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              const Text(
                'Sistem Bakımda',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                state.message ?? 'Lütfen daha sonra tekrar deneyiniz.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (state is StartupForceUpdate) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.system_update_rounded,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                'Güncelleme Gerekli',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Minimum sürüm: ${state.minimumVersion ?? "Bilinmiyor"}'),
            ],
          ),
        ),
      );
    }

    // StartupReady — ve beklenmedik [StartupFailed] / [StartupInitial] /
    // [StartupLoading] olasılığı için güvenli varsayılan davranış: Home.
    final needsOnboarding =
        state is StartupReady && state.needsOnboarding && !_onboardingCompleted;
    if (needsOnboarding) {
      return OnboardingScreen(onFinished: _completeOnboarding);
    }
    return HomeScreen(
      onAction: (action, payload) =>
          NewsNavigation.handleHome(context, action, payload),
    );
  }
}
