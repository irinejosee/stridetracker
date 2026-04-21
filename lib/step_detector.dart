import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';

enum ActivityStatus { stopped, walking, running }

class StepDetector {
  static const double _gravity = 9.80665;
  
  // User requested: Lower minimum acceleration threshold for gentle walking
  static const double _walkingMinG = 0.8; 
  static const double _shakeLimitG = 4.0; 

  // User requested: Min gap 250ms, Max gap 1500ms
  static const int _minStepMs = 250; 
  static const int _maxStepMs = 1500; 
  static const int _minPeakTime = 80; 

  // User requested: Less aggressive LPF
  static const double _lpfAlpha = 0.35; 
  static const int _movingAvgWindow = 5; 

  final _stepController = StreamController<int>.broadcast();
  final _activityController = StreamController<ActivityStatus>.broadcast();
  
  Stream<int> get stepStream => _stepController.stream;
  Stream<ActivityStatus> get activityStream => _activityController.stream;

  final List<double> _magWindow = [];
  final List<int> _deltas = [];
  
  double _gx = 0, _gy = 0, _gz = 0;
  int _lastStepAt = 0;
  int _peakStartedAt = 0;
  int _streak = 0;
  bool _activePeak = false;
  
  ActivityStatus _status = ActivityStatus.stopped;
  ActivityStatus _tempStatus = ActivityStatus.stopped;
  DateTime? _stableSince;

  void processAccelerometerEvent(AccelerometerEvent event) {
    // 1. Gravity estimation (LPF)
    _gx = _lpfAlpha * event.x + (1 - _lpfAlpha) * _gx;
    _gy = _lpfAlpha * event.y + (1 - _lpfAlpha) * _gy;
    _gz = _lpfAlpha * event.z + (1 - _lpfAlpha) * _gz;
    
    // 2. Flat phone detection (Keep as requested)
    double gMag = math.sqrt(_gx * _gx + _gy * _gy + _gz * _gz);
    if (gMag > 0 && (_gz / gMag).abs() > 0.9) {
      _reset();
      return;
    }

    // 3. Magnitude Calculation
    double cx = event.x - _gx;
    double cy = event.y - _gy;
    double cz = event.z - _gz;
    double rawMag = math.sqrt(cx * cx + cy * cy + cz * cz + (_gravity * _gravity)) / _gravity;

    _magWindow.add(rawMag);
    if (_magWindow.length > _movingAvgWindow) _magWindow.removeAt(0);
    if (_magWindow.length < _movingAvgWindow) return;

    double smoothMag = _magWindow.reduce((a, b) => a + b) / _movingAvgWindow;

    // 4. Analysis
    _analyze(smoothMag);
    _updateStatus();
  }

  void _analyze(double mag) {
    int now = DateTime.now().millisecondsSinceEpoch;

    if (mag > _shakeLimitG) {
      _reset();
      return;
    }

    if (_lastStepAt > 0 && (now - _lastStepAt) > _maxStepMs) {
      _reset();
      return;
    }

    if (mag > _walkingMinG && !_activePeak) {
      _activePeak = true;
      _peakStartedAt = now;
    } else if (mag < _walkingMinG && _activePeak) {
      _activePeak = false;
      int duration = now - _peakStartedAt;

      if (duration >= _minPeakTime) {
        _validate(now);
      }
    }
  }

  void _validate(int now) {
    if (_lastStepAt == 0) {
      _lastStepAt = now;
      _streak = 1;
      return;
    }

    int delta = now - _lastStepAt;

    if (delta >= _minStepMs && delta <= _maxStepMs) {
      // Rhythm check (Allow slightly more variance for natural gentle walking)
      if (_deltas.isNotEmpty) {
        double diff = (delta - _deltas.last).abs().toDouble();
        if (diff > delta * 0.65) { 
          _streak = 1;
          _deltas.clear();
          _lastStepAt = now;
          return;
        }
      }

      _streak++;
      _lastStepAt = now;
      _deltas.add(delta);
      if (_deltas.length > 5) _deltas.removeAt(0);

      // User requested: Reduce from 3 to 2 consecutive peaks
      if (_streak >= 2) {
        _stepController.add(1);
      }
    } else {
      _streak = 1;
      _lastStepAt = now;
    }
  }

  void _updateStatus() {
    int now = DateTime.now().millisecondsSinceEpoch;
    ActivityStatus current;

    if (_lastStepAt == 0 || (now - _lastStepAt) > _maxStepMs) {
      current = ActivityStatus.stopped;
    } else if (_deltas.isEmpty) {
      current = ActivityStatus.stopped;
    } else {
      double avg = _deltas.reduce((a, b) => a + b) / _deltas.length;
      double sps = 1000 / avg;
      double intensity = _magWindow.last;

      if (sps >= 2.0 && intensity > 1.8) {
        current = ActivityStatus.running;
      } else if (sps >= 0.6) {
        current = ActivityStatus.walking;
      } else {
        current = ActivityStatus.stopped;
      }
    }

    if (current != _tempStatus) {
      _tempStatus = current;
      _stableSince = DateTime.now();
    } else if (_stableSince != null) {
      // Use 3 seconds for confirmation to be slightly more responsive
      if (DateTime.now().difference(_stableSince!).inSeconds >= 3) {
        if (_status != _tempStatus) {
          _status = _tempStatus;
          _activityController.add(_status);
        }
      }
    }
  }

  void _reset() {
    _streak = 0;
    _deltas.clear();
    _lastStepAt = 0;
    if (_status != ActivityStatus.stopped) {
      _status = ActivityStatus.stopped;
      _activityController.add(_status);
    }
    _stableSince = null;
  }

  void dispose() {
    _stepController.close();
    _activityController.close();
  }
}
