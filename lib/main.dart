import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

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
        scaffoldBackgroundColor: const Color(0xFF080C14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF7C4DFF),
          surface: Color(0xFF111726),
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
  final String speaker;
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
  final String category;
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
  String contactName;
  String role;
  String company;
  String phone;
  String avatarInitials;
  Color avatarColor;
  List<CallDialogueLine> transcript;
  List<SmartQuestionPrompt> suggestedQuestions;
  List<MindMapNode> mindMapNodes;
  String executiveSummary;
  List<String> decisions;
  List<String> actionItems;
  int sentimentScore;

  CallScenario({
    required this.id,
    required this.contactName,
    required this.role,
    required this.company,
    this.phone = '+39 340 123 4567',
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

// ---------------------------------------------------------------------------
// MAIN CONTAINER & AUDIO SYNTHESIZER CONTROLLER
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
  int _callDurationSeconds = 85;
  Timer? _callTimer;

  // Real Audio Engine (Text-to-Speech & Voice Player)
  final FlutterTts _flutterTts = FlutterTts();
  bool _isAudioPlaying = false;
  int _currentSpokenIndex = 0;

  late List<CallScenario> _scenarios;

  @override
  void initState() {
    super.initState();
    _initScenarios();
    _initTts();
    _startCallTimer();
  }

  void _initScenarios() {
    _scenarios = [
      CallScenario(
        id: '1',
        contactName: 'Marco Rossi',
        role: 'Product Lead',
        company: 'FinTech Dynamics',
        phone: '+39 349 987 6543',
        avatarInitials: 'MR',
        avatarColor: const Color(0xFF00E5FF),
        sentimentScore: 88,
        executiveSummary:
            'Allineamento sul rilascio MVP entro metà Dicembre. Marco ha confermato un extra budget del 15% per integrare il modulo biometrico FaceID. Richiede le specifiche API entro giovedì sera.',
        decisions: [
          'Rilascio MVP iOS confermato per il 15 Dicembre.',
          'Extra budget del 15% approvato per FaceID.',
          'Testflight beta chiuso ai primi 50 utenti.',
        ],
        actionItems: [
          'Inviare specifiche API entro Giovedì ore 18:00.',
          'Fissare sync con team backend per Lunedì ore 10:00.',
        ],
        transcript: [
          const CallDialogueLine(
            speaker: 'Marco Rossi',
            text: 'Ciao Giacomo! Volevo allinearci sulla timeline per la release iOS.',
            time: '00:12',
            isUser: false,
          ),
          const CallDialogueLine(
            speaker: 'Tu',
            text: 'Ciao Marco, stiamo chiudendo i test del rendering grafico a 120 FPS.',
            time: '00:25',
            isUser: true,
          ),
          const CallDialogueLine(
            speaker: 'Marco Rossi',
            text: 'Ottimo! Se includiamo subito anche FaceID, ce la facciamo per il 15 Dicembre?',
            time: '00:48',
            isUser: false,
          ),
          const CallDialogueLine(
            speaker: 'Tu',
            text: 'Sì, ma richiede 4 giorni di lavoro aggiuntivo sull\'infrastruttura di sicurezza.',
            time: '01:05',
            isUser: true,
          ),
          const CallDialogueLine(
            speaker: 'Marco Rossi',
            text: 'Perfetto, posso approvare un extra budget del 15%. Mandami le specifiche entro giovedì!',
            time: '01:25',
            isUser: false,
          ),
        ],
        suggestedQuestions: [
          const SmartQuestionPrompt(
            question: 'Come gestiamo il fallback per utenti con FaceID disattivato o PIN?',
            rationale: 'Evita colli di bottiglia nelle linee guida di revisione Apple.',
            tag: 'Sicurezza iOS',
            tagColor: Color(0xFF00E5FF),
          ),
          const SmartQuestionPrompt(
            question: 'Il +15% di budget copre anche il costo del penetration test esterno?',
            rationale: 'Chiarisce subito i confini dell\'accordo finanziario preso a voce.',
            tag: 'Budget',
            tagColor: Color(0xFFFFB703),
          ),
          const SmartQuestionPrompt(
            question: 'Vuoi che coordini io il setup dell\'ambiente di staging col vostro team?',
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
            label: 'Invio API Giovedì',
            category: 'Action Item',
            position: const Offset(295, 280),
            color: const Color(0xFF00E676),
            connectedTo: [],
          ),
        ],
      ),
    ];
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("it-IT");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);

    _flutterTts.setCompletionHandler(() {
      if (!mounted) return;
      final scenario = _scenarios[_activeScenarioIndex];
      if (_isAudioPlaying && _currentSpokenIndex < scenario.transcript.length - 1) {
        setState(() => _currentSpokenIndex++);
        _speakCurrentLine();
      } else {
        setState(() => _isAudioPlaying = false);
      }
    });

    _flutterTts.setErrorHandler((msg) {
      if (!mounted) return;
      setState(() => _isAudioPlaying = false);
    });
  }

  void _speakCurrentLine() async {
    final scenario = _scenarios[_activeScenarioIndex];
    if (_currentSpokenIndex >= scenario.transcript.length) return;
    final line = scenario.transcript[_currentSpokenIndex];
    await _flutterTts.speak(line.text);
  }

  void _playEntireConversation() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isAudioPlaying = true;
      _currentSpokenIndex = 0;
    });
    _speakCurrentLine();
  }

  void _stopAudio() async {
    HapticFeedback.lightImpact();
    await _flutterTts.stop();
    setState(() => _isAudioPlaying = false);
  }

  void _speakSpecificText(String text) async {
    HapticFeedback.selectionClick();
    await _flutterTts.stop();
    setState(() => _isAudioPlaying = true);
    await _flutterTts.speak(text);
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
    _flutterTts.stop();
    super.dispose();
  }

  void _toggleCallStatus() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isCallActive = !_isCallActive;
      if (!_isCallActive) _stopAudio();
    });
  }

  void _switchScenario(int index) {
    HapticFeedback.selectionClick();
    _stopAudio();
    setState(() {
      _activeScenarioIndex = index;
      _callDurationSeconds = 60;
      _isCallActive = true;
    });
  }

  // Aggiungi un nuovo contatto personalizzato
  void _addNewCustomContact(
    String name,
    String role,
    String company,
    String phone,
    String callTopic,
  ) {
    HapticFeedback.heavyImpact();
    final initials = name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
    final colors = [
      const Color(0xFF00E5FF),
      const Color(0xFF00E676),
      const Color(0xFFFFB703),
      const Color(0xFFFF0080),
      const Color(0xFF7C4DFF),
    ];
    final color = colors[_scenarios.length % colors.length];

    final newScenario = CallScenario(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      contactName: name,
      role: role,
      company: company,
      phone: phone,
      avatarInitials: initials.isEmpty ? 'CT' : initials,
      avatarColor: color,
      sentimentScore: 90,
      executiveSummary:
          'Conversazione strategica con $name su "$callTopic". Sono stati definiti i passaggi chiave operativi e le prossime scadenze di allineamento.',
      decisions: [
        'Accordo confermato per procedere su "$callTopic".',
        'Definita la roadmap operativa per i prossimi giorni.',
      ],
      actionItems: [
        'Condividere bozza riassuntiva via WhatsApp/Email.',
        'Pianificare follow-up telefonico di controllo.',
      ],
      transcript: [
        CallDialogueLine(
          speaker: name,
          text: 'Ciao! Grazie per la chiamata. Volevo confrontarmi subito su $callTopic.',
          time: '00:08',
          isUser: false,
        ),
        CallDialogueLine(
          speaker: 'Tu',
          text: 'Certamente, sono a completa disposizione. Qual è la priorità principale?',
          time: '00:20',
          isUser: true,
        ),
        CallDialogueLine(
          speaker: name,
          text: 'La priorità è chiudere i dettagli operativi senza intoppi entro questa settimana.',
          time: '00:40',
          isUser: false,
        ),
      ],
      suggestedQuestions: [
        SmartQuestionPrompt(
          question: 'Qual è il termine perentorio entro cui dobbiamo dare conferma?',
          rationale: 'Fissa confini temporali precisi evitando fraintendimenti.',
          tag: 'Timeline',
          tagColor: color,
        ),
        const SmartQuestionPrompt(
          question: 'Ci sono altri decisori o persone che devono validare questo passaggio?',
          rationale: 'Mappa subito tutti gli stakeholder coinvolti.',
          tag: 'Stakeholder',
          tagColor: Color(0xFFFFB703),
        ),
      ],
      mindMapNodes: [
        MindMapNode(
          id: 'root',
          label: callTopic,
          category: 'Topic',
          position: const Offset(190, 180),
          color: color,
          connectedTo: ['node1', 'node2'],
        ),
        MindMapNode(
          id: 'node1',
          label: 'Dettagli $name',
          category: 'Contatto',
          position: const Offset(90, 90),
          color: const Color(0xFF00E5FF),
          connectedTo: [],
        ),
        MindMapNode(
          id: 'node2',
          label: 'Priorità Settimana',
          category: 'Action Item',
          position: const Offset(290, 100),
          color: const Color(0xFF00E676),
          connectedTo: [],
        ),
      ],
    );

    setState(() {
      _scenarios.add(newScenario);
      _activeScenarioIndex = _scenarios.length - 1;
      _currentTabIndex = 0; // Torna alla Live Call
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Contatto "$name" aggiunto con successo alla rubrica VoxMind!'),
        backgroundColor: color,
      ),
    );
  }

  String _formatDuration(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final scenario = _scenarios[_activeScenarioIndex];

    return Scaffold(
      body: Stack(
        children: [
          // Background ambient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.4),
                  radius: 1.3,
                  colors: [
                    Color(0xFF0E1626),
                    Color(0xFF06090F),
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
                isAudioPlaying: _isAudioPlaying,
                currentSpokenIndex: _currentSpokenIndex,
                onPlayAllAudio: _playEntireConversation,
                onStopAudio: _stopAudio,
                onSpeakText: _speakSpecificText,
                onOpenAddContact: _openAddContactModal,
              ),
              MindMapTab(scenario: scenario),
              ExecutiveSummaryTab(scenario: scenario),
              ContactIntelligenceTab(
                scenarios: _scenarios,
                activeScenarioIndex: _activeScenarioIndex,
                onSelectScenario: _switchScenario,
                onOpenAddContact: _openAddContactModal,
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
        color: const Color(0xFF0C111C).withAlpha(235),
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
          _dockItem(3, CupertinoIcons.person_2_fill, 'Rubrica'),
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

  void _openAddContactModal() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddCustomContactSheet(onAdd: _addNewCustomContact),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. LIVE CALL CO-PILOT TAB (With Real Voice Audio Player)
// ---------------------------------------------------------------------------

class LiveCallCoPilotTab extends StatelessWidget {
  final CallScenario scenario;
  final bool isCallActive;
  final String callDuration;
  final VoidCallback onToggleCall;
  final bool isAudioPlaying;
  final int currentSpokenIndex;
  final VoidCallback onPlayAllAudio;
  final VoidCallback onStopAudio;
  final Function(String) onSpeakText;
  final VoidCallback onOpenAddContact;

  const LiveCallCoPilotTab({
    super.key,
    required this.scenario,
    required this.isCallActive,
    required this.callDuration,
    required this.onToggleCall,
    required this.isAudioPlaying,
    required this.currentSpokenIndex,
    required this.onPlayAllAudio,
    required this.onStopAudio,
    required this.onSpeakText,
    required this.onOpenAddContact,
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
            // Top HUD Bar
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
                  onTap: onOpenAddContact,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withAlpha(25),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF00E5FF)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(CupertinoIcons.person_add_solid, size: 12, color: Color(0xFF00E5FF)),
                        SizedBox(width: 4),
                        Text(
                          '+ MIO CONTATTO',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF00E5FF)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Caller Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: const Color(0xFF101625),
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
                        const SizedBox(height: 3),
                        Text(
                          scenario.phone,
                          style: const TextStyle(fontSize: 11, color: Colors.white38),
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
            const SizedBox(height: 14),

            // REAL AUDIO PLAYER CONTROL (Sintesi Vocale Attiva)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isAudioPlaying ? const Color(0xFF00E5FF).withAlpha(30) : const Color(0xFF0E1422),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isAudioPlaying ? const Color(0xFF00E5FF) : Colors.white.withAlpha(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isAudioPlaying ? CupertinoIcons.speaker_3_fill : CupertinoIcons.speaker_slash_fill,
                    color: isAudioPlaying ? const Color(0xFF00E5FF) : Colors.white54,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAudioPlaying ? 'RIPRODUZIONE AUDIO VOCALE ATTIVA' : 'AUDIO VOCE IN STANDBY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: isAudioPlaying ? const Color(0xFF00E5FF) : Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Sintesi vocale in italiano direttamente dallo speaker.',
                          style: TextStyle(fontSize: 10, color: Colors.white38),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: isAudioPlaying ? onStopAudio : onPlayAllAudio,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isAudioPlaying ? Colors.redAccent : const Color(0xFF00E5FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        isAudioPlaying ? 'STOP AUDIO' : 'ASCOLTA CHIAMATA',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // LIVE SMART QUESTIONS PROMPTER
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

            const SizedBox(height: 20),

            // LIVE TRANSCRIPT FEED WITH AUDIO TRIGGERS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'TRASCRIZIONE & VOCE IN DIRETTA',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w800,
                    color: Colors.white38,
                  ),
                ),
                Text(
                  'Tocca un fumetto per ascoltare',
                  style: TextStyle(fontSize: 10, color: Color(0xFF00E5FF)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...List.generate(scenario.transcript.length, (idx) {
              final line = scenario.transcript[idx];
              final isBeingSpoken = isAudioPlaying && currentSpokenIndex == idx;
              return _buildTranscriptBubble(line, isBeingSpoken);
            }),
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
              Row(
                children: [
                  GestureDetector(
                    onTap: () => onSpeakText(prompt.question),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withAlpha(15),
                      ),
                      child: const Icon(CupertinoIcons.volume_up, size: 16, color: Color(0xFF00E5FF)),
                    ),
                  ),
                  const SizedBox(width: 8),
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

  Widget _buildTranscriptBubble(CallDialogueLine line, bool isBeingSpoken) {
    return GestureDetector(
      onTap: () => onSpeakText(line.text),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isBeingSpoken
              ? const Color(0xFF00E5FF).withAlpha(35)
              : (line.isUser ? const Color(0xFF142038) : const Color(0xFF0F1522)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isBeingSpoken
                ? const Color(0xFF00E5FF)
                : (line.isUser ? const Color(0xFF00E5FF).withAlpha(40) : Colors.white.withAlpha(12)),
            width: isBeingSpoken ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
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
                    if (isBeingSpoken) ...[
                      const SizedBox(width: 8),
                      const Icon(CupertinoIcons.waveform, size: 12, color: Color(0xFF00E5FF)),
                    ],
                  ],
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. INTERACTIVE CONCEPT MIND MAP TAB
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
          // Header
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
                  'Mappa: ${widget.scenario.contactName}',
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

          // Canvas Layer
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

          // Bottom Details
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
    // 1. Lines
    final linePaint = Paint()
      ..color = Colors.white.withAlpha(35)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    for (final node in nodes) {
      for (final targetId in node.connectedTo) {
        final target = nodes.firstWhere((n) => n.id == targetId, orElse: () => node);
        if (target != node) {
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

    // 2. Nodes
    for (final node in nodes) {
      final isSel = node == selectedNode;

      if (isSel) {
        final aura = Paint()
          ..color = node.color.withAlpha(90)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0;
        canvas.drawCircle(node.position, 48, aura);
      }

      final glow = Paint()
        ..color = node.color.withAlpha(50)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(node.position, 40, glow);

      final body = Paint()..color = const Color(0xFF101625);
      canvas.drawCircle(node.position, 38, body);

      final border = Paint()
        ..color = node.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(node.position, 38, border);

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
// 3. EXECUTIVE SUMMARY TAB
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

            // Summary
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

            // Decisions
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
// 4. CONTACT INTELLIGENCE & CUSTOM CONTACT CREATOR TAB
// ---------------------------------------------------------------------------

class ContactIntelligenceTab extends StatelessWidget {
  final List<CallScenario> scenarios;
  final int activeScenarioIndex;
  final Function(int) onSelectScenario;
  final VoidCallback onOpenAddContact;

  const ContactIntelligenceTab({
    super.key,
    required this.scenarios,
    required this.activeScenarioIndex,
    required this.onSelectScenario,
    required this.onOpenAddContact,
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
            // Title & Add Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'LA TUA RUBRICA INTELLIGENTE',
                      style: TextStyle(
                        letterSpacing: 2.2,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7C4DFF),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'I Tuoi Contatti',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: onOpenAddContact,
                  child: Container(
                    height: 44,
                    width: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
                      ),
                    ),
                    child: const Icon(CupertinoIcons.plus, color: Colors.black, size: 22),
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
                            const SizedBox(height: 4),
                            Text(
                              item.phone,
                              style: const TextStyle(fontSize: 11, color: Colors.white38),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isCurrent ? const Color(0xFF00E5FF).withAlpha(30) : Colors.white.withAlpha(10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isCurrent ? 'ATTIVA' : 'CHIAMA',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isCurrent ? const Color(0xFF00E5FF) : Colors.white70,
                          ),
                        ),
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

// ---------------------------------------------------------------------------
// ADD CUSTOM CONTACT MODAL SHEET
// ---------------------------------------------------------------------------

class AddCustomContactSheet extends StatefulWidget {
  final Function(String, String, String, String, String) onAdd;

  const AddCustomContactSheet({super.key, required this.onAdd});

  @override
  State<AddCustomContactSheet> createState() => _AddCustomContactSheetState();
}

class _AddCustomContactSheetState extends State<AddCustomContactSheet> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _roleCtrl = TextEditingController(text: 'Cliente / Partner');
  final TextEditingController _companyCtrl = TextEditingController(text: 'Azienda Privata');
  final TextEditingController _phoneCtrl = TextEditingController(text: '+39 333 456 7890');
  final TextEditingController _topicCtrl = TextEditingController(text: 'Nuova Collaborazione & Budget');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _roleCtrl.dispose();
    _companyCtrl.dispose();
    _phoneCtrl.dispose();
    _topicCtrl.dispose();
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
        color: Color(0xFF101726),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'AGGIUNGI IL TUO CONTATTO',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00E5FF),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.white38),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _inputField('Nome e Cognome', _nameCtrl, 'Es. Luca Moretti', CupertinoIcons.person),
            const SizedBox(height: 10),
            _inputField('Ruolo / Qualifica', _roleCtrl, 'Es. Avvocato, Medico, Lead Dev', CupertinoIcons.briefcase),
            const SizedBox(height: 10),
            _inputField('Azienda o Settore', _companyCtrl, 'Es. Studio Associato, Google', CupertinoIcons.building_2_fill),
            const SizedBox(height: 10),
            _inputField('Numero di Telefono', _phoneCtrl, 'Es. +39 347 1234567', CupertinoIcons.phone),
            const SizedBox(height: 10),
            _inputField('Argomento della Chiamata', _topicCtrl, 'Es. Trattativa acquisto, Contratto, Visita', CupertinoIcons.bubble_left_bubble_right),
            const SizedBox(height: 20),

            GestureDetector(
              onTap: () {
                if (_nameCtrl.text.trim().isNotEmpty) {
                  widget.onAdd(
                    _nameCtrl.text.trim(),
                    _roleCtrl.text.trim(),
                    _companyCtrl.text.trim(),
                    _phoneCtrl.text.trim(),
                    _topicCtrl.text.trim(),
                  );
                  Navigator.pop(context);
                }
              },
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(27),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
                  ),
                ),
                child: const Center(
                  child: Text(
                    'SALVA E AVVIA CHIAMATA ASSISTITA',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      fontSize: 12,
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

  Widget _inputField(String label, TextEditingController ctrl, String hint, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(fontSize: 10, letterSpacing: 1.1, fontWeight: FontWeight.bold, color: Colors.white54),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          style: const TextStyle(fontSize: 14, color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.black38,
            prefixIcon: Icon(icon, color: const Color(0xFF00E5FF), size: 18),
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
