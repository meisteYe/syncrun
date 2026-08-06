import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../injection_container.dart';
import '../../data/repositories/activity_repository.dart';

class ActivityDetailPage extends StatelessWidget {
  final String activityId;
  final Map<String, dynamic> summaryData;

  const ActivityDetailPage({
    super.key,
    required this.activityId,
    required this.summaryData,
  });

  @override
  Widget build(BuildContext context) {
    final distance = summaryData['totalDistance'] as double;

    // Tarih formatlama
    final startTimeStr = summaryData['startTime'] as String;
    final startTime = DateTime.parse(startTimeStr).toLocal();
    final dateStr =
        "${startTime.day.toString().padLeft(2, '0')}.${startTime.month.toString().padLeft(2, '0')}.${startTime.year}";

    return Scaffold(
      appBar: AppBar(
        title: Text('$dateStr Koşusu'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: FutureBuilder<List<LatLng>>(
        // Repository üzerinden telemetry verilerini çekiyoruz
        future: sl<ActivityRepository>().getActivityRoute(activityId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Hata: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final routePoints = snapshot.data;

          if (routePoints == null || routePoints.isEmpty) {
            return const Center(
              child: Text(
                'Bu antrenman için rota verisi bulunamadı.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          // Rotanın haritaya tam sığması için sınırları (Bounds) hesaplıyoruz
          final bounds = LatLngBounds.fromPoints(routePoints);

          return Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  // Kamerayı rotanın tamamını görecek şekilde ayarlar
                  initialCameraFit: CameraFit.bounds(
                    bounds: bounds,
                    padding: const EdgeInsets.all(50.0),
                    // Kenarlardan biraz boşluk bırak
                  ),
                  maxZoom: 18.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.syncrun.app',
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routePoints,
                        strokeWidth: 5.0,
                        color: const Color(0xFF00E676),
                      ),
                    ],
                  ),
                  // Başlangıç Noktası (Yeşil)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: routePoints.first,
                        width: 15,
                        height: 15,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                        ),
                      ),
                      // Bitiş Noktası (Kırmızı)
                      Marker(
                        point: routePoints.last,
                        width: 15,
                        height: 15,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Alt kısımdaki özet bilgi paneli
              Positioned(
                bottom: 30,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[800]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Toplam Mesafe',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${distance.toStringAsFixed(1)} m',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      // İleride buraya Süre, Ortalama Hız vb. eklenebilir
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
