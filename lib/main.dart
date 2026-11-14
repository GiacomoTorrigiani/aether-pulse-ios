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
  runApp(const SynapseLifeOSApp());
}

class SynapseLifeOSApp extends StatelessWidget {
  const SynapseLifeOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Synapse: Kinetic Life OS',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF030508),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00F5D4),
          secondary: Color(0xFF7928CA),
          surface: Color(0xFF0C1018),
        ),
      ),
      home: const SynapseMainScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// GLOBAL STATE & DATA MODELS
// ---------------------------------------------------------------------------

enum NodeCategory { deepWork, bioHealth, microHabit, breakthrough }

class OrbitalNode {
  final String id;
  String title;
  NodeCategory category;
  double orbitRadius; // Distance from central sun
  double angle; // Current orbital angle in radians
  double speed; // Orbital velocity
  double mass; // Size and gravitational weight
  Color glowColor;
  bool isCompleted;
  int xpValue;

  OrbitalNode({
    required this.id,
    required this.title,
    required this.category,
    required this.orbitRadius,
    required this.angle,
    required this.speed,
    required this.mass,
    required this.glowColor,
    this.isCompleted = false,
    required this.xpValue,
  });
}

class ThoughtBubble {
  final String id;
  String text;
  double x;
  double y;
  double vx;
  double vy;
  double radius;
  Color color;

  ThoughtBubble({
    required this.id,
    required this.text,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.color,
  });
}

// ---------------------------------------------------------------------------
// MAIN CONTAINER & FLOATING CYBER HUD
// ---------------------------------------------------------------------------

class SynapseMainScreen extends StatefulWidget {
  const SynapseMainScreen({super.key});

  @override
  State<SynapseMainScreen> createState() => _SynapseMainScreenState();
}

class _SynapseMainScreenState extends State<SynapseMainScreen> {
  int _currentTabIndex = 0;
  int _userXp = 480;
  int _userLevel = 3;
  final int _streakDays = 12;

  // Active Orbital Nodes
  final List<OrbitalNode> _nodes = [
    OrbitalNode(
      id: '1',
      title: 'Deep Coding Sprint',
      category: NodeCategory.deepWork,
      orbitRadius: 105,
      angle: 0.4,
      speed: 0.008,
      mass: 26,
      glowColor: const Color(0xFF00F5D4),
      xpValue: 150,
    ),
    OrbitalNode(
      id: '2',
      title: 'Cold Hydration 1L',
      category: NodeCategory.bioHealth,
      orbitRadius: 145,
      angle: 2.1,
      speed: 0.006,
      mass: 18,
      glowColor: const Color(0xFF00BBF9),
      xpValue: 50,
    ),
    OrbitalNode(
      id: '3',
      title: 'Architect Breakthrough',
      category: NodeCategory.breakthrough,
      orbitRadius: 185,
      angle: 4.2,
      speed: 0.004,
      mass: 32,
      glowColor: const Color(0xFFFF0080),
      xpValue: 250,
    ),
    OrbitalNode(
      id: '4',
      title: 'Micro Meditation 5m',
      category: NodeCategory.microHabit,
      orbitRadius: 75,
      angle: 1.2,
      speed: 0.012,
      mass: 16,
      glowColor: const Color(0xFFFFB703),
      xpValue: 80,
    ),
    OrbitalNode(
      id: '5',
      title: 'Evening Zero-Light',
      category: NodeCategory.bioHealth,
      orbitRadius: 160,
      angle: 5.5,
      speed: 0.005,
      mass: 20,
      glowColor: const Color(0xFF7928CA),
      xpValue: 100,
    ),
  ];

  void _addXp(int amount) {
    setState(() {
      _userXp += amount;
      if (_userXp >= _userLevel * 300) {
        _userLevel++;
        HapticFeedback.heavyImpact();
      }
    });
  }

  void _completeNode(String id) {
    final idx = _nodes.indexWhere((n) => n.id == id);
    if (idx != -1 && !_nodes[idx].isCompleted) {
      HapticFeedback.heavyImpact();
      setState(() {
        _nodes[idx].isCompleted = true;
        _addXp(_nodes[idx].xpValue);
      });
    }
  }

  void _addNewNode(String title, NodeCategory category, double urgency) {
    Color color;
    switch (category) {
      case NodeCategory.deepWork:
        color = const Color(0xFF00F5D4);
        break;
      case NodeCategory.bioHealth:
        color = const Color(0xFF00BBF9);
        break;
      case NodeCategory.breakthrough:
        color = const Color(0xFFFF0080);
        break;
      case NodeCategory.microHabit:
        color = const Color(0xFFFFB703);
        break;
    }

    final rand = math.Random();
    setState(() {
      _nodes.add(
        OrbitalNode(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          category: category,
          orbitRadius: 80 + (1.0 - urgency) * 110,
          angle: rand.nextDouble() * 2 * math.pi,
          speed: 0.005 + rand.nextDouble() * 0.007,
          mass: 16 + (urgency * 14),
          glowColor: color,
          xpValue: (100 * urgency).toInt() + 50,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Cosmic Dust & Ambient Bioluminescence
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.2),
                  radius: 1.2,
                  colors: [
                    Color(0xFF0C1425),
                    Color(0xFF04060A),
                  ],
                ),
              ),
            ),
          ),

          // Main Pages
          IndexedStack(
            index: _currentTabIndex,
            children: [
              OrbitalRealityTab(
                nodes: _nodes,
                onCompleteNode: _completeNode,
                onAddNode: _openAddNodeSheet,
                userXp: _userXp,
                userLevel: _userLevel,
                streakDays: _streakDays,
              ),
              const NeuralIgnitionTab(),
              const BioBatteryTab(),
              const ThoughtVoidTab(),
            ],
          ),

          // Floating Glass Capsule Navigation Bar
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
        color: const Color(0xFF080D16).withAlpha(225),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: Colors.white.withAlpha(25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(180),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _dockItem(0, CupertinoIcons.circle_grid_hex, 'Orbit'),
          _dockItem(1, CupertinoIcons.bolt_fill, 'Ignition'),
          _dockItem(2, CupertinoIcons.battery_charging, 'Bio-Energy'),
          _dockItem(3, CupertinoIcons.bubble_left_bubble_right, 'Void'),
        ],
      ),
    );
  }

  Widget _dockItem(int index, IconData icon, String label) {
    final bool isSelected = _currentTabIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _currentTabIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                color: isSelected ? const Color(0xFF00F5D4) : Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAddNodeSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddOrbitalNodeModal(onAdd: _addNewNode),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. ORBITAL REALITY TAB (Gravitational Life Matrix)
// ---------------------------------------------------------------------------

class OrbitalRealityTab extends StatefulWidget {
  final List<OrbitalNode> nodes;
  final Function(String) onCompleteNode;
  final VoidCallback onAddNode;
  final int userXp;
  final int userLevel;
  final int streakDays;

  const OrbitalRealityTab({
    super.key,
    required this.nodes,
    required this.onCompleteNode,
    required this.onAddNode,
    required this.userXp,
    required this.userLevel,
    required this.streakDays,
  });

  @override
  State<OrbitalRealityTab> createState() => _OrbitalRealityTabState();
}

class _OrbitalRealityTabState extends State<OrbitalRealityTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _orbitController;
  OrbitalNode? _selectedNode;
  final List<SupernovaParticle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_tickOrbit)..repeat();
  }

  void _tickOrbit() {
    for (final node in widget.nodes) {
      node.angle += node.speed;
      if (node.angle > 2 * math.pi) node.angle -= 2 * math.pi;
    }

    // Update supernova particles
    for (int i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.x += p.vx;
      p.y += p.vy;
      p.life -= 0.035;
      if (p.life <= 0) {
        _particles.removeAt(i);
      }
    }
    setState(() {});
  }

  void _triggerSupernova(Offset center, Color color) {
    for (int i = 0; i < 45; i++) {
      final angle = _random.nextDouble() * 2 * math.pi;
      final speed = _random.nextDouble() * 6.5 + 2.0;
      _particles.add(
        SupernovaParticle(
          x: center.dx,
          y: center.dy,
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed,
          color: color,
          life: 1.0,
        ),
      );
    }
  }

  @override
  void dispose() {
    _orbitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final center = Offset(size.width / 2, size.height * 0.44);

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          // Top HUD Bar (Level, XP, Streak)
          Positioned(
            top: 14,
            left: 20,
            right: 20,
            child: _buildTopHud(),
          ),

          // Central Gravity Simulation Canvas
          Positioned.fill(
            child: GestureDetector(
              onTapUp: (details) {
                // Check if user tapped a node
                for (final node in widget.nodes) {
                  final nodeX = center.dx + math.cos(node.angle) * node.orbitRadius;
                  final nodeY = center.dy + math.sin(node.angle) * node.orbitRadius;
                  final dist = (details.localPosition - Offset(nodeX, nodeY)).distance;
                  if (dist < node.mass + 15) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedNode = node);
                    return;
                  }
                }
                setState(() => _selectedNode = null);
              },
              child: CustomPaint(
                painter: OrbitalMatrixPainter(
                  center: center,
                  nodes: widget.nodes,
                  selectedNode: _selectedNode,
                  particles: _particles,
                ),
              ),
            ),
          ),

          // Central Sun Tap Action (Core Focus)
          Positioned(
            left: center.dx - 38,
            top: center.dy - 38,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                _triggerSupernova(center, const Color(0xFF00F5D4));
              },
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [
                      Color(0xFF00F5D4),
                      Color(0xFF00BBF9),
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00F5D4).withAlpha(120),
                      blurRadius: 35,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    CupertinoIcons.flame_fill,
                    color: Colors.black,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),

          // Floating Add Action Button
          Positioned(
            top: 76,
            right: 20,
            child: GestureDetector(
              onTap: widget.onAddNode,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00F5D4).withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF00F5D4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(CupertinoIcons.add, size: 14, color: Color(0xFF00F5D4)),
                    SizedBox(width: 4),
                    Text(
                      'SPAWN ORB',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Color(0xFF00F5D4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Inspector Card at Bottom if a Node is Selected
          if (_selectedNode != null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 110,
              child: _buildNodeInspectorCard(center),
            ),
        ],
      ),
    );
  }

  Widget _buildTopHud() {
    final nextLevelXp = widget.userLevel * 300;
    final progress = (widget.userXp % 300) / 300.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1422).withAlpha(200),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00F5D4).withAlpha(30),
                  border: Border.all(color: const Color(0xFF00F5D4)),
                ),
                child: Center(
                  child: Text(
                    'L${widget.userLevel}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF00F5D4),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SYNAPTIC MASTERY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${widget.userXp} / $nextLevelXp XP',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 110,
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.05, 1.0),
                      minHeight: 4,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF00F5D4)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB703).withAlpha(25),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFB703).withAlpha(80)),
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.flame_fill, size: 16, color: Color(0xFFFFB703)),
                const SizedBox(width: 6),
                Text(
                  '${widget.streakDays}d FLOW',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFFB703),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeInspectorCard(Offset center) {
    final node = _selectedNode!;
    final nodeX = center.dx + math.cos(node.angle) * node.orbitRadius;
    final nodeY = center.dy + math.sin(node.angle) * node.orbitRadius;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF101728),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: node.glowColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: node.glowColor.withAlpha(50),
            blurRadius: 30,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                node.category.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                  color: node.glowColor,
                ),
              ),
              Text(
                '+${node.xpValue} XP',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: node.glowColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            node.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    widget.onCompleteNode(node.id);
                    _triggerSupernova(Offset(nodeX, nodeY), node.glowColor);
                    setState(() => _selectedNode = null);
                  },
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        colors: [node.glowColor, node.glowColor.withAlpha(180)],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        node.isCompleted ? 'ABSORBED • HARVESTED' : 'ABSORB ORB INTO CORE',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => setState(() => _selectedNode = null),
                child: Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(15),
                  ),
                  child: const Icon(CupertinoIcons.xmark, color: Colors.white70, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SupernovaParticle {
  double x;
  double y;
  double vx;
  double vy;
  Color color;
  double life;

  SupernovaParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.life,
  });
}

class OrbitalMatrixPainter extends CustomPainter {
  final Offset center;
  final List<OrbitalNode> nodes;
  final OrbitalNode? selectedNode;
  final List<SupernovaParticle> particles;

  OrbitalMatrixPainter({
    required this.center,
    required this.nodes,
    required this.selectedNode,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Concentric Orbital Rings
    final ringPaint = Paint()
      ..color = Colors.white.withAlpha(14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final rings = [75.0, 105.0, 145.0, 185.0];
    for (final r in rings) {
      canvas.drawCircle(center, r, ringPaint);
    }

    // 2. Draw Gravitational Rays connecting Sun to Nodes
    for (final node in nodes) {
      final nodeX = center.dx + math.cos(node.angle) * node.orbitRadius;
      final nodeY = center.dy + math.sin(node.angle) * node.orbitRadius;

      final rayPaint = Paint()
        ..color = node.glowColor.withAlpha(node.isCompleted ? 15 : 45)
        ..strokeWidth = 1.0;
      canvas.drawLine(center, Offset(nodeX, nodeY), rayPaint);
    }

    // 3. Draw Nodes (Planet Orbs)
    for (final node in nodes) {
      final nodeX = center.dx + math.cos(node.angle) * node.orbitRadius;
      final nodeY = center.dy + math.sin(node.angle) * node.orbitRadius;
      final pos = Offset(nodeX, nodeY);

      if (node == selectedNode) {
        // Selection Aura
        final selPaint = Paint()
          ..color = node.glowColor.withAlpha(80)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0;
        canvas.drawCircle(pos, node.mass + 8, selPaint);
      }

      // Outer Glow
      final glowPaint = Paint()
        ..color = node.glowColor.withAlpha(node.isCompleted ? 40 : 120)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(pos, node.mass, glowPaint);

      // Inner Core
      final corePaint = Paint()
        ..color = node.isCompleted ? Colors.white24 : node.glowColor;
      canvas.drawCircle(pos, node.mass * 0.7, corePaint);
    }

    // 4. Draw Supernova Particles
    for (final p in particles) {
      final partPaint = Paint()
        ..color = p.color.withAlpha((p.life * 255).toInt());
      canvas.drawCircle(Offset(p.x, p.y), 2.5 * p.life, partPaint);
    }
  }

  @override
  bool shouldRepaint(covariant OrbitalMatrixPainter oldDelegate) => true;
}

// ---------------------------------------------------------------------------
// 2. NEURAL IGNITION (120s Procrastination Destroyer)
// ---------------------------------------------------------------------------

class NeuralIgnitionTab extends StatefulWidget {
  const NeuralIgnitionTab({super.key});

  @override
  State<NeuralIgnitionTab> createState() => _NeuralIgnitionTabState();
}

class _NeuralIgnitionTabState extends State<NeuralIgnitionTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  int _secondsLeft = 120;
  bool _isRunning = false;
  Timer? _timer;
  final TextEditingController _taskInput = TextEditingController(
    text: 'Write the first 3 lines of code',
  );

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    _taskInput.dispose();
    super.dispose();
  }

  void _startIgnition() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isRunning = true;
      _secondsLeft = 120;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
        if (_secondsLeft % 10 == 0) HapticFeedback.lightImpact();
      } else {
        _timer?.cancel();
        setState(() => _isRunning = false);
        HapticFeedback.heavyImpact();
      }
    });
  }

  void _abortIgnition() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _secondsLeft = 120;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = (120 - _secondsLeft) / 120.0;

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
                      'FRICTION BREAKER',
                      style: TextStyle(
                        letterSpacing: 2.5,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFF0080),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '120s Neural Ignition',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0080).withAlpha(25),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'ZERO INERTIA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Color(0xFFFF0080),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Scientific Prompt Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1524),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withAlpha(15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'THE 120-SECOND NEURO-PRINCIPLE:',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                      color: Colors.white38,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'The brain craves avoidance until task-initiation inertia is broken. Commit to doing ONLY 120 seconds of the micro-step below. Dopamine will handle the rest.',
                    style: TextStyle(fontSize: 12, height: 1.4, color: Colors.white70),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _taskInput,
                    enabled: !_isRunning,
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black38,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(CupertinoIcons.bolt, color: Color(0xFFFF0080)),
                      hintText: 'Define your tiny 120s action...',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // Giant Hyper-Pulsing Core Gauge
            Center(
              child: SizedBox(
                width: 250,
                height: 250,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 240,
                      height: 240,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 10,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation(Color(0xFFFF0080)),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final scale = _isRunning ? 1.0 + (_pulseController.value * 0.08) : 1.0;
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 170,
                            height: 170,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFFFF0080).withAlpha(_isRunning ? 120 : 40),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${_secondsLeft}s',
                                    style: const TextStyle(
                                      fontSize: 52,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    _isRunning ? 'MOMENTUM FIRING' : 'READY TO ENGAGE',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                      color: Color(0xFFFF0080),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 36),

            // Master Ignition Trigger Button
            GestureDetector(
              onTap: _isRunning ? _abortIgnition : _startIgnition,
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: LinearGradient(
                    colors: _isRunning
                        ? [const Color(0xFF7928CA), const Color(0xFFFF0080)]
                        : [const Color(0xFFFF0080), const Color(0xFFFFB703)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF0080).withAlpha(90),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _isRunning ? 'ABORT IGNITION' : 'FIRE 120s IGNITION ENGINE',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1.5,
                    ),
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

// ---------------------------------------------------------------------------
// 3. BIO-BATTERY TAB (Circadian Capacity Predictor)
// ---------------------------------------------------------------------------

class BioBatteryTab extends StatelessWidget {
  const BioBatteryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;

    int batteryLevel = 85;
    String status = 'OPTIMAL FOCUS';
    Color glowColor = const Color(0xFF00F5D4);

    if (hour >= 6 && hour < 11) {
      batteryLevel = 92;
      status = 'CORTISOL SURGE';
      glowColor = const Color(0xFFFFB703);
    } else if (hour >= 11 && hour < 14) {
      batteryLevel = 68;
      status = 'POST-LUNCH ADENOSINE';
      glowColor = const Color(0xFF00BBF9);
    } else if (hour >= 14 && hour < 18) {
      batteryLevel = 88;
      status = 'SECOND PEAK';
      glowColor = const Color(0xFF00F5D4);
    } else if (hour >= 18 && hour < 22) {
      batteryLevel = 54;
      status = 'TWILIGHT RESTORATION';
      glowColor = const Color(0xFFFF0080);
    } else {
      batteryLevel = 28;
      status = 'GLYMPHATIC RECHARGE';
      glowColor = const Color(0xFF7928CA);
    }

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 120),
          children: [
            // Top Title
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CIRCADIAN TELEMETRY',
                  style: TextStyle(
                    letterSpacing: 2.5,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: glowColor,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Biological Battery',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Giant Futuristic Battery Cell
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: const Color(0xFF0D1322),
                border: Border.all(color: glowColor.withAlpha(60)),
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withAlpha(25),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: glowColor,
                        ),
                      ),
                      Text(
                        '$batteryLevel%',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: glowColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: batteryLevel / 100.0,
                      minHeight: 18,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation(glowColor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Circadian Timeline Recommendation Cards
            const Text(
              'CHRONO-PROTOCOL TODAY',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 12),
            _protocolCard(
              '09:00 - 12:00',
              'Deep Cognitive Window',
              'Prefrontal cortex is at maximum throughput. Reserve for coding, design and hard logic.',
              const Color(0xFF00F5D4),
            ),
            _protocolCard(
              '13:00 - 14:30',
              'Adenosine Dip (Rest)',
              'Avoid high-stakes meetings. Take a 20 min walk or theta frequency reset.',
              const Color(0xFF00BBF9),
            ),
            _protocolCard(
              '15:00 - 17:30',
              'Creative Synthesis',
              'Associative memory spikes. Brainstorm, map architecture, communicate vision.',
              const Color(0xFFFF0080),
            ),
            _protocolCard(
              '21:00 - 23:00',
              'Blue-Light Quarantine',
              'Melatonin onset. Zero screen brightness, prepare biological recovery.',
              const Color(0xFF7928CA),
            ),
          ],
        ),
      ),
    );
  }

  Widget _protocolCard(String time, String title, String desc, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1422),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                time,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: color,
                ),
              ),
              Icon(CupertinoIcons.waveform, size: 14, color: color),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: const TextStyle(fontSize: 12, color: Colors.white54, height: 1.3),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. THOUGHT VOID TAB (Interactive Spatial Memory Bubbles)
// ---------------------------------------------------------------------------

class ThoughtVoidTab extends StatefulWidget {
  const ThoughtVoidTab({super.key});

  @override
  State<ThoughtVoidTab> createState() => _ThoughtVoidTabState();
}

class _ThoughtVoidTabState extends State<ThoughtVoidTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _physicsController;
  final List<ThoughtBubble> _bubbles = [
    ThoughtBubble(
      id: '1',
      text: 'AI Agent Architecture',
      x: 100,
      y: 200,
      vx: 1.2,
      vy: 0.8,
      radius: 46,
      color: const Color(0xFF00F5D4),
    ),
    ThoughtBubble(
      id: '2',
      text: 'Buy High-Magnesium',
      x: 250,
      y: 320,
      vx: -0.9,
      vy: 1.1,
      radius: 42,
      color: const Color(0xFFFFB703),
    ),
    ThoughtBubble(
      id: '3',
      text: 'Fix iOS Impeller Bug',
      x: 180,
      y: 460,
      vx: 0.7,
      vy: -1.3,
      radius: 48,
      color: const Color(0xFFFF0080),
    ),
    ThoughtBubble(
      id: '4',
      text: 'Call Marco for Startup',
      x: 80,
      y: 390,
      vx: -1.1,
      vy: -0.6,
      radius: 44,
      color: const Color(0xFF00BBF9),
    ),
  ];

  final TextEditingController _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    _physicsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_updateBubblePhysics)..repeat();
  }

  void _updateBubblePhysics() {
    for (final b in _bubbles) {
      b.x += b.vx;
      b.y += b.vy;

      // Friction
      b.vx *= 0.995;
      b.vy *= 0.995;

      // Wall bounce
      if (b.x < b.radius || b.x > 380 - b.radius) b.vx *= -1;
      if (b.y < 120 + b.radius || b.y > 660 - b.radius) b.vy *= -1;
    }
    setState(() {});
  }

  void _popBubble(String id) {
    HapticFeedback.mediumImpact();
    setState(() {
      _bubbles.removeWhere((b) => b.id == id);
    });
  }

  void _addThought() {
    if (_input.text.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    final rand = math.Random();
    final colors = [
      const Color(0xFF00F5D4),
      const Color(0xFFFF0080),
      const Color(0xFF00BBF9),
      const Color(0xFFFFB703),
    ];
    setState(() {
      _bubbles.add(
        ThoughtBubble(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: _input.text.trim(),
          x: 150 + rand.nextDouble() * 80,
          y: 250 + rand.nextDouble() * 100,
          vx: (rand.nextDouble() - 0.5) * 3.0,
          vy: (rand.nextDouble() - 0.5) * 3.0,
          radius: 44,
          color: colors[rand.nextInt(colors.length)],
        ),
      );
      _input.clear();
    });
  }

  @override
  void dispose() {
    _physicsController.dispose();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          // Header & Thought Input Field
          Positioned(
            top: 16,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'KINETIC VOID',
                  style: TextStyle(
                    letterSpacing: 2.5,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF00BBF9),
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Thought Evaporator',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        style: const TextStyle(fontSize: 14, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Dump raw thought or task...',
                          filled: true,
                          fillColor: const Color(0xFF0F1626),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onSubmitted: (_) => _addThought(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _addThought,
                      child: Container(
                        height: 48,
                        width: 48,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF00BBF9), Color(0xFF00F5D4)],
                          ),
                        ),
                        child: const Icon(CupertinoIcons.arrow_up, color: Colors.black, size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Floating Physics Bubbles
          ..._bubbles.map((b) {
            return Positioned(
              left: b.x - b.radius,
              top: b.y - b.radius,
              child: GestureDetector(
                onTap: () => _popBubble(b.id),
                onPanUpdate: (details) {
                  b.x += details.delta.dx;
                  b.y += details.delta.dy;
                  b.vx = details.delta.dx * 0.4;
                  b.vy = details.delta.dy * 0.4;
                },
                child: Container(
                  width: b.radius * 2,
                  height: b.radius * 2,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: b.color.withAlpha(45),
                    border: Border.all(color: b.color, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: b.color.withAlpha(50),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      b.text,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ADD NODE MODAL SHEET
// ---------------------------------------------------------------------------

class AddOrbitalNodeModal extends StatefulWidget {
  final Function(String, NodeCategory, double) onAdd;

  const AddOrbitalNodeModal({super.key, required this.onAdd});

  @override
  State<AddOrbitalNodeModal> createState() => _AddOrbitalNodeModalState();
}

class _AddOrbitalNodeModalState extends State<AddOrbitalNodeModal> {
  final TextEditingController _ctrl = TextEditingController();
  NodeCategory _cat = NodeCategory.deepWork;
  double _urgency = 0.8;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF101625),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SPAWN ORBITAL NODE',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00F5D4),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            style: const TextStyle(fontSize: 16, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter mission or habit name...',
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'ORBITAL CATEGORY',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
              color: Colors.white38,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: NodeCategory.values.map((c) {
              final isSel = _cat == c;
              return ChoiceChip(
                label: Text(c.name.toUpperCase()),
                selected: isSel,
                onSelected: (_) => setState(() => _cat = c),
                selectedColor: const Color(0xFF00F5D4),
                labelStyle: TextStyle(
                  color: isSel ? Colors.black : Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Gravitational Urgency',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
              Text(
                '${(_urgency * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00F5D4),
                ),
              ),
            ],
          ),
          Slider(
            value: _urgency,
            min: 0.1,
            max: 1.0,
            activeColor: const Color(0xFF00F5D4),
            onChanged: (v) => setState(() => _urgency = v),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              if (_ctrl.text.trim().isNotEmpty) {
                widget.onAdd(_ctrl.text.trim(), _cat, _urgency);
                Navigator.pop(context);
              }
            },
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(27),
                gradient: const LinearGradient(
                  colors: [Color(0xFF00F5D4), Color(0xFF00BBF9)],
                ),
              ),
              child: const Center(
                child: Text(
                  'INJECT INTO GRAVITY MATRIX',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
