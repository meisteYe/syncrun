import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:ui';
import '../../../../injection_container.dart';
import '../../data/repositories/activity_repository.dart';
import '../../../ghost_run/ghost_runner_cubit.dart';
import 'main_page.dart'; // YENİ EKLENDİ: Global kumandaya erişmek için

class ActivityDetailPage extends StatelessWidget {
  final String activityId;
  final Map<String, dynamic> summaryData;

  const ActivityDetailPage({
    super.key,
    required this.activityId,
    required this.summaryData,
  });

  Future<void> _loadGhostRun(BuildContext context, String activityId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
      ),
    );

    try {
      final telemetrySnapshot = await FirebaseFirestore.instance
          .collection('activities')
          .doc(activityId)
          .collection('telemetry')
          .orderBy('timeOffset')
          .get();

      if (context.mounted) Navigator.pop(context);

      if (telemetrySnapshot.docs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bu koşunun GPS verisi bulunamadı!')),
          );
        }
        return;
      }

      final ghostPath = telemetrySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'lat': data['lat'],
          'lng': data['lng'],
          'timeOffset': data['timeOffset'],
        };
      }).toList();

      if (context.mounted) {
        context.read<GhostRunnerCubit>().startGhostRun(ghostPath);

        // YENİ DÜZELTME: ALT MENÜYÜ HARİTAYA (INDEX 1) ZORLA!
        globalPageIndex.value = 1;

        // Tüm pencereleri kapatıp ana haritaya dön
        Navigator.of(context).popUntil((route) => route.isFirst);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hayalet rotası yüklendi! Yarış başlıyor...'),
            backgroundColor: Colors.deepPurpleAccent,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final distance = summaryData['totalDistance'] as double;
    final startTimeStr = summaryData['startTime'] as String?;
    final endTimeStr = summaryData['endTime'] as String?;

    int durationInSeconds = 0;
    if (startTimeStr != null && endTimeStr != null) {
      try {
        final start = DateTime.parse(startTimeStr);
        final end = DateTime.parse(endTimeStr);
        durationInSeconds = end.difference(start).inSeconds;
      } catch (_) {}
    }

    String paceStr = "--:--";
    if (distance > 15 && durationInSeconds > 0) {
      double distanceKm = distance / 1000.0;
      double minutes = durationInSeconds / 60.0;
      double pace = minutes / distanceKm;

      if (pace <= 30) {
        int paceMinutes = pace.floor();
        int paceSeconds = ((pace - paceMinutes) * 60).round();
        paceStr = "$paceMinutes'${paceSeconds.toString().padLeft(2, '0')}\"";
      }
    }

    final startTime = DateTime.parse(startTimeStr!).toLocal();
    final dateStr =
        "${startTime.day.toString().padLeft(2, '0')}.${startTime.month.toString().padLeft(2, '0')}.${startTime.year}";

    return Scaffold(
      appBar: AppBar(
        title: Text('$dateStr Koşusu'),
        backgroundColor: Colors.grey[900],
        elevation: 0,
      ),
      body: FutureBuilder<List<LatLng>>(
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

          final bounds = LatLngBounds.fromPoints(routePoints);

          return Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCameraFit: CameraFit.bounds(
                    bounds: bounds,
                    padding: const EdgeInsets.all(50.0),
                  ),
                  maxZoom: 18.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}', // Google Maps
                    userAgentPackageName: 'com.syncrun.app',
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routePoints,
                        strokeWidth: 5.0,
                        color: Colors.redAccent,
                      ),
                    ],
                  ),
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

              Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.15),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildHudStat(
                                'Mesafe',
                                '${distance.toStringAsFixed(1)} m',
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.white.withOpacity(0.2),
                              ),
                              _buildHudStat(
                                'Süre',
                                '${(durationInSeconds / 60).toStringAsFixed(1)} dk',
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.white.withOpacity(0.2),
                              ),
                              _buildHudStat('Tempo', paceStr),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurpleAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(
                          Icons.sports_score,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Bu Koşuyla Yarış',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () => _loadGhostRun(context, activityId),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHudStat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
