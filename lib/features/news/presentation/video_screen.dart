import 'package:flutter/material.dart';

import '../../../app/bottom_nav_preferences.dart';
import '../../../design/branding_state.dart';
import '../../home/presentation/home_widgets.dart';
import 'news_navigation.dart';

class VideoScreen extends StatelessWidget {
  const VideoScreen({super.key});
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
          selected: BottomNavPreferences.instance.indexOf(NavDestination.video),
          onSelect: (i) => NewsNavigation.handleBottom(context, i),
        ),
        body: const SafeArea(
          top: false,
          bottom: false,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_circle_outline_rounded,
                    size: 58,
                    color: homeNavy,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Henüz video haberi bulunmuyor',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: homeNavy,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Video haberleri yayınlandıkça burada izleyebilirsiniz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: homeMuted, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
