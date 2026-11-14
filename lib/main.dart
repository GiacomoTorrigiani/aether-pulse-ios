import 'dart:async';
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
  runApp(const VoxMindApp());
}

class VoxMindApp extends StatelessWidget {
  const VoxMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoxMind AI — Call Co-Pilot',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF090C12),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF7C4DFF),
          surface: Color(0xFF131924),
        ),
      ),
      home: const VoxMindMainScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// DATA MODELS
// ---------------------------------------------------------------------------

class CallDialogueLine {
  final String speaker; // "Tu" or contact name
  final String text;
  final String time;
  final bool isUser;

  const CallDialogueLine({
    required this.speaker,
    required this.text,
    required this.time,
    required this.isUser,
  });
}

class SmartQuestionPrompt {
  final String question;
  final String rationale;
  final String tag;
  final Color tagColor;

  const SmartQuestionPrompt({
    required this.question,
    required this.rationale,
    required this.tag,
    required this.tagColor,
  });
}

class MindMapNode {
  final String id;
  final String label;
  final String category; // Topic, Decision, Action, Risk
  Offset position;
  final Color color;
  final List<String> connectedTo;

  MindMapNode({
    required this.id,
    required this.label,
    required this.category,
    required this.position,
    required this.color,
    required this.connectedTo,
  });
}

class CallScenario {
  final String id;
  final String contactName;
  final String role;
  final String company;
  final String avatarInitials;
  final Color avatarColor;
  final List<CallDialogueLine> transcript;
  final List<SmartQuestionPrompt> suggestedQuestions;
  final List<MindMapNode> mindMapNodes;
  final String executiveSummary;
  final List<String> decisions;
  final List<String> actionItems;
  final int sentimentScore; // 0-100

  const CallScenario({
    required this.id,
    required this.contactName,
    required this.role,
    required this.company,
    required this.avatarInitials,
    required this.avatarColor,
    required this.transcript,
    required this.suggestedQuestions,
    required this.mindMapNodes,
    required this.executiveSummary,
    required this.decisions,
    required this.actionItems,
    required this.sentimentScore,
  });
}

// Pre-packaged Scenarios
final List<CallScenario> scenarios = [
  CallScenario(
    id: '1',
    contactName: 'Marco Rossi',
    role: 'Product Lead',
    company: 'FinTech Dynamics',
    avatarInitials: 'MR',
    avatarColor: const Color(0xFF00E5FF),
    sentimentScore: 88,
    executiveSummary:
        'Allineamento strategico sul rilascio MVP entro metà Dicembre. Marco ha confermato un budget flessibile del +15% per integrare il modulo di firma biometrica su iOS. Richiede la documentazione tecnica delle API entro giovedì sera.',
    decisions: [
      'Lancio MVP confermato per il 15 Dicembre.',
      'Integrazione FaceID / Biometric auth approvata con extra budget 15%.',
      'Testflight beta privato limitato ai primi 50 utenti selezionati.',
    ],
    actionItems: [
      'Inviare specifiche API e architettura entro Giovedì 18:00.',
      'Fissare call tecnica con il team backend per Lunedì ore 10:00.',
      'Predisporre account Apple Developer per upload Testflight.',
    ],
    transcript: [
      CallDialogueLine(
        speaker: 'Marco Rossi',
        text: 'Ciao! Grazie della disponibilità. Volevo allinearci sulla timeline della release iOS.',
        time: '00:12',
        isUser: false,
      ),
      CallDialogueLine(
        speaker: 'Tu',
        text: 'Certamente Marco, stiamo chiudendo i test del core grafico a 120 FPS.',
        time: '00:25',
        isUser: true,
      ),
      CallDialogueLine(
        speaker: 'Marco Rossi',
        text: 'Ottimo! Ma se volessimo includere subito anche l\'autenticazione biometrica FaceID, riusciamo entro il 15 Dicembre?',
        time: '00:48',
        isUser: false,
      ),
      CallDialogueLine(
        speaker: 'Tu',
        text: 'Sì, ma richiede circa 4 giorni di lavoro aggiuntivo sull\'infrastruttura di sicurezza.',
        time: '01:05',
        isUser: true,
      ),
      CallDialogueLine(
        speaker: 'Marco Rossi',
        text: 'Perfetto, posso sbloccare un extra budget del 15% per coprirlo. Mandami solo le specifiche entro giovedì sera!',
        time: '01:30',
        isUser: false,
      ),
    ],
    suggestedQuestions: [
      SmartQuestionPrompt(
        question: 'Come gestiamo il fallback per utenti con FaceID disattivato o PIN locale?',
        rationale: 'Evita colli di bottiglia nelle linee guida di revisione App Store.',
        tag: 'Sicurezza iOS',
        tagColor: Color(0xFF00E5FF),
      ),
      SmartQuestionPrompt(
        question: 'Il +15% di budget copre anche i costi del penetration test esterno?',
        rationale: 'Chiarisce subito i confini dell\'impegno finanziario pattuito a voce.',
        tag: 'Negoziazione Budget',
        tagColor: Color(0xFFFFB703),
      ),
      SmartQuestionPrompt(
        question: 'Vuoi che coordini io il setup dell\'ambiente di staging col vostro DevOps?',
        rationale: 'Accelera il rilascio evitando ritardi di comunicazione interna.',
        tag: 'Operativo',
        tagColor: Color(0xFF00E676),
      ),
    ],
    mindMapNodes: [
      MindMapNode(
        id: 'root',
        label: 'Release iOS MVP',
        category: 'Topic',
        position: const Offset(190, 180),
        color: const Color(0xFF00E5FF),
        connectedTo: ['faceid', 'deadline', 'budget', 'actions'],
      ),
      MindMapNode(
        id: 'faceid',
        label: 'Biometric FaceID',
        category: 'Feature',
        position: const Offset(80, 80),
        color: const Color(0xFF7C4DFF),
        connectedTo: ['budget'],
      ),
      MindMapNode(
        id: 'budget',
        label: '+15% Extra Budget',
        category: 'Decision',
        position: const Offset(300, 90),
        color: const Color(0xFFFFB703),
        connectedTo: [],
      ),
      MindMapNode(
        id: 'deadline',
        label: 'Scadenza 15 Dicembre',
        category: 'Milestone',
        position: const Offset(80, 290),
        color: const Color(0xFFFF0080),
        connectedTo: [],
      ),
      MindMapNode(
        id: 'actions',
        label: 'Invio API entro Giovedì',
        category: 'Action Item',
        position: const Offset(295, 280),
        color: const Color(0xFF00E676),
        connectedTo: [],
      ),
    ],
  ),
  CallScenario(
    id: '2',
    contactName: 'Elena Valli',
    role: 'Senior Tech Recruiter',
    company: 'ScaleUp Ventures',
    avatarInitials: 'EV',
    avatarColor: const Color(0xFFFF0080),
    sentimentScore: 94,
    executiveSummary:
        'Intervista conoscitiva per ruolo di Staff Mobile Architect. Forte interesse per l\'esperienza su architetture reattive e AI on-device. Proposta di colloquio tecnico finale con il CTO per mercoledì prossimo con range 85k-95k.',
    decisions: [
      'Superata la prima fase di screening conoscitivo.',
      'Fissato colloquio tecnico finale con il CTO per Mercoledì alle 15:00.',
    ],
    actionItems: [
      'Inviare portfolio GitHub con repo Aether & VoxMind.',
      'Rivedere architettura di threading e isolate Dart per il deep dive.',
    ],
    transcript: [
      CallDialogueLine(
        speaker: 'Elena Valli',
        text: 'Ho visto i tuoi progetti recenti in Flutter e Impeller, sono rimasta davvero colpita.',
        time: '00:15',
        isUser: false,
      ),
      CallDialogueLine(
        speaker: 'Tu',
        text: 'Grazie Elena, mi concentro su interfacce ad altissima frequenza e zero latenza con AI.',
        time: '00:32',
        isUser: true,
      ),
      CallDialogueLine(
        speaker: 'Elena Valli',
        text: 'È esattamente ciò che cerca il nostro CTO. Possiamo fissare una sessione di architettura per mercoledì?',
        time: '00:55',
        isUser: false,
      ),
    ],
    suggestedQuestions: [
      SmartQuestionPrompt(
        question: 'Il team mobile lavora con cicli di release settimanali o bi-settimanali?',
        rationale: 'Dimostra maturità sui processi di CI/CD e qualità del codice.',
        tag: 'Cultura Tech',
        tagColor: Color(0xFF00E5FF),
      ),
      SmartQuestionPrompt(
        question: 'Qual è l\'attuale debito tecnico sul rendering su dispositivi più datati?',
        rationale: 'Ti posiziona come problem solver ad alto impatto.',
        tag: 'Architettura',
        tagColor: Color(0xFF7C4DFF),
      ),
    ],
    mindMapNodes: [
      MindMapNode(
        id: 'root',
        label: 'Colloquio Staff Arch',
        category: 'Topic',
        position: const Offset(190, 180),
        color: const Color(0xFFFF0080),
        connectedTo: ['cto', 'range', 'portfolio'],
      ),
      MindMapNode(
        id: 'cto',
        label: 'Tech Deep Dive CTO',
        category: 'Decision',
        position: const Offset(90, 90),
        color: const Color(0xFF00E5FF),
        connectedTo: [],
      ),
      MindMapNode(
        id: 'range',
        label: 'Comp: 85k - 95k',
        category: 'Decision',
        position: const Offset(290, 100),
        color: const Color(0xFF00E676),
        connectedTo: [],
      ),
      MindMapNode(
        id: 'portfolio',
        label: 'Inviare Repo GitHub',
        category: 'Action Item',
        position: const Offset(190, 300),
        color: const Color(0xFFFFB703),
        connectedTo: [],
      ),
    ],
  ),
];

// ---------------------------------------------------------------------------
// MAIN SHELL & TOP DOCK
// ---------------------------------------------------------------------------

class VoxMindMainScreen extends StatefulWidget {
  const VoxMindMainScreen({super.key});

  @override
  State<VoxMindMainScreen> createState() => _VoxMindMainScreenState();
}

class _VoxMindMainScreenState extends State<VoxMindMainScreen> {
  int _currentTabIndex = 0;
  int _activeScenarioIndex = 0;
  bool _isCallActive = true;
  int _callDurationSeconds = 94;
  Timer? _callTimer;

  @override
  void initState() {
    super.initState();
    _startCallTimer();
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_isCallActive) {
        setState(() => _callDurationSeconds++);
      }
    });
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }

  void _toggleCallStatus() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isCallActive = !_isCallActive;
    });
  }

  void _switchScenario(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _activeScenarioIndex = index;
      _callDurationSeconds = 75;
    });
  }

  String _formatDuration(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final scenario = scenarios[_activeScenarioIndex];

    return Scaffold(
      body: Stack(
        children: [
          // Background ambient gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.4),
                  radius: 1.3,
                  colors: [
                    Color(0xFF101726),
                    Color(0xFF070A0F),
                  ],
                ),
              ),
            ),
          ),

          // Main Tabs
          IndexedStack(
            index: _currentTabIndex,
            children: [
              LiveCallCoPilotTab(
                scenario: scenario,
                isCallActive: _isCallActive,
                callDuration: _formatDuration(_callDurationSeconds),
                onToggleCall: _toggleCallStatus,
                onSwitchScenario: _switchScenario,
                currentScenarioIndex: _activeScenarioIndex,
              ),
              MindMapTab(scenario: scenario),
              ExecutiveSummaryTab(scenario: scenario),
              ContactIntelligenceTab(
                scenarios: scenarios,
                activeScenarioIndex: _activeScenarioIndex,
                onSelectScenario: (idx) {
                  _switchScenario(idx);
                  setState(() => _currentTabIndex = 0);
                },
              ),
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
        color: const Color(0xFF0D121D).withAlpha(235),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: Colors.white.withAlpha(25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(190),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _dockItem(0, CupertinoIcons.phone_arrow_up_right, 'Live Call'),
          _dockItem(1, CupertinoIcons.flowchart, 'Mappa'),
          _dockItem(2, CupertinoIcons.doc_text_fill, 'Sunto AI'),
          _dockItem(3, CupertinoIcons.person_crop_circle_badge_checkmark, 'Contatti'),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00E5FF).withAlpha(35) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? const Color(0xFF00E5FF) : Colors.white54,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.normal,
                color: isSelected ? const Color(0xFF00E5FF) : Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. LIVE CALL CO-PILOT TAB
// ---------------------------------------------------------------------------

class LiveCallCoPilotTab extends StatelessWidget {
  final CallScenario scenario;
  final bool isCallActive;
  final String callDuration;
  final VoidCallback onToggleCall;
  final Function(int) onSwitchScenario;
  final int currentScenarioIndex;

  const LiveCallCoPilotTab({
    super.key,
    required this.scenario,
    required this.isCallActive,
    required this.callDuration,
    required this.onToggleCall,
    required this.onSwitchScenario,
    required this.currentScenarioIndex,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ListView(
          padding: const EdgeInsets.only(top: 14, bottom: 120),
          children: [
            // Top HUD Banner
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCallActive ? const Color(0xFF00E676) : Colors.redAccent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isCallActive ? 'AI CO-PILOT ATTIVO • $callDuration' : 'CHIAMATA TERMINATA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: isCallActive ? const Color(0xFF00E676) : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    final next = (currentScenarioIndex + 1) % scenarios.length;
                    onSwitchScenario(next);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'CAMBIA CHIAMATA',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white70),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Caller Card (iOS Style Call Header)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: const Color(0xFF111726),
                border: Border.all(color: Colors.white.withAlpha(20)),
                boxShadow: [
                  BoxShadow(
                    color: scenario.avatarColor.withAlpha(20),
                    blurRadius: 30,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scenario.avatarColor.withAlpha(40),
                      border: Border.all(color: scenario.avatarColor, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        scenario.avatarInitials,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: scenario.avatarColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scenario.contactName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${scenario.role} • ${scenario.company}',
                          style: const TextStyle(fontSize: 12, color: Colors.white60),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E676).withAlpha(25),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Intesa: ${scenario.sentimentScore}%',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00E676),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onToggleCall,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCallActive ? Colors.redAccent : const Color(0xFF00E676),
                      ),
                      child: Icon(
                        isCallActive ? CupertinoIcons.phone_down_fill : CupertinoIcons.phone_fill,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // LIVE SMART QUESTIONS PROMPTER (La vera svolta!)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'DOMANDE SUGGERITE IN TEMPO REALE',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF00E5FF),
                  ),
                ),
                Icon(CupertinoIcons.sparkles, size: 14, color: Color(0xFF00E5FF)),
              ],
            ),
            const SizedBox(height: 10),
            ...scenario.suggestedQuestions.map((q) => _buildQuestionCard(context, q)),

            const SizedBox(height: 24),

            // LIVE TRANSCRIPT FEED
            const Text(
              'TRASCRIZIONE E ANALISI LIVE',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 12),
            ...scenario.transcript.map((line) => _buildTranscriptBubble(line)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(BuildContext context, SmartQuestionPrompt prompt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101726),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: prompt.tagColor.withAlpha(70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: prompt.tagColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  prompt.tag.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: prompt.tagColor,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: prompt.question));
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Domanda copiata negli appunti!'),
                      duration: Duration(milliseconds: 1200),
                    ),
                  );
                },
                child: const Icon(CupertinoIcons.doc_on_doc, size: 16, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '"${prompt.question}"',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              height: 1.3,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '💡 Perché farla: ${prompt.rationale}',
            style: const TextStyle(fontSize: 11, color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptBubble(CallDialogueLine line) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: line.isUser ? const Color(0xFF142038) : const Color(0xFF0F1522),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: line.isUser ? const Color(0xFF00E5FF).withAlpha(40) : Colors.white.withAlpha(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                line.speaker.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: line.isUser ? const Color(0xFF00E5FF) : const Color(0xFFFF0080),
                ),
              ),
              Text(
                line.time,
                style: const TextStyle(fontSize: 10, color: Colors.white38),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            line.text,
            style: const TextStyle(fontSize: 13, height: 1.35, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. INTERACTIVE CONCEPT MIND MAP TAB (Mappa Concettuale Automatica)
// ---------------------------------------------------------------------------

class MindMapTab extends StatefulWidget {
  final CallScenario scenario;

  const MindMapTab({super.key, required this.scenario});

  @override
  State<MindMapTab> createState() => _MindMapTabState();
}

class _MindMapTabState extends State<MindMapTab> {
  MindMapNode? _selectedNode;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          // Header Overlay
          Positioned(
            top: 14,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'KNOWLEDGE GRAPH LIVE',
                  style: TextStyle(
                    letterSpacing: 2.2,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF00E5FF),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Mappa Concettuale: ${widget.scenario.contactName}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tocca un nodo per ispezionare collegamenti e decisioni.',
                  style: TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
          ),

          // Interactive Canvas Layer
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(top: 80, bottom: 100),
              child: GestureDetector(
                onTapUp: (details) {
                  for (final node in widget.scenario.mindMapNodes) {
                    final dist = (details.localPosition - node.position).distance;
                    if (dist < 45) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedNode = node);
                      return;
                    }
                  }
                  setState(() => _selectedNode = null);
                },
                child: CustomPaint(
                  painter: MindMapCanvasPainter(
                    nodes: widget.scenario.mindMapNodes,
                    selectedNode: _selectedNode,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),

          // Selected Node Detail Card at Bottom
          if (_selectedNode != null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 110,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF121828),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _selectedNode!.color, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: _selectedNode!.color.withAlpha(40),
                      blurRadius: 25,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _selectedNode!.color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedNode!.category.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: _selectedNode!.color,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedNode!.label,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _selectedNode = null),
                      child: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MindMapCanvasPainter extends CustomPainter {
  final List<MindMapNode> nodes;
  final MindMapNode? selectedNode;

  MindMapCanvasPainter({required this.nodes, required this.selectedNode});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Connection Lines between nodes
    final linePaint = Paint()
      ..color = Colors.white.withAlpha(35)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    for (final node in nodes) {
      for (final targetId in node.connectedTo) {
        final target = nodes.firstWhere((n) => n.id == targetId, orElse: () => node);
        if (target != node) {
          // Curved path
          final path = Path()
            ..moveTo(node.position.dx, node.position.dy)
            ..quadraticBezierTo(
              (node.position.dx + target.position.dx) / 2,
              (node.position.dy + target.position.dy) / 2 - 20,
              target.position.dx,
              target.position.dy,
            );
          canvas.drawPath(path, linePaint);
        }
      }
    }

    // 2. Draw Nodes
    for (final node in nodes) {
      final isSel = node == selectedNode;

      // Selection Glow Aura
      if (isSel) {
        final aura = Paint()
          ..color = node.color.withAlpha(90)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0;
        canvas.drawCircle(node.position, 48, aura);
      }

      // Outer glow
      final glow = Paint()
        ..color = node.color.withAlpha(50)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(node.position, 40, glow);

      // Node Body
      final body = Paint()..color = const Color(0xFF101625);
      canvas.drawCircle(node.position, 38, body);

      final border = Paint()
        ..color = node.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(node.position, 38, border);

      // Node Text
      final textSpan = TextSpan(
        text: node.label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 68);

      textPainter.paint(
        canvas,
        Offset(
          node.position.dx - (textPainter.width / 2),
          node.position.dy - (textPainter.height / 2),
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant MindMapCanvasPainter oldDelegate) => true;
}

// ---------------------------------------------------------------------------
// 3. EXECUTIVE SUMMARY & ACTION ITEMS TAB
// ---------------------------------------------------------------------------

class ExecutiveSummaryTab extends StatelessWidget {
  final CallScenario scenario;

  const ExecutiveSummaryTab({super.key, required this.scenario});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ListView(
          padding: const EdgeInsets.only(top: 14, bottom: 120),
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'AI DEBRIEF AUTOMATICO',
                      style: TextStyle(
                        letterSpacing: 2.2,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF00E676),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Sunto & Azioni Future',
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
                    final report = '''
📌 SUNTO CHIAMATA - ${scenario.contactName} (${scenario.company})
${scenario.executiveSummary}

✅ DECISIONI:
${scenario.decisions.map((d) => '- $d').join('\n')}

🚀 DA FARE (ACTION ITEMS):
${scenario.actionItems.map((a) => '- $a').join('\n')}
''';
                    Clipboard.setData(ClipboardData(text: report));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sunto completo copiato per WhatsApp o Email!'),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withAlpha(30),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF00E676)),
                    ),
                    child: Row(
                      children: const [
                        Icon(CupertinoIcons.share, size: 14, color: Color(0xFF00E676)),
                        SizedBox(width: 6),
                        Text(
                          'CONDIVIDI',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00E676),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Executive Summary Paragraph
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF101726),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withAlpha(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SINTESI ESECUTIVA DELLA CONVERSAZIONE',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                      color: Colors.white38,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    scenario.executiveSummary,
                    style: const TextStyle(fontSize: 14, height: 1.45, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Decisions Made
            const Text(
              'DECISIONI PRESE NELLA CHIAMATA',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.4,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFFB703),
              ),
            ),
            const SizedBox(height: 10),
            ...scenario.decisions.map(
              (d) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF101726),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFB703).withAlpha(40)),
                ),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.checkmark_seal_fill, size: 18, color: Color(0xFFFFB703)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        d,
                        style: const TextStyle(fontSize: 13, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action Items
            const Text(
              'COSE DA FARE (ACTION ITEMS & DEADLINES)',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.4,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00E5FF),
              ),
            ),
            const SizedBox(height: 10),
            ...scenario.actionItems.map(
              (a) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF101726),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF00E5FF).withAlpha(40)),
                ),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.arrow_right_circle_fill, size: 18, color: Color(0xFF00E5FF)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        a,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ],
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
// 4. CONTACT INTELLIGENCE & DOSSIER TAB
// ---------------------------------------------------------------------------

class ContactIntelligenceTab extends StatelessWidget {
  final List<CallScenario> scenarios;
  final int activeScenarioIndex;
  final Function(int) onSelectScenario;

  const ContactIntelligenceTab({
    super.key,
    required this.scenarios,
    required this.activeScenarioIndex,
    required this.onSelectScenario,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ListView(
          padding: const EdgeInsets.only(top: 14, bottom: 120),
          children: [
            // Title
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'RELAZIONI & MEMORIA STORICA',
                  style: TextStyle(
                    letterSpacing: 2.2,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7C4DFF),
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Dossier Contatti',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Contacts List
            ...List.generate(scenarios.length, (idx) {
              final item = scenarios[idx];
              final isCurrent = idx == activeScenarioIndex;

              return GestureDetector(
                onTap: () => onSelectScenario(idx),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isCurrent ? const Color(0xFF141F35) : const Color(0xFF0E1320),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isCurrent ? const Color(0xFF00E5FF) : Colors.white.withAlpha(15),
                      width: isCurrent ? 1.6 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: item.avatarColor.withAlpha(35),
                          border: Border.all(color: item.avatarColor),
                        ),
                        child: Center(
                          child: Text(
                            item.avatarInitials,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: item.avatarColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.contactName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.role} • ${item.company}',
                              style: const TextStyle(fontSize: 12, color: Colors.white54),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Ultima sintesi: ${item.decisions.first}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: item.avatarColor),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isCurrent ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.chevron_right,
                        color: isCurrent ? const Color(0xFF00E5FF) : Colors.white30,
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
