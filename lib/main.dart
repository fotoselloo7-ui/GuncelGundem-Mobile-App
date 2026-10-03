import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_startup.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final startupCoordinator = AppStartupCoordinator();

  runApp(GuncelGundemApp(startupCoordinator: startupCoordinator));
}
