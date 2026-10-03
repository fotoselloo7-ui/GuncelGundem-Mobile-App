import '../../../data/models/location_model.dart';

/// Presentation-only resolution of saved canonical IDs; never changes preferences.
class HomeCity {
  final LocationSnippetModel location;
  final String provinceName;
  final String provinceSlug;
  final String? districtSlug;

  const HomeCity({
    required this.location,
    required this.provinceName,
    required this.provinceSlug,
    this.districtSlug,
  });

  String get label =>
      districtSlug == null ? location.name : '${location.name} / $provinceName';

  static HomeCity? resolve(
    List<String> savedIds,
    List<LocationProvinceModel> provinces,
  ) {
    // Prefer a saved district over its also-saved province, preserving ID order.
    for (final id in savedIds) {
      for (final province in provinces) {
        for (final district in province.districts) {
          if (district.id == id) {
            return HomeCity(
              location: LocationSnippetModel(
                id: district.id,
                name: district.name,
                slug: district.slug,
                type: district.type,
                provinceCode: district.provinceCode,
              ),
              provinceName: province.name,
              provinceSlug: province.slug,
              districtSlug: district.slug,
            );
          }
        }
      }
    }
    for (final id in savedIds) {
      for (final province in provinces) {
        if (province.id == id) {
          return HomeCity(
            location: LocationSnippetModel(
              id: province.id,
              name: province.name,
              slug: province.slug,
              type: province.type,
              provinceCode: province.provinceCode,
            ),
            provinceName: province.name,
            provinceSlug: province.slug,
          );
        }
      }
    }
    return null;
  }
}
