import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/services/location_service.dart';
import '../../data/repositories/activity_repository.dart';
import 'activity_event.dart';
import 'activity_state.dart';

class ActivityBloc extends Bloc<ActivityEvent, ActivityState> {
  final LocationService _locationService;
  final ActivityRepository _activityRepository;

  StreamSubscription<Position>? _locationSubscription;
  DateTime? _startTime; // Antrenman başlangıç zamanı

  ActivityBloc(this._locationService, this._activityRepository)
    : super(ActivityInitial()) {
    on<StartActivity>(_onStartActivity);
    on<PauseActivity>(_onPauseActivity); // YENİ
    on<ResumeActivity>(_onResumeActivity); // YENİ
    on<LocationUpdated>(_onLocationUpdated);
    on<StopActivity>(_onStopActivity);
  }

  Future<void> _onStartActivity(
    StartActivity event,
    Emitter<ActivityState> emit,
  ) async {
    _startTime = DateTime.now();
    final initialPosition = await _locationService.getCurrentLocation();
    final startPoint = LatLng(
      initialPosition.latitude,
      initialPosition.longitude,
    );

    // currentDistance parametresini başlangıçta 0.0 olarak veriyoruz
    emit(ActivityTracking(routePoints: [startPoint], currentDistance: 0.0));

    _locationSubscription = _locationService.locationStream.listen((position) {
      add(LocationUpdated(position));
    });
  }

  // YENİ: DURAKLATMA MANTIĞI
  void _onPauseActivity(PauseActivity event, Emitter<ActivityState> emit) {
    if (state is ActivityTracking) {
      _locationSubscription?.pause(); // GPS Dinlemeyi Uyut
      final currentState = state as ActivityTracking;
      emit(
        ActivityPaused(
          routePoints: currentState.routePoints,
          currentDistance: currentState.currentDistance,
        ),
      );
    }
  }

  // YENİ: DEVAM ETME MANTIĞI
  void _onResumeActivity(ResumeActivity event, Emitter<ActivityState> emit) {
    if (state is ActivityPaused) {
      _locationSubscription?.resume(); // GPS Dinlemeyi Uyandır
      final currentState = state as ActivityPaused;
      emit(
        ActivityTracking(
          routePoints: currentState.routePoints,
          currentDistance: currentState.currentDistance,
        ),
      );
    }
  }

  void _onLocationUpdated(LocationUpdated event, Emitter<ActivityState> emit) {
    if (state is ActivityTracking) {
      final currentState = state as ActivityTracking;
      final position = event.newPosition;

      // 1. HASSASİYET FİLTRESİ: Doğruluk payı 20 metreden kötüyse (uydu tam kilitlenemediyse) yoksay
      if (position.accuracy > 20.0) return;

      final newPoint = LatLng(position.latitude, position.longitude);

      final distance = const Distance().as(
        LengthUnit.Meter,
        currentState.routePoints.last,
        newPoint,
      );

      // 2. MESAFE FİLTRESİ (GPS Zıplaması/Drift Engeli): Kullanıcı en az 3 metre hareket etmeden yeni noktayı çizme
      if (distance < 3.0) return;

      final updatedRoute = List<LatLng>.from(currentState.routePoints)
        ..add(newPoint);

      emit(
        ActivityTracking(
          routePoints: updatedRoute,
          currentDistance: currentState.currentDistance + distance,
        ),
      );
    }
  }

  Future<void> _onStopActivity(
    StopActivity event,
    Emitter<ActivityState> emit,
  ) async {
    // GPS dinlemeyi hemen durdur
    _locationSubscription?.cancel();

    // Hem takipteyken hem de duraklatılmışken bitirebilmek için kontrol
    if (state is ActivityTracking || state is ActivityPaused) {
      double finalDistance = 0.0;
      List<LatLng> finalRoute = [];

      if (state is ActivityTracking) {
        finalDistance = (state as ActivityTracking).currentDistance;
        finalRoute = (state as ActivityTracking).routePoints;
      } else if (state is ActivityPaused) {
        finalDistance = (state as ActivityPaused).currentDistance;
        finalRoute = (state as ActivityPaused).routePoints;
      }

      final endTime = DateTime.now();

      try {
        // Firebase Firestore'a kaydetmeyi dene
        await _activityRepository.saveActivity(
          routePoints: finalRoute,
          totalDistance: finalDistance,
          startTime: _startTime ?? endTime,
          endTime: endTime,
        );

        // Başarılı olursa bitiş ekranı state'ine geç
        emit(ActivityCompleted(finalDistance));
      } catch (e) {
        // Hata durumunda konsola log basıyoruz.
        print("Firebase kayıt hatası: $e");

        // CRITICAL FIX: Firebase yazma izni (Permission) hatası alsa bile arayüzü asılı bırakmıyoruz.
        emit(ActivityCompleted(finalDistance));
      }
    }
  }

  @override
  Future<void> close() {
    _locationSubscription?.cancel();
    return super.close();
  }
}
