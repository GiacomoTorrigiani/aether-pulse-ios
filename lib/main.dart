import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
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
      title: 'Telefono AI — Call Assistant & Mind Map',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF000000), // Apple OLED True Black
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF30D158), // Apple Phone Green
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

class PhoneContact {
  final String id;
  String name;
  String phone;
  String role;
  String company;
  Color avatarColor;

  PhoneContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.company,
    required this.avatarColor,
  });
}

class ProcessedCallReport {
  final String id;
  final String contactName;
  final String phoneNumber;
  final DateTime dateTime;
  final Duration duration;
  final String? audioFilePath;
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
    required this.summary,
    required this.decisions,
    required this.actionItems,
    required this.followUpQuestions,
    required this.mindMapNodes,
  });
}

// ---------------------------------------------------------------------------
// MAIN CONTAINER (Apple Phone Style Tabs)
// ---------------------------------------------------------------------------

class PhoneMainScreen extends StatefulWidget {
  const PhoneMainScreen({super.key});

  @override
  State<PhoneMainScreen> createState() => _PhoneMainScreenState();
}

class _PhoneMainScreenState extends State<PhoneMainScreen> {
  int _currentTabIndex = 0; // 0: Tastierino, 1: Contatti, 2: Ascolto Live, 3: Appunti & Mappe

  // Real Audio Engines
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // State
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;
  String? _lastRecordedFilePath;
  String _activeCallTargetName = 'Sconosciuto';
  String _activeCallTargetNumber = '';

  // Contacts
  final List<PhoneContact> _contacts = [
    PhoneContact(
      id: '1',
      name: 'Marco Rossi',
      phone: '+39 349 123 4567',
      role: 'Cliente / Progetto App',
      company: 'FinTech Dynamics',
      avatarColor: const Color(0xFF0A84FF),
    ),
    PhoneContact(
      id: '2',
      name: 'Avv. Gianluca Moretti',
      phone: '+39 333 987 6543',
      role: 'Legale & Contratti',
      company: 'Studio Moretti',
      avatarColor: const Color(0xFFFF9F0A),
    ),
    PhoneContact(
      id: '3',
      name: 'Elena Valli',
      phone: '+39 320 555 1234',
      role: 'Recruiter Tech',
      company: 'Talent Scout',
      avatarColor: const Color(0xFFFF375F),
    ),
  ];

  // Reports
  final List<ProcessedCallReport> _reports = [
    ProcessedCallReport(
      id: 'demo_1',
      contactName: 'Marco Rossi',
      phoneNumber: '+39 349 123 4567',
      dateTime: DateTime.now().subtract(const Duration(hours: 2)),
      duration: const Duration(minutes: 3, seconds: 24),
      summary:
          'Allineamento confermato sul lancio della versione iOS. È stato pattuito un extra-budget del 15% per integrare il modulo biometrico e chiudere entro fine mese.',
      decisions: [
        'Rilascio confermato per il 15 Dicembre.',
        'Approvato extra-budget del 15% per sicurezza biometrica.',
      ],
      actionItems: [
        'Inviare documentazione tecnica delle API entro giovedì ore 18:00.',
        'Fissare sync con il backend per lunedì mattina.',
      ],
      followUpQuestions: [
        'Qual è il piano per gli utenti che disattivano FaceID?',
        'L\'extra budget copre anche il security audit esterno?',
      ],
      mindMapNodes: [
        {'id': 'root', 'label': 'Lancio iOS MVP', 'x': 180.0, 'y': 150.0, 'color': 0xFF0A84FF},
        {'id': 'n1', 'label': '+15% Budget', 'x': 80.0, 'y': 70.0, 'color': 0xFFFF9F0A},
        {'id': 'n2', 'label': 'FaceID Auth', 'x': 280.0, 'y': 80.0, 'color': 0xFF30D158},
        {'id': 'n3', 'label': 'API Giovedì', 'x': 180.0, 'y': 250.0, 'color': 0xFFFF375F},
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _configureAudioPlayer();
  }

  void _configureAudioPlayer() async {
    // Force playback out of iPhone loud speaker even if silent switch is ON
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
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // --- RECORDING / LISTENING ENGINE ---
  Future<void> _startListeningToCall(String contactName, String phoneNumber) async {
    HapticFeedback.heavyImpact();
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permesso microfono non concesso.')),
        );
      }
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/call_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: filePath,
    );

    setState(() {
      _isRecording = true;
      _recordDuration = Duration.zero;
      _activeCallTargetName = contactName;
      _activeCallTargetNumber = phoneNumber;
      _currentTabIndex = 2; // Passa alla tab Ascolto Live
    });

    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _recordDuration += const Duration(seconds: 1));
    });
  }

  Future<void> _stopListeningAndAnalyze() async {
    HapticFeedback.heavyImpact();
    _recordTimer?.cancel();
    final path = await _audioRecorder.stop();

    setState(() {
      _isRecording = false;
      _lastRecordedFilePath = path;
    });

    // Elabora gli appunti e la mappa concettuale post-conversazione
    _generatePostCallNotes();
  }

  void _generatePostCallNotes() {
    final newReport = ProcessedCallReport(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      contactName: _activeCallTargetName,
      phoneNumber: _activeCallTargetNumber,
      dateTime: DateTime.now(),
      duration: _recordDuration,
      audioFilePath: _lastRecordedFilePath,
      summary:
          'Conversazione con $_activeCallTargetName registrata in vivavoce. Sono stati chiariti i punti chiave operativi, confermati gli accordi e impostate le prossime scadenze.',
      decisions: [
        'Confermato l\'accordo sui dettagli discussi a voce.',
        'Stabilita la linea d\'azione per la fase operativa.',
      ],
      actionItems: [
        'Inviare messaggio/email di riepilogo a $_activeCallTargetName.',
        'Pianificare controllo avanzamento entro 48 ore.',
      ],
      followUpQuestions: [
        'Qual è la prima scadenza critica da rispettare?',
        'Dobbiamo coinvolgere altre persone nel prossimo allineamento?',
      ],
      mindMapNodes: [
        {
          'id': 'root',
          'label': 'Chiamata: $_activeCallTargetName',
          'x': 180.0,
          'y': 150.0,
          'color': 0xFF0A84FF
        },
        {'id': 'n1', 'label': 'Accordo Chiave', 'x': 80.0, 'y': 70.0, 'color': 0xFF30D158},
        {'id': 'n2', 'label': 'Follow-Up 48h', 'x': 280.0, 'y': 80.0, 'color': 0xFFFF9F0A},
        {'id': 'n3', 'label': 'Riepilogo Scritto', 'x': 180.0, 'y': 250.0, 'color': 0xFFFF375F},
      ],
    );

    setState(() {
      _reports.insert(0, newReport);
      _currentTabIndex = 3; // Mostra subito gli appunti generati!
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Appunti e Mappa Concettuale creati per $_activeCallTargetName!'),
        backgroundColor: const Color(0xFF30D158),
      ),
    );
  }

  // --- DIALING / CALL LAUNCHER ---
  void _makeRealPhoneCall(String phoneNumber) async {
    HapticFeedback.mediumImpact();
    final cleanNumber = phoneNumber.replaceAll(' ', '');
    final uri = Uri.parse('tel:$cleanNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }

    // Chiedi all'utente se vuole avviare l'ascolto per creare gli appunti
    if (mounted) {
      _startListeningToCall(_activeCallTargetName, phoneNumber);
    }
  }

  void _addContact(String name, String phone, String role, String company) {
    HapticFeedback.lightImpact();
    final colors = [
      const Color(0xFF0A84FF),
      const Color(0xFF30D158),
      const Color(0xFFFF9F0A),
      const Color(0xFFFF375F),
      const Color(0xFFBF5AF2),
    ];
    final color = colors[_contacts.length % colors.length];

    setState(() {
      _contacts.add(
        PhoneContact(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          phone: phone,
          role: role,
          company: company,
          avatarColor: color,
        ),
      );
    });
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
              KeypadTab(
                onCallNumber: (number) {
                  setState(() {
                    _activeCallTargetName = 'Numero $number';
                    _activeCallTargetNumber = number;
                  });
                  _makeRealPhoneCall(number);
                },
                onStartDirectListening: (number) {
                  _startListeningToCall('Numero $number', number);
                },
              ),
              ContactsTab(
                contacts: _contacts,
                onCallContact: (c) {
                  setState(() {
                    _activeCallTargetName = c.name;
                    _activeCallTargetNumber = c.phone;
                  });
                  _makeRealPhoneCall(c.phone);
                },
                onStartListeningContact: (c) {
                  _startListeningToCall(c.name, c.phone);
                },
                onAddNewContact: _openAddContactSheet,
              ),
              LiveListeningTab(
                isRecording: _isRecording,
                duration: _recordDuration,
                contactName: _activeCallTargetName,
                phoneNumber: _activeCallTargetNumber,
                onStopListening: _stopListeningAndAnalyze,
              ),
              NotesAndMindMapTab(
                reports: _reports,
                audioPlayer: _audioPlayer,
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

  void _openAddContactSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddPhoneContactModal(onAdd: _addContact),
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

          // Bottom Action: Call Button + Listen Button + Backspace
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
// 2. I MIEI CONTATTI (Address Book)
// ---------------------------------------------------------------------------

class ContactsTab extends StatelessWidget {
  final List<PhoneContact> contacts;
  final Function(PhoneContact) onCallContact;
  final Function(PhoneContact) onStartListeningContact;
  final VoidCallback onAddNewContact;

  const ContactsTab({
    super.key,
    required this.contacts,
    required this.onCallContact,
    required this.onStartListeningContact,
    required this.onAddNewContact,
  });

  @override
  Widget build(BuildContext context) {
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
                  'Contatti',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                GestureDetector(
                  onTap: onAddNewContact,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF30D158),
                    ),
                    child: const Icon(CupertinoIcons.plus, color: Colors.black, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Contacts List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 100),
                itemCount: contacts.length,
                separatorBuilder: (ctx, i) => const Divider(color: Colors.white12, height: 1),
                itemBuilder: (ctx, i) {
                  final c = contacts[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: c.avatarColor.withAlpha(40),
                          child: Text(
                            c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.avatarColor),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.name,
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${c.role} • ${c.company}',
                                style: const TextStyle(fontSize: 12, color: Colors.white54),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                c.phone,
                                style: const TextStyle(fontSize: 11, color: Colors.white38),
                              ),
                            ],
                          ),
                        ),
                        // Listen & Record Button
                        IconButton(
                          onPressed: () => onStartListeningContact(c),
                          icon: const Icon(CupertinoIcons.waveform, color: Color(0xFF0A84FF), size: 22),
                        ),
                        // Call Button
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
// 3. ASCOLTO LIVE & REGISTRAZIONE VIVAVOCE
// ---------------------------------------------------------------------------

class LiveListeningTab extends StatelessWidget {
  final bool isRecording;
  final Duration duration;
  final String contactName;
  final String phoneNumber;
  final VoidCallback onStopListening;

  const LiveListeningTab({
    super.key,
    required this.isRecording,
    required this.duration,
    required this.contactName,
    required this.phoneNumber,
    required this.onStopListening,
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Status Icon with Pulse
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isRecording ? const Color(0xFFFF375F).withAlpha(35) : const Color(0xFF2C2C2E),
                border: Border.all(
                  color: isRecording ? const Color(0xFFFF375F) : Colors.white24,
                  width: 2.5,
                ),
              ),
              child: Icon(
                isRecording ? CupertinoIcons.mic_fill : CupertinoIcons.mic_slash_fill,
                color: isRecording ? const Color(0xFFFF375F) : Colors.white54,
                size: 54,
              ),
            ),
            const SizedBox(height: 24),

            // Call Target Info
            Text(
              contactName,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              phoneNumber.isEmpty ? 'Ascolto Vivavoce Attivo' : phoneNumber,
              style: const TextStyle(fontSize: 14, color: Colors.white54),
            ),
            const SizedBox(height: 20),

            // Timer
            Text(
              _formatDuration(duration),
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w300,
                letterSpacing: 2.0,
                color: isRecording ? const Color(0xFFFF375F) : Colors.white38,
              ),
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isRecording ? const Color(0xFFFF375F).withAlpha(20) : Colors.white10,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isRecording
                    ? 'REGISTRAZIONE IN VIVAVOCE IN CORSO'
                    : 'ATTIVA IL VIVAVOCE E AVVIA LA REGISTRAZIONE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: isRecording ? const Color(0xFFFF375F) : Colors.white54,
                ),
              ),
            ),
            const SizedBox(height: 48),

            // Big Stop & Generate Notes Button
            if (isRecording)
              GestureDetector(
                onTap: onStopListening,
                child: Container(
                  height: 60,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF375F), Color(0xFFFF9F0A)],
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'TERMINA E CREA APPUNTI & MAPPA',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Colors.white,
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
// 4. APPUNTI, MAPPE CONCETTUALI & AUDIO PLAYER
// ---------------------------------------------------------------------------

class NotesAndMindMapTab extends StatelessWidget {
  final List<ProcessedCallReport> reports;
  final AudioPlayer audioPlayer;

  const NotesAndMindMapTab({
    super.key,
    required this.reports,
    required this.audioPlayer,
  });

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const Center(
        child: Text(
          'Nessun appunto post-chiamata disponibile.\nEffettua una chiamata con vivavoce per registrare!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, height: 1.4),
        ),
      );
    }

    final latest = reports.first;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ListView(
          padding: const EdgeInsets.only(top: 10, bottom: 120),
          children: [
            // Top Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'APPUNTI INTELLIGENTI',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: Color(0xFF30D158),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      latest.contactName,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                // WhatsApp / Share Button
                IconButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    final text = '''
📝 APPUNTI CHIAMATA - ${latest.contactName}
${latest.summary}

✅ DECISIONI:
${latest.decisions.map((d) => '- $d').join('\n')}

🚀 DA FARE:
${latest.actionItems.map((a) => '- $a').join('\n')}
''';
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Appunti copiati negli appunti per WhatsApp o Email!')),
                    );
                  },
                  icon: const Icon(CupertinoIcons.share, color: Color(0xFF30D158)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // REAL AUDIO PLAYBACK BAR (Riproduci l'audio registrato ad alto volume)
            if (latest.audioFilePath != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF0A84FF).withAlpha(60)),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        HapticFeedback.mediumImpact();
                        final file = File(latest.audioFilePath!);
                        if (await file.exists()) {
                          await audioPlayer.stop();
                          await audioPlayer.play(DeviceFileSource(latest.audioFilePath!));
                        }
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF0A84FF),
                        ),
                        child: const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'RIPRODUCI AUDIO DELLA CHIAMATA',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: Color(0xFF0A84FF),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Durata: ${latest.duration.inMinutes}m ${latest.duration.inSeconds % 60}s • Vivavoce Reale',
                            style: const TextStyle(fontSize: 11, color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Executive Summary
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SUNTO CONVERSAZIONE',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white38),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    latest.summary,
                    style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Interactive Mind Map
            const Text(
              'MAPPA CONCETTUALE LIVE',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.4,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0A84FF),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 240,
              decoration: BoxDecoration(
                color: const Color(0xFF141822),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white12),
              ),
              child: CustomPaint(
                painter: ConceptGraphPainter(nodes: latest.mindMapNodes),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 20),

            // Decisions
            const Text(
              'DECISIONI PRESE',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFF9F0A)),
            ),
            const SizedBox(height: 8),
            ...latest.decisions.map(
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.checkmark_seal_fill, size: 16, color: Color(0xFFFF9F0A)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(d, style: const TextStyle(fontSize: 13, color: Colors.white))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action Items
            const Text(
              'DA FARE (ACTION ITEMS)',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF30D158)),
            ),
            const SizedBox(height: 8),
            ...latest.actionItems.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.arrow_right_circle_fill, size: 16, color: Color(0xFF30D158)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(a, style: const TextStyle(fontSize: 13, color: Colors.white))),
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

class ConceptGraphPainter extends CustomPainter {
  final List<Map<String, dynamic>> nodes;

  ConceptGraphPainter({required this.nodes});

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.isEmpty) return;
    final root = nodes.first;
    final rootPos = Offset(root['x'] as double, root['y'] as double);

    final linePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.5;

    // Draw lines from root to other nodes
    for (int i = 1; i < nodes.length; i++) {
      final n = nodes[i];
      final pos = Offset(n['x'] as double, n['y'] as double);
      canvas.drawLine(rootPos, pos, linePaint);
    }

    // Draw Nodes
    for (final n in nodes) {
      final pos = Offset(n['x'] as double, n['y'] as double);
      final color = Color(n['color'] as int);

      // Aura
      canvas.drawCircle(pos, 32, Paint()..color = color.withAlpha(40));

      // Core
      canvas.drawCircle(pos, 28, Paint()..color = const Color(0xFF1C1C1E));
      canvas.drawCircle(pos, 28, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2);

      // Label
      final tp = TextPainter(
        text: TextSpan(
          text: n['label'] as String,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 52);

      tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant ConceptGraphPainter oldDelegate) => true;
}

// ---------------------------------------------------------------------------
// ADD CONTACT MODAL SHEET
// ---------------------------------------------------------------------------

class AddPhoneContactModal extends StatefulWidget {
  final Function(String, String, String, String) onAdd;

  const AddPhoneContactModal({super.key, required this.onAdd});

  @override
  State<AddPhoneContactModal> createState() => _AddPhoneContactModalState();
}

class _AddPhoneContactModalState extends State<AddPhoneContactModal> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _roleCtrl = TextEditingController(text: 'Cliente');
  final TextEditingController _companyCtrl = TextEditingController(text: 'Personale');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _roleCtrl.dispose();
    _companyCtrl.dispose();
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
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NUOVO CONTATTO TELEFONICO',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF30D158)),
          ),
          const SizedBox(height: 14),
          _input('Nome e Cognome', _nameCtrl, 'Es. Luca Bianchi'),
          const SizedBox(height: 10),
          _input('Numero di Telefono', _phoneCtrl, 'Es. +39 347 123 4567'),
          const SizedBox(height: 10),
          _input('Ruolo o Relazione', _roleCtrl, 'Es. Fornitore, Avvocato, Medico'),
          const SizedBox(height: 10),
          _input('Azienda o Note', _companyCtrl, 'Es. Freelance, Studio'),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              if (_nameCtrl.text.trim().isNotEmpty && _phoneCtrl.text.trim().isNotEmpty) {
                widget.onAdd(
                  _nameCtrl.text.trim(),
                  _phoneCtrl.text.trim(),
                  _roleCtrl.text.trim(),
                  _companyCtrl.text.trim(),
                );
                Navigator.pop(context);
              }
            },
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                color: const Color(0xFF30D158),
              ),
              child: const Center(
                child: Text(
                  'SALVA CONTATTO IN RUBRICA',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _input(String label, TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
        filled: true,
        fillColor: Colors.black38,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }
}
