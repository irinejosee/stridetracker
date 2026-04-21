import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';

enum ActivityStatus { stationary, walking, running }

class StepDetector {
  // Constants for algorithm tuning
  static const int _minStepIntervalMs = 250; // Faster than 4 steps/sec is unlikely for running
  static const int _maxStepIntervalMs = 1200; // Slower than 0.8 steps/sec is stationary
  static const int _bufferSize = 30; // Larger buffer for better pattern recognition
  static const double _walkingThreshold = 0.8;
  
  // Smoothing parameters
  static const double _alphaMagnitude = 0.15; // Low-pass filter for magnitude smoothing
  static const double _alphaGravity = 0.1; // Low-pass filter for gravity estimation

  // Stream controllers
  final _stepController = StreamController<int>.broadcast();
  final _activityController = StreamController<ActivityStatus>.broadcast();
  
  Stream<int> get stepStream => _stepController.stream;
  Stream<ActivityStatus> get activityStream => _activityController.stream;

  // State variables
  final List<double> _magnitudeBuffer = [];
  final List<int> _timeIntervals = [];
  
  double _gx = 0, _gy = 0, _gz = 0; // Gravity components
  double _smoothedMagnitude = 0;
  int _lastStepTime = 0;
  int _consecutiveSteps = 0;
  ActivityStatus _currentActivity = ActivityStatus.stationary;

  void processAccelerometerEvent(AccelerometerEvent event) {
    // 1. Orientation Check: Ignore if phone is lying flat
    // If gravity is mostly on the Z axis (horizontal position), it's likely flat
    _gx = _alphaGravity * event.x + (1 - _alphaGravity) * _gx;
    _gy = _alphaGravity * event.y + (1 - _alphaGravity) * _gy;
    _gz = _alphaGravity * event.z + (1 - _alphaGravity) * _gz;
    
    double gravityMag = math.sqrt(_gx * _gx + _gy * _gy + _gz * _gz);
    double zDist = (_gz / gravityMag).abs();
    
    // If Z component is more than 90% of total gravity, phone is roughly flat
    if (zDist > 0.9) {
      _resetActivity();
      return;
    }

    // 2. Remove Gravity & Compute Magnitude
    double cleanX = event.x - _gx;
    double cleanY = event.y - _gy;
    double cleanZ = event.z - _gz;
    double rawMagnitude = math.sqrt(cleanX * cleanX + cleanY * cleanY + cleanZ * cleanZ);

    // 3. Low-Pass Filter on Magnitude to smooth jerky movements/shaking
    _smoothedMagnitude = _alphaMagnitude * rawMagnitude + (1 - _alphaMagnitude) * _smoothedMagnitude;

    // 4. Update Buffer
    _magnitudeBuffer.add(_smoothedMagnitude);
    if (_magnitudeBuffer.length > _bufferSize) {
      _magnitudeBuffer.removeAt(0);
    }

    if (_magnitudeBuffer.length < _bufferSize) return;

    // 5. Peak Detection & Footfall Validation
    _detectStep();

    // 6. Update Activity Status based on frequency and intensity
    _updateActivityStatus();
  }

  void _detectStep() {
    int i = _magnitudeBuffer.length - 2; // Check the middle point of a 3-point window
    double prev = _magnitudeBuffer[i - 1];
    double curr = _magnitudeBuffer[i];
    double next = _magnitudeBuffer[i + 1];

    // Peak criteria: higher than neighbors and exceeds threshold
    if (curr > prev && curr > next && curr > _walkingThreshold) {
      int currentTime = DateTime.now().millisecondsSinceEpoch;
      int delta = currentTime - _lastStepTime;

      // Rule: Ignore movements shorter than 250ms (debouncing)
      if (delta < _minStepIntervalMs) return;

      // Rule: Only count if pattern matches natural footfall (rise then fall)
      // Check if the rise (curr - prev) and fall (curr - next) are gradual, not spikes
      // A sharp spike often indicates a jolt/shake
      double rise = (curr - prev);
      double fall = (curr - next);
      
      // If rise/fall is too extreme relative to the peak, it's a "spike"
      if (rise > 2.0 || fall > 2.0) return; 

      // Rule: Consistent rhythmic motion
      if (_isRhythmic(delta)) {
        _consecutiveSteps++;
        
        // Require at least 3 consistent steps before counting
        if (_consecutiveSteps >= 3) {
          _stepController.add(1);
          
          // Update time intervals for cadence detection
          _timeIntervals.add(delta);
          if (_timeIntervals.length > 5) _timeIntervals.removeAt(0);
        }
        
        _lastStepTime = currentTime;
      } else {
        // Not rhythmic enough yet
        _consecutiveSteps = 1;
        _lastStepTime = currentTime;
      }
    }
  }

  bool _isRhythmic(int newDelta) {
    if (_timeIntervals.isEmpty) return true;
    
    // Compare new delta with average of recent deltas
    double avgDelta = _timeIntervals.reduce((a, b) => a + b) / _timeIntervals.length;
    double variance = (newDelta - avgDelta).abs() / avgDelta;
    
    // If variance is less than 30%, it's rhythmic
    return variance < 0.35;
  }

  void _updateActivityStatus() {
    int currentTime = DateTime.now().millisecondsSinceEpoch;
    int deltaSinceLastStep = currentTime - _lastStepTime;

    if (deltaSinceLastStep > _maxStepIntervalMs) {
      _resetActivity();
      return;
    }

    if (_timeIntervals.isEmpty) return;

    double avgDelta = _timeIntervals.reduce((a, b) => a + b) / _timeIntervals.length;
    double stepsPerSecond = 1000 / avgDelta;

    ActivityStatus newStatus;
    if (stepsPerSecond >= 2.0) { // 2-3 steps per second
      newStatus = ActivityStatus.running;
    } else if (stepsPerSecond >= 0.8) { // 1-2 steps per second
      newStatus = ActivityStatus.walking;
    } else {
      newStatus = ActivityStatus.stationary;
    }

    if (newStatus != _currentActivity) {
      _currentActivity = newStatus;
      _activityController.add(_currentActivity);
    }
  }

  void _resetActivity() {
    if (_currentActivity != ActivityStatus.stationary) {
      _currentActivity = ActivityStatus.stationary;
      _activityController.add(_currentActivity);
    }
    _consecutiveSteps = 0;
    _timeIntervals.clear();
  }

  void dispose() {
    _stepController.close();
    _activityController.close();
  }
}
