import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../bloc/activity_bloc.dart';
import '../bloc/activity_event.dart';
import '../bloc/activity_state.dart';

class TrackingPage extends StatelessWidget {
  const TrackingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SyncRun Takip'),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                  // YENİ API: center yerine initialCenter, zoom yerine initialZoom kullanılıyor
                  options: MapOptions(
                    initialCenter: currentPoint,
                    initialZoom: 17.0,
                    // YENİ API: interactionOptions kullanımı
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    // Koyu temalı (Dark Matter) harita
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.syncrun.app',
                    ),
                    // YENİ API: isDotted kaldırıldı, pattern (desen) eklendi
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: state.routePoints,
                          strokeWidth: 5.0,
                          color: const Color(0xFF00E676),
                          // pattern: const StrokePattern.solid(), // Gerekirse kesik çizgi için kullanılabilir
                        ),
                      ],
                    ),
                    // YENİ API: builder yerine child kullanılıyor
                    MarkerLayer(
                      markers: [
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
                              ), // Noktaya beyaz bir dış çizgi ekledim, daha şık durur
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Mesafe Göstergesi (HUD)
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
            return FloatingActionButton.extended(
              onPressed: () =>
                  context.read<ActivityBloc>().add(StartActivity()),
              backgroundColor: const Color(0xFF00E676),
              icon: const Icon(Icons.play_arrow, color: Colors.black),
              label: const Text('Başla', style: TextStyle(color: Colors.black)),
            );
          } else if (state is ActivityTracking) {
            return FloatingActionButton.extended(
              onPressed: () => context.read<ActivityBloc>().add(StopActivity()),
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
}
