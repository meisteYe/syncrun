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

    emit(ActivityTracking(routePoints: [startPoint]));

    _locationSubscription = _locationService.locationStream.listen((position) {
      add(LocationUpdated(position));
    });
  }

  void _onLocationUpdated(LocationUpdated event, Emitter<ActivityState> emit) {
    if (state is ActivityTracking) {
      final currentState = state as ActivityTracking;
      final newPoint = LatLng(
        event.newPosition.latitude,
        event.newPosition.longitude,
      );

      final distance = const Distance().as(
        LengthUnit.Meter,
        currentState.routePoints.last,
        newPoint,
      );

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

    if (state is ActivityTracking) {
      final currentState = state as ActivityTracking;
      final endTime = DateTime.now();

      try {
        // Firebase Firestore'a kaydetmeyi dene
        await _activityRepository.saveActivity(
          routePoints: currentState.routePoints,
          totalDistance: currentState.currentDistance,
          startTime: _startTime ?? endTime,
          endTime: endTime,
        );

        // Başarılı olursa bitiş ekranı state'ine geç
        emit(ActivityCompleted(currentState.currentDistance));
      } catch (e) {
        // Hata durumunda konsola log basıyoruz.
        print("Firebase kayıt hatası: $e");

        // CRITICAL FIX: Firebase yazma izni (Permission) hatası alsa bile
        // arayüzü "Takip Ediliyor" (ActivityTracking) state'inde asılı bırakmıyoruz.
        // Antrenmanı yerel olarak bitirip tamamlanmış sayıyoruz.
        emit(ActivityCompleted(currentState.currentDistance));
      }
    }
  }

  @override
  Future<void> close() {
    _locationSubscription?.cancel();
    return super.close();
  }
}
