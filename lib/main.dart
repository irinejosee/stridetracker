import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animations/animations.dart';

void main() {
  runApp(const StrideTrackApp());
}

class StrideTrackApp extends StatelessWidget {
  const StrideTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StrideTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFFA855F7), // Neon Purple
          secondary: const Color(0xFFE11D48), // Neon Rose/Pink
          surface: const Color(0xFF0F172A), // Dark slate surface
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  int _todaySteps = 0;
  String _status = 'Stopped';
  late Stream<StepCount> _stepCountStream;
  int _baseStepCount = -1;

  @override
  void initState() {
    super.initState();
    _initPedometer();
    _checkMidnightReset();
  }

  Future<void> _initPedometer() async {
    if (await Permission.activityRecognition.request().isGranted) {
      _startListening();
    } else {
      setState(() => _status = 'Access Denied');
    }
  }

  void _startListening() {
    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream.listen(
      _onStepCount,
      onError: _onStepCountError,
      cancelOnError: false,
    );
  }

  void _onStepCount(StepCount event) async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    // 1. Check for day change
    await _checkMidnightReset();

    int currentSensorSteps = event.steps;
    int lastSensorValue = prefs.getInt('last_sensor_value') ?? currentSensorSteps;
    int totalToday = prefs.getInt('today_steps_live') ?? 0;

    // 2. Calculate the difference (delta)
    int delta = currentSensorSteps - lastSensorValue;

    // 3. Handle Sensor Reset (Reboot)
    // If delta is negative, the phone likely rebooted and the sensor started from 0
    if (delta < 0) {
      delta = currentSensorSteps;
    }

    // 4. Update the running total for today
    if (delta > 0) {
      totalToday += delta;
    }

    setState(() {
      _todaySteps = totalToday;
      _status = 'Walking';
    });

    // 5. Save state for next update
    await prefs.setInt('last_sensor_value', currentSensorSteps);
    await prefs.setInt('today_steps_live', totalToday);
  }

  void _onStepCountError(error) {
    setState(() => _status = 'Sensor Error');
  }

  Future<void> _checkMidnightReset() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getString('last_check_date') ?? '';
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (lastCheck != '' && lastCheck != todayStr) {
      // Midnight happened!
      final finalSteps = prefs.getInt('today_steps_live') ?? 0;
      
      // Save yesterday's data to history
      List<String> history = prefs.getStringList('step_history') ?? [];
      history.insert(0, jsonEncode({'date': lastCheck, 'steps': finalSteps}));
      if (history.length > 30) history = history.sublist(0, 30);
      
      await prefs.setStringList('step_history', history);
      
      // Reset daily counter
      await prefs.setInt('today_steps_live', 0);
      
      // Note: We keep 'last_sensor_value' so the next event calculates correctly
      setState(() => _todaySteps = 0);
    }
    await prefs.setString('last_check_date', todayStr);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        steps: _todaySteps,
        status: _status,
        onRefresh: () async {
          await _initPedometer();
          await _checkMidnightReset();
          final prefs = await SharedPreferences.getInstance();
          setState(() {
            _todaySteps = prefs.getInt('today_steps_live') ?? _todaySteps;
          });
        },
      ),
      const HistoryScreen(),
    ];

    return Scaffold(
      body: PageTransitionSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (child, primaryAnimation, secondaryAnimation) {
          return FadeThroughTransition(
            animation: primaryAnimation,
            secondaryAnimation: secondaryAnimation,
            child: child,
          );
        },
        child: screens[_currentIndex],
      ),
      bottomNavigationBar: CustomNeonNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final int steps;
  final String status;
  final Future<void> Function() onRefresh;
  final int goal = 10000;

  const HomeScreen({
    super.key,
    required this.steps,
    required this.status,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    double progress = (steps / goal).clamp(0.0, 1.0);
    double calories = steps * 0.04;
    double km = steps * 0.0008;

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: const Color(0xFFA855F7),
      backgroundColor: const Color(0xFF0F172A),
      displacement: 20,
      child: Container(
        decoration: const BoxDecoration(color: Colors.black),
        child: Stack(
          children: [
            // Background Glows
            Positioned(
              top: -150,
              right: -100,
              child: _GlowBlob(color: const Color(0xFFA855F7).withOpacity(0.15), size: 400),
            ),
            Positioned(
              bottom: 50,
              left: -150,
              child: _GlowBlob(color: const Color(0xFFE11D48).withOpacity(0.1), size: 500),
            ),
            SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - 90, // Navbar height approx
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 60), // Account for header/safearea
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Activity Center',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white38,
                                  letterSpacing: 2,
                                ),
                              ),
                              Text(
                                DateFormat('MMM d, yyyy').format(DateTime.now()),
                                style: GoogleFonts.outfit(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          _NeonStatusPill(status: status),
                        ],
                      ),
                      const SizedBox(height: 60),
                      Center(
                        child: NeonCircularIndicator(
                          progress: progress,
                          steps: steps,
                          goal: goal,
                        ),
                      ),
                      const SizedBox(height: 60),
                      Row(
                        children: [
                          Expanded(
                            child: _NeonStatCard(
                              icon: Icons.local_fire_department_rounded,
                              label: 'Burned',
                              value: calories.toStringAsFixed(0),
                              unit: 'kcal',
                              color: const Color(0xFFF97316),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _NeonStatCard(
                              icon: Icons.auto_awesome_rounded,
                              label: 'Distance',
                              value: km.toStringAsFixed(2),
                              unit: 'km',
                              color: const Color(0xFF06B6D4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      // Added Motivation Text
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '"The journey of a thousand miles begins with a single step."',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontStyle: FontStyle.italic,
                                color: Colors.white60,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '- Lao Tzu',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFA855F7),
                                fontSize: 12,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NeonCircularIndicator extends StatefulWidget {
  final double progress;
  final int steps;
  final int goal;

  const NeonCircularIndicator({
    super.key,
    required this.progress,
    required this.steps,
    required this.goal,
  });

  @override
  State<NeonCircularIndicator> createState() => _NeonCircularIndicatorState();
}

class _NeonCircularIndicatorState extends State<NeonCircularIndicator> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _animation = Tween<double>(begin: 0, end: widget.progress).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(NeonCircularIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _animation = Tween<double>(begin: oldWidget.progress, end: widget.progress).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Inner Glow
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFA855F7).withOpacity(0.3),
                    blurRadius: 60,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 280,
              height: 280,
              child: CustomPaint(
                painter: _NeonProgressPainter(
                  progress: _animation.value,
                  color: const Color(0xFFA855F7),
                  backgroundColor: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFFFFFFF), Color(0xFFA855F7)],
                  ).createShader(bounds),
                  child: Text(
                    NumberFormat('#,###').format(widget.steps),
                    style: GoogleFonts.outfit(
                      fontSize: 56,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  'Steps Taken',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white30,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Goal: ${widget.goal}',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _NeonProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _NeonProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 14.0;

    // Track
    canvas.drawCircle(
      center,
      radius - strokeWidth / 2,
      Paint()
        ..color = backgroundColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Glow Effect
    final glowPaint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..strokeCap = StrokeCap.round;

    final angle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -math.pi / 2,
      angle,
      false,
      glowPaint,
    );

    // Primary Stroke
    final strokePaint = Paint()
      ..shader = LinearGradient(
        colors: [color, color.withBlue(255).withRed(255)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -math.pi / 2,
      angle,
      false,
      strokePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _NeonProgressPainter oldDelegate) => true;
}

class _NeonStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _NeonStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 16),
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 12, color: Colors.white38, letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: Colors.white24,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final strings = prefs.getStringList('step_history') ?? [];
    setState(() {
      _history = strings.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Data History',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: _history.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_rounded, size: 80, color: Colors.white10),
                          const SizedBox(height: 16),
                          Text('No stored records', style: GoogleFonts.outfit(color: Colors.white24)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _history.length,
                      itemBuilder: (context, index) {
                        final item = _history[index];
                        final date = DateTime.parse(item['date']);
                        return _NeonHistoryCard(date: date, steps: item['steps'] as int);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NeonHistoryCard extends StatelessWidget {
  final DateTime date;
  final int steps;
  final int goal = 10000;

  const _NeonHistoryCard({required this.date, required this.steps});

  @override
  Widget build(BuildContext context) {
    double progress = (steps / goal).clamp(0.0, 1.0);
    bool isAchieved = steps >= goal;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE').format(date),
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    DateFormat('MMMM d').format(date),
                    style: GoogleFonts.outfit(fontSize: 14, color: Colors.white30),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    NumberFormat('#,###').format(steps),
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isAchieved ? const Color(0xFF10B981) : const Color(0xFFA855F7),
                    ),
                  ),
                  Text('steps', style: GoogleFonts.outfit(fontSize: 12, color: Colors.white24)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(seconds: 1),
                height: 8,
                width: MediaQuery.of(context).size.width * 0.7 * progress,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFFA855F7), isAchieved ? const Color(0xFF10B981) : const Color(0xFFE11D48)],
                  ),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFA855F7).withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CustomNeonNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomNeonNavBar({super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NeonNavBarItem(
            icon: Icons.bolt_rounded,
            label: 'TRACKER',
            isActive: currentIndex == 0,
            onTap: () => onTap(0),
          ),
          _NeonNavBarItem(
            icon: Icons.analytics_rounded,
            label: 'RECORDS',
            isActive: currentIndex == 1,
            onTap: () => onTap(1),
          ),
        ],
      ),
    );
  }
}

class _NeonNavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NeonNavBarItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFFA855F7) : Colors.white24;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 2,
            ),
          ),
          if (isActive)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 4,
              height: 4,
              decoration: const BoxDecoration(color: Color(0xFFA855F7), shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }
}

class _NeonStatusPill extends StatelessWidget {
  final String status;

  const _NeonStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    bool isWalking = status == 'Walking';
    final color = isWalking ? const Color(0xFF10B981) : const Color(0xFFA855F7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
