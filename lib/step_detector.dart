import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';

class StepDetector {
  // Constants for algorithm tuning
  static const double _gravity = 9.80665;
  static const int _minStepIntervalMs = 250;
  static const int _maxStepIntervalMs = 2000;
  static const int _bufferSize = 20; // Size for moving average and thresholding
  static const int _requiredWalkingSteps = 6; // Increased from 5 to 6 for better pattern confirmation
  static const double _minPeakAmplitude = 1.2; // Minimum amplitude (m/s^2) for a valid step peak
  static const double _maxValidVariance = 15.0; // Too much variance might be intense shaking
  static const double _minValidVariance = 0.05; // Too little variance is just idling/fidgeting

  // Stream controller for step events
  final _stepController = StreamController<int>.broadcast();
  Stream<int> get stepStream => _stepController.stream;

  // State variables
  final List<double> _magnitudeBuffer = [];
  double _dynamicThreshold = 1.2; // Initial threshold above gravity
  int _lastStepTime = 0;
  int _consecutiveSteps = 0;
  bool _isWalking = false;
  
  // Low-pass filter variables for gravity estimation
  double _gx = 0, _gy = 0, _gz = 0;
  static const double _alpha = 0.8; // Filter coefficient

  void processAccelerometerEvent(AccelerometerEvent event) {
    // 1. Remove gravity using a simple low-pass filter (High-pass effect on output)
    _gx = _alpha * _gx + (1 - _alpha) * event.x;
    _gy = _alpha * _gy + (1 - _alpha) * event.y;
    _gz = _alpha * _gz + (1 - _alpha) * event.z;

    double cleanX = event.x - _gx;
    double cleanY = event.y - _gy;
    double cleanZ = event.z - _gz;

    // 2. Compute magnitude
    double magnitude = math.sqrt(cleanX * cleanX + cleanY * cleanY + cleanZ * cleanZ);

    // 3. Smooth the signal using Moving Average
    _magnitudeBuffer.add(magnitude);
    if (_magnitudeBuffer.length > _bufferSize) {
      _magnitudeBuffer.removeAt(0);
    }

    if (_magnitudeBuffer.length < _bufferSize) return;

    // 4. Peak Detection & Adaptive Thresholding
    _updateThreshold();

    // Check for peak using a 3-point local window (i-1, i, i+1)
    int i = _magnitudeBuffer.length - 2;
    double prev = _magnitudeBuffer[i - 1];
    double curr = _magnitudeBuffer[i];
    double next = _magnitudeBuffer[i + 1];

    if (curr > _dynamicThreshold && curr > prev && curr > next) {
      // 5. Additional Validation for Fake Motion
      if (_isValidStepSignal(curr)) {
        _handlePotentialStep();
      }
    }
  }

  bool _isValidStepSignal(double peakValue) {
    // Check 1: Minimum Peak Amplitude (Filters out subtle fidgeting)
    double minInBuf = _magnitudeBuffer.reduce(math.min);
    double amplitude = peakValue - minInBuf;
    if (amplitude < _minPeakAmplitude) return false;

    // Check 2: Signal Variance (Filters out constant engine vibration or random noise)
    double mean = _magnitudeBuffer.reduce((a, b) => a + b) / _bufferSize;
    double variance = _magnitudeBuffer.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) / _bufferSize;

    if (variance < _minValidVariance || variance > _maxValidVariance) {
      return false; // Signal is either too flat (idle) or too chaotic (random shaking)
    }

    return true;
  }

  void _updateThreshold() {
    double maxInBuf = _magnitudeBuffer.reduce(math.max);
    double minInBuf = _magnitudeBuffer.reduce(math.min);
    double range = maxInBuf - minInBuf;
    
    // Adaptive threshold: a bit above the mean, but at least a minimum sensitivity
    double calculatedThreshold = minInBuf + (range * 0.6);
    _dynamicThreshold = math.max(0.8, calculatedThreshold); 
  }

  void _handlePotentialStep() {
    int currentTime = DateTime.now().millisecondsSinceEpoch;
    
    if (_lastStepTime == 0) {
      _lastStepTime = currentTime;
      _consecutiveSteps = 1;
      return;
    }

    int delta = currentTime - _lastStepTime;

    // 5. Enforce realistic time intervals (250ms - 2000ms)
    if (delta > _minStepIntervalMs && delta < _maxStepIntervalMs) {
      _consecutiveSteps++;
      
      // 6. Detect continuous walking patterns before counting steps
      if (!_isWalking) {
        if (_consecutiveSteps >= _requiredWalkingSteps) {
          _isWalking = true;
          // When walking starts, we "catch up" the steps
          for (int i = 0; i < _requiredWalkingSteps; i++) {
            _stepController.add(1);
          }
        }
      } else {
        _stepController.add(1);
      }
      _lastStepTime = currentTime;
    } else if (delta >= _maxStepIntervalMs) {
      // Too long since last step, reset walking detection
      _consecutiveSteps = 1;
      _isWalking = false;
      _lastStepTime = currentTime;
    }
  }

  void dispose() {
    _stepController.close();
  }
}
