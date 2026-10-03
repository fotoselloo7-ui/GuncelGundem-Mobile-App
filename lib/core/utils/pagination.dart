import 'package:equatable/equatable.dart';

/// Tekrar kullanılabilir sayfalama durumu yöneticisi
class PaginatedList<T> extends Equatable {
  final List<T> items;
  final int page;
  final int limit;
  final bool hasMore;
  final int? total;
  final bool isLoadingMore;

  const PaginatedList({
    required this.items,
    this.page = 1,
    this.limit = 15,
    this.hasMore = false,
    this.total,
    this.isLoadingMore = false,
  });

  factory PaginatedList.empty({int limit = 15}) =>
      PaginatedList<T>(items: const [], page: 1, limit: limit, hasMore: false);

  /// Yeni sayfa verilerini ekler ve ID'ye göre tekilleştirir (deduplicate)
  PaginatedList<T> appendPage({
    required List<T> newItems,
    required bool hasMore,
    required String Function(T item) idSelector,
    int? total,
  }) {
    final existingIds = items.map(idSelector).toSet();
    final uniqueNewItems = newItems
        .where((i) => !existingIds.contains(idSelector(i)))
        .toList();

    return PaginatedList<T>(
      items: [...items, ...uniqueNewItems],
      page: page + 1,
      limit: limit,
      hasMore: hasMore,
      total: total ?? this.total,
      isLoadingMore: false,
    );
  }

  PaginatedList<T> copyWith({
    List<T>? items,
    int? page,
    int? limit,
    bool? hasMore,
    int? total,
    bool? isLoadingMore,
  }) {
    return PaginatedList<T>(
      items: items ?? this.items,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [
    items,
    page,
    limit,
    hasMore,
    total,
    isLoadingMore,
  ];
}
