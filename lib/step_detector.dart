import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';

enum ActivityStatus { stopped, walking, running }

class StepDetector {
  // Constants for algorithm tuning
  static const int _minStepIntervalMs = 250; 
  static const int _maxStepIntervalMs = 1200; 
  static const int _bufferSize = 40; // Larger for pattern verification
  static const double _walkingThreshold = 0.8;
  
  // Smoothing parameters
  static const double _alphaMagnitude = 0.15;
  static const double _alphaGravity = 0.1;

  // Stream controllers
  final _stepController = StreamController<int>.broadcast();
  final _activityController = StreamController<ActivityStatus>.broadcast();
  
  Stream<int> get stepStream => _stepController.stream;
  Stream<ActivityStatus> get activityStream => _activityController.stream;

  // State variables
  final List<double> _magnitudeBuffer = [];
  final List<int> _timeIntervals = [];
  final List<ActivityStatus> _recentPotentials = [];
  
  double _gx = 0, _gy = 0, _gz = 0;
  double _smoothedMagnitude = 0;
  int _lastStepTime = 0;
  int _consecutiveSteps = 0;
  ActivityStatus _currentActivity = ActivityStatus.stopped;
  
  // Pattern confirmation timers
  DateTime? _patternStartTime;
  ActivityStatus _potentialStatus = ActivityStatus.stopped;

  void processAccelerometerEvent(AccelerometerEvent event) {
    // 1. Orientation Check
    _gx = _alphaGravity * event.x + (1 - _alphaGravity) * _gx;
    _gy = _alphaGravity * event.y + (1 - _alphaGravity) * _gy;
    _gz = _alphaGravity * event.z + (1 - _alphaGravity) * _gz;
    
    double gravityMag = math.sqrt(_gx * _gx + _gy * _gy + _gz * _gz);
    double zDist = (_gz / gravityMag).abs();
    
    if (zDist > 0.9) {
      _resetActivity();
      return;
    }

    // 2. Remove Gravity & Compute Magnitude
    double cleanX = event.x - _gx;
    double cleanY = event.y - _gy;
    double cleanZ = event.z - _gz;
    double rawMagnitude = math.sqrt(cleanX * cleanX + cleanY * cleanY + cleanZ * cleanZ);

    _smoothedMagnitude = _alphaMagnitude * rawMagnitude + (1 - _alphaMagnitude) * _smoothedMagnitude;

    // 3. Update Buffer
    _magnitudeBuffer.add(_smoothedMagnitude);
    if (_magnitudeBuffer.length > _bufferSize) _magnitudeBuffer.removeAt(0);
    if (_magnitudeBuffer.length < _bufferSize) return;

    // 4. Step Detection
    _detectStep();

    // 5. Status Management (Walking / Running / Stopped)
    _manageActivityStatus();
  }

  void _detectStep() {
    int i = _magnitudeBuffer.length - 2;
    double prev = _magnitudeBuffer[i - 1];
    double curr = _magnitudeBuffer[i];
    double next = _magnitudeBuffer[i + 1];

    if (curr > prev && curr > next && curr > _walkingThreshold) {
      int currentTime = DateTime.now().millisecondsSinceEpoch;
      int delta = currentTime - _lastStepTime;

      if (delta < _minStepIntervalMs) return;

      // Spike detection (Shaking filtering)
      double rise = (curr - prev);
      double fall = (curr - next);
      if (rise > 1.8 || fall > 1.8) return; 

      if (_isRhythmic(delta)) {
        _consecutiveSteps++;
        if (_consecutiveSteps >= 3) {
          _stepController.add(1);
          _timeIntervals.add(delta);
          if (_timeIntervals.length > 8) _timeIntervals.removeAt(0);
        }
        _lastStepTime = currentTime;
      } else {
        _consecutiveSteps = 1;
        _lastStepTime = currentTime;
      }
    }
  }

  bool _isRhythmic(int newDelta) {
    if (_timeIntervals.isEmpty) return true;
    double avgDelta = _timeIntervals.reduce((a, b) => a + b) / _timeIntervals.length;
    double variance = (newDelta - avgDelta).abs() / avgDelta;
    return variance < 0.30; // Stricter rhythm requirement (30%)
  }

  void _manageActivityStatus() {
    int currentTime = DateTime.now().millisecondsSinceEpoch;
    int deltaSinceLastStep = currentTime - _lastStepTime;

    ActivityStatus potentialNow;
    if (deltaSinceLastStep > _maxStepIntervalMs) {
      potentialNow = ActivityStatus.stopped;
    } else if (_timeIntervals.isEmpty) {
      potentialNow = ActivityStatus.stopped;
    } else {
      double avgDelta = _timeIntervals.reduce((a, b) => a + b) / _timeIntervals.length;
      double stepsPerSecond = 1000 / avgDelta;

      if (stepsPerSecond >= 2.0 && stepsPerSecond <= 3.5) {
        potentialNow = ActivityStatus.running;
      } else if (stepsPerSecond >= 0.8 && stepsPerSecond < 2.0) {
        potentialNow = ActivityStatus.walking;
      } else {
        potentialNow = ActivityStatus.stopped;
      }
    }

    // Confirmation Logic
    if (potentialNow != _potentialStatus) {
      _potentialStatus = potentialNow;
      _patternStartTime = DateTime.now();
    } else if (_patternStartTime != null) {
      int confirmedDurationSeconds = DateTime.now().difference(_patternStartTime!).inSeconds;
      
      // RULE: Running requires 4 seconds confirmation
      // RULE: Others require 3 seconds confirmation
      int requiredSeconds = (potentialNow == ActivityStatus.running) ? 4 : 3;

      if (confirmedDurationSeconds >= requiredSeconds) {
        if (_currentActivity != potentialNow) {
          _currentActivity = potentialNow;
          _activityController.add(_currentActivity);
        }
      }
    }
  }

  void _resetActivity() {
    if (_currentActivity != ActivityStatus.stopped) {
      _currentActivity = ActivityStatus.stopped;
      _activityController.add(_currentActivity);
    }
    _potentialStatus = ActivityStatus.stopped;
    _patternStartTime = null;
    _consecutiveSteps = 0;
    _timeIntervals.clear();
  }

  void dispose() {
    _stepController.close();
    _activityController.close();
  }
}
