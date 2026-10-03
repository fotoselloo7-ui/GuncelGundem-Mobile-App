/// İçerik Erişilebilirlik Durumu
///
/// Admin panelinden silinen, arşive alınan veya yayından kaldırılan haberlerin
/// istemci tarafında güvenli ve kontrollü şekilde ele alınmasını sağlar.
enum ContentAvailability {
  /// İçerik yayında ve erişilebilir
  available,

  /// İçerik silinmiş, arşive kaldırılmış veya 404 dönmüş
  unavailable,

  /// Ağ bağlantısı yok; çevrimdışı önbellekten sunuluyor
  cachedOffline,
}
