import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';

enum ActivityStatus { stopped, walking, running }

class StepDetector {
  static const double _gravity = 9.80665;
  
  // Stricter thresholds for anti-shake
  static const double _walkingMinG = 1.15;
  static const double _walkingMaxG = 1.9;
  static const double _runningMaxG = 4.0;
  static const double _shakeLimitG = 4.05; 

  // Timing: Standard human gait is very consistent
  static const int _minStepMs = 280; // 3.5 steps/sec max
  static const int _maxStepMs = 1500; // 0.6 steps/sec min
  static const int _minPeakTime = 160; 

  // Signal processing
  static const int _movingAvgWindow = 12; // Larger window for better smoothing
  static const double _lpfAlpha = 0.12;

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
    // 1. Gravity estimation
    _gx = _lpfAlpha * event.x + (1 - _lpfAlpha) * _gx;
    _gy = _lpfAlpha * event.y + (1 - _lpfAlpha) * _gy;
    _gz = _lpfAlpha * event.z + (1 - _lpfAlpha) * _gz;
    
    // 2. Flat phone detection
    double gMag = math.sqrt(_gx * _gx + _gy * _gy + _gz * _gz);
    if ((_gz / gMag).abs() > 0.9) {
      _reset();
      return;
    }

    // 3. Magnitude Calculation & Smoothing
    double cx = event.x - _gx;
    double cy = event.y - _gy;
    double cz = event.z - _gz;
    double rawMag = math.sqrt(cx * cx + cy * cy + cz * cz + (_gravity * _gravity)) / _gravity;

    _magWindow.add(rawMag);
    if (_magWindow.length > _movingAvgWindow) _magWindow.removeAt(0);
    if (_magWindow.length < _movingAvgWindow) return;

    double smoothMag = _magWindow.reduce((a, b) => a + b) / _movingAvgWindow;

    // 4. Pattern Logic
    _analyze(smoothMag);
    _updateStatus();
  }

  void _analyze(double mag) {
    int now = DateTime.now().millisecondsSinceEpoch;

    // RULE: Random high-intensity shaking rejection
    if (mag > _shakeLimitG) {
      _reset();
      return;
    }

    // Pattern Timeout
    if (_lastStepAt > 0 && (now - _lastStepAt) > _maxStepMs) {
      _reset();
      return;
    }

    // Peak Analysis
    if (mag > _walkingMinG && !_activePeak) {
      _activePeak = true;
      _peakStartedAt = now;
    } else if (mag < _walkingMinG && _activePeak) {
      _activePeak = false;
      int duration = now - _peakStartedAt;

      // RULE: Steps occupy a specific time-energy profile
      // Shaking creates very fast impulses; walking is a gradual footfall
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

    // RULE: Consistent gait frequency
    if (delta >= _minStepMs && delta <= _maxStepMs) {
      // rhythm check: compare to last delta to ensure it's not random shaking
      if (_deltas.isNotEmpty) {
        double diff = (delta - _deltas.last).abs().toDouble();
        if (diff > delta * 0.4) { // Variance > 40% is likely irregular shaking
          _streak = 1;
          _deltas.clear();
          _lastStepAt = now;
          return;
        }
      }

      _streak++;
      _lastStepAt = now;
      _deltas.add(delta);
      if (_deltas.length > 6) _deltas.removeAt(0);

      // RULE: 4 consecutive rhythmic steps required to count
      if (_streak >= 4) {
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

      if (sps >= 2.0 && intensity > 1.9) {
        current = ActivityStatus.running;
      } else if (sps >= 0.7) {
        current = ActivityStatus.walking;
      } else {
        current = ActivityStatus.stopped;
      }
    }

    if (current != _tempStatus) {
      _tempStatus = current;
      _stableSince = DateTime.now();
    } else if (_stableSince != null) {
      if (DateTime.now().difference(_stableSince!).inSeconds >= 4) {
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
