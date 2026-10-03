import 'package:connectivity_plus/connectivity_plus.dart';

/// Ağ bağlantı durumunu izleyen servis
class NetworkInfo {
  final Connectivity _connectivity;

  NetworkInfo({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  /// Cihazın internete bağlı olup olmadığını kontrol eder
  Future<bool> get isConnected async {
    final result = await _connectivity.checkConnectivity();
    if (result.contains(ConnectivityResult.none) && result.length == 1) {
      return false;
    }
    return true;
  }

  /// Bağlantı değişikliklerini yayınlar
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;
}
