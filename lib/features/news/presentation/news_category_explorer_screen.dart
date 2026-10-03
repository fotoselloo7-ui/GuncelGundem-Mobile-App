import 'package:flutter/material.dart';

import '../../../app/bottom_nav_preferences.dart';
import '../../../data/models/category_model.dart';
import '../../../data/repositories/blog_repository.dart';
import '../../../data/repositories/taxonomy_repository.dart';
import '../../../design/branding_state.dart';
import '../../blog/presentation/blog_category_explorer.dart';
import '../../home/presentation/home_widgets.dart';
import 'news_navigation.dart';

/// Keeps the two taxonomy domains separate while preserving their repositories.
class NewsCategoryExplorerScreen extends StatefulWidget {
  final TaxonomyRepository? taxonomy;
  final BlogRepository? blogRepository;
  const NewsCategoryExplorerScreen({
    super.key,
    this.taxonomy,
    this.blogRepository,
  });
  @override
  State<NewsCategoryExplorerScreen> createState() =>
      _NewsCategoryExplorerScreenState();
}

class _NewsCategoryExplorerScreenState
    extends State<NewsCategoryExplorerScreen> {
  late final TaxonomyRepository _taxonomy =
      widget.taxonomy ?? TaxonomyRepository();
  late final BlogRepository _blog = widget.blogRepository ?? BlogRepository();
  final _search = TextEditingController();
  List<CategoryModel> _roots = const [];
  CategoryModel? _parent;
  bool _loading = true;
  bool _error = false;
  bool _blogDomain = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final roots = await _taxonomy.getCategories();
      if (mounted) setState(() => _roots = roots);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Iterable<CategoryModel> get _visible {
    final items = (_parent?.children ?? _roots).where(
      (item) => item.contentTypes.contains('news'),
    );
    final q = _search.text.trim().toLowerCase();
    return q.isEmpty
        ? items
        : items.where((item) => item.name.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final brand = BrandingState.instance;
    return Theme(
      data: homeTheme(brand),
      child: Scaffold(
        appBar: HomeBrandHeader(
          brand: brand,
          allowBack: true,
          onSearch: () => NewsNavigation.openSearch(context),
          onNotifications: () => NewsNavigation.openNotifications(context),
        ),
        bottomNavigationBar: HomeBottomBar(
          selected: BottomNavPreferences.instance.indexOf(
            NavDestination.categories,
          ),
          onSelect: (index) => NewsNavigation.handleBottom(context, index),
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Tüm Kategoriler',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: homeNavy,
                  ),
                ),
                const SizedBox(height: 12),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _domain(
                        false,
                        'Haber Kategorileri',
                        Icons.newspaper_outlined,
                      ),
                      const SizedBox(width: 8),
                      _domain(
                        true,
                        'Bilgi Köşesi',
                        Icons.auto_stories_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_blogDomain) ...[
                  Expanded(
                    child: BlogCategoryExplorer(
                      repository: _blog,
                      embedded: true,
                      onSelected: (selection) => Navigator.of(context)
                          .pushNamed(
                            '/bilgi-kosesi/kategori',
                            arguments: selection,
                          ),
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Haber kategorilerinde ara',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_parent != null)
                    TextButton.icon(
                      onPressed: () => setState(() => _parent = null),
                      icon: const Icon(Icons.arrow_back),
                      label: Text(_parent!.name),
                    ),
                  if (_parent != null)
                    FilledButton(
                      onPressed: () => Navigator.of(context)
                          .pushNamed('/haber-kategorileri', arguments: _parent),
                      child: Text('${_parent!.name} · Tüm Haberler'),
                    ),
                  if (_error)
                    HomeMessage(
                      'Kategoriler yüklenemedi.',
                      icon: Icons.error_outline,
                    ),
                  if (_error)
                    TextButton(
                      onPressed: _load,
                      child: const Text('Tekrar Dene'),
                    ),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.separated(
                            itemCount: _visible.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final category = _visible.elementAt(index);
                              final hasChildren = category.children.isNotEmpty;
                              return Material(
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: homeLine),
                                ),
                                child: ListTile(
                                  key: ValueKey('news-category-${category.id}'),
                                  minTileHeight: 56,
                                  title: Text(
                                    category.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: homeNavy,
                                    ),
                                  ),
                                  subtitle: Text(
                                    hasChildren
                                        ? '${category.children.length} alt kategori'
                                        : 'Haberleri görüntüle',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: homeMuted,
                                    ),
                                  ),
                                  trailing: Icon(
                                    hasChildren
                                        ? Icons.chevron_right_rounded
                                        : Icons.grid_view_rounded,
                                  ),
                                  onTap: () => hasChildren
                                      ? setState(() => _parent = category)
                                      : Navigator.of(context).pushNamed(
                                          '/haber-kategorileri',
                                          arguments: category,
                                        ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _domain(bool value, String label, IconData icon) => Expanded(
    child: Semantics(
      selected: value == _blogDomain,
      button: true,
      child: Material(
        color: value == _blogDomain ? homeNavy : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: homeLine),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _blogDomain = value),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: value == _blogDomain ? Colors.white : homeNavy,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: value == _blogDomain ? Colors.white : homeNavy,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
