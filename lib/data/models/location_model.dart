import 'package:equatable/equatable.dart';

/// Haber kartlarındaki lokasyon özeti
class LocationSnippetModel extends Equatable {
  final String id;
  final String name;
  final String slug;
  final String type;
  final String? provinceCode;

  const LocationSnippetModel({
    required this.id,
    required this.name,
    required this.slug,
    this.type = 'province',
    this.provinceCode,
  });

  factory LocationSnippetModel.fromJson(Map<String, dynamic> json) {
    return LocationSnippetModel(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      slug: (json['slug'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'province',
      provinceCode: json['province_code'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'type': type,
    if (provinceCode != null) 'province_code': provinceCode,
  };

  @override
  List<Object?> get props => [id, name, slug, type, provinceCode];
}

/// İlçe Lokasyon Modeli
class LocationDistrictModel extends Equatable {
  final String id;
  final String name;
  final String slug;
  final String type;
  final String provinceId;
  final String? parentId;
  final String? provinceCode;
  final String? canonicalUrl;

  const LocationDistrictModel({
    required this.id,
    required this.name,
    required this.slug,
    this.type = 'district',
    required this.provinceId,
    this.parentId,
    this.provinceCode,
    this.canonicalUrl,
  });

  factory LocationDistrictModel.fromJson(Map<String, dynamic> json) {
    return LocationDistrictModel(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      slug: (json['slug'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'district',
      provinceId:
          (json['province_id'] as String?) ??
          (json['parent_id'] as String?) ??
          '',
      parentId: json['parent_id'] as String?,
      provinceCode: json['province_code'] as String?,
      canonicalUrl: json['canonical_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'type': type,
    'province_id': provinceId,
    'parent_id': parentId,
    if (provinceCode != null) 'province_code': provinceCode,
    if (canonicalUrl != null) 'canonical_url': canonicalUrl,
  };

  @override
  List<Object?> get props => [
    id,
    name,
    slug,
    type,
    provinceId,
    parentId,
    provinceCode,
    canonicalUrl,
  ];
}

/// İl Lokasyon Modeli (İlçeleri ile birlikte)
class LocationProvinceModel extends Equatable {
  final String id;
  final String name;
  final String slug;
  final String type;
  final String? parentId;
  final String? provinceCode;
  final List<LocationDistrictModel> districts;
  final String? canonicalUrl;

  const LocationProvinceModel({
    required this.id,
    required this.name,
    required this.slug,
    this.type = 'province',
    this.parentId,
    this.provinceCode,
    this.districts = const [],
    this.canonicalUrl,
  });

  factory LocationProvinceModel.fromJson(Map<String, dynamic> json) {
    final rawDistricts = json['districts'] as List<dynamic>?;
    final districts = rawDistricts != null
        ? rawDistricts
              .whereType<Map<String, dynamic>>()
              .map((d) => LocationDistrictModel.fromJson(d))
              .toList()
        : const <LocationDistrictModel>[];

    return LocationProvinceModel(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      slug: (json['slug'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'province',
      parentId: json['parent_id'] as String?,
      provinceCode: json['province_code'] as String?,
      districts: districts,
      canonicalUrl: json['canonical_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'type': type,
    'parent_id': parentId,
    if (provinceCode != null) 'province_code': provinceCode,
    'districts': districts.map((d) => d.toJson()).toList(),
    if (canonicalUrl != null) 'canonical_url': canonicalUrl,
  };

  @override
  List<Object?> get props => [
    id,
    name,
    slug,
    type,
    parentId,
    provinceCode,
    districts,
    canonicalUrl,
  ];
}
