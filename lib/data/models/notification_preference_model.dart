import 'package:equatable/equatable.dart';

/// Sessiz Saatler Modeli
class QuietHoursModel extends Equatable {
  final bool enabled;
  final String? start; // HH:MM
  final String? end; // HH:MM

  const QuietHoursModel({this.enabled = false, this.start, this.end});

  factory QuietHoursModel.fromJson(Map<String, dynamic> json) {
    return QuietHoursModel(
      enabled: json['enabled'] as bool? ?? false,
      start: json['start'] as String?,
      end: json['end'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'start': start,
    'end': end,
  };

  @override
  List<Object?> get props => [enabled, start, end];
}

/// Bildirim Tercihleri Modeli
class NotificationPreferenceModel extends Equatable {
  final bool notificationsEnabled;
  final bool breakingNews;
  final bool allCategories;
  final List<String> categoryIds;
  final bool allLocations;
  final List<String> locationIds;
  final QuietHoursModel quietHours;

  const NotificationPreferenceModel({
    this.notificationsEnabled = true,
    this.breakingNews = true,
    this.allCategories = false,
    this.categoryIds = const [],
    this.allLocations = false,
    this.locationIds = const [],
    this.quietHours = const QuietHoursModel(),
  });

  factory NotificationPreferenceModel.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(dynamic list) {
      if (list is List) {
        return list
            .map((e) => e?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      }
      return const [];
    }

    final rawQuiet = json['quiet_hours'];
    final quiet = rawQuiet is Map<String, dynamic>
        ? QuietHoursModel.fromJson(rawQuiet)
        : const QuietHoursModel();

    return NotificationPreferenceModel(
      notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
      breakingNews: json['breaking_news'] as bool? ?? true,
      allCategories: json['all_categories'] as bool? ?? false,
      categoryIds: parseStringList(json['category_ids']),
      allLocations: json['all_locations'] as bool? ?? false,
      locationIds: parseStringList(json['location_ids']),
      quietHours: quiet,
    );
  }

  Map<String, dynamic> toJson() => {
    'notifications_enabled': notificationsEnabled,
    'breaking_news': breakingNews,
    'all_categories': allCategories,
    'category_ids': categoryIds,
    'all_locations': allLocations,
    'location_ids': locationIds,
    'quiet_hours': quietHours.toJson(),
  };

  NotificationPreferenceModel copyWith({
    bool? notificationsEnabled,
    bool? breakingNews,
    bool? allCategories,
    List<String>? categoryIds,
    bool? allLocations,
    List<String>? locationIds,
    QuietHoursModel? quietHours,
  }) {
    return NotificationPreferenceModel(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      breakingNews: breakingNews ?? this.breakingNews,
      allCategories: allCategories ?? this.allCategories,
      categoryIds: categoryIds ?? this.categoryIds,
      allLocations: allLocations ?? this.allLocations,
      locationIds: locationIds ?? this.locationIds,
      quietHours: quietHours ?? this.quietHours,
    );
  }

  @override
  List<Object?> get props => [
    notificationsEnabled,
    breakingNews,
    allCategories,
    categoryIds,
    allLocations,
    locationIds,
    quietHours,
  ];
}
