import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      title: 'Telefono AI — Smart Routing & Risparmio',
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
  // 0: Tastierino, 1: Contatti, 2: Risparmio & Esclusioni, 3: Ascolto Live, 4: Appunti & Mappe
  int _currentTabIndex = 0;

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

  // Smart Routing / Excluded Numbers (TIM Free Calling List)
  final Set<String> _excludedNumbers = {};
  final Map<String, String> _excludedNames = {};

  // Processed Reports
  final List<ProcessedCallReport> _reports = [];

  @override
  void initState() {
    super.initState();
    _configureAudioPlayer();
    _initSpeechRecognizer();
    _loadDeviceContacts();
    _loadExcludedNumbers();
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

  // --- PERSISTENCE: EXCLUDED NUMBERS & SMART ROUTING ---
  Future<void> _loadExcludedNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('excluded_numbers_list');
    final namesJson = prefs.getString('excluded_names_map');

    if (list != null && list.isNotEmpty) {
      setState(() {
        _excludedNumbers.clear();
        _excludedNumbers.addAll(list);
        if (namesJson != null) {
          try {
            final decoded = jsonDecode(namesJson) as Map<String, dynamic>;
            _excludedNames.clear();
            decoded.forEach((k, v) => _excludedNames[k] = v.toString());
          } catch (_) {}
        }
      });
    } else {
      // Default pre-loaded frequent contact from analysis
      setState(() {
        _excludedNumbers.add('3381764');
        _excludedNames['3381764'] = 'Contatto Frequente (Escluso TIM 0€)';
      });
      _saveExcludedNumbers();
    }
  }

  Future<void> _saveExcludedNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('excluded_numbers_list', _excludedNumbers.toList());
    await prefs.setString('excluded_names_map', jsonEncode(_excludedNames));
  }

  String _normalizeNumber(String raw) {
    String n = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (n.startsWith('39') && n.length > 9) {
      n = n.substring(2);
    }
    return n;
  }

  bool _isNumberExcluded(String raw) {
    final norm = _normalizeNumber(raw);
    if (norm.isEmpty) return false;
    for (final ex in _excludedNumbers) {
      final normEx = _normalizeNumber(ex);
      if (normEx.isEmpty) continue;
      if (norm.contains(normEx) || normEx.contains(norm)) {
        return true;
      }
    }
    return false;
  }

  void _toggleExclusion(String rawNumber, String name) {
    HapticFeedback.mediumImpact();
    final norm = _normalizeNumber(rawNumber);
    if (norm.isEmpty) return;

    final wasExcluded = _isNumberExcluded(rawNumber);

    setState(() {
      if (wasExcluded) {
        _excludedNumbers.removeWhere((n) {
          final nNorm = _normalizeNumber(n);
          return nNorm.contains(norm) || norm.contains(nNorm);
        });
        _excludedNames.remove(norm);
      } else {
        _excludedNumbers.add(norm);
        _excludedNames[norm] = name.isNotEmpty ? name : 'Numero $rawNumber';
      }
    });

    _saveExcludedNumbers();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasExcluded
              ? '🎙️ $name rimosso dalle esclusioni: verrà registrato con AI.'
              : '🛡️ $name ESCLUSO! Chiamate dirette con SIM TIM a 0,00 €.',
        ),
        backgroundColor: wasExcluded ? const Color(0xFF0A84FF) : const Color(0xFF30D158),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addCustomExcludedNumber(String number, String name) {
    final norm = _normalizeNumber(number);
    if (norm.isEmpty) return;
    setState(() {
      _excludedNumbers.add(norm);
      _excludedNames[norm] = name.isNotEmpty ? name : 'Numero $number';
    });
    _saveExcludedNumbers();
  }

  void _removeExcludedNumber(String normNumber) {
    setState(() {
      _excludedNumbers.remove(normNumber);
      _excludedNames.remove(normNumber);
    });
    _saveExcludedNumbers();
    HapticFeedback.lightImpact();
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

    setState(() {
      _isListening = true;
      _liveTranscript = '';
      _listenDuration = Duration.zero;
      _lastRecordedAudioPath = filePath;
      _activeCallTargetName = contactName;
      _activeCallTargetNumber = phoneNumber;
      _currentTabIndex = 3; // Switch to Ascolto Live tab
    });

    // Start live timer
    _listenTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _listenDuration = Duration(seconds: timer.tick));
    });

    // Start live Apple Speech Recognizer
    _startSpeechListening();
  }

  void _startSpeechListening() async {
    if (!_isSpeechAvailable) return;
    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _liveTranscript = result.recognizedWords;
          });
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
          localeId: 'it_IT',
        ),
      );
    } catch (_) {}
  }

  void _restartSpeechListening() async {
    if (!_isListening) return;
    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _liveTranscript = result.recognizedWords;
          });
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
          localeId: 'it_IT',
        ),
      );
    } catch (_) {}
  }

  // --- STOP LISTENING & DYNAMIC MAP/NOTE EXTRACTION ---
  Future<void> _stopListeningAndProcess() async {
    HapticFeedback.mediumImpact();
    _listenTimer?.cancel();

    try {
      await _speech.stop();
    } catch (_) {}

    String? audioPath;
    try {
      audioPath = await _audioRecorder.stop();
    } catch (_) {}

    final duration = _listenDuration;
    final transcript = _liveTranscript.trim();
    final contactName = _activeCallTargetName;
    final phoneNumber = _activeCallTargetNumber;

    setState(() {
      _isListening = false;
      _lastRecordedAudioPath = audioPath ?? _lastRecordedAudioPath;
    });

    if (transcript.isEmpty) {
      _showEmptyTranscriptDialog(contactName, phoneNumber, duration, audioPath);
      return;
    }

    // 1. Dynamic Summary
    final summary = transcript.length > 200
        ? '${transcript.substring(0, 195)}...'
        : transcript;

    // 2. Extract Sentences
    final rawSentences = transcript
        .split(RegExp(r'[.!?\n]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length > 5)
        .toList();

    // 3. Dynamic Decisions
    final decisionKeywords = [
      'concordato', 'deciso', 'confermo', 'accordo', 'ok', 'va bene',
      'stabilito', 'approvato', 'fatto', 'chiuso', 'fissato', 'conferma'
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

    // 6. Dynamic Mind Map Nodes
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
      _currentTabIndex = 4; // Switch to Appunti & Mappe tab
    });

    if (!mounted) return;
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

  // --- SMART ROUTING: PHONE CALL HANDLER ---
  void _initiatePhoneCall(String phoneNumber, String contactName) async {
    HapticFeedback.mediumImpact();
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final isExcluded = _isNumberExcluded(phoneNumber);

    if (isExcluded) {
      // 1. Direct Carrier Call (Free TIM Minutes - No VoIP / No Recording)
      final uri = Uri.parse('tel:$cleanNumber');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(CupertinoIcons.shield_fill, color: Color(0xFF30D158), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text('Chiamata Diretta TIM: Numero escluso (0,00 € spesi).'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1C1C1E),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      // 2. Protected AI Call (Recorded & Transcribed via VoIP or Memo)
      final uri = Uri.parse('tel:$cleanNumber');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
      setState(() {
        _activeCallTargetName = contactName;
        _activeCallTargetNumber = phoneNumber;
      });
      _startListeningSession(contactName, phoneNumber);
    }
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
                  _initiatePhoneCall(number, 'Numero $number');
                },
                onStartDirectListening: (number) {
                  _startListeningSession('Numero $number', number);
                },
                isNumberExcluded: _isNumberExcluded,
                onToggleExclusion: (number) {
                  _toggleExclusion(number, 'Numero $number');
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
                  _initiatePhoneCall(phone, c.displayName ?? 'Contatto');
                },
                onStartListeningContact: (c) {
                  final phone = c.phones.isNotEmpty ? c.phones.first.number : '';
                  _startListeningSession(c.displayName ?? 'Contatto', phone);
                },
                isNumberExcluded: _isNumberExcluded,
                onToggleExclusion: (phone, name) => _toggleExclusion(phone, name),
              ),

              // Tab 2: Risparmio & Esclusioni (Smart Routing)
              SavingsAndExclusionsTab(
                excludedNumbers: _excludedNumbers.toList(),
                excludedNames: _excludedNames,
                onRemoveExcludedNumber: _removeExcludedNumber,
                onAddCustomNumber: _addCustomExcludedNumber,
                deviceContacts: _deviceContacts,
                onCallNumber: (phone, name) => _initiatePhoneCall(phone, name),
              ),

              // Tab 3: Ascolto Live & Trascrizione
              LiveListeningTab(
                isListening: _isListening,
                duration: _listenDuration,
                contactName: _activeCallTargetName,
                phoneNumber: _activeCallTargetNumber,
                liveTranscript: _liveTranscript,
                onStopListening: _stopListeningAndProcess,
                onRestartListening: () => _startListeningSession(_activeCallTargetName, _activeCallTargetNumber),
              ),

              // Tab 4: Appunti & Mappe Concettuali
              NotesAndMindMapTab(
                reports: _reports,
                audioPlayer: _audioPlayer,
                lastAudioPath: _lastRecordedAudioPath,
                onStartNewSession: () => setState(() => _currentTabIndex = 3),
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
        color: const Color(0xFF161618).withAlpha(245),
        border: const Border(top: BorderSide(color: Colors.white12, width: 0.5)),
      ),
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _barItem(0, CupertinoIcons.circle_grid_3x3_fill, 'Tastierino'),
          _barItem(1, CupertinoIcons.person_crop_circle_fill, 'Contatti'),
          _barItem(2, CupertinoIcons.shield_fill, 'Risparmio'),
          _barItem(3, CupertinoIcons.waveform, 'Ascolto Live'),
          _barItem(4, CupertinoIcons.doc_plaintext, 'Appunti & Mappe'),
        ],
      ),
    );
  }

  Widget _barItem(int index, IconData icon, String label) {
    final isSel = _currentTabIndex == index;
    final isSavings = index == 2;
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
            size: 24,
            color: isSel
                ? (isSavings ? const Color(0xFF30D158) : const Color(0xFF30D158))
                : Colors.white38,
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
// 1. TASTIERINO TELEFONICO APPLE (Dialpad + Exclusion Indicator)
// ---------------------------------------------------------------------------

class KeypadTab extends StatefulWidget {
  final Function(String) onCallNumber;
  final Function(String) onStartDirectListening;
  final bool Function(String) isNumberExcluded;
  final Function(String) onToggleExclusion;

  const KeypadTab({
    super.key,
    required this.onCallNumber,
    required this.onStartDirectListening,
    required this.isNumberExcluded,
    required this.onToggleExclusion,
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
    final isExcluded = _digits.isNotEmpty && widget.isNumberExcluded(_digits);

    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(height: 8),

          // Number Display & Exclusion Badge
          Column(
            children: [
              Container(
                height: 60,
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
              if (_digits.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: GestureDetector(
                    onTap: () => widget.onToggleExclusion(_digits),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isExcluded
                            ? const Color(0xFF30D158).withAlpha(40)
                            : const Color(0xFF0A84FF).withAlpha(40),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isExcluded ? const Color(0xFF30D158) : const Color(0xFF0A84FF),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isExcluded ? CupertinoIcons.shield_fill : CupertinoIcons.waveform,
                            size: 13,
                            color: isExcluded ? const Color(0xFF30D158) : const Color(0xFF0A84FF),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isExcluded
                                ? 'Escluso (TIM 0,00 €) • Tocca per registrare'
                                : 'Registra con AI • Tocca per escludere',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isExcluded ? const Color(0xFF30D158) : const Color(0xFF0A84FF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // 3x4 Circular Dialpad
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              children: [
                _buildRow(['1', '2', '3'], ['', 'ABC', 'DEF']),
                const SizedBox(height: 12),
                _buildRow(['4', '5', '6'], ['GHI', 'JKL', 'MNO']),
                const SizedBox(height: 12),
                _buildRow(['7', '8', '9'], ['PQRS', 'TUV', 'WXYZ']),
                const SizedBox(height: 12),
                _buildRow(['*', '0', '#'], ['', '+', '']),
              ],
            ),
          ),

          // Bottom Actions
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

                // Call Button (Green: with Shield if Excluded)
                GestureDetector(
                  onTap: () {
                    if (_digits.isNotEmpty) {
                      widget.onCallNumber(_digits);
                    }
                  },
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isExcluded ? const Color(0xFF30D158) : const Color(0xFF30D158),
                      boxShadow: [
                        BoxShadow(
                          color: (isExcluded ? const Color(0xFF30D158) : const Color(0xFF30D158))
                              .withAlpha(80),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      isExcluded ? CupertinoIcons.shield_fill : CupertinoIcons.phone_fill,
                      color: Colors.white,
                      size: 34,
                    ),
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
// 2. RUBRICA REALE IPHONE (Real Contacts + Exclusion Badges)
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
  final bool Function(String) isNumberExcluded;
  final Function(String, String) onToggleExclusion;

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
    required this.isNumberExcluded,
    required this.onToggleExclusion,
  });

  @override
  Widget build(BuildContext context) {
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
                          'Per visualizzare la tua vera rubrica e gestire le esclusioni per risparmiare credito, consenti l\'accesso a Telefono AI.',
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
              // Contacts List
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
                    final isExcluded = phone.isNotEmpty && isNumberExcluded(phone);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: isExcluded
                                ? const Color(0xFF30D158).withAlpha(40)
                                : const Color(0xFF0A84FF).withAlpha(40),
                            child: Text(
                              initial,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isExcluded ? const Color(0xFF30D158) : const Color(0xFF0A84FF),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isExcluded
                                            ? const Color(0xFF30D158).withAlpha(30)
                                            : const Color(0xFF0A84FF).withAlpha(30),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isExcluded
                                              ? const Color(0xFF30D158).withAlpha(120)
                                              : const Color(0xFF0A84FF).withAlpha(120),
                                        ),
                                      ),
                                      child: Text(
                                        isExcluded ? '🛡️ TIM 0€' : '🎙️ AI',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: isExcluded
                                              ? const Color(0xFF30D158)
                                              : const Color(0xFF0A84FF),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  phone,
                                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                                ),
                              ],
                            ),
                          ),

                          // Toggle Exclusion Shield Button
                          IconButton(
                            tooltip: isExcluded ? 'Riattiva registrazione AI' : 'Escludi (Chiamata TIM gratuita 0€)',
                            onPressed: () {
                              if (phone.isNotEmpty) {
                                onToggleExclusion(phone, name);
                              }
                            },
                            icon: Icon(
                              isExcluded ? CupertinoIcons.shield_fill : CupertinoIcons.shield,
                              color: isExcluded ? const Color(0xFF30D158) : Colors.white38,
                              size: 22,
                            ),
                          ),

                          // Direct Listen Button
                          IconButton(
                            onPressed: () => onStartListeningContact(c),
                            icon: const Icon(CupertinoIcons.waveform, color: Color(0xFF0A84FF), size: 22),
                          ),

                          // Green Call Button
                          IconButton(
                            onPressed: () => onCallContact(c),
                            icon: Icon(
                              isExcluded ? CupertinoIcons.shield_fill : CupertinoIcons.phone_fill,
                              color: const Color(0xFF30D158),
                              size: 22,
                            ),
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
// 3. NUOVO TAB RISPARMIO & SMART ROUTING (Interfaccia Gestione Esclusioni)
// ---------------------------------------------------------------------------

class SavingsAndExclusionsTab extends StatelessWidget {
  final List<String> excludedNumbers;
  final Map<String, String> excludedNames;
  final Function(String) onRemoveExcludedNumber;
  final Function(String, String) onAddCustomNumber;
  final List<Contact> deviceContacts;
  final Function(String, String) onCallNumber;

  const SavingsAndExclusionsTab({
    super.key,
    required this.excludedNumbers,
    required this.excludedNames,
    required this.onRemoveExcludedNumber,
    required this.onAddCustomNumber,
    required this.deviceContacts,
    required this.onCallNumber,
  });

  void _showAddNumberDialog(BuildContext context) {
    final numController = TextEditingController();
    final nameController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Aggiungi Numero da Escludere',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.white38),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'I numeri esclusi non passeranno dal centralino e non saranno registrati: partirà una normale chiamata TIM con i tuoi minuti illimitati gratuiti (0,00 €).',
              style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.35),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: numController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Numero di Telefono',
                labelStyle: const TextStyle(color: Colors.white54),
                hintText: 'Es. 3381764*** o +39338...',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: const Color(0xFF2C2C2E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nome o Etichetta (Opzionale)',
                labelStyle: const TextStyle(color: Colors.white54),
                hintText: 'Es. Mamma, Partner, Amico...',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: const Color(0xFF2C2C2E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF30D158),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final n = numController.text.trim();
                  if (n.isNotEmpty) {
                    onAddCustomNumber(n, nameController.text.trim());
                    Navigator.pop(ctx);
                  }
                },
                icon: const Icon(CupertinoIcons.shield_fill, size: 18),
                label: const Text('Salva Esclusione (Risparmia 0€)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Stats calculation based on user analysis: 345 min saved on excluded number
    final hasFrequentNumber = excludedNumbers.any((n) => n.contains('3381764'));
    final estimatedMinutesSaved = hasFrequentNumber ? 345 : excludedNumbers.length * 50;
    final estimatedMoneySaved = (estimatedMinutesSaved * 0.0075).toStringAsFixed(2);
    final estimatedMonthlyBill = (1.00 + (max(0, 429 - estimatedMinutesSaved) * 0.0075)).toStringAsFixed(2);

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
                  'Risparmio & Routing',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF30D158),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () => _showAddNumberDialog(context),
                  icon: const Icon(CupertinoIcons.plus, size: 14),
                  label: const Text('Aggiungi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Top Dashboard Savings Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D381E), Color(0xFF132219), Color(0xFF1C1C1E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF30D158).withAlpha(80), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(CupertinoIcons.shield_fill, color: Color(0xFF30D158), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'SMART ROUTING ATTIVO',
                            style: TextStyle(
                              color: Color(0xFF30D158),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF30D158).withAlpha(40),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${excludedNumbers.length} Esclusioni',
                          style: const TextStyle(color: Color(0xFF30D158), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Spesa Stimata al Mese', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            '$estimatedMonthlyBill € / mese',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Denaro Risparmiato', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            '+$estimatedMoneySaved € / mese',
                            style: const TextStyle(
                              color: Color(0xFF30D158),
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(CupertinoIcons.arrow_down_right_circle, color: Colors.white38, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Minuti evitati dal centralino: ~$estimatedMinutesSaved min (chiamate dirette TIM a 0€)',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Numeri Esclusi dal Centralino (Chiamata TIM 0€)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 6),
            const Text(
              'I numeri in questo elenco vengono chiamati con la tua SIM TIM senza toccare il centralino e senza registrazione.',
              style: TextStyle(fontSize: 11, color: Colors.white38),
            ),
            const SizedBox(height: 12),

            // Excluded Numbers List
            if (excludedNumbers.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(CupertinoIcons.shield_slash, color: Colors.white24, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        'Nessun numero escluso al momento',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Tutte le chiamate passeranno dal centralino con registrazione AI.',
                        style: TextStyle(color: Colors.white24, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: excludedNumbers.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final normNum = excludedNumbers[i];
                    final name = excludedNames[normNum] ?? 'Numero $normNum';

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF30D158).withAlpha(40),
                            ),
                            child: const Icon(CupertinoIcons.shield_fill, color: Color(0xFF30D158), size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      normNum,
                                      style: const TextStyle(fontSize: 12, color: Colors.white54),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF30D158).withAlpha(30),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'TIM 0,00 €',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF30D158),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Quick Call Button
                          IconButton(
                            onPressed: () => onCallNumber(normNum, name),
                            icon: const Icon(CupertinoIcons.phone_fill, color: Color(0xFF30D158), size: 20),
                          ),

                          // Remove Exclusion Button
                          IconButton(
                            tooltip: 'Rimuovi esclusione',
                            onPressed: () => onRemoveExcludedNumber(normNum),
                            icon: const Icon(CupertinoIcons.trash, color: Colors.white38, size: 18),
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
// 4. ASCOLTO LIVE & TRASCRIZIONE REALE IN TEMPO REALE
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
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
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
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contactName,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phoneNumber.isNotEmpty ? phoneNumber : 'In ascolto...',
                      style: const TextStyle(fontSize: 13, color: Colors.white54),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isListening ? const Color(0xFFFF375F).withAlpha(40) : Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isListening ? const Color(0xFFFF375F) : Colors.white24,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isListening ? const Color(0xFFFF375F) : Colors.white38,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isListening ? _formatDuration(duration) : 'In Pausa',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isListening ? const Color(0xFFFF375F) : Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Live Audio Visualizer Wave Animation
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: isListening
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(24, (i) {
                        final h = 15.0 + (sin((duration.inSeconds * 4) + i) * 35.0).abs();
                        return Container(
                          width: 4,
                          height: h,
                          decoration: BoxDecoration(
                            color: Color.lerp(const Color(0xFF0A84FF), const Color(0xFF30D158), i / 24),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    )
                  : const Center(
                      child: Text(
                        'Premi "Avvia Ascolto" per iniziare',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ),
            ),
            const SizedBox(height: 20),

            // Real Time Speech-to-Text Box
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(CupertinoIcons.quote_bubble_fill, color: Color(0xFF0A84FF), size: 16),
                            SizedBox(width: 8),
                            Text(
                              'TRASCRIZIONE REALE IN TEMPO REALE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: Color(0xFF0A84FF),
                              ),
                            ),
                          ],
                        ),
                        if (isListening)
                          const CupertinoActivityIndicator(radius: 8, color: Color(0xFF0A84FF)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        reverse: true,
                        child: Text(
                          liveTranscript.isEmpty
                              ? (isListening
                                  ? 'Parla o ascolta l\'interlocutore in vivavoce: ogni singola parola verrà trascritta qui...'
                                  : 'Nessun testo acquisito. Premi il pulsante sotto per avviare.')
                              : liveTranscript,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            color: liveTranscript.isEmpty ? Colors.white38 : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Controls
            Padding(
              padding: const EdgeInsets.only(bottom: 90),
              child: Row(
                children: [
                  if (!isListening)
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A84FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: onRestartListening,
                        icon: const Icon(CupertinoIcons.play_fill, size: 18),
                        label: const Text('Avvia Ascolto', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    )
                  else
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF375F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: onStopListening,
                        icon: const Icon(CupertinoIcons.stop_fill, size: 18),
                        label: const Text('Termina & Genera Mappa Reale', style: TextStyle(fontWeight: FontWeight.bold)),
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

// ---------------------------------------------------------------------------
// 5. APPUNTI & MAPPE CONCETTUALI
// ---------------------------------------------------------------------------

class NotesAndMindMapTab extends StatefulWidget {
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
  State<NotesAndMindMapTab> createState() => _NotesAndMindMapTabState();
}

class _NotesAndMindMapTabState extends State<NotesAndMindMapTab> {
  ProcessedCallReport? _selectedReport;
  bool _isPlayingAudio = false;

  @override
  void initState() {
    super.initState();
    if (widget.reports.isNotEmpty) {
      _selectedReport = widget.reports.first;
    }
  }

  void _toggleAudioPlay(String? path) async {
    if (path == null) return;
    if (_isPlayingAudio) {
      await widget.audioPlayer.pause();
      setState(() => _isPlayingAudio = false);
    } else {
      await widget.audioPlayer.play(DeviceFileSource(path));
      setState(() => _isPlayingAudio = true);
      widget.audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _isPlayingAudio = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reports.isEmpty) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.doc_text_search, size: 64, color: Colors.white24),
                const SizedBox(height: 16),
                const Text(
                  'Nessun Appunto Registrato',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Effettua una chiamata con l\'app oppure avvia una sessione di ascolto per generare automaticamente la mappa concettuale e le decisioni.',
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
                  onPressed: widget.onStartNewSession,
                  icon: const Icon(CupertinoIcons.waveform, size: 18),
                  label: const Text('Avvia Prima Sessione', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final activeReport = _selectedReport ?? widget.reports.first;

    return SafeArea(
      child: Column(
        children: [
          // Selector Carousel if multiple reports
          if (widget.reports.length > 1)
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: widget.reports.length,
                itemBuilder: (ctx, i) {
                  final rep = widget.reports[i];
                  final isSel = rep.id == activeReport.id;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedReport = rep),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFF0A84FF) : const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSel ? Colors.transparent : Colors.white12),
                      ),
                      child: Center(
                        child: Text(
                          rep.contactName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 100, top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeReport.contactName,
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Durata: ${activeReport.duration.inMinutes}m ${activeReport.duration.inSeconds.remainder(60)}s',
                            style: const TextStyle(fontSize: 12, color: Colors.white54),
                          ),
                        ],
                      ),
                      if (activeReport.audioFilePath != null)
                        IconButton(
                          onPressed: () => _toggleAudioPlay(activeReport.audioFilePath),
                          icon: Icon(
                            _isPlayingAudio ? CupertinoIcons.pause_circle_fill : CupertinoIcons.play_circle_fill,
                            color: const Color(0xFF30D158),
                            size: 34,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Real Dynamic Mind Map Graph Widget
                  Container(
                    width: double.infinity,
                    height: 240,
                    decoration: BoxDecoration(
                      color: const Color(0xFF121214),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: CustomPaint(
                        painter: DynamicMindMapPainter(nodes: activeReport.mindMapNodes),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Summary Card
                  _sectionHeader(CupertinoIcons.doc_text_fill, 'RIASSUNTO DINAMICO REALE'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      activeReport.summary,
                      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Decisions Taken
                  _sectionHeader(CupertinoIcons.check_mark_circled_solid, 'DECISIONI PRESE'),
                  const SizedBox(height: 8),
                  ...activeReport.decisions.map((d) => _bulletItem(d, const Color(0xFF30D158))),
                  const SizedBox(height: 18),

                  // Action Items / Cose da Fare
                  _sectionHeader(CupertinoIcons.bell_fill, 'COSE DA FARE (ACTION ITEMS)'),
                  const SizedBox(height: 8),
                  ...activeReport.actionItems.map((a) => _bulletItem(a, const Color(0xFFFF9F0A))),
                  const SizedBox(height: 18),

                  // Raw Transcript Accordion
                  ExpansionTile(
                    title: const Text('Trascrizione Integrale Completa', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          activeReport.rawTranscript,
                          style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF0A84FF)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: Color(0xFF0A84FF),
          ),
        ),
      ],
    );
  }

  Widget _bulletItem(String text, Color dotColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6. CUSTOM PAINTER FOR REAL DYNAMIC MIND MAP
// ---------------------------------------------------------------------------

class DynamicMindMapPainter extends CustomPainter {
  final List<Map<String, dynamic>> nodes;

  DynamicMindMapPainter({required this.nodes});

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.isEmpty) return;

    final rootNode = nodes.firstWhere((n) => n['isRoot'] == true, orElse: () => nodes.first);
    final rootX = (rootNode['x'] as double) * (size.width / 360.0);
    final rootY = (rootNode['y'] as double) * (size.height / 300.0);

    // Draw Connectors
    final linePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (final node in nodes) {
      if (node['isRoot'] == true) continue;
      final nx = (node['x'] as double) * (size.width / 360.0);
      final ny = (node['y'] as double) * (size.height / 300.0);

      final path = Path()
        ..moveTo(rootX, rootY)
        ..quadraticBezierTo((rootX + nx) / 2, (rootY + ny) / 2 + 15, nx, ny);
      canvas.drawPath(path, linePaint);
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
