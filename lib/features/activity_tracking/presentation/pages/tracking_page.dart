import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_tts/flutter_tts.dart';
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

  void _startCountdown(BuildContext parentContext) {
    int countdown = 3;
    Timer? timer;
    bool gpsStarted = false;

    showDialog(
      context: parentContext,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
              if (countdown > 1) {
                setState(() => countdown--);
              } else {
                t.cancel();
                setState(() => countdown = 0);

                if (!gpsStarted) {
                  parentContext.read<ActivityBloc>().add(StartActivity());
                  gpsStarted = true;
                }

                Future.delayed(const Duration(milliseconds: 400), () {
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                });
              }
            });

            return Material(
              color: Colors.transparent,
              child: Center(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(countdown),
                  tween: Tween<double>(begin: 0.5, end: 1.0),
                  duration: const Duration(milliseconds: 400),
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
    ).then((_) => timer?.cancel());
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SyncRun Fit'),
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

      // YENİ: GHOST RUNNER DİNLEYİCİSİ (Geçmişten gelindiğinde otomatik tetikler)
      body: BlocListener<GhostRunnerCubit, GhostRunnerState>(
        listenWhen: (previous, current) =>
            !previous.isActive && current.isActive,
        listener: (context, state) {
          final activityState = context.read<ActivityBloc>().state;
          if (activityState is ActivityInitial ||
              activityState is ActivityCompleted) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (context.mounted) {
                _startCountdown(context);
              }
            });
          }
        },
        child: BlocBuilder<ActivityBloc, ActivityState>(
          builder: (context, state) {
            if (state is ActivityInitial) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.satellite_alt,
                      size: 48,
                      color: Colors.grey[700],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "GPS Bağlantısı Bekleniyor...\nBaşlamak için 'Başla' butonuna basın.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              );
            }

            if (state is ActivityTracking || state is ActivityPaused) {
              List<LatLng> currentRoute = [];
              double currentDist = 0.0;
              bool isPaused = state is ActivityPaused;

              if (state is ActivityTracking) {
                currentRoute = state.routePoints;
                currentDist = state.currentDistance;
              } else if (state is ActivityPaused) {
                currentRoute = state.routePoints;
                currentDist = state.currentDistance;
              }

              final currentPoint = currentRoute.last;

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
                            'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                        userAgentPackageName: 'com.syncrun.app',
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: currentRoute,
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
                          if (snapshot.hasData &&
                              snapshot.data!.data() != null) {
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

                          return BlocBuilder<
                            GhostRunnerCubit,
                            GhostRunnerState
                          >(
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

                  if (isPaused)
                    Container(
                      color: Colors.black.withOpacity(0.3),
                      width: double.infinity,
                      height: double.infinity,
                    ),

                  Positioned(
                    top: 100,
                    left: 16,
                    right: 16,
                    child: BlocBuilder<GhostRunnerCubit, GhostRunnerState>(
                      builder: (context, ghostState) {
                        return LiveRunHUD(
                          distanceMeters: currentDist,
                          isTracking: true,
                          isPaused: isPaused,
                          userPosition: currentPoint,
                          ghostPosition: ghostState.isActive
                              ? ghostState.ghostPosition
                              : null,
                        );
                      },
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
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('GPS Kapalı!')),
                        );
                      return;
                    }

                    LocationPermission permission =
                        await Geolocator.checkPermission();
                    if (permission == LocationPermission.denied) {
                      permission = await Geolocator.requestPermission();
                      if (permission == LocationPermission.denied) return;
                    }

                    if (context.mounted) _startCountdown(context);
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
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'pause_btn',
                  onPressed: () =>
                      context.read<ActivityBloc>().add(PauseActivity()),
                  backgroundColor: Colors.amberAccent,
                  icon: const Icon(Icons.pause, color: Colors.black),
                  label: const Text(
                    'Durdur',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                FloatingActionButton.extended(
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
                ),
              ],
            );
          } else if (state is ActivityPaused) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'resume_btn',
                  onPressed: () =>
                      context.read<ActivityBloc>().add(ResumeActivity()),
                  backgroundColor: const Color(0xFF00E676),
                  icon: const Icon(Icons.play_arrow, color: Colors.black),
                  label: const Text(
                    'Devam Et',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                FloatingActionButton.extended(
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
                ),
              ],
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
                  if (context.mounted)
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
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

// ---------------------------------------------------------
// HUD VE SESLİ KOÇ (VOICE ASSISTANT) ENTEGRASYONU
// ---------------------------------------------------------
class LiveRunHUD extends StatefulWidget {
  final double distanceMeters;
  final bool isTracking;
  final bool isPaused;
  final LatLng? userPosition;
  final LatLng? ghostPosition;

  const LiveRunHUD({
    super.key,
    required this.distanceMeters,
    required this.isTracking,
    this.isPaused = false,
    this.userPosition,
    this.ghostPosition,
  });

  @override
  State<LiveRunHUD> createState() => _LiveRunHUDState();
}

class _LiveRunHUDState extends State<LiveRunHUD> {
  Timer? _timer;
  int _elapsedSeconds = 0;

  final FlutterTts _flutterTts = FlutterTts();
  int _lastSpokenKm = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isTracking && !widget.isPaused) {
      _startTimer();
    }
    _setupVoiceAndSpeak();
  }

  Future<void> _setupVoiceAndSpeak() async {
    try {
      await _flutterTts.setLanguage("tr-TR");
      await _flutterTts.setSpeechRate(0.55);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.1);
      await _flutterTts.awaitSpeakCompletion(true);

      if (widget.isTracking && mounted && !widget.isPaused) {
        var result = await _flutterTts.speak(
          "Antrenman başladı. Başarılar Emir!",
        );
        if (result == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ses motoru tetiklendi ama ses veremedi.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('TTS Hatası: $e')));
    }
  }

  @override
  void didUpdateWidget(LiveRunHUD oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isPaused && !oldWidget.isPaused) {
      _timer?.cancel();
    } else if (!widget.isPaused && oldWidget.isPaused) {
      _startTimer();
    } else if (widget.isTracking && !oldWidget.isTracking) {
      _startTimer();
    } else if (!widget.isTracking && oldWidget.isTracking) {
      _timer?.cancel();
    }

    if (widget.isTracking && !widget.isPaused) {
      int currentKm = (widget.distanceMeters / 1000).floor();
      if (currentKm > _lastSpokenKm && currentKm > 0) {
        _lastSpokenKm = currentKm;
        _speakMilestone(currentKm);
      }
    }
  }

  Future<void> _speakMilestone(int km) async {
    double distanceKm = widget.distanceMeters / 1000.0;
    double minutes = _elapsedSeconds / 60.0;
    double pace = minutes / distanceKm;

    int paceMins = pace.floor();
    int paceSecs = ((pace - paceMins) * 60).round();

    String text =
        "Harika gidiyorsun. $km. kilometreyi tamamladın. Ortalama tempon $paceMins dakika, $paceSecs saniye.";

    if (widget.ghostPosition != null && widget.userPosition != null) {
      final gap = const Distance().as(
        LengthUnit.Meter,
        widget.userPosition!,
        widget.ghostPosition!,
      );
      text +=
          " Hayaletle arandaki fark yaklaşık ${gap.toInt()} metre. Tempoyu koru!";
    }

    await _flutterTts.speak(text);
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
    _flutterTts.stop();
    super.dispose();
  }

  String _formatTime(int seconds) {
    int h = seconds ~/ 3600;
    int m = (seconds % 3600) ~/ 60;
    int s = seconds % 60;
    if (h > 0)
      return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
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
            color: widget.isPaused
                ? Colors.amber.withOpacity(0.2)
                : Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTime(_elapsedSeconds),
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: widget.isPaused ? Colors.amberAccent : Colors.white,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                widget.isPaused ? 'DURAKLATILDI' : 'SÜRE',
                style: TextStyle(
                  color: widget.isPaused ? Colors.amberAccent : Colors.black,
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

              if (widget.ghostPosition != null &&
                  widget.userPosition != null) ...[
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    final gap = const Distance().as(
                      LengthUnit.Meter,
                      widget.userPosition!,
                      widget.ghostPosition!,
                    );
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepPurpleAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.deepPurpleAccent.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('👻', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text(
                            'Aralarındaki Fark: ${gap.toInt()} Metre',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
