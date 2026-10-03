import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/models/category_model.dart';
import '../../../data/models/news_model.dart';
import '../../../data/repositories/news_repository.dart';
import '../../../data/repositories/taxonomy_repository.dart';
import '../../../design/branding_state.dart';
import '../../home/presentation/home_widgets.dart';
import 'news_navigation.dart';
import 'widgets/news_feed_card.dart';

enum NewsFeedMode { breaking, categories, search, latest, featured, mostRead }

class NewsFeedScreen extends StatefulWidget {
  final NewsFeedMode mode;
  final NewsRepository? repository;
  final TaxonomyRepository? taxonomy;
  final CategoryModel? initialCategory;
  final ValueChanged<NewsModel>? onArticle;
  const NewsFeedScreen({
    super.key,
    required this.mode,
    this.repository,
    this.taxonomy,
    this.initialCategory,
    this.onArticle,
  });
  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> {
  late final NewsRepository _repository;
  late final TaxonomyRepository _taxonomy;
  final _queryController = TextEditingController();
  final _scroll = ScrollController();
  final List<NewsModel> _items = [];
  List<CategoryModel> _categories = const [];
  CategoryModel? _category;
  String _query = '';
  Timer? _debounce;
  int _generation = 0;
  int _page = 0;
  int _failedPage = 0;
  int? _total;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _error = false;
  bool _offline = false;
  bool _taxonomyLoading = false;
  bool _taxonomyError = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? NewsRepository();
    _taxonomy = widget.taxonomy ?? TaxonomyRepository();
    _category = widget.initialCategory;
    _scroll.addListener(_onScroll);
    if (widget.mode == NewsFeedMode.categories) {
      unawaited(_loadCategories());
    }
    if (widget.mode != NewsFeedMode.search &&
            widget.mode != NewsFeedMode.categories ||
        _category != null) {
      unawaited(_loadFirst());
    }
  }

  Future<void> _loadCategories() async {
    setState(() {
      _taxonomyLoading = true;
      _taxonomyError = false;
    });
    try {
      final categories = await _taxonomy.getCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          if (_category != null) {
            _category =
                flattenNewsCategories(categories)
                    .where((entry) => entry.category.slug == _category!.slug)
                    .firstOrNull
                    ?.category ??
                _category;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _taxonomyError = true);
    } finally {
      if (mounted) setState(() => _taxonomyLoading = false);
    }
  }

  Future<PaginatedNewsResult> _fetch(int page) => switch (widget.mode) {
    NewsFeedMode.breaking => _repository.getBreakingPage(page: page),
    NewsFeedMode.categories => _repository.getCategoryNews(
      _category!.slug,
      page: page,
    ),
    NewsFeedMode.search => _repository.search(_query, page: page),
    NewsFeedMode.latest => _repository.getArchive(page: page),
    NewsFeedMode.featured => _repository.getArchive(
      page: page,
      feed: 'featured',
    ),
    NewsFeedMode.mostRead => _repository.getArchive(
      page: page,
      feed: 'most_read',
    ),
  };

  bool get _canFetch =>
      widget.mode != NewsFeedMode.categories &&
          widget.mode != NewsFeedMode.search ||
      (widget.mode == NewsFeedMode.categories && _category != null) ||
      (widget.mode == NewsFeedMode.search && _query.runes.length >= 2);

  Future<void> _loadFirst() async {
    if (!_canFetch) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = false;
    });
    try {
      final result = await _fetch(1);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items
          ..clear()
          ..addAll(_unique(result.news));
        _page = 1;
        _hasMore = result.hasMore;
        _total = result.meta?.total;
        _offline = result.isOffline;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = true;
          _failedPage = 1;
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  List<NewsModel> _unique(Iterable<NewsModel> news) {
    final seen = <String>{};
    return news
        .where((item) => seen.add(item.id.isNotEmpty ? item.id : item.slug))
        .toList();
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore || !_canFetch) return;
    final generation = _generation;
    final nextPage = _page + 1;
    setState(() {
      _loadingMore = true;
      _error = false;
    });
    try {
      final result = await _fetch(nextPage);
      if (!mounted || generation != _generation) return;
      setState(() {
        final combined = _unique([..._items, ...result.news]);
        _items
          ..clear()
          ..addAll(combined);
        _page = nextPage;
        _hasMore = result.hasMore;
        _total = result.meta?.total ?? _total;
        _offline = _offline || result.isOffline;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = true;
          _failedPage = nextPage;
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loadingMore = false);
      }
    }
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 240 && !_error) {
      unawaited(_loadMore());
    }
  }

  void _reset() {
    _generation++;
    _items.clear();
    _page = 0;
    _total = null;
    _hasMore = false;
    _loading = false;
    _loadingMore = false;
    _error = false;
    _offline = false;
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _queryChanged(String text) {
    _debounce?.cancel();
    final query = text.trim();
    if (_query == query) return;
    setState(() {
      _reset();
      _query = query;
    });
    if (query.runes.length >= 2) {
      _debounce = Timer(
        const Duration(milliseconds: 400),
        () => unawaited(_loadFirst()),
      );
    }
  }

  void _select(CategoryModel category) {
    setState(() {
      _reset();
      _category = category;
    });
    unawaited(_loadFirst());
  }

  Future<void> _refresh() =>
      widget.mode == NewsFeedMode.categories && _category == null
      ? _loadCategories()
      : _loadFirst();

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    _queryController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: BrandingState.instance,
    builder: (context, _) {
      final brand = BrandingState.instance;
      final categoryList =
          widget.mode == NewsFeedMode.categories && _category == null;
      final entries = flattenNewsCategories(_categories);
      final title = switch (widget.mode) {
        NewsFeedMode.breaking => 'Son Dakika',
        NewsFeedMode.categories => _category?.name ?? 'Tüm Kategoriler',
        NewsFeedMode.search => 'Haber Ara',
        NewsFeedMode.latest => 'Güncel Haberler',
        NewsFeedMode.featured => 'Öne Çıkan Haberler',
        NewsFeedMode.mostRead => 'Çok Okunanlar',
      };
      return Theme(
        data: homeTheme(brand),
        child: Scaffold(
          appBar: HomeBrandHeader(
            brand: brand,
            allowBack: true,
            onSearch: () {
              if (widget.mode != NewsFeedMode.search) {
                NewsNavigation.openSearch(context);
              }
            },
            onNotifications: () => NewsNavigation.openNotifications(context),
          ),
          bottomNavigationBar: HomeBottomBar(
            selected: widget.mode == NewsFeedMode.breaking ? 1 : -1,
            onSelect: (index) {
              if (index == 0) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              } else if (index == 1) {
                if (widget.mode == NewsFeedMode.breaking &&
                    _scroll.hasClients) {
                  _scroll.animateTo(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                } else {
                  NewsNavigation.openBreaking(context);
                }
              } else {
                NewsNavigation.handleBottom(context, index);
              }
            },
          ),
          body: SafeArea(
            top: false,
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                key: const ValueKey('news-scroll'),
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 24,
                                  height: 1.4,
                                  fontWeight: FontWeight.w700,
                                  color: homeNavy,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (widget.mode == NewsFeedMode.search) ...[
                                TextField(
                                  key: const ValueKey('news-search'),
                                  controller: _queryController,
                                  onChanged: _queryChanged,
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: (_) {
                                    _debounce?.cancel();
                                    unawaited(_loadFirst());
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Haberlerde ara',
                                    prefixIcon: const Icon(Icons.search),
                                    filled: true,
                                    fillColor: Colors.white,
                                    suffixIcon: IconButton(
                                      tooltip: 'Aramayı temizle',
                                      onPressed: () {
                                        _queryController.clear();
                                        _queryChanged('');
                                      },
                                      icon: const Icon(Icons.close),
                                      constraints: const BoxConstraints(
                                        minWidth: 48,
                                        minHeight: 48,
                                      ),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: homeLine,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _query.runes.length < 2
                                      ? 'Aramak için en az 2 karakter yazın.'
                                      : '“$_query” için haber sonuçları',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.5,
                                    color: homeMuted,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              // Tek satır, yatay kaydırılabilir filtre barı.
                              // İlk chip her zaman "Tüm Kategoriler" (global
                              // kategori gezgini). Devamında alt kategoriler.
                              // Satır kırılmaz; ekrana sığmayanlara yatay kaydırmayla ulaşılır.
                              SizedBox(
                                height: 40,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  padding: EdgeInsets.zero,
                                  children: [
                                    _CategoryFilterChip(
                                      label: 'Tüm Kategoriler',
                                      icon: Icons.grid_view_rounded,
                                      selected: false,
                                      onTap: () => NewsNavigation.openCategories(
                                        context,
                                      ),
                                    ),
                                    if (_category != null)
                                      for (final child in _category!.children) ...[
                                        const SizedBox(width: 8),
                                        _CategoryFilterChip(
                                          label: child.name,
                                          selected: false,
                                          onTap: () => _select(child),
                                        ),
                                      ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (_total != null)
                                Text(
                                  '${_items.length} / $_total haber',
                                  key: const ValueKey('news-count'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: homeMuted,
                                  ),
                                ),
                              if (_offline)
                                const Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: HomeMessage(
                                    'Bağlantı kurulamadı. Kaydedilmiş haberler gösteriliyor.',
                                    icon: Icons.wifi_off,
                                  ),
                                ),
                              if (_loading && _items.isEmpty ||
                                  categoryList && _taxonomyLoading)
                                const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              if (categoryList && _taxonomyError ||
                                  !categoryList && _error && _items.isEmpty)
                                _errorState(
                                  categoryList ? _loadCategories : _loadFirst,
                                ),
                              if (categoryList &&
                                  !_taxonomyLoading &&
                                  !_taxonomyError &&
                                  entries.isEmpty)
                                const HomeMessage('Henüz kategori bulunmuyor.'),
                              if (!categoryList &&
                                  _canFetch &&
                                  !_loading &&
                                  !_error &&
                                  _items.isEmpty)
                                const HomeMessage(
                                  'Bu seçime uygun haber bulunamadı.',
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (categoryList)
                    SliverList.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, i) {
                        final entry = entries[i];
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 640),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Material(
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: const BorderSide(color: homeLine),
                                  ),
                                  child: ListTile(
                                    key: ValueKey(
                                      'news-category-${entry.category.id}',
                                    ),
                                    minTileHeight: 56,
                                    contentPadding: EdgeInsets.only(
                                      left:
                                          16 +
                                          (entry.depth.clamp(0, 3) * 8)
                                              .toDouble(),
                                      right: 12,
                                    ),
                                    title: Text(
                                      entry.category.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: homeNavy,
                                      ),
                                    ),
                                    subtitle: entry.parent == null
                                        ? null
                                        : Text(
                                            entry.parent!,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: homeMuted,
                                            ),
                                          ),
                                    trailing: const Icon(
                                      Icons.chevron_right,
                                      size: 20,
                                    ),
                                    onTap: () => _select(entry.category),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => CompactNewsGridCard(
                            news: _items[i],
                            onTap: () => _openArticle(_items[i]),
                          ),
                          childCount: _items.length,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          mainAxisExtent: compactNewsGridHeight(
                            context,
                            (MediaQuery.sizeOf(context).width - 42) / 2,
                          ),
                        ),
                      ),
                    ),
                  if (!categoryList && _items.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        child: Column(
                          children: [
                            if (_loadingMore || _loading)
                              const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else if (_error)
                              _errorState(
                                _failedPage == 1 ? _loadFirst : _loadMore,
                              )
                            else if (_hasMore)
                              OutlinedButton.icon(
                                key: const ValueKey('news-more'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(180, 48),
                                ),
                                onPressed: _loadMore,
                                icon: const Icon(Icons.expand_more),
                                label: const Text('Daha Fazla Haber'),
                              )
                            else
                              const Text(
                                key: ValueKey('news-end'),
                                'Tüm haberler gösterildi.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: homeMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _errorState(Future<void> Function() retry) => Column(
    children: [
      const HomeMessage(
        'Haberler şu anda yüklenemiyor. Mevcut liste korunuyor.',
        icon: Icons.error_outline,
      ),
      TextButton(
        key: const ValueKey('news-retry'),
        onPressed: retry,
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        child: const Text('Tekrar Dene'),
      ),
    ],
  );

  void _openArticle(NewsModel news) => widget.onArticle != null
      ? widget.onArticle!(news)
      : NewsNavigation.openArticle(context, news);
}

class NewsCategoryEntry {
  final CategoryModel category;
  final int depth;
  final String? parent;
  const NewsCategoryEntry(this.category, this.depth, this.parent);
}

List<NewsCategoryEntry> flattenNewsCategories(List<CategoryModel> roots) {
  final entries = <NewsCategoryEntry>[];
  final seen = <String>{};
  void visit(CategoryModel category, int depth, String? parent) {
    if (!seen.add(category.id.isNotEmpty ? category.id : category.slug)) return;
    entries.add(NewsCategoryEntry(category, depth, parent));
    for (final child in category.children) {
      visit(child, depth + 1, category.name);
    }
  }

  for (final category in roots) {
    visit(category, 0, null);
  }
  return entries;
}

/// Yatay kaydırılabilir filtre barı için chip.
///
/// Yükseklik 40px, radius 20, tek satır (maxLines: 1, softWrap: false). İçerik
/// genişliğine göre otomatik boyutlanır — Wrap kullanılmaz, kırılma olmaz.
class _CategoryFilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    final bg = selected ? brand : Colors.white;
    final fg = selected ? Colors.white : brand;
    return Material(
      color: bg,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? brand : homeLine, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: icon == null ? 16 : 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fg,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
