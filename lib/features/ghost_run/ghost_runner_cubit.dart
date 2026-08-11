import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart'; // Ücretsiz haritamızın koordinat sistemi!

class GhostRunnerState {
  final LatLng? ghostPosition;
  final bool isActive;
  final bool hasFinished;

  GhostRunnerState({
    this.ghostPosition,
    this.isActive = false,
    this.hasFinished = false,
  });
}

class GhostRunnerCubit extends Cubit<GhostRunnerState> {
  GhostRunnerCubit() : super(GhostRunnerState());

  Timer? _timer;
  // ghostPath verisi işte tam burada, uygulamanın hafızasında tutulacak.
  List<Map<String, dynamic>> _ghostPath = [];
  int _elapsedSeconds = 0;

  void startGhostRun(List<Map<String, dynamic>> pastRunData) {
    if (pastRunData.isEmpty) return;

    _ghostPath = pastRunData;
    _elapsedSeconds = 0;

    emit(
      GhostRunnerState(
        ghostPosition: LatLng(_ghostPath[0]['lat'], _ghostPath[0]['lng']),
        isActive: true,
      ),
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedSeconds++;
      _updateGhostPosition();
    });
  }

  void _updateGhostPosition() {
    try {
      var currentPoint = _ghostPath.lastWhere(
        (point) => point['timeOffset'] <= _elapsedSeconds,
      );

      emit(
        GhostRunnerState(
          ghostPosition: LatLng(currentPoint['lat'], currentPoint['lng']),
          isActive: true,
        ),
      );

      if (_elapsedSeconds >= _ghostPath.last['timeOffset']) {
        _timer?.cancel();
        emit(
          GhostRunnerState(
            ghostPosition: state.ghostPosition,
            isActive: true,
            hasFinished: true,
          ),
        );
      }
    } catch (e) {
      _timer?.cancel();
    }
  }

  void stopGhostRun() {
    _timer?.cancel();
    emit(GhostRunnerState());
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
