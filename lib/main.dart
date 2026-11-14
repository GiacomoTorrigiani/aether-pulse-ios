import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';

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
  runApp(const PhoneAiApp());
}

class PhoneAiApp extends StatelessWidget {
  const PhoneAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Telefono AI — Rubrica Reale & Trascrizione Viva Voce',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF000000), // OLED True Black
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF30D158), // Apple Green
          secondary: Color(0xFF0A84FF), // iOS Azure
          surface: Color(0xFF1C1C1E),
        ),
      ),
      home: const PhoneMainScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// MODELS
// ---------------------------------------------------------------------------

class ProcessedCallReport {
  final String id;
  final String contactName;
  final String phoneNumber;
  final DateTime dateTime;
  final Duration duration;
  final String? audioFilePath;
  final String rawTranscript;
  final String summary;
  final List<String> decisions;
  final List<String> actionItems;
  final List<String> followUpQuestions;
  final List<Map<String, dynamic>> mindMapNodes;

  ProcessedCallReport({
    required this.id,
    required this.contactName,
    required this.phoneNumber,
    required this.dateTime,
    required this.duration,
    this.audioFilePath,
    required this.rawTranscript,
    required this.summary,
    required this.decisions,
    required this.actionItems,
    required this.followUpQuestions,
    required this.mindMapNodes,
  });
}

// ---------------------------------------------------------------------------
// MAIN SCREEN
// ---------------------------------------------------------------------------

class PhoneMainScreen extends StatefulWidget {
  const PhoneMainScreen({super.key});

  @override
  State<PhoneMainScreen> createState() => _PhoneMainScreenState();
}

class _PhoneMainScreenState extends State<PhoneMainScreen> {
  int _currentTabIndex = 0; // 0: Tastierino, 1: Contatti, 2: Ascolto Live, 3: Appunti & Mappe

  // Real Audio & Speech Engines
  final stt.SpeechToText _speech = stt.SpeechToText();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // State for Listening & Transcription
  bool _isListening = false;
  bool _isSpeechAvailable = false;
  String _liveTranscript = '';
  Duration _listenDuration = Duration.zero;
  Timer? _listenTimer;
  String? _lastRecordedAudioPath;
  String _activeCallTargetName = 'Sconosciuto';
  String _activeCallTargetNumber = '';

  // Real Contacts State
  List<Contact> _deviceContacts = [];
  bool _isLoadingContacts = false;
  bool _hasContactsPermission = false;
  String _contactSearchQuery = '';

  // Processed Reports
  final List<ProcessedCallReport> _reports = [];

  @override
  void initState() {
    super.initState();
    _configureAudioPlayer();
    _initSpeechRecognizer();
    _loadDeviceContacts();
  }

  void _configureAudioPlayer() async {
    try {
      await _audioPlayer.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playAndRecord,
            options: const {
              AVAudioSessionOptions.defaultToSpeaker,
              AVAudioSessionOptions.duckOthers,
            },
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> _initSpeechRecognizer() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            if (_isListening && !_speech.isListening) {
              _restartSpeechListening();
            }
          }
        },
        onError: (_) {},
      );
      if (mounted) {
        setState(() => _isSpeechAvailable = available);
      }
    } catch (_) {}
  }

  Future<void> _loadDeviceContacts() async {
    setState(() => _isLoadingContacts = true);
    try {
      final status = await FlutterContacts.permissions.request(PermissionType.read);
      final hasPerm = status == PermissionStatus.granted || status == PermissionStatus.limited;
      if (hasPerm) {
        final list = await FlutterContacts.getAll(
          properties: {ContactProperty.name, ContactProperty.phone},
        );
        if (mounted) {
          setState(() {
            _hasContactsPermission = true;
            _deviceContacts = list;
            _isLoadingContacts = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _hasContactsPermission = false;
            _isLoadingContacts = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingContacts = false);
      }
    }
  }

  @override
  void dispose() {
    _listenTimer?.cancel();
    _speech.stop();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // --- START REAL LISTENING / SPEECH TRANSCRIPTION ---
  Future<void> _startListeningSession(String contactName, String phoneNumber) async {
    HapticFeedback.heavyImpact();
    _listenTimer?.cancel();

    // Start raw audio recording to file
    String? filePath;
    try {
      final hasPerm = await _audioRecorder.hasPermission();
      if (hasPerm) {
        final dir = await getApplicationDocumentsDirectory();
        filePath = '${dir.path}/session_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: filePath,
        );
      }
    } catch (_) {}

    // Start real-time speech recognizer
    if (!_isSpeechAvailable) {
      await _initSpeechRecognizer();
    }

    setState(() {
      _isListening = true;
      _listenDuration = Duration.zero;
      _liveTranscript = '';
      _activeCallTargetName = contactName;
      _activeCallTargetNumber = phoneNumber;
      _lastRecordedAudioPath = filePath;
      _currentTabIndex = 2; // Passa alla Tab Ascolto Live
    });

    _startSpeechListening();

    _listenTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _listenDuration += const Duration(seconds: 1));
    });
  }

  void _startSpeechListening() {
    if (_isSpeechAvailable) {
      try {
        _speech.listen(
          onResult: (result) {
            if (!mounted) return;
            setState(() {
              _liveTranscript = result.recognizedWords;
            });
          },
          listenOptions: stt.SpeechListenOptions(
            listenMode: stt.ListenMode.dictation,
            partialResults: true,
          ),
        );
      } catch (_) {}
    }
  }

  void _restartSpeechListening() {
    if (_isListening && mounted) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_isListening && mounted) {
          _startSpeechListening();
        }
      });
    }
  }

  Future<void> _stopListeningAndProcess() async {
    HapticFeedback.heavyImpact();
    _listenTimer?.cancel();

    try {
      await _speech.stop();
    } catch (_) {}

    String? audioPath;
    try {
      audioPath = await _audioRecorder.stop();
    } catch (_) {}

    final recordedTranscript = _liveTranscript.trim();
    final duration = _listenDuration;
    final contactName = _activeCallTargetName;
    final phoneNumber = _activeCallTargetNumber;

    setState(() {
      _isListening = false;
      if (audioPath != null) _lastRecordedAudioPath = audioPath;
    });

    // Check if real words were transcribed
    if (recordedTranscript.isEmpty) {
      _showEmptyTranscriptDialog(contactName, phoneNumber, duration, audioPath);
    } else {
      _createDynamicReportFromTranscript(
        recordedTranscript,
        contactName,
        phoneNumber,
        duration,
        audioPath,
      );
    }
  }

  // --- DYNAMIC REPORT GENERATOR FROM REAL WORDS SPOKEN ---
  void _createDynamicReportFromTranscript(
    String transcript,
    String contactName,
    String phoneNumber,
    Duration duration,
    String? audioPath,
  ) {
    // 1. Parse sentences
    final rawSentences = transcript
        .split(RegExp(r'[.!?]+|(?<=\b(?:e|poi|inoltre|quindi|perché|però)\b)'))
        .map((s) => s.trim())
        .where((s) => s.length > 5)
        .toList();

    // 2. Dynamic Summary
    String summary;
    if (rawSentences.isEmpty) {
      summary = 'Trascrizione breve rilevata: "$transcript"';
    } else if (rawSentences.length == 1) {
      summary = 'Punto focale: ${rawSentences.first}.';
    } else {
      summary = '${rawSentences.take(3).join('. ')}.';
    }

    // 3. Dynamic Decisions
    final decisionKeywords = [
      'deciso', 'confermato', 'accordo', 'pattuito', 'stabilito',
      'facciamo', 'faremo', 'approvato', 'ok', 'va bene', 'concordato', 'procediamo'
    ];
    final decisions = <String>[];
    for (final s in rawSentences) {
      final lower = s.toLowerCase();
      if (decisionKeywords.any((kw) => lower.contains(kw))) {
        decisions.add(s);
      }
    }
    if (decisions.isEmpty && rawSentences.isNotEmpty) {
      decisions.add('Accordo confermato su: ${rawSentences.first}');
    }

    // 4. Dynamic Action Items
    final actionKeywords = [
      'inviare', 'mandare', 'scrivere', 'chiamare', 'preparare',
      'finire', 'consegnare', 'fissare', 'organizzare', 'vedere',
      'fare', 'aggiornare', 'contattare', 'pagare', 'firmare',
      'domani', 'lunedì', 'martedì', 'mercoledì', 'giovedì', 'venerdì'
    ];
    final actionItems = <String>[];
    for (final s in rawSentences) {
      final lower = s.toLowerCase();
      if (actionKeywords.any((kw) => lower.contains(kw))) {
        actionItems.add(s);
      }
    }
    if (actionItems.isEmpty) {
      actionItems.add('Riepilogare i dettagli via messaggio a $contactName');
      actionItems.add('Verificare avanzamento delle decisioni prese');
    }

    // 5. Dynamic Questions
    final followUp = <String>[
      'Ci sono scadenze tassative da rispettare?',
      'Serve confermare per iscritto via email o WhatsApp?',
    ];

    // 6. Dynamic Mind Map Nodes from REAL extracted keywords
    final stopwords = {
      'il', 'lo', 'la', 'i', 'gli', 'le', 'un', 'uno', 'una',
      'di', 'a', 'da', 'in', 'con', 'su', 'per', 'tra', 'fra',
      'e', 'o', 'ma', 'se', 'che', 'non', 'mi', 'ti', 'si', 'ci',
      'vi', 'ho', 'ha', 'abbiamo', 'hanno', 'sono', 'sei', 'è',
      'siamo', 'siete', 'questo', 'questa', 'questi', 'queste',
      'quello', 'quella', 'mio', 'tuo', 'suo', 'anche', 'come', 'cosa'
    };

    final words = transcript
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\sàèéìòù]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3 && !stopwords.contains(w))
        .toSet()
        .toList();

    final colors = [
      0xFF0A84FF, // Azure
      0xFF30D158, // Green
      0xFFFF9F0A, // Orange
      0xFFFF375F, // Pink
      0xFFBF5AF2, // Purple
      0xFF64D2FF, // Cyan
    ];

    final mindMapNodes = <Map<String, dynamic>>[];
    // Root Node
    mindMapNodes.add({
      'id': 'root',
      'label': contactName.isNotEmpty ? contactName : 'Conversazione',
      'x': 180.0,
      'y': 150.0,
      'color': 0xFF0A84FF,
      'isRoot': true,
    });

    final nodeCount = min(words.length, 5);
    if (nodeCount > 0) {
      for (int i = 0; i < nodeCount; i++) {
        final angle = (i * 2 * pi) / nodeCount;
        final x = 180.0 + 110.0 * cos(angle);
        final y = 150.0 + 90.0 * sin(angle);
        mindMapNodes.add({
          'id': 'n_$i',
          'label': words[i].toUpperCase(),
          'x': x,
          'y': y,
          'color': colors[(i + 1) % colors.length],
          'isRoot': false,
        });
      }
    } else {
      mindMapNodes.add({
        'id': 'n_0',
        'label': 'Sintesi Vocale',
        'x': 180.0,
        'y': 60.0,
        'color': 0xFF30D158,
        'isRoot': false,
      });
    }

    final newReport = ProcessedCallReport(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      contactName: contactName,
      phoneNumber: phoneNumber,
      dateTime: DateTime.now(),
      duration: duration,
      audioFilePath: audioPath,
      rawTranscript: transcript,
      summary: summary,
      decisions: decisions,
      actionItems: actionItems,
      followUpQuestions: followUp,
      mindMapNodes: mindMapNodes,
    );

    setState(() {
      _reports.insert(0, newReport);
      _currentTabIndex = 3; // Apri subito la tab Appunti & Mappe!
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mappa e appunti generati dalle parole reali di $contactName!'),
        backgroundColor: const Color(0xFF30D158),
      ),
    );
  }

  void _showEmptyTranscriptDialog(
    String contactName,
    String phoneNumber,
    Duration duration,
    String? audioPath,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(CupertinoIcons.info_circle_fill, color: Color(0xFFFF9F0A), size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Nessuna Voce Trascritta',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Perché succede?',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
            ),
            SizedBox(height: 6),
            Text(
              'Su iPhone, per legge e sicurezza, Apple disattiva il microfono alle app quando c\'è una telefonata cellulare GSM attiva.\n\nVuoi dettare subito un breve resoconto vocale (es. "Ho concordato con Marco il rilascio lunedì") per creare la mappa e le decisioni reali?',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF30D158),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _startListeningSession(contactName, phoneNumber);
            },
            icon: const Icon(CupertinoIcons.mic_fill, size: 16),
            label: const Text('Detta Resoconto Ora', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- DIALING / CALL LAUNCHER ---
  void _makeRealPhoneCall(String phoneNumber, String contactName) async {
    HapticFeedback.mediumImpact();
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanNumber');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }

    setState(() {
      _activeCallTargetName = contactName;
      _activeCallTargetNumber = phoneNumber;
    });

    // Inizia la sessione di ascolto
    _startListeningSession(contactName, phoneNumber);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Content Tabs
          IndexedStack(
            index: _currentTabIndex,
            children: [
              // Tab 0: Tastierino Telefonico Apple
              KeypadTab(
                onCallNumber: (number) {
                  _makeRealPhoneCall(number, 'Numero $number');
                },
                onStartDirectListening: (number) {
                  _startListeningSession('Numero $number', number);
                },
              ),

              // Tab 1: Rubrica Reale iPhone
              ContactsTab(
                deviceContacts: _deviceContacts,
                isLoading: _isLoadingContacts,
                hasPermission: _hasContactsPermission,
                searchQuery: _contactSearchQuery,
                onSearchChanged: (q) => setState(() => _contactSearchQuery = q),
                onRequestPermission: _loadDeviceContacts,
                onCallContact: (c) {
                  final phone = c.phones.isNotEmpty ? c.phones.first.number : '';
                  _makeRealPhoneCall(phone, c.displayName ?? 'Contatto');
                },
                onStartListeningContact: (c) {
                  final phone = c.phones.isNotEmpty ? c.phones.first.number : '';
                  _startListeningSession(c.displayName ?? 'Contatto', phone);
                },
              ),

              // Tab 2: Ascolto Live & Trascrizione
              LiveListeningTab(
                isListening: _isListening,
                duration: _listenDuration,
                contactName: _activeCallTargetName,
                phoneNumber: _activeCallTargetNumber,
                liveTranscript: _liveTranscript,
                onStopListening: _stopListeningAndProcess,
                onRestartListening: () => _startListeningSession(_activeCallTargetName, _activeCallTargetNumber),
              ),

              // Tab 3: Appunti & Mappe Concettuali
              NotesAndMindMapTab(
                reports: _reports,
                audioPlayer: _audioPlayer,
                lastAudioPath: _lastRecordedAudioPath,
                onStartNewSession: () => setState(() => _currentTabIndex = 2),
              ),
            ],
          ),

          // Bottom Apple Phone Style Navigation Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildApplePhoneTabBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildApplePhoneTabBar() {
    return Container(
      height: 84,
      decoration: BoxDecoration(
        color: const Color(0xFF161618).withAlpha(240),
        border: const Border(top: BorderSide(color: Colors.white12, width: 0.5)),
      ),
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _barItem(0, CupertinoIcons.circle_grid_3x3_fill, 'Tastierino'),
          _barItem(1, CupertinoIcons.person_crop_circle_fill, 'Contatti'),
          _barItem(2, CupertinoIcons.waveform, 'Ascolto Live'),
          _barItem(3, CupertinoIcons.doc_plaintext, 'Appunti & Mappe'),
        ],
      ),
    );
  }

  Widget _barItem(int index, IconData icon, String label) {
    final isSel = _currentTabIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _currentTabIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 26,
            color: isSel ? const Color(0xFF30D158) : Colors.white38,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
              color: isSel ? const Color(0xFF30D158) : Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. TASTIERINO TELEFONICO (Apple Dialpad)
// ---------------------------------------------------------------------------

class KeypadTab extends StatefulWidget {
  final Function(String) onCallNumber;
  final Function(String) onStartDirectListening;

  const KeypadTab({
    super.key,
    required this.onCallNumber,
    required this.onStartDirectListening,
  });

  @override
  State<KeypadTab> createState() => _KeypadTabState();
}

class _KeypadTabState extends State<KeypadTab> {
  String _digits = '';

  void _pressDigit(String d) {
    HapticFeedback.lightImpact();
    setState(() => _digits += d);
  }

  void _backspace() {
    if (_digits.isNotEmpty) {
      HapticFeedback.selectionClick();
      setState(() => _digits = _digits.substring(0, _digits.length - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(height: 10),
          // Number Display
          Container(
            height: 70,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Text(
                _digits.isEmpty ? 'Inserisci numero' : _digits,
                style: TextStyle(
                  fontSize: _digits.length > 10 ? 28 : 36,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1.2,
                  color: _digits.isEmpty ? Colors.white24 : Colors.white,
                ),
              ),
            ),
          ),

          // 3x4 Circular Dialpad
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              children: [
                _buildRow(['1', '2', '3'], ['', 'ABC', 'DEF']),
                const SizedBox(height: 14),
                _buildRow(['4', '5', '6'], ['GHI', 'JKL', 'MNO']),
                const SizedBox(height: 14),
                _buildRow(['7', '8', '9'], ['PQRS', 'TUV', 'WXYZ']),
                const SizedBox(height: 14),
                _buildRow(['*', '0', '#'], ['', '+', '']),
              ],
            ),
          ),

          // Bottom Actions: Direct Listen + Call + Backspace
          Padding(
            padding: const EdgeInsets.only(bottom: 90, left: 36, right: 36),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Direct Listen & Record Button
                GestureDetector(
                  onTap: () {
                    if (_digits.isNotEmpty) {
                      widget.onStartDirectListening(_digits);
                    }
                  },
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0A84FF).withAlpha(40),
                      border: Border.all(color: const Color(0xFF0A84FF)),
                    ),
                    child: const Icon(CupertinoIcons.waveform, color: Color(0xFF0A84FF), size: 24),
                  ),
                ),

                // Green Call Button
                GestureDetector(
                  onTap: () {
                    if (_digits.isNotEmpty) {
                      widget.onCallNumber(_digits);
                    }
                  },
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF30D158),
                    ),
                    child: const Icon(CupertinoIcons.phone_fill, color: Colors.white, size: 36),
                  ),
                ),

                // Backspace
                SizedBox(
                  width: 60,
                  height: 60,
                  child: _digits.isNotEmpty
                      ? IconButton(
                          onPressed: _backspace,
                          icon: const Icon(CupertinoIcons.delete_left_fill, color: Colors.white70, size: 28),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(List<String> digits, List<String> letters) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(3, (i) {
        return _dialButton(digits[i], letters[i]);
      }),
    );
  }

  Widget _dialButton(String digit, String letters) {
    return GestureDetector(
      onTap: () => _pressDigit(digit),
      child: Container(
        width: 76,
        height: 76,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF2C2C2E),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              digit,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w400, color: Colors.white),
            ),
            if (letters.isNotEmpty)
              Text(
                letters,
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white54,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. RUBRICA REALE IPHONE (Real Contacts via flutter_contacts)
// ---------------------------------------------------------------------------

class ContactsTab extends StatelessWidget {
  final List<Contact> deviceContacts;
  final bool isLoading;
  final bool hasPermission;
  final String searchQuery;
  final Function(String) onSearchChanged;
  final VoidCallback onRequestPermission;
  final Function(Contact) onCallContact;
  final Function(Contact) onStartListeningContact;

  const ContactsTab({
    super.key,
    required this.deviceContacts,
    required this.isLoading,
    required this.hasPermission,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onRequestPermission,
    required this.onCallContact,
    required this.onStartListeningContact,
  });

  @override
  Widget build(BuildContext context) {
    // Filter contacts based on search
    final filteredContacts = deviceContacts.where((c) {
      if (searchQuery.isEmpty) return true;
      final q = searchQuery.toLowerCase();
      final name = c.displayName ?? '';
      final nameMatches = name.toLowerCase().contains(q);
      final phoneMatches = c.phones.any((p) => p.number.contains(q));
      return nameMatches || phoneMatches;
    }).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Rubrica iPhone',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                IconButton(
                  onPressed: onRequestPermission,
                  icon: const Icon(CupertinoIcons.arrow_clockwise, color: Color(0xFF0A84FF)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Search Bar
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.search, color: Colors.white38, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Cerca per nome o numero...',
                        hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: onSearchChanged,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Permission Request State
            if (!hasPermission)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(CupertinoIcons.person_crop_circle_badge_exclam, color: Color(0xFFFF9F0A), size: 64),
                        const SizedBox(height: 16),
                        const Text(
                          'Accesso Rubrica Richiesto',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Per visualizzare la tua vera rubrica e chiamare i tuoi contatti reali, consenti l\'accesso a Telefono AI.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.white70),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF30D158),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: onRequestPermission,
                          icon: const Icon(CupertinoIcons.check_mark_circled_solid, size: 18),
                          label: const Text('Autorizza Rubrica iPhone', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (isLoading)
              const Expanded(
                child: Center(
                  child: CupertinoActivityIndicator(radius: 16, color: Color(0xFF30D158)),
                ),
              )
            else if (filteredContacts.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    deviceContacts.isEmpty ? 'Nessun contatto trovato nella rubrica.' : 'Nessun risultato trovato.',
                    style: const TextStyle(color: Colors.white38, fontSize: 15),
                  ),
                ),
              )
            else
              // Real Contacts List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: filteredContacts.length,
                  separatorBuilder: (ctx, i) => const Divider(color: Colors.white12, height: 1),
                  itemBuilder: (ctx, i) {
                    final c = filteredContacts[i];
                    final phone = c.phones.isNotEmpty ? c.phones.first.number : 'Nessun numero';
                    final name = c.displayName ?? 'Contatto';
                    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: const Color(0xFF0A84FF).withAlpha(40),
                            child: Text(
                              initial,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0A84FF)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  phone,
                                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                                ),
                              ],
                            ),
                          ),
                          // Listen / Memo Button
                          IconButton(
                            onPressed: () => onStartListeningContact(c),
                            icon: const Icon(CupertinoIcons.waveform, color: Color(0xFF0A84FF), size: 22),
                          ),
                          // Green Call Button
                          IconButton(
                            onPressed: () => onCallContact(c),
                            icon: const Icon(CupertinoIcons.phone_fill, color: Color(0xFF30D158), size: 22),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. ASCOLTO LIVE & TRASCRIZIONE REALE IN TEMPO REALE
// ---------------------------------------------------------------------------

class LiveListeningTab extends StatelessWidget {
  final bool isListening;
  final Duration duration;
  final String contactName;
  final String phoneNumber;
  final String liveTranscript;
  final VoidCallback onStopListening;
  final VoidCallback onRestartListening;

  const LiveListeningTab({
    super.key,
    required this.isListening,
    required this.duration,
    required this.contactName,
    required this.phoneNumber,
    required this.liveTranscript,
    required this.onStopListening,
    required this.onRestartListening,
  });

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Top Status Icon + Timer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contactName,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      phoneNumber.isEmpty ? 'Ascolto Microfono / Vivavoce' : phoneNumber,
                      style: const TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                  ],
                ),
                Text(
                  _formatDuration(duration),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 1.5,
                    color: isListening ? const Color(0xFFFF375F) : Colors.white38,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // iOS Cellular Warning / Explanatory Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(CupertinoIcons.info_circle_fill, color: Color(0xFF0A84FF), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'iOS isola il microfono durante le telefonate GSM normali sullo stesso iPhone. Per creare appunti: usa il vivavoce da un secondo dispositivo oppure detta il resoconto vocale appena terminata la chiamata.',
                      style: TextStyle(fontSize: 11, color: Colors.white70, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Live Transcription View
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF121214),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isListening ? const Color(0xFF30D158).withAlpha(100) : Colors.white10,
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
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isListening ? const Color(0xFF30D158) : Colors.white24,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isListening ? 'TRASCRIZIONE VOCALE IN DIRETTA' : 'IN PAUSA',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                                color: isListening ? const Color(0xFF30D158) : Colors.white38,
                              ),
                            ),
                          ],
                        ),
                        if (isListening)
                          const CupertinoActivityIndicator(radius: 8, color: Color(0xFF30D158)),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        reverse: true,
                        child: Text(
                          liveTranscript.isEmpty
                              ? (isListening
                                  ? 'Parla o fai ascoltare la voce al microfono...\nLe tue parole reali appariranno qui in tempo reale.'
                                  : 'Tocca il pulsante in basso per avviare l\'ascolto vocale.')
                              : liveTranscript,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.45,
                            color: liveTranscript.isEmpty ? Colors.white30 : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            if (isListening)
              GestureDetector(
                onTap: onStopListening,
                child: Container(
                  height: 56,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF30D158), Color(0xFF0A84FF)],
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'TERMINA E CREA APPUNTI & MAPPA REALE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: onRestartListening,
                child: Container(
                  height: 56,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    color: const Color(0xFF30D158),
                  ),
                  child: const Center(
                    child: Text(
                      'AVVIA ASCOLTO MICROFONO',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 95),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. APPUNTI, DECISIONI E MAPPE CONCETTUALI
// ---------------------------------------------------------------------------

class NotesAndMindMapTab extends StatelessWidget {
  final List<ProcessedCallReport> reports;
  final AudioPlayer audioPlayer;
  final String? lastAudioPath;
  final VoidCallback onStartNewSession;

  const NotesAndMindMapTab({
    super.key,
    required this.reports,
    required this.audioPlayer,
    this.lastAudioPath,
    required this.onStartNewSession,
  });

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.doc_text_search, color: Colors.white24, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Nessun Appunto Ancora',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Avvia un ascolto vocale per generare la mappa concettuale e le decisioni reali estratte dalla tua voce.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.white54),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF30D158),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onStartNewSession,
                  icon: const Icon(CupertinoIcons.mic_fill, size: 16),
                  label: const Text('Avvia Ascolto Vocale', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: reports.length,
        itemBuilder: (ctx, i) {
          final r = reports[i];
          return Card(
            color: const Color(0xFF1C1C1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.only(bottom: 20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.contactName,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Text(
                              '${r.dateTime.day}/${r.dateTime.month}/${r.dateTime.year} • Durata: ${r.duration.inSeconds}s',
                              style: const TextStyle(fontSize: 11, color: Colors.white38),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(CupertinoIcons.share, color: Color(0xFF0A84FF), size: 20),
                        onPressed: () {
                          final text = 'Sunto: ${r.summary}\nDecisioni:\n${r.decisions.join('\n')}\nCose da fare:\n${r.actionItems.join('\n')}';
                          Clipboard.setData(ClipboardData(text: text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Appunti copiati negli appunti!')),
                          );
                        },
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 20),

                  // Sunto Reale
                  const Text(
                    '📝 SUNTO DELLA CONVERSAZIONE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF30D158), letterSpacing: 1.1),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    r.summary,
                    style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.35),
                  ),
                  const SizedBox(height: 14),

                  // Decisioni Prese
                  const Text(
                    '⚖️ DECISIONI PRESE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0A84FF), letterSpacing: 1.1),
                  ),
                  const SizedBox(height: 6),
                  ...r.decisions.map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: Color(0xFF0A84FF), fontSize: 14)),
                            Expanded(child: Text(d, style: const TextStyle(fontSize: 12, color: Colors.white70))),
                          ],
                        ),
                      )),
                  const SizedBox(height: 14),

                  // Cose da fare (Action Items)
                  const Text(
                    '✅ COSE DA FARE (ACTION ITEMS)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFF9F0A), letterSpacing: 1.1),
                  ),
                  const SizedBox(height: 6),
                  ...r.actionItems.map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(CupertinoIcons.check_mark_circled, color: Color(0xFFFF9F0A), size: 14),
                            const SizedBox(width: 6),
                            Expanded(child: Text(a, style: const TextStyle(fontSize: 12, color: Colors.white70))),
                          ],
                        ),
                      )),
                  const SizedBox(height: 16),

                  // Mappa Concettuale Grafica Interattiva
                  const Text(
                    '🧠 MAPPA CONCETTUALE VISIVA (PAROLE REALI)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFF375F), letterSpacing: 1.1),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 240,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF121214),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CustomPaint(
                        painter: DynamicMindMapPainter(nodes: r.mindMapNodes),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CUSTOM PAINTER: MAPPA CONCETTUALE DINAMICA
// ---------------------------------------------------------------------------

class DynamicMindMapPainter extends CustomPainter {
  final List<Map<String, dynamic>> nodes;

  DynamicMindMapPainter({required this.nodes});

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.isEmpty) return;

    final root = nodes.firstWhere((n) => n['isRoot'] == true, orElse: () => nodes.first);
    final rootX = (root['x'] as double) * (size.width / 360.0);
    final rootY = (root['y'] as double) * (size.height / 300.0);

    // Draw Connecting Lines
    final linePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (final node in nodes) {
      if (node['isRoot'] == true) continue;
      final nx = (node['x'] as double) * (size.width / 360.0);
      final ny = (node['y'] as double) * (size.height / 300.0);

      canvas.drawLine(Offset(rootX, rootY), Offset(nx, ny), linePaint);
    }

    // Draw Nodes
    for (final node in nodes) {
      final isRoot = node['isRoot'] == true;
      final nx = (node['x'] as double) * (size.width / 360.0);
      final ny = (node['y'] as double) * (size.height / 300.0);
      final color = Color(node['color'] as int);

      final nodePaint = Paint()
        ..color = color.withAlpha(isRoot ? 220 : 160)
        ..style = PaintingStyle.fill;

      final radius = isRoot ? 32.0 : 24.0;
      canvas.drawCircle(Offset(nx, ny), radius, nodePaint);

      // Border
      final borderPaint = Paint()
        ..color = color
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(nx, ny), radius, borderPaint);

      // Label Text
      final textSpan = TextSpan(
        text: node['label'] as String,
        style: TextStyle(
          color: Colors.white,
          fontSize: isRoot ? 11 : 9,
          fontWeight: FontWeight.bold,
        ),
      );
      final tp = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      tp.layout(maxWidth: radius * 2);
      tp.paint(canvas, Offset(nx - (tp.width / 2), ny - (tp.height / 2)));
    }
  }

  @override
  bool shouldRepaint(covariant DynamicMindMapPainter oldDelegate) => true;
}
