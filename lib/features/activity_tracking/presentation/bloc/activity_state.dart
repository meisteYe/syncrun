import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

abstract class ActivityState extends Equatable {
  const ActivityState();
  @override
  List<Object?> get props => [];
}

class ActivityInitial extends ActivityState {}

class ActivityTracking extends ActivityState {
  final List<LatLng> routePoints;
  final double currentDistance;

  const ActivityTracking({
    required this.routePoints,
    this.currentDistance = 0.0,
  });

  @override
  List<Object?> get props => [routePoints, currentDistance];
}

// --- YENİ EKLENEN DURUM (STATE) ---
class ActivityPaused extends ActivityState {
  final List<LatLng> routePoints;
  final double currentDistance;

  const ActivityPaused({
    required this.routePoints,
    required this.currentDistance,
  });

  @override
  List<Object?> get props => [routePoints, currentDistance];
}
// ----------------------------------

class ActivityCompleted extends ActivityState {
  final double totalDistance;
  const ActivityCompleted(this.totalDistance);

  @override
  List<Object?> get props => [totalDistance];
}
