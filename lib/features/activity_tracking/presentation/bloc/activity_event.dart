import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';

abstract class ActivityEvent extends Equatable {
  const ActivityEvent();
  @override
  List<Object?> get props => [];
}

class StartActivity extends ActivityEvent {}

// --- YENİ EKLENEN EVENTLER ---
class PauseActivity extends ActivityEvent {}

class ResumeActivity extends ActivityEvent {}
// -----------------------------

class LocationUpdated extends ActivityEvent {
  final Position newPosition;
  const LocationUpdated(this.newPosition);

  @override
  List<Object?> get props => [newPosition];
}

class StopActivity extends ActivityEvent {}
