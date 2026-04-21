import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';

enum ActivityStatus { stationary, walking, running }

class StepDetector {
  // Constant thresholds based on g-force (1g ≈ 9.8 m/s^2)
  static const double _gravity = 9.80665;
  static const double _minWalkingG = 1.2;
  static const double _maxWalkingG = 2.0;
  static const double _maxRunningG = 4.0;
  static const double _shakeG = 4.1; // Anything above this is considered shaking

  // Timing constraints
  static const int _minStepIntervalMs = 250;
  static const int _maxStepIntervalMs = 2000;
  static const int _minPeakDurationMs = 150; // Step must stay above threshold for this long
  static const int _maxShakeDurationMs = 100; // Fast spikes under 100ms are noise/shakes

  // Smoothing
  static const int _smoothWindowSize = 10;
  static const double _alphaLPF = 0.15;

  // Stream controllers
  final _stepController = StreamController<int>.broadcast();
  final _activityController = StreamController<ActivityStatus>.broadcast();
  
  Stream<int> get stepStream => _stepController.stream;
  Stream<ActivityStatus> get activityStream => _activityController.stream;

  // State buffers
  final List<double> _rawMagnitudeBuffer = [];
  final List<int> _cadenceBuffer = [];
  
  double _gx = 0, _gy = 0, _gz = 0; // Filtered gravity
  double _lastProcessedMagnitude = 0;
  int _lastStepTime = 0;
  int _peakStartTime = 0;
  int _validPeakCount = 0;
  bool _isAboveThreshold = false;
  
  ActivityStatus _currentStatus = ActivityStatus.stationary;
  ActivityStatus _potentialStatus = ActivityStatus.stationary;
  DateTime? _statusChangeTime;

  void processAccelerometerEvent(AccelerometerEvent event) {
    // 1. Orientation Gating (Ignore if Z-axis is dominant/phone is flat)
    _gx = _alphaLPF * event.x + (1 - _alphaLPF) * _gx;
    _gy = _alphaLPF * event.y + (1 - _alphaLPF) * _gy;
    _gz = _alphaLPF * event.z + (1 - _alphaLPF) * _gz;
    
    double totalGravity = math.sqrt(_gx * _gx + _gy * _gy + _gz * _gz);
    if ((_gz / totalGravity).abs() > 0.85) {
      _resetPattern();
      return;
    }

    // 2. Magnitude Calculation (Normalized to G-force)
    double cleanX = event.x - _gx;
    double cleanY = event.y - _gy;
    double cleanZ = event.z - _gz;
    double magnitude = math.sqrt(cleanX * cleanX + cleanY * cleanY + cleanZ * cleanZ + (_gravity * _gravity)) / _gravity;

    // 3. Signal Smoothing (Moving Average)
    _rawMagnitudeBuffer.add(magnitude);
    if (_rawMagnitudeBuffer.length > _smoothWindowSize) _rawMagnitudeBuffer.removeAt(0);
    if (_rawMagnitudeBuffer.length < _smoothWindowSize) return;

    double smoothedMag = _rawMagnitudeBuffer.reduce((a, b) => a + b) / _smoothWindowSize;

    // 4. Advanced Step & Shake Filtering
    _analyzeSignal(smoothedMag);
    
    // 5. Activity Status Management
    _updateActivityState();
  }

  void _analyzeSignal(double mag) {
    int now = DateTime.now().millisecondsSinceEpoch;

    // Rule: Anything above 4.0g is an immediate shake - ignore and reset
    if (mag > _shakeG) {
      _resetPattern();
      return;
    }

    // Check for pattern reset (No steps for 2 seconds)
    if (_lastStepTime > 0 && (now - _lastStepTime) > _maxStepIntervalMs) {
      _resetPattern();
      return;
    }

    // Threshold logic (Starts at 1.2g for walking)
    if (mag > _minWalkingG && !_isAboveThreshold) {
      _isAboveThreshold = true;
      _peakStartTime = now;
    } else if (mag < _minWalkingG && _isAboveThreshold) {
      _isAboveThreshold = false;
      int peakDuration = now - _peakStartTime;

      // RULE: Steps must be sustained (>150ms) but not erratic (<100ms is a flicker/shake)
      if (peakDuration >= _minPeakDurationMs) {
        _validateStep(now, mag);
      }
    }
  }

  void _validateStep(int now, double mag) {
    if (_lastStepTime == 0) {
      _lastStepTime = now;
      _validPeakCount = 1;
      return;
    }

    int delta = now - _lastStepTime;

    // RULE: 250ms - 2000ms valid window
    if (delta >= _minStepIntervalMs && delta <= _maxStepIntervalMs) {
      _validPeakCount++;
      _lastStepTime = now;
      _cadenceBuffer.add(delta);
      if (_cadenceBuffer.length > 5) _cadenceBuffer.removeAt(0);

      // RULE: Only count after 3 consecutive valid peaks
      if (_validPeakCount >= 3) {
        _stepController.add(1);
      }
    } else {
      _validPeakCount = 1; // Unrealistic timing, restart count
      _lastStepTime = now;
    }
  }

  void _updateActivityState() {
    int now = DateTime.now().millisecondsSinceEpoch;
    ActivityStatus currentSample;

    if (_lastStepTime == 0 || (now - _lastStepTime) > _maxStepIntervalMs) {
      currentSample = ActivityStatus.stationary;
    } else if (_cadenceBuffer.isEmpty) {
      currentSample = ActivityStatus.stationary;
    } else {
      double avgDelta = _cadenceBuffer.reduce((a, b) => a + b) / _cadenceBuffer.length;
      double stepsPerSec = 1000 / avgDelta;
      
      // We use the most recent smoothed magnitude as a hint for intensity
      double intensity = _rawMagnitudeBuffer.last;

      if (stepsPerSec >= 2.0 && stepsPerSec <= 3.1 && intensity > 2.0) {
        currentSample = ActivityStatus.running;
      } else if (stepsPerSec >= 0.8 && stepsPerSec < 2.0) {
        currentSample = ActivityStatus.walking;
      } else {
        currentSample = ActivityStatus.stationary;
      }
    }

    // RULE: Confirm status for 4 consecutive seconds
    if (currentSample != _potentialStatus) {
      _potentialStatus = currentSample;
      _statusChangeTime = DateTime.now();
    } else if (_statusChangeTime != null) {
      if (DateTime.now().difference(_statusChangeTime!).inSeconds >= 4) {
        if (_currentStatus != _potentialStatus) {
          _currentStatus = _potentialStatus;
          _activityController.add(_currentStatus);
        }
      }
    }
  }

  void _resetPattern() {
    _validPeakCount = 0;
    _cadenceBuffer.clear();
    _lastStepTime = 0;
    if (_currentStatus != ActivityStatus.stationary) {
      _currentStatus = ActivityStatus.stationary;
      _activityController.add(_currentStatus);
    }
    _statusChangeTime = null;
  }

  void dispose() {
    _stepController.close();
    _activityController.close();
  }
}
