import 'package:flutter/foundation.dart';

import '../models/home_model.dart';
import '../models/home_view_model.dart';
import '../models/info_corner_model.dart';

/// Reuses the foundation's ChangeNotifier pattern (BrandingState); no UI change.
class HomeDataState extends ChangeNotifier {
  static final HomeDataState instance = HomeDataState();
  HomeModel? _home;
  HomeModel? get home => _home;
  String? _locationId;
  int _locationEpoch = 0;
  int activateLocation(String? id) {
    if (_locationId != id) {
      _locationId = id;
      _locationEpoch++;
      if (_home?.liveModules != null) {
        _home = _home!.withLiveModules(_home!.liveModules!.forLocation(id));
        notifyListeners();
      }
    }
    return _locationEpoch;
  }

  bool isActiveLocation(String? id, int epoch) =>
      _locationId == id && _locationEpoch == epoch;
  InfoCornerModel? get infoCorner => _home?.infoCorner;
  HomeViewModel? get viewModel =>
      _home == null ? null : HomeViewModel(home: _home!);
  void updateFromHome(HomeModel home) {
    if (_home == home) return;
    _home = home;
    notifyListeners();
  }
}
