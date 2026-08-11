import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart'; // KONUM İZİNLERİ İÇİN EKLENDİ
import '../bloc/activity_bloc.dart';
import '../bloc/activity_event.dart';
import '../bloc/activity_state.dart';
import 'history_page.dart';
import '../../../../core/network/prediction_service.dart';
import '../../../../injection_container.dart';

import '../../../ghost_run/ghost_runner_cubit.dart';

class TrackingPage extends StatelessWidget {
  const TrackingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SyncRun Takip'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            tooltip: 'Geçmiş Antrenmanlar',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryPage()),
              );
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: BlocBuilder<ActivityBloc, ActivityState>(
        builder: (context, state) {
          if (state is ActivityInitial) {
            return const Center(
              child: Text("Başlamak için 'Başla' butonuna basın."),
            );
          }

          if (state is ActivityTracking) {
            final currentPoint = state.routePoints.last;

            return Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: currentPoint,
                    initialZoom: 17.0,
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
                          points: state.routePoints,
                          strokeWidth: 5.0,
                          color: const Color(0xFF00E676),
                        ),
                      ],
                    ),
                    BlocBuilder<GhostRunnerCubit, GhostRunnerState>(
                      builder: (context, ghostState) {
                        final markers = <Marker>[
                          Marker(
                            point: currentPoint,
                            width: 20,
                            height: 20,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blueAccent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ];

                        if (ghostState.isActive &&
                            ghostState.ghostPosition != null) {
                          markers.add(
                            Marker(
                              point: ghostState.ghostPosition!,
                              width: 20,
                              height: 20,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.8),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white54,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        return MarkerLayer(markers: markers);
                      },
                    ),
                  ],
                ),
                Positioned(
                  top: 100,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Mesafe: ${state.currentDistance.toStringAsFixed(1)} m',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            );
          }

          if (state is ActivityCompleted) {
            return Center(
              child: Text(
                'Antrenman Bitti!\nToplam: ${state.totalDistance.toStringAsFixed(1)} metre',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24),
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: BlocBuilder<ActivityBloc, ActivityState>(
        builder: (context, state) {
          if (state is ActivityInitial || state is ActivityCompleted) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'ai_btn',
                  onPressed: () => _showPredictionDialog(context),
                  backgroundColor: Colors.deepPurpleAccent,
                  icon: const Icon(Icons.auto_awesome, color: Colors.white),
                  label: const Text(
                    'Akıllı Tahmin',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                // GÜVENLİ BAŞLA BUTONU (İzin ve GPS Kontrolü Ekli)
                FloatingActionButton.extended(
                  heroTag: 'start_btn',
                  onPressed: () async {
                    // 1. Cihazın GPS servisi açık mı?
                    bool serviceEnabled =
                        await Geolocator.isLocationServiceEnabled();
                    if (!serviceEnabled) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Lütfen telefonun konumunu (GPS) açın!',
                            ),
                          ),
                        );
                      }
                      return;
                    }

                    // 2. Uygulamaya izin verilmiş mi?
                    LocationPermission permission =
                        await Geolocator.checkPermission();
                    if (permission == LocationPermission.denied) {
                      permission = await Geolocator.requestPermission();
                      if (permission == LocationPermission.denied) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Konum izni verilmedi.'),
                            ),
                          );
                        }
                        return;
                      }
                    }

                    if (permission == LocationPermission.deniedForever) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Konum izinleri kalıcı olarak reddedilmiş. Ayarlardan açmalısınız.',
                            ),
                          ),
                        );
                      }
                      return;
                    }

                    // İzinler tamamsa antrenmanı başlat
                    if (context.mounted) {
                      context.read<ActivityBloc>().add(StartActivity());
                    }
                  },
                  backgroundColor: const Color(0xFF00E676),
                  icon: const Icon(Icons.play_arrow, color: Colors.black),
                  label: const Text(
                    'Başla',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            );
          } else if (state is ActivityTracking) {
            return FloatingActionButton.extended(
              heroTag: 'stop_btn',
              onPressed: () {
                context.read<ActivityBloc>().add(StopActivity());
                context.read<GhostRunnerCubit>().stopGhostRun();
              },
              backgroundColor: Colors.redAccent,
              icon: const Icon(Icons.stop),
              label: const Text('Bitir'),
            );
          }
          return const SizedBox.shrink();
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void _showPredictionDialog(BuildContext context) {
    final TextEditingController distanceController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Hedef Mesafeni Gir (Metre)',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: distanceController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Örn: 5000 (5km için)',
              hintStyle: const TextStyle(color: Colors.grey),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[700]!),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF00E676)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('İptal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
              ),
              onPressed: () async {
                final distanceText = distanceController.text.trim();
                if (distanceText.isEmpty) return;

                final distance = double.tryParse(distanceText);
                if (distance == null) return;

                Navigator.pop(dialogContext);

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00E676)),
                  ),
                );

                try {
                  final prediction = await sl<PredictionService>()
                      .getPacePrediction(distance);

                  if (context.mounted) Navigator.pop(context);

                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: Colors.grey[900],
                        title: const Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: Colors.deepPurpleAccent,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Tahmin Sonucu',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                        content: Text(
                          'Mevcut formuna ve günün bu saatine göre tahmini tempon:\n\n'
                          '${prediction['predicted_pace_per_km']} dk/km',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Tamam',
                              style: TextStyle(color: Color(0xFF00E676)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
              child: const Text(
                'Tahmin Al',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        );
      },
    );
  }
}
