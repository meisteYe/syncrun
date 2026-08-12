import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../bloc/activity_bloc.dart';
import '../bloc/activity_event.dart';
import '../bloc/activity_state.dart';
import 'history_page.dart';
import '../../../../core/network/prediction_service.dart';
import '../../../../injection_container.dart';
import 'dart:ui';
import '../../../ghost_run/ghost_runner_cubit.dart';

class TrackingPage extends StatelessWidget {
  const TrackingPage({super.key});

  // ---------------------------------------------------------
  // YENİ WIDGET: 3-2-1 GERİ SAYIM ANİMASYONU
  // ---------------------------------------------------------
  void _startCountdown(BuildContext parentContext) {
    int countdown = 3;
    Timer? timer;

    showDialog(
      context: parentContext,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.9), // Koyu mat arka plan
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Timer'ı sadece bir kez başlat
            timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
              if (countdown > 1) {
                setState(() => countdown--);
              } else if (countdown == 1) {
                setState(() => countdown = 0); // 0 olduğunda "BAŞLA!" yazacak
              } else {
                t.cancel();
                Navigator.pop(dialogContext); // Animasyonu kapat
                // GERÇEK GPS TAKİBİNİ BAŞLAT
                parentContext.read<ActivityBloc>().add(StartActivity());
              }
            });

            return Material(
              color: Colors.transparent,
              child: Center(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(countdown),
                  tween: Tween<double>(begin: 0.5, end: 1.0),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Text(
                        countdown > 0 ? '$countdown' : 'BAŞLA!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: countdown > 0 ? 150 : 80,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF00E676),
                          shadows: [
                            BoxShadow(
                              color: const Color(0xFF00E676).withOpacity(0.5),
                              blurRadius: 30,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    ).then((_) => timer?.cancel()); // Her ihtimale karşı timer'ı temizle
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
              child: Text(
                "Başlamak için 'Başla' butonuna basın.",
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          if (state is ActivityTracking) {
            final currentPoint = state.routePoints.last;

            return Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: currentPoint,
                    initialZoom: 17.5,
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
                          strokeWidth: 6.0,
                          color: const Color(0xFF00E676),
                        ),
                      ],
                    ),
                    StreamBuilder<DocumentSnapshot>(
                      stream: user != null
                          ? FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .snapshots()
                          : const Stream.empty(),
                      builder: (context, snapshot) {
                        String colorStr = 'grey';
                        if (snapshot.hasData && snapshot.data!.data() != null) {
                          final data =
                              snapshot.data!.data() as Map<String, dynamic>;
                          colorStr = data['ghostColor'] ?? 'grey';
                        }

                        Color ghostColor;
                        switch (colorStr) {
                          case 'purple':
                            ghostColor = Colors.deepPurpleAccent;
                            break;
                          case 'red':
                            ghostColor = Colors.redAccent;
                            break;
                          case 'yellow':
                            ghostColor = Colors.amberAccent;
                            break;
                          case 'grey':
                          default:
                            ghostColor = Colors.grey;
                            break;
                        }

                        return BlocBuilder<GhostRunnerCubit, GhostRunnerState>(
                          builder: (context, ghostState) {
                            final markers = <Marker>[
                              Marker(
                                point: currentPoint,
                                width: 22,
                                height: 22,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blueAccent.withOpacity(
                                          0.5,
                                        ),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ];

                            if (ghostState.isActive &&
                                ghostState.ghostPosition != null) {
                              markers.add(
                                Marker(
                                  point: ghostState.ghostPosition!,
                                  width: 22,
                                  height: 22,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: ghostColor.withOpacity(0.85),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white70,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: ghostColor.withOpacity(0.5),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }

                            return MarkerLayer(markers: markers);
                          },
                        );
                      },
                    ),
                  ],
                ),
                Positioned(
                  top: 100,
                  left: 16,
                  right: 16,
                  child: LiveRunHUD(
                    distanceMeters: state.currentDistance,
                    isTracking: true,
                  ),
                ),
              ],
            );
          }

          if (state is ActivityCompleted) {
            return Center(
              child: Text(
                'Antrenman Bitti!\nToplam: ${(state.totalDistance / 1000).toStringAsFixed(2)} km',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
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
                  backgroundColor: Colors.grey[850],
                  icon: const Icon(
                    Icons.auto_awesome,
                    color: Colors.deepPurpleAccent,
                  ),
                  label: const Text(
                    'Akıllı Tahmin',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                FloatingActionButton.extended(
                  heroTag: 'start_btn',
                  onPressed: () async {
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

                    // İZİNLER TAMAMSA DİREKT BAŞLAMAK YERİNE GERİ SAYIMI TETİKLE
                    if (context.mounted) {
                      _startCountdown(context);
                    }
                  },
                  backgroundColor: const Color(0xFF00E676),
                  icon: const Icon(Icons.play_arrow, color: Colors.black),
                  label: const Text(
                    'Başla',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
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
              icon: const Icon(Icons.stop, color: Colors.white),
              label: const Text(
                'Bitir',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
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
                  builder: (_) => AlertDialog(
                    backgroundColor: Colors.grey[900],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 16),
                        const CircularProgressIndicator(
                          color: Color(0xFF00E676),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Yapay Zeka Motoru Isıtılıyor...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Sunucu uyku modundan çıkarılıyor.\nBu işlem ilk seferde 1-2 dakika sürebilir, lütfen bekleyin.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
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
                          'Mevcut formuna ve günün bu saatine göre tahmini tempon:\n\n${prediction['predicted_pace_per_km']} dk/km',
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
                  if (context.mounted) Navigator.pop(context);
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

class LiveRunHUD extends StatefulWidget {
  final double distanceMeters;
  final bool isTracking;

  const LiveRunHUD({
    super.key,
    required this.distanceMeters,
    required this.isTracking,
  });

  @override
  State<LiveRunHUD> createState() => _LiveRunHUDState();
}

class _LiveRunHUDState extends State<LiveRunHUD> {
  Timer? _timer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isTracking) _startTimer();
  }

  @override
  void didUpdateWidget(LiveRunHUD oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTracking && !oldWidget.isTracking) {
      _startTimer();
    } else if (!widget.isTracking && oldWidget.isTracking) {
      _timer?.cancel();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    int h = seconds ~/ 3600;
    int m = (seconds % 3600) ~/ 60;
    int s = seconds % 60;
    if (h > 0) {
      return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
    }
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  String _calculatePace(double distanceMeters, int seconds) {
    if (distanceMeters < 15 || seconds == 0) return "--:--";
    double distanceKm = distanceMeters / 1000.0;
    double minutes = seconds / 60.0;
    double pace = minutes / distanceKm;

    if (pace > 30) return "--:--";

    int paceMinutes = pace.floor();
    int paceSeconds = ((pace - paceMinutes) * 60).round();
    return "$paceMinutes'${paceSeconds.toString().padLeft(2, '0')}\"";
  }

  @override
  Widget build(BuildContext context) {
    double distanceKm = widget.distanceMeters / 1000.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTime(_elapsedSeconds),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const Text(
                'SÜRE',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        distanceKm.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00E676),
                        ),
                      ),
                      const Text(
                        'KİLOMETRE',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.white.withOpacity(0.2),
                  ),
                  Column(
                    children: [
                      Text(
                        _calculatePace(widget.distanceMeters, _elapsedSeconds),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'ORT. TEMPO',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
