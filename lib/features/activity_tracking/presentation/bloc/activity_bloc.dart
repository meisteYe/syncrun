import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/services/location_service.dart';
import 'activity_event.dart';
import 'activity_state.dart';

class ActivityBloc extends Bloc<ActivityEvent, ActivityState> {
  final LocationService _locationService;
  StreamSubscription<Position>? _locationSubscription;

  ActivityBloc(this._locationService) : super(ActivityInitial()) {
    on<StartActivity>(_onStartActivity);
    on<LocationUpdated>(_onLocationUpdated);
    on<StopActivity>(_onStopActivity);
  }

  Future<void> _onStartActivity(
    StartActivity event,
    Emitter<ActivityState> emit,
  ) async {
    // Önce ilk konumu alıp haritanın merkezine koyuyoruz
    final initialPosition = await _locationService.getCurrentLocation();
    final startPoint = LatLng(
      initialPosition.latitude,
      initialPosition.longitude,
    );

    emit(ActivityTracking(routePoints: [startPoint]));

    // Sonra hareketi dinlemeye başlıyoruz
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

      // Mesafe hesaplaması (metre)
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

  void _onStopActivity(StopActivity event, Emitter<ActivityState> emit) {
    _locationSubscription?.cancel();
    if (state is ActivityTracking) {
      final currentState = state as ActivityTracking;
      emit(ActivityCompleted(currentState.currentDistance));
    }
  }

  @override
  Future<void> close() {
    _locationSubscription?.cancel();
    return super.close();
  }
}
