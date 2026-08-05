import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Kullanıcının anlık konumunu almadan önce izinleri kontrol eder.
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Cihazın konum servisi (GPS) açık mı?
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
        'Konum servisleri kapalı. Lütfen cihazınızın GPS\'ini açın.',
      );
    }

    // 2. Uygulamaya izin verilmiş mi?
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Konum izni reddedildi. Rota takibi yapılamaz.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Konum izinleri kalıcı olarak reddedilmiş. Lütfen ayarlardan manuel olarak açın.',
      );
    }

    // 3. Her şey tamamsa, en yüksek hassasiyetle konumu al
    return await Geolocator.getCurrentPosition(
      desiredAccuracy:
          LocationAccuracy.high, // Yüksek doğrulukta (sporda önemlidir)
    );
  }

  /// Aktif GPS takibi için konum akışını (Stream) dinler.
  Stream<Position> get locationStream {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter:
            3, // Sadece cihaz 3 metre hareket ettiğinde yeni veri gönder (Pil tasarrufu)
      ),
    );
  }
}
