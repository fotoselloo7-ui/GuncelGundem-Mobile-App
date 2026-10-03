import 'ad_model.dart';
import 'home_model.dart';
import 'info_corner_model.dart';
import 'location_model.dart';
import 'news_model.dart';

/// Data slots for 6C-B, not a widget or a new API contract. City, local, ads and
/// video are supplied by their existing services; /home does not supply them yet.
class HomeViewModel {
  final HomeModel home;
  final LocationSnippetModel? city;
  final List<NewsModel> local;
  final List<MobileAdModel> ads;
  final List<NewsModel> video;
  const HomeViewModel({
    required this.home,
    this.city,
    this.local = const [],
    this.ads = const [],
    this.video = const [],
  });
  String? get locationId => city?.id;
  List<NewsModel> get breaking => home.breaking;
  List<NewsModel> get hero => home.hero;
  List<HomeCategorySectionModel> get newsSections => home.categorySections;
  InfoCornerModel? get infoCorner => home.infoCorner;
}
