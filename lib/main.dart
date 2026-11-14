import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const AetherPulseApp());
}

class AetherPulseApp extends StatelessWidget {
  const AetherPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aether Pulse',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF080B10),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00F5D4),
          secondary: Color(0xFF7B2CBF),
          surface: Color(0xFF111622),
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// MODELS & DATA
// ---------------------------------------------------------------------------

enum BrainwaveType { delta, theta, alpha, beta, gamma }

class BrainwaveData {
  final BrainwaveType type;
  final String name;
  final String targetHz;
  final String state;
  final String description;
  final Color primaryColor;
  final Color secondaryColor;
  final double frequency;

  const BrainwaveData({
    required this.type,
    required this.name,
    required this.targetHz,
    required this.state,
    required this.description,
    required this.primaryColor,
    required this.secondaryColor,
    required this.frequency,
  });
}

const List<BrainwaveData> brainwaveModes = [
  BrainwaveData(
    type: BrainwaveType.delta,
    name: 'Delta',
    targetHz: '2.5 Hz',
    state: 'Deep Sleep & Healing',
    description: 'Immune restoration, growth hormone release and cellular repair.',
    primaryColor: Color(0xFF7209B7),
    secondaryColor: Color(0xFF3F37C9),
    frequency: 2.5,
  ),
  BrainwaveData(
    type: BrainwaveType.theta,
    name: 'Theta',
    targetHz: '6.0 Hz',
    state: 'REM & Deep Meditation',
    description: 'Enhanced intuitive insight, memory consolidation & lucid clarity.',
    primaryColor: Color(0xFF00F5D4),
    secondaryColor: Color(0xFF00BBF9),
    frequency: 6.0,
  ),
  BrainwaveData(
    type: BrainwaveType.alpha,
    name: 'Alpha',
    targetHz: '10.0 Hz',
    state: 'Superlearning & Flow',
    description: 'Relaxed alertness, anxiety dissolution and cognitive agility.',
    primaryColor: Color(0xFF52B788),
    secondaryColor: Color(0xFF2D6A4F),
    frequency: 10.0,
  ),
  BrainwaveData(
    type: BrainwaveType.beta,
    name: 'Beta',
    targetHz: '18.0 Hz',
    state: 'Sharp Cognitive Focus',
    description: 'Analytical execution, dynamic problem-solving & executive work.',
    primaryColor: Color(0xFFFF9E00),
    secondaryColor: Color(0xFFFF5400),
    frequency: 18.0,
  ),
  BrainwaveData(
    type: BrainwaveType.gamma,
    name: 'Gamma',
    targetHz: '40.0 Hz',
    state: 'Peak Synchrony',
    description: 'Simultaneous multi-sensory synthesis & high-voltage awareness.',
    primaryColor: Color(0xFFF72585),
    secondaryColor: Color(0xFFB5179E),
    frequency: 40.0,
  ),
];

// ---------------------------------------------------------------------------
// MAIN NAVIGATION WRAPPER (Custom Frosted iOS Dock)
// ---------------------------------------------------------------------------

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    NeuralResonanceScreen(),
    ParticleUniverseScreen(),
    SacredBreathingScreen(),
    CircadianClockScreen(),
    QuantumFlowScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background ambient gradient flare
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00F5D4).withAlpha(35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7B2CBF).withAlpha(45),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Active Screen
          IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          // Floating iOS Bottom Glass Dock
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: _buildFloatingDock(),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingDock() {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFF10141E).withAlpha(220),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(
          color: Colors.white.withAlpha(28),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(160),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _dockItem(0, CupertinoIcons.waveform_path, 'Wave'),
          _dockItem(1, CupertinoIcons.sparkles, 'Quantum'),
          _dockItem(2, CupertinoIcons.wind, 'Breath'),
          _dockItem(3, CupertinoIcons.circle_grid_hex, 'Chrono'),
          _dockItem(4, CupertinoIcons.timer, 'Flow'),
        ],
      ),
    );
  }

  Widget _dockItem(int index, IconData icon, String label) {
    final bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _currentIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00F5D4).withAlpha(35) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? const Color(0xFF00F5D4) : Colors.white54,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? const Color(0xFF00F5D4) : Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. NEURAL RESONANCE (Quantum Waveform Generator)
// ---------------------------------------------------------------------------

class NeuralResonanceScreen extends StatefulWidget {
  const NeuralResonanceScreen({super.key});

  @override
  State<NeuralResonanceScreen> createState() => _NeuralResonanceScreenState();
}

class _NeuralResonanceScreenState extends State<NeuralResonanceScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  int _selectedModeIndex = 2; // Alpha default
  bool _isPlaying = false;
  double _carrierFrequency = 432.0; // Hz Pythagorean Miracle
  double _volume = 0.75;
  int _sessionSeconds = 0;
  Timer? _sessionTimer;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _sessionTimer?.cancel();
    super.dispose();
  }

  void _togglePlayback() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() => _sessionSeconds++);
        });
      } else {
        _sessionTimer?.cancel();
      }
    });
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final activeMode = brainwaveModes[_selectedModeIndex];

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 120),
          children: [
            // Top HUD
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AETHER RESONANCE',
                      style: TextStyle(
                        letterSpacing: 2.5,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: activeMode.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Neural Entrainment',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: activeMode.primaryColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: activeMode.primaryColor.withAlpha(80)),
                  ),
                  child: Text(
                    _isPlaying ? 'ACTIVE • ${_formatDuration(_sessionSeconds)}' : 'STANDBY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: activeMode.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Live Waveform Canvas Card
            Container(
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: const Color(0xFF101420),
                border: Border.all(color: Colors.white.withAlpha(20)),
                boxShadow: [
                  BoxShadow(
                    color: activeMode.primaryColor.withAlpha(25),
                    blurRadius: 30,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  children: [
                    AnimatedBuilder(
                      animation: _waveController,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: WaveformPainter(
                            animationValue: _waveController.value,
                            primaryColor: activeMode.primaryColor,
                            secondaryColor: activeMode.secondaryColor,
                            frequencyFactor: activeMode.frequency,
                            isPlaying: _isPlaying,
                          ),
                          child: const SizedBox.expand(),
                        );
                      },
                    ),
                    Positioned(
                      top: 16,
                      left: 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TARGET DELTA: ${activeMode.targetHz}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: activeMode.primaryColor,
                            ),
                          ),
                          Text(
                            'Carrier: ${_carrierFrequency.toStringAsFixed(0)} Hz Solfeggio',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Play / Pause Master Action Button
            GestureDetector(
              onTap: _togglePlayback,
              child: Container(
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(29),
                  gradient: LinearGradient(
                    colors: [
                      activeMode.primaryColor,
                      activeMode.secondaryColor,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: activeMode.primaryColor.withAlpha(90),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                      color: Colors.black,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _isPlaying ? 'STOP NEURAL SYNCHRONY' : 'ENGAGE NEURAL SYNCHRONY',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Brainwave State Selector Carousel
            const Text(
              'TARGET BRAINWAVE STATE',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: brainwaveModes.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final mode = brainwaveModes[index];
                  final isSel = index == _selectedModeIndex;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedModeIndex = index);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 180,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFF161C2C) : const Color(0xFF0E121B),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isSel ? mode.primaryColor : Colors.white.withAlpha(15),
                          width: isSel ? 1.8 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  mode.name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isSel ? mode.primaryColor : Colors.white70,
                                  ),
                                ),
                              ),
                              Text(
                                mode.targetHz,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: mode.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            mode.state,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Harmonic Modulation & Tuning Sliders
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: const Color(0xFF0F1420),
                border: Border.all(color: Colors.white.withAlpha(16)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Carrier Frequency Tuning',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                      Text(
                        '${_carrierFrequency.toInt()} Hz',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: activeMode.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbColor: activeMode.primaryColor,
                      activeTrackColor: activeMode.primaryColor,
                      inactiveTrackColor: Colors.white12,
                    ),
                    child: Slider(
                      value: _carrierFrequency,
                      min: 174.0,
                      max: 963.0,
                      divisions: 8,
                      onChanged: (val) {
                        setState(() => _carrierFrequency = val);
                      },
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Acoustic Field Intensity',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                      Text(
                        '${(_volume * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: activeMode.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbColor: activeMode.primaryColor,
                      activeTrackColor: activeMode.primaryColor,
                      inactiveTrackColor: Colors.white12,
                    ),
                    child: Slider(
                      value: _volume,
                      min: 0.1,
                      max: 1.0,
                      onChanged: (val) {
                        setState(() => _volume = val);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final double animationValue;
  final Color primaryColor;
  final Color secondaryColor;
  final double frequencyFactor;
  final bool isPlaying;

  WaveformPainter({
    required this.animationValue,
    required this.primaryColor,
    required this.secondaryColor,
    required this.frequencyFactor,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double midY = size.height * 0.55;
    final double amp = isPlaying ? 38.0 : 12.0;

    // Draw background grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withAlpha(12)
      ..strokeWidth = 1.0;
    for (double y = 30; y < size.height; y += 35) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Layer 1: Secondary Harmonic Wave
    final path2 = Path();
    for (double x = 0; x <= size.width; x += 3) {
      final normX = x / size.width;
      final y = midY +
          math.sin((normX * 8 * (frequencyFactor / 8)) + (animationValue * 2 * math.pi * 1.5)) *
              (amp * 0.55) +
          math.cos((normX * 4) + animationValue * math.pi) * 8;
      if (x == 0) {
        path2.moveTo(x, y);
      } else {
        path2.lineTo(x, y);
      }
    }
    final paint2 = Paint()
      ..color = secondaryColor.withAlpha(90)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path2, paint2);

    // Layer 2: Main Primary Harmonic Wave with glow
    final path1 = Path();
    for (double x = 0; x <= size.width; x += 2) {
      final normX = x / size.width;
      final y = midY +
          math.sin((normX * 12 * (frequencyFactor / 6)) + (animationValue * 2 * math.pi * 2.0)) *
              amp *
          math.sin(normX * math.pi); // Taper edges
      if (x == 0) {
        path1.moveTo(x, y);
      } else {
        path1.lineTo(x, y);
      }
    }

    final glowPaint = Paint()
      ..color = primaryColor.withAlpha(60)
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path1, glowPaint);

    final paint1 = Paint()
      ..color = primaryColor
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path1, paint1);
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) => true;
}

// ---------------------------------------------------------------------------
// 2. QUANTUM BIO-PARTICLE FIELD (Interactive Kinetic Physics)
// ---------------------------------------------------------------------------

class ParticleUniverseScreen extends StatefulWidget {
  const ParticleUniverseScreen({super.key});

  @override
  State<ParticleUniverseScreen> createState() => _ParticleUniverseScreenState();
}

class _ParticleUniverseScreenState extends State<ParticleUniverseScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final List<QuantumParticle> _particles = [];
  Offset? _touchPosition;
  bool _isAttractorActive = false;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _initParticles(80);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_updatePhysics)..repeat();
  }

  void _initParticles(int count) {
    _particles.clear();
    for (int i = 0; i < count; i++) {
      _particles.add(
        QuantumParticle(
          x: _random.nextDouble() * 380,
          y: _random.nextDouble() * 700,
          vx: (_random.nextDouble() - 0.5) * 1.8,
          vy: (_random.nextDouble() - 0.5) * 1.8,
          radius: _random.nextDouble() * 2.5 + 1.5,
          color: i % 3 == 0
              ? const Color(0xFF00F5D4)
              : (i % 3 == 1 ? const Color(0xFF7B2CBF) : const Color(0xFFF72585)),
        ),
      );
    }
  }

  void _updatePhysics() {
    for (final p in _particles) {
      if (_isAttractorActive && _touchPosition != null) {
        // Gravitational attractor towards touch
        final dx = _touchPosition!.dx - p.x;
        final dy = _touchPosition!.dy - p.y;
        final dist = math.sqrt(dx * dx + dy * dy).clamp(10.0, 400.0);
        final force = (120.0 / dist).clamp(0.0, 1.8);
        p.vx += (dx / dist) * force * 0.15;
        p.vy += (dy / dist) * force * 0.15;
      }

      p.x += p.vx;
      p.y += p.vy;

      // Friction
      p.vx *= 0.99;
      p.vy *= 0.99;

      // Screen boundary wrap
      if (p.x < 0) p.x = 400;
      if (p.x > 400) p.x = 0;
      if (p.y < 0) p.y = 800;
      if (p.y > 800) p.y = 0;
    }
    setState(() {});
  }

  void _createShockwave(Offset pos) {
    HapticFeedback.mediumImpact();
    for (final p in _particles) {
      final dx = p.x - pos.dx;
      final dy = p.y - pos.dy;
      final dist = math.sqrt(dx * dx + dy * dy).clamp(1.0, 500.0);
      if (dist < 180) {
        final push = (180 - dist) * 0.08;
        p.vx += (dx / dist) * push;
        p.vy += (dy / dist) * push;
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06080D),
      body: Stack(
        children: [
          // Touch gesture listener layer
          GestureDetector(
            onPanStart: (details) {
              setState(() {
                _touchPosition = details.localPosition;
                _isAttractorActive = true;
              });
            },
            onPanUpdate: (details) {
              setState(() {
                _touchPosition = details.localPosition;
              });
            },
            onPanEnd: (_) {
              setState(() => _isAttractorActive = false);
            },
            onDoubleTapDown: (details) {
              _createShockwave(details.localPosition);
            },
            child: CustomPaint(
              painter: ParticleCanvasPainter(
                particles: _particles,
                touchPosition: _touchPosition,
                isAttractorActive: _isAttractorActive,
              ),
              child: const SizedBox.expand(),
            ),
          ),

          // Header Overlay
          Positioned(
            top: 54,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'QUANTUM FIELD',
                      style: TextStyle(
                        letterSpacing: 2.5,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF00F5D4),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Bio-Kinetic Matrix',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'DRAG TO ATTRACT • DOUBLE-TAP BURST',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class QuantumParticle {
  double x;
  double y;
  double vx;
  double vy;
  double radius;
  Color color;

  QuantumParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.color,
  });
}

class ParticleCanvasPainter extends CustomPainter {
  final List<QuantumParticle> particles;
  final Offset? touchPosition;
  final bool isAttractorActive;

  ParticleCanvasPainter({
    required this.particles,
    required this.touchPosition,
    required this.isAttractorActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Constellation network lines between close particles
    final linePaint = Paint()..strokeWidth = 0.8;
    for (int i = 0; i < particles.length; i++) {
      for (int j = i + 1; j < particles.length; j++) {
        final p1 = particles[i];
        final p2 = particles[j];
        final dx = p1.x - p2.x;
        final dy = p1.y - p2.y;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist < 65) {
          final alpha = ((1.0 - (dist / 65)) * 60).toInt();
          linePaint.color = Colors.white.withAlpha(alpha);
          canvas.drawLine(Offset(p1.x, p1.y), Offset(p2.x, p2.y), linePaint);
        }
      }
    }

    // 2. Draw Touch Attractor Ripple
    if (isAttractorActive && touchPosition != null) {
      final ripplePaint = Paint()
        ..color = const Color(0xFF00F5D4).withAlpha(40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(touchPosition!, 55, ripplePaint);
      canvas.drawCircle(touchPosition!, 15, Paint()..color = const Color(0xFF00F5D4).withAlpha(120));
    }

    // 3. Draw Particles
    for (final p in particles) {
      final paint = Paint()..color = p.color;
      canvas.drawCircle(Offset(p.x, p.y), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ParticleCanvasPainter oldDelegate) => true;
}

// ---------------------------------------------------------------------------
// 3. SACRED RESPIRATION & HRV COHERENCE COACH
// ---------------------------------------------------------------------------

class SacredBreathingScreen extends StatefulWidget {
  const SacredBreathingScreen({super.key});

  @override
  State<SacredBreathingScreen> createState() => _SacredBreathingScreenState();
}

class _SacredBreathingScreenState extends State<SacredBreathingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathAnim;
  Timer? _timer;
  int _patternIndex = 0;
  String _currentPhase = 'Inhale';
  int _secondsRemainingInPhase = 4;
  int _completedCycles = 0;
  bool _isActive = false;

  // Patterns: [Inhale, Hold, Exhale, Rest]
  final List<Map<String, dynamic>> _patterns = [
    {
      'title': '4-4-4-4 Box Breathing',
      'subtitle': 'Tactical autonomic nervous equilibrium',
      'durations': [4, 4, 4, 4],
      'phases': ['Inhale', 'Hold', 'Exhale', 'Pause'],
    },
    {
      'title': '4-7-8 Vagus Reset',
      'subtitle': 'Deep parasympathetic sleep induction',
      'durations': [4, 7, 8, 0],
      'phases': ['Inhale', 'Deep Hold', 'Release', ''],
    },
    {
      'title': '5.5s Heart Coherence',
      'subtitle': 'Heart Rate Variability (HRV) alignment',
      'durations': [5, 0, 5, 0],
      'phases': ['Inhale Flow', '', 'Exhale Flow', ''],
    },
  ];

  @override
  void initState() {
    super.initState();
    _breathAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void dispose() {
    _breathAnim.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startBreathing() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isActive = true;
      _runCycle();
    });
  }

  void _stopBreathing() {
    HapticFeedback.mediumImpact();
    _timer?.cancel();
    _breathAnim.stop();
    setState(() {
      _isActive = false;
      _currentPhase = 'Ready';
      _secondsRemainingInPhase = 4;
    });
  }

  void _runCycle() {
    if (!_isActive) return;
    final currentPattern = _patterns[_patternIndex];
    final List<int> durations = currentPattern['durations'];
    final List<String> phases = currentPattern['phases'];

    int phaseIdx = 0;

    void advancePhase() {
      if (!_isActive) return;

      while (durations[phaseIdx] == 0) {
        phaseIdx = (phaseIdx + 1) % 4;
        if (phaseIdx == 0) _completedCycles++;
      }

      final phaseName = phases[phaseIdx];
      final phaseDuration = durations[phaseIdx];

      setState(() {
        _currentPhase = phaseName;
        _secondsRemainingInPhase = phaseDuration;
      });

      HapticFeedback.mediumImpact();

      if (phaseIdx == 0) {
        // Inhale expand
        _breathAnim.duration = Duration(seconds: phaseDuration);
        _breathAnim.forward(from: 0.0);
      } else if (phaseIdx == 2) {
        // Exhale contract
        _breathAnim.duration = Duration(seconds: phaseDuration);
        _breathAnim.reverse(from: 1.0);
      }

      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted || !_isActive) {
          t.cancel();
          return;
        }
        setState(() => _secondsRemainingInPhase--);
        if (_secondsRemainingInPhase <= 0) {
          t.cancel();
          phaseIdx = (phaseIdx + 1) % 4;
          if (phaseIdx == 0) {
            setState(() => _completedCycles++);
          }
          advancePhase();
        }
      });
    }

    advancePhase();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 120),
          children: [
            // Top HUD
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'BIO-RESPIRATION',
                      style: TextStyle(
                        letterSpacing: 2.5,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF00BBF9),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Sacred Coherence',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BBF9).withAlpha(28),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'CYCLES: $_completedCycles',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Color(0xFF00BBF9),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Expanding Sacred Geometry Breathing Sphere
            Center(
              child: SizedBox(
                width: 280,
                height: 280,
                child: AnimatedBuilder(
                  animation: _breathAnim,
                  builder: (context, child) {
                    final scale = 0.5 + (_breathAnim.value * 0.5);
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          painter: SacredGeometryPainter(progress: _breathAnim.value),
                          child: const SizedBox.expand(),
                        ),
                        // Inner pulsing core
                        Container(
                          width: 140 * scale,
                          height: 140 * scale,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFF00F5D4).withAlpha(160),
                                const Color(0xFF00BBF9).withAlpha(40),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        // Status Text
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _isActive ? _currentPhase.toUpperCase() : 'STANDBY',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2.0,
                                color: Colors.white,
                              ),
                            ),
                            if (_isActive) ...[
                              const SizedBox(height: 6),
                              Text(
                                '${_secondsRemainingInPhase}s',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF00F5D4),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Start / Stop Action Button
            GestureDetector(
              onTap: _isActive ? _stopBreathing : _startBreathing,
              child: Container(
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(29),
                  gradient: LinearGradient(
                    colors: _isActive
                        ? [const Color(0xFFF72585), const Color(0xFF7209B7)]
                        : [const Color(0xFF00BBF9), const Color(0xFF00F5D4)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isActive ? const Color(0xFFF72585) : const Color(0xFF00BBF9))
                          .withAlpha(90),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _isActive ? 'END SESSION' : 'BEGIN BIO-COHERENCE',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Breathing Pattern Selector Cards
            const Text(
              'COHERENCE PROTOCOL',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(_patterns.length, (index) {
              final item = _patterns[index];
              final isSel = index == _patternIndex;
              return GestureDetector(
                onTap: () {
                  if (_isActive) _stopBreathing();
                  setState(() => _patternIndex = index);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFF141A28) : const Color(0xFF0D121B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSel ? const Color(0xFF00BBF9) : Colors.white.withAlpha(15),
                      width: isSel ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'],
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isSel ? const Color(0xFF00BBF9) : Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['subtitle'],
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        isSel ? CupertinoIcons.checkmark_alt_circle_fill : CupertinoIcons.circle,
                        color: isSel ? const Color(0xFF00BBF9) : Colors.white24,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class SacredGeometryPainter extends CustomPainter {
  final double progress;

  SacredGeometryPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = 55.0 + (progress * 45.0);

    final linePaint = Paint()
      ..color = const Color(0xFF00BBF9).withAlpha((30 + (progress * 40)).toInt())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Draw 6 concentric overlapping circles (Flower of Life nucleus)
    const petals = 6;
    for (int i = 0; i < petals; i++) {
      final angle = (i * 2 * math.pi) / petals;
      final offset = Offset(
        center.dx + math.cos(angle) * (baseRadius * 0.65),
        center.dy + math.sin(angle) * (baseRadius * 0.65),
      );
      canvas.drawCircle(offset, baseRadius * 0.7, linePaint);
    }

    // Outer boundary ring
    final outerPaint = Paint()
      ..color = const Color(0xFF00F5D4).withAlpha(60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(center, baseRadius * 1.15, outerPaint);
  }

  @override
  bool shouldRepaint(covariant SacredGeometryPainter oldDelegate) => true;
}

// ---------------------------------------------------------------------------
// 4. CHRONOBIOLOGICAL AI CLOCK (Circadian Neuro-Optimization)
// ---------------------------------------------------------------------------

class CircadianClockScreen extends StatelessWidget {
  const CircadianClockScreen({super.key});

  CircadianProfile _calculateCurrentPhase() {
    final now = DateTime.now();
    final hour = now.hour;

    if (hour >= 6 && hour < 9) {
      return const CircadianProfile(
        name: 'Cortisol Awakening',
        energyPercent: 82,
        phase: 'Photonic & Dopamine Activation',
        primaryAdvice: 'View 10 min of morning sunlight; delay caffeine by 90 minutes.',
        color: Color(0xFFFFB703),
      );
    } else if (hour >= 9 && hour < 12) {
      return const CircadianProfile(
        name: 'Executive Brain Peak',
        energyPercent: 96,
        phase: 'Prefrontal High-Cognitive Bandwidth',
        primaryAdvice: 'Tackle high-friction tasks, deep analytical thinking and coding.',
        color: Color(0xFF00F5D4),
      );
    } else if (hour >= 12 && hour < 14) {
      return const CircadianProfile(
        name: 'Post-Prandial Pause',
        energyPercent: 64,
        phase: 'Autonomic Digest & Reset',
        primaryAdvice: 'Take a 20 min walk or theta meditation; avoid heavy carbs.',
        color: Color(0xFF48CAE4),
      );
    } else if (hour >= 14 && hour < 17) {
      return const CircadianProfile(
        name: 'Creative Divergence',
        energyPercent: 88,
        phase: 'Associative Memory & Brainstorming',
        primaryAdvice: 'Optimal time for creative architecture, writing and collaborative syncs.',
        color: Color(0xFF7B2CBF),
      );
    } else if (hour >= 17 && hour < 20) {
      return const CircadianProfile(
        name: 'Neuromuscular Peak',
        energyPercent: 90,
        phase: 'Optimal Body Temp & Reaction Velocity',
        primaryAdvice: 'Peak window for intense physical training and high motor coordination.',
        color: Color(0xFFFF5400),
      );
    } else if (hour >= 20 && hour < 23) {
      return const CircadianProfile(
        name: 'Melatonin Surge',
        energyPercent: 50,
        phase: 'Dim-Light Twilight Wind-Down',
        primaryAdvice: 'Block blue light, lower ambient temp to 19°C, engage in soft alpha audio.',
        color: Color(0xFFF72585),
      );
    } else {
      return const CircadianProfile(
        name: 'Glymphatic Cleansing',
        energyPercent: 25,
        phase: 'Deep Cellular & Memory Detox',
        primaryAdvice: 'Cerebrospinal fluid clears metabolic waste; prioritize deep REM and slow-wave sleep.',
        color: Color(0xFF3A0CA3),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _calculateCurrentPhase();
    final now = DateTime.now();

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 120),
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CHRONOBIOLOGY AI',
                      style: TextStyle(
                        letterSpacing: 2.5,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: profile.color,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Circadian Rhythm',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Circular 24-Hour Circadian Dial
            Center(
              child: SizedBox(
                width: 250,
                height: 250,
                child: CustomPaint(
                  painter: CircadianDialPainter(
                    currentHour: now.hour + (now.minute / 60.0),
                    accentColor: profile.color,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${profile.energyPercent}%',
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            color: profile.color,
                          ),
                        ),
                        const Text(
                          'COGNITIVE CAPACITY',
                          style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Active Biological Phase Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: const Color(0xFF101522),
                border: Border.all(color: profile.color.withAlpha(70)),
                boxShadow: [
                  BoxShadow(
                    color: profile.color.withAlpha(20),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: profile.color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        profile.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: profile.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    profile.phase,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 8),
                  const Text(
                    'OPTIMAL NEURO-PROTOCOL:',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                      color: Colors.white38,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.primaryAdvice,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CircadianProfile {
  final String name;
  final int energyPercent;
  final String phase;
  final String primaryAdvice;
  final Color color;

  const CircadianProfile({
    required this.name,
    required this.energyPercent,
    required this.phase,
    required this.primaryAdvice,
    required this.color,
  });
}

class CircadianDialPainter extends CustomPainter {
  final double currentHour;
  final Color accentColor;

  CircadianDialPainter({
    required this.currentHour,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16;

    // Track Background
    final trackPaint = Paint()
      ..color = Colors.white.withAlpha(20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(center, radius, trackPaint);

    // Glowing Arc based on current hour in 24h
    final sweepAngle = (currentHour / 24.0) * 2 * math.pi;
    final arcPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 12;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      arcPaint,
    );

    // 24h hour tick marks
    final tickPaint = Paint()..strokeWidth = 1.5;
    for (int h = 0; h < 24; h += 3) {
      final angle = (h / 24.0) * 2 * math.pi - (math.pi / 2);
      final p1 = Offset(
        center.dx + math.cos(angle) * (radius - 12),
        center.dy + math.sin(angle) * (radius - 12),
      );
      final p2 = Offset(
        center.dx + math.cos(angle) * (radius - 20),
        center.dy + math.sin(angle) * (radius - 20),
      );
      tickPaint.color = Colors.white.withAlpha(60);
      canvas.drawLine(p1, p2, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CircadianDialPainter oldDelegate) => true;
}

// ---------------------------------------------------------------------------
// 5. QUANTUM FLOW SPRINT (HUD Deep Work Timer)
// ---------------------------------------------------------------------------

class QuantumFlowScreen extends StatefulWidget {
  const QuantumFlowScreen({super.key});

  @override
  State<QuantumFlowScreen> createState() => _QuantumFlowScreenState();
}

class _QuantumFlowScreenState extends State<QuantumFlowScreen> {
  int _targetMinutes = 45;
  int _remainingSeconds = 45 * 60;
  bool _isRunning = false;
  Timer? _timer;
  int _distractionCounter = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleTimer() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isRunning = !_isRunning;
      if (_isRunning) {
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) return;
          if (_remainingSeconds > 0) {
            setState(() => _remainingSeconds--);
          } else {
            _timer?.cancel();
            setState(() => _isRunning = false);
            HapticFeedback.heavyImpact();
          }
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  void _resetTimer(int minutes) {
    _timer?.cancel();
    setState(() {
      _targetMinutes = minutes;
      _remainingSeconds = minutes * 60;
      _isRunning = false;
      _distractionCounter = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    final progress = 1.0 - (_remainingSeconds / (_targetMinutes * 60));

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 120),
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'DEEP WORK HUD',
                      style: TextStyle(
                        letterSpacing: 2.5,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF00F5D4),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Quantum Sprint',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _distractionCounter++);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF72585).withAlpha(30),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF72585).withAlpha(80)),
                    ),
                    child: Text(
                      'LOG DISTRACTION: $_distractionCounter',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF72585),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Circular HUD Timer
            Center(
              child: SizedBox(
                width: 250,
                height: 250,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 230,
                      height: 230,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 10,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF00F5D4)),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _isRunning ? 'FLOW PROTOCOL ENGAGED' : 'READY TO ENGAGE',
                          style: const TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00F5D4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Play / Pause Toggle
            GestureDetector(
              onTap: _toggleTimer,
              child: Container(
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(29),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00F5D4), Color(0xFF00BBF9)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00F5D4).withAlpha(80),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _isRunning ? 'PAUSE FLOW SPRINT' : 'START FLOW SPRINT',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Sprint Interval Presets
            const Text(
              'ULTRADIAN CYCLE PRESETS',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _presetButton(25, '25m Pomodoro'),
                const SizedBox(width: 10),
                _presetButton(45, '45m Deep Sprint'),
                const SizedBox(width: 10),
                _presetButton(90, '90m Ultradian'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetButton(int minutes, String label) {
    final isSel = _targetMinutes == minutes;
    return Expanded(
      child: GestureDetector(
        onTap: () => _resetTimer(minutes),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSel ? const Color(0xFF151D2C) : const Color(0xFF0D121B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSel ? const Color(0xFF00F5D4) : Colors.white.withAlpha(15),
            ),
          ),
          child: Column(
            children: [
              Text(
                '${minutes}m',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isSel ? const Color(0xFF00F5D4) : Colors.white,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label.split(' ').last,
                style: const TextStyle(fontSize: 10, color: Colors.white54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
