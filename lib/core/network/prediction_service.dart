import 'package:dio/dio.dart';

class PredictionService {
  final Dio _dio = Dio();

  // Render'dan aldığın kendi canlı URL'ni buraya yapıştır
  // Sonunda slash (/) OLMASIN! Örn: https://syncrun-api-xxxx.onrender.com
  final String baseUrl = "https://syncrun-api.onrender.com";

  Future<Map<String, dynamic>> getPacePrediction(
    double distanceInMeters,
  ) async {
    final now = DateTime.now();

    // Dart'ta DateTime.weekday 1 (Pzt) ile 7 (Paz) arasıdır.
    // Python'daki (0-6) formatına uydurmak için 1 çıkartıyoruz.
    final dayOfWeek = now.weekday - 1;
    final hourOfDay = now.hour;

    try {
      final response = await _dio.post(
        '$baseUrl/predict_pace/',
        data: {
          "total_distance": distanceInMeters,
          "day_of_week": dayOfWeek,
          "hour_of_day": hourOfDay,
        },
      );

      return response
          .data; // { "predicted_speed_m_s": X, "predicted_pace_per_km": Y }
    } catch (e) {
      throw Exception("Tahmin alınırken bir hata oluştu: $e");
    }
  }
}
