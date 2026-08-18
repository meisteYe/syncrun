import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:ui';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../injection_container.dart';
import '../../data/repositories/activity_repository.dart';
import '../../../ghost_run/ghost_runner_cubit.dart';
import 'main_page.dart';

class ActivityDetailPage extends StatelessWidget {
  final String activityId;
  final Map<String, dynamic> summaryData;

  final ScreenshotController _screenshotController = ScreenshotController();

  ActivityDetailPage({
    super.key,
    required this.activityId,
    required this.summaryData,
  });

  Future<Map<String, dynamic>> _fetchActivityData(String activityId) async {
    final snap = await FirebaseFirestore.instance
        .collection('activities')
        .doc(activityId)
        .collection('telemetry')
        .orderBy('timeOffset')
        .get();

    List<LatLng> route = [];
    List<FlSpot> spots = [];

    double totalDistance = 0;
    LatLng? lastPos;
    int? lastTime;
    List<double> recentPaces = [];

    double lastSpotX = -1.0;

    for (var doc in snap.docs) {
      final data = doc.data();
      final currentPos = LatLng(data['lat'], data['lng']);
      final currentTime = data['timeOffset'] as int;

      route.add(currentPos);

      if (lastPos != null && lastTime != null) {
        final dist = const Distance().as(LengthUnit.Meter, lastPos, currentPos);
        final timeDiff = currentTime - lastTime;

        if (dist > 0 && timeDiff > 0) {
          totalDistance += dist;
          double secondsDiff = timeDiff > 1000
              ? timeDiff / 1000.0
              : timeDiff.toDouble();
          double pace = (secondsDiff / 60.0) / (dist / 1000.0);

          if (pace > 2.0 && pace < 15.0) {
            recentPaces.add(pace);
            if (recentPaces.length > 5) recentPaces.removeAt(0);

            double avgPace =
                recentPaces.reduce((a, b) => a + b) / recentPaces.length;
            double spotX = totalDistance / 1000.0;

            if (spotX > lastSpotX + 0.05) {
              spots.add(FlSpot(spotX, avgPace));
              lastSpotX = spotX;
            }
          }
        }
      }
      lastPos = currentPos;
      lastTime = currentTime;
    }

    return {'route': route, 'spots': spots};
  }

  Future<void> _takeScreenshotAndShare(
    BuildContext context,
    double distance,
    int durationInSeconds,
    String paceStr,
    List<LatLng> routePoints,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF00E676)),
      ),
    );

    try {
      final stickerWidget = Directionality(
        textDirection: TextDirection.ltr,
        child: DefaultTextStyle(
          style: const TextStyle(decoration: TextDecoration.none),
          child: _buildShareSticker(
            distance / 1000.0,
            durationInSeconds,
            paceStr,
            routePoints,
          ),
        ),
      );

      final Uint8List imageBytes = await _screenshotController
          .captureFromWidget(
            stickerWidget,
            delay: const Duration(milliseconds: 200),
            pixelRatio: 4.0,
            context: context,
          );

      if (context.mounted) Navigator.pop(context);

      final directory = Directory.systemTemp;
      final imagePath = await File(
        '${directory.path}/syncrun_sticker.png',
      ).create();
      await imagePath.writeAsBytes(imageBytes);

      await Share.shareXFiles([
        XFile(imagePath.path),
      ], text: 'SyncRun Fit ile harika bir koşu! 🏃‍♂️🔥');
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Paylaşım Hatası: $e')));
    }
  }

  Widget _buildShareSticker(
    double distKm,
    int durationSecs,
    String paceStr,
    List<LatLng> points,
  ) {
    int h = durationSecs ~/ 3600;
    int m = (durationSecs % 3600) ~/ 60;
    int s = durationSecs % 60;
    String timeStr = h > 0 ? "${h}h ${m}m ${s}s" : "${m}m ${s}s";

    return Container(
      width: 400,
      height: 700,
      color: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildStickerStat('Distance', '${distKm.toStringAsFixed(2)} km'),
          const SizedBox(height: 24),
          _buildStickerStat('Pace', '$paceStr /km'),
          const SizedBox(height: 24),
          _buildStickerStat('Time', timeStr),
          const SizedBox(height: 48),

          if (points.isNotEmpty)
            SizedBox(
              width: 250,
              height: 250,
              child: CustomPaint(
                painter: RoutePainter(points, const Color(0xFF00E676)),
              ),
            ),
          const SizedBox(height: 40),

          const Text(
            'SYNCRUN',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 10.0,
              shadows: [
                Shadow(
                  color: Colors.black45,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerStat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black45,
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 48,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(
                color: Colors.black45,
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }

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
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bu koşunun GPS verisi bulunamadı!')),
          );
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
        globalPageIndex.value = 1;
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
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
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
        paceStr = "$paceMinutes'${paceSeconds.toString().padLeft(2, '0')}";
      }
    }

    final startTime = DateTime.parse(startTimeStr!).toLocal();
    final dateStr =
        "${startTime.day.toString().padLeft(2, '0')}.${startTime.month.toString().padLeft(2, '0')}.${startTime.year}";

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text('$dateStr Koşusu'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchActivityData(activityId),
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

          final routePoints = (snapshot.data?['route'] as List<LatLng>?) ?? [];
          final spots = (snapshot.data?['spots'] as List<FlSpot>?) ?? [];

          if (routePoints.isEmpty) {
            return const Center(
              child: Text(
                'Bu antrenman için rota verisi bulunamadı.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          LatLngBounds bounds = LatLngBounds.fromPoints(routePoints);

          // KRİTİK DÜZELTME: EĞER KOŞU NOKTASI 0 METRE İSE (ZERO-AREA BOUNDS KORUMASI)
          if (bounds.southWest.latitude == bounds.northEast.latitude &&
              bounds.southWest.longitude == bounds.northEast.longitude) {
            final p = routePoints.first;
            bounds = LatLngBounds(
              LatLng(p.latitude - 0.005, p.longitude - 0.005),
              LatLng(p.latitude + 0.005, p.longitude + 0.005),
            );
          }

          return Column(
            children: [
              // Üst Kısım: Harita Alanı
              SizedBox(
                height: 300,
                child: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCameraFit: CameraFit.bounds(
                          bounds: bounds,
                          padding: const EdgeInsets.all(50.0),
                        ),
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                          userAgentPackageName: 'com.syncrun.app',
                        ),
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: routePoints,
                              strokeWidth: 6.0,
                              color: const Color(0xFFFF5252),
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
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 2,
                                  ),
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
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.ios_share,
                            color: Color(0xFF00E676),
                          ),
                          tooltip: 'Instagram İçin Paylaş',
                          onPressed: () => _takeScreenshotAndShare(
                            context,
                            distance,
                            durationInSeconds,
                            paceStr,
                            routePoints,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. DETAYLAR VE GRAFİK EKRANI
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // İSTATİSTİK KARTI
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 24,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildAppHudStat(
                              'MESAFE',
                              '${(distance / 1000).toStringAsFixed(2)} km',
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.white.withOpacity(0.2),
                            ),
                            _buildAppHudStat(
                              'SÜRE',
                              '${(durationInSeconds / 60).toStringAsFixed(1)} dk',
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.white.withOpacity(0.2),
                            ),
                            _buildAppHudStat('TEMPO', paceStr),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // TEMPO GRAFİĞİ BAŞLIĞI
                      const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Text(
                          'TEMPO ANALİZİ (dk/km)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // YENİ: TEMPO (PACE) GRAFİĞİ ÇİZİM ALANI
                      spots.length < 2
                          ? const SizedBox(
                              height: 200,
                              child: Center(
                                child: Text(
                                  'Grafik için yeterli GPS verisi yok.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          : Container(
                              height: 250,
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                24,
                                24,
                                16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: LineChart(
                                LineChartData(
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    getDrawingHorizontalLine: (value) => FlLine(
                                      color: Colors.white.withOpacity(0.1),
                                      strokeWidth: 1,
                                    ),
                                  ),
                                  titlesData: FlTitlesData(
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 22,
                                        getTitlesWidget: (value, meta) =>
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8.0,
                                              ),
                                              child: Text(
                                                '${value.toStringAsFixed(1)}k',
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 32,
                                        getTitlesWidget: (value, meta) => Text(
                                          '${value.toInt()}:00',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ),
                                    topTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    rightTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: spots,
                                      isCurved: true,
                                      curveSmoothness: 0.35,
                                      color: const Color(0xFF00E676),
                                      barWidth: 3,
                                      isStrokeCapRound: true,
                                      dotData: const FlDotData(show: false),
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: const Color(
                                          0xFF00E676,
                                        ).withOpacity(0.2),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // 3. YARIŞ BUTONU PANELİ
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                decoration: BoxDecoration(
                  color: Colors.black,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.sports_score, color: Colors.white),
                    label: const Text(
                      'Bu Koşuyla Yarış',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    onPressed: () => _loadGhostRun(context, activityId),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppHudStat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

class RoutePainter extends CustomPainter {
  final List<LatLng> points;
  final Color color;

  RoutePainter(this.points, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    double latRange = maxLat - minLat;
    double lngRange = maxLng - minLng;

    if (latRange == 0) latRange = 0.0001;
    if (lngRange == 0) lngRange = 0.0001;

    double padding = 20.0;
    double scale = (size.width - padding * 2) / lngRange;
    if ((size.height - padding * 2) / latRange < scale) {
      scale = (size.height - padding * 2) / latRange;
    }

    double scaledWidth = lngRange * scale;
    double scaledHeight = latRange * scale;
    double offsetX = (size.width - scaledWidth) / 2;
    double offsetY = (size.height - scaledHeight) / 2;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 10.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..strokeWidth = 14.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final x = offsetX + (p.longitude - minLng) * scale;
      final y = offsetY + (maxLat - p.latitude) * scale;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
