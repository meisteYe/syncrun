import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart'; // YENİ: İzin paketi eklendi
import 'dart:io';

class HealthService {
  final Health _health = Health();

  // Telefonun sağlık servisine (Google Fit / Apple Health) bağlanma izni ister
  Future<bool> requestPermissions() async {
    // İhtiyacımız olan veri tiplerini tanımlıyoruz
    final types = [
      HealthDataType.WORKOUT,
      HealthDataType.DISTANCE_WALKING_RUNNING,
      HealthDataType.ACTIVE_ENERGY_BURNED,
    ];

    // Bu verileri sadece "YAZMAK" istediğimizi belirtiyoruz (Okumak şimdilik gerekmiyor)
    final permissions = [
      HealthDataAccess.WRITE,
      HealthDataAccess.WRITE,
      HealthDataAccess.WRITE,
    ];

    try {
      // YENİ: Sağlık verilerine erişmeden önce cihazın "Fiziksel Aktivite" iznini garantiye alıyoruz
      if (Platform.isAndroid) {
        final activityStatus = await Permission.activityRecognition.status;
        if (activityStatus.isDenied) {
          await Permission.activityRecognition.request();
        }
      }

      // Android 14+ için Health Connect kontrolü
      if (Platform.isAndroid) {
        final hasPermissions = await _health.hasPermissions(
          types,
          permissions: permissions,
        );
        if (hasPermissions != null && hasPermissions) {
          return true;
        }
      }

      // Kullanıcıya ana sağlık (Health Connect/HealthKit) izin ekranını göster
      bool requested = await _health.requestAuthorization(
        types,
        permissions: permissions,
      );
      return requested;
    } catch (e) {
      return false;
    }
  }

  // Antrenmanı Telefona Kaydet
  Future<bool> saveWorkout({
    required DateTime startTime,
    required DateTime endTime,
    required double distanceMeters,
    required String activityType, // 'running', 'walking', 'fitness'
  }) async {
    try {
      // Önce izinleri kontrol et
      bool hasPermission = await requestPermissions();
      if (!hasPermission) return false;

      // Uygulamamızdaki tipleri, sistemin anladığı tiplere (Enum) çeviriyoruz
      HealthWorkoutActivityType workoutType = HealthWorkoutActivityType.RUNNING;
      if (activityType == 'walking') {
        workoutType = HealthWorkoutActivityType.WALKING;
      } else if (activityType == 'fitness') {
        workoutType = HealthWorkoutActivityType.CROSS_TRAINING;
      }

      // Kalori Hesabı (Ortalama ve çok basit bir formül: 1 km'de kilosu kadar kalori yakar)
      // Şimdilik ortalama 70 kg bir insan üzerinden hesaplıyoruz.
      // (Bunu ileride profil sayfasından çekebiliriz)
      double caloriesBurned = (distanceMeters / 1000.0) * 70.0;

      // Antrenmanı sisteme kaydet
      bool success = await _health.writeWorkoutData(
        activityType: workoutType,
        start: startTime,
        end: endTime,
        totalDistance: (distanceMeters / 1000.0).toInt(),
        totalEnergyBurned: caloriesBurned.toInt(),
        totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
        totalDistanceUnit: HealthDataUnit.METER,
      );

      return success;
    } catch (e) {
      return false;
    }
  }
}
