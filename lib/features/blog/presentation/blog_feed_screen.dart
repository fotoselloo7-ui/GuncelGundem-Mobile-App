import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/models/blog_article_model.dart';
import '../../../data/models/blog_category_model.dart';
import '../../../data/models/info_corner_model.dart';
import '../../../data/repositories/blog_repository.dart';
import '../../../data/state/home_data_state.dart';
import '../../home/presentation/home_widgets.dart';
import 'blog_category_explorer.dart';
import 'blog_navigation.dart';
import 'blog_widgets.dart';

class BlogFeedScreen extends StatefulWidget {
  final BlogRepository? repository;
  final BlogCategorySelection? selection;
  final InfoCornerModel? info;
  const BlogFeedScreen({super.key, this.repository, this.selection, this.info});
  @override
  State<BlogFeedScreen> createState() => _BlogFeedScreenState();
}

class _BlogFeedScreenState extends State<BlogFeedScreen> {
  late final BlogRepository _repo;
  final _scroll = ScrollController();
  List<BlogArticleModel> _items = [];
  BlogCategoryModel? _category;
  int _page = 0, _total = 0, _generation = 0;
  bool _loading = true,
      _moreLoading = false,
      _hasMore = false,
      _offline = false;
  bool _firstError = false, _moreError = false;
  InfoCornerModel? get _info =>
      widget.info ?? HomeDataState.instance.infoCorner;
  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? BlogRepository();
    _scroll.addListener(_onScroll);
    _first();
  }

  @override
  void dispose() {
    _generation++;
    _scroll.dispose();
    super.dispose();
  }

  Future<PaginatedBlogResult> _fetch(int page, {bool refresh = false}) {
    final category = widget.selection?.category;
    return category == null
        ? _repo.getArticles(page: page, perPage: 15, forceRefresh: refresh)
        : _repo.getCategoryArticles(
            Uri.encodeComponent(
              category.slug.isNotEmpty ? category.slug : category.id,
            ),
            page: page,
            perPage: 15,
            forceRefresh: refresh,
          );
  }

  Future<void> _first({bool refresh = false}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _firstError = false;
      _moreLoading = false;
      _moreError = false;
    });
    try {
      final result = await _fetch(1, refresh: refresh);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = _unique(result.articles);
        _category = result.category;
        _page = result.page;
        _total = result.data.totalItems;
        _hasMore = result.hasMore;
        _offline = result.isOffline;
        _loading = false;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _firstError = true;
        });
      }
    }
  }

  List<BlogArticleModel> _unique(List<BlogArticleModel> articles) {
    final seen = <String>{};
    return articles
        .where((a) => seen.add(a.id.isNotEmpty ? a.id : a.slug))
        .toList();
  }

  Future<void> _more() async {
    if (_moreLoading || _loading || !_hasMore) return;
    final generation = _generation;
    setState(() {
      _moreLoading = true;
      _moreError = false;
    });
    try {
      final result = await _fetch(_page + 1);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = _unique([..._items, ...result.articles]);
        _page = result.page;
        _total = result.data.totalItems;
        _hasMore = result.hasMore;
        _offline = result.isOffline;
        _moreLoading = false;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _moreLoading = false;
          _moreError = true;
        });
      }
    }
  }

  void _onScroll() {
    if (_scroll.hasClients &&
        _scroll.position.extentAfter < 240 &&
        !_moreError &&
        !_firstError) {
      unawaited(_more());
    }
  }

  Widget _grid(List<BlogArticleModel> articles) => SliverLayoutBuilder(
    builder: (context, constraints) => SliverGrid.builder(
      itemCount: articles.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: compactBlogGridHeight(
          context,
          (constraints.crossAxisExtent - 10) / 2,
        ),
      ),
      itemBuilder: (context, index) => CompactBlogGridCard(
        article: articles[index],
        onTap: () => BlogNavigation.openArticle(context, articles[index]),
      ),
    ),
  );

  Future<void> _select() async {
    final current = widget.selection;
    final selectedCategory = _category ?? current?.category;
    final parent =
        current?.parent ??
        (selectedCategory?.parentId == null ? selectedCategory : null);
    final selection = await showBlogCategoryExplorer(
      context,
      _repo,
      initialParent: parent,
    );
    if (mounted && selection != null) {
      BlogNavigation.openCategory(context, selection);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selection = widget.selection == null
        ? null
        : BlogCategorySelection(
            _category ?? widget.selection!.category,
            parent: widget.selection!.parent,
          );
    final featured = selection == null
        ? _unique([
            ..._items.where((a) => a.featured),
            ...(_info?.featured ?? const <BlogArticleModel>[]),
          ])
        : <BlogArticleModel>[];
    final ids = featured.map((a) => a.id.isNotEmpty ? a.id : a.slug).toSet();
    final latest = _items
        .where((a) => !ids.contains(a.id.isNotEmpty ? a.id : a.slug))
        .toList();
    return BlogShell(
      body: RefreshIndicator(
        onRefresh: () => _first(refresh: true),
        child: CustomScrollView(
          key: const ValueKey('blog-scroll'),
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (selection != null)
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () => BlogNavigation.openIndex(context),
                            child: const Text('Bilgi Köşesi'),
                          ),
                          if (selection.parent != null) ...[
                            const Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: homeMuted,
                            ),
                            TextButton(
                              onPressed: () => BlogNavigation.openCategory(
                                context,
                                BlogCategorySelection(selection.parent!),
                              ),
                              child: Text(selection.parent!.name),
                            ),
                          ],
                        ],
                      ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: homeNavy,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.auto_stories_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              selection?.category.name ??
                                  ((_info?.title ?? '').isNotEmpty
                                      ? _info!.title
                                      : 'Bilgi Köşesi'),
                              style: const TextStyle(
                                fontSize: 23,
                                height: 1.3,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if ((selection?.category.description ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          selection!.category.description,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.7,
                            color: homeMuted,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        key: const ValueKey('blog-category-picker'),
                        onPressed: _select,
                        icon: const Icon(Icons.grid_view_outlined, size: 18),
                        label: Text(
                          selection?.category.children.isNotEmpty == true
                              ? 'Alt Konu / Kategori Seç'
                              : 'Kategori Seç',
                        ),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size(48, 48),
                          side: const BorderSide(color: homeLine),
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_offline)
                      const HomeMessage(
                        'Kaydedilmiş yazılar gösteriliyor.',
                        icon: Icons.wifi_off,
                      ),
                    if (!_loading || _items.isNotEmpty)
                      Text(
                        '${_items.length} / $_total yazı',
                        key: const ValueKey('blog-count'),
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.7,
                          color: homeMuted,
                        ),
                      ),
                    if (_loading && _items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (_firstError) ...[
                      const HomeMessage(
                        'Yazılar yüklenemedi.',
                        icon: Icons.error_outline,
                      ),
                      TextButton(
                        key: const ValueKey('blog-first-retry'),
                        onPressed: () => _first(),
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                    if (!_loading &&
                        !_firstError &&
                        _items.isEmpty &&
                        featured.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: HomeMessage(
                          'Bu bölümde henüz yayınlanmış yazı bulunmuyor.',
                          icon: Icons.menu_book_outlined,
                        ),
                      ),
                    if (featured.isNotEmpty) blogHeading('Öne Çıkan Rehberler'),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: _grid(featured),
            ),
            if (latest.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: blogHeading(
                    selection == null ? 'Son Yazılar' : 'Yazılar',
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: _grid(latest),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    if (_moreLoading)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    if (_moreError)
                      const HomeMessage(
                        'Sonraki sayfa yüklenemedi. Mevcut yazılar korunuyor.',
                        icon: Icons.error_outline,
                      ),
                    if (_hasMore && !_loading && !_moreLoading)
                      OutlinedButton(
                        key: const ValueKey('blog-more'),
                        onPressed: _more,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(180, 48),
                        ),
                        child: Text(_moreError ? 'Tekrar Dene' : 'Daha Fazla'),
                      ),
                    if (!_hasMore && !_loading && _items.isNotEmpty)
                      const Text(
                        'Tüm yazılar gösterildi.',
                        key: ValueKey('blog-end'),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.7,
                          color: homeMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
