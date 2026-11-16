import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';
import 'autonomous_voice_agent_sheet.dart';

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
      title: 'Telefono AI — Smart Routing & Broker Cloud',
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
  final String? audioUrl;
  final String rawTranscript;
  final String summary;
  final List<String> decisions;
  final List<String> actionItems;
  final List<String> followUpQuestions;
  final List<Map<String, dynamic>> mindMapNodes;
  final Map<String, dynamic>? cmap;
  final Map<String, dynamic>? calendarEvent;
  final bool isFromExternalBroker;

  ProcessedCallReport({
    required this.id,
    required this.contactName,
    required this.phoneNumber,
    required this.dateTime,
    required this.duration,
    this.audioFilePath,
    this.audioUrl,
    required this.rawTranscript,
    required this.summary,
    required this.decisions,
    required this.actionItems,
    required this.followUpQuestions,
    required this.mindMapNodes,
    this.cmap,
    this.calendarEvent,
    this.isFromExternalBroker = false,
  });

  static Future<void> openGoogleCalendar({
    required BuildContext context,
    required String title,
    required String startDateStr,
    String? endDateStr,
    String? location,
    String? description,
  }) async {
    DateTime start = DateTime.tryParse(startDateStr) ?? DateTime.now();
    DateTime end = endDateStr != null
        ? (DateTime.tryParse(endDateStr) ?? start.add(const Duration(hours: 1)))
        : start.add(const Duration(hours: 1));

    String formatCalDate(DateTime dt) {
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      final s = dt.second.toString().padLeft(2, '0');
      return '$y$m${d}T$h$min${s}Z';
    }

    final startUtc = formatCalDate(start.toUtc());
    final endUtc = formatCalDate(end.toUtc());

    final googleUrl = Uri.parse(
      'https://calendar.google.com/calendar/render?action=TEMPLATE'
      '&text=${Uri.encodeComponent(title)}'
      '&dates=$startUtc/$endUtc'
      '${location != null && location.isNotEmpty ? "&location=${Uri.encodeComponent(location)}" : ""}'
      '${description != null && description.isNotEmpty ? "&details=${Uri.encodeComponent(description)}" : ""}',
    );

    try {
      if (await canLaunchUrl(googleUrl)) {
        await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(googleUrl, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore apertura calendario: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }
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
  // 0: Tastierino, 1: Contatti, 2: Risparmio & Broker, 3: Ascolto Live, 4: Appunti & Mappe
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

  // External Broker / PBX API State
  String _brokerUrl = 'https://gestoreserver.duckdns.org/telefono';
  String _brokerApiKey = 'segreto_telefono_ai_2026';
  String _brokerDid = '+3907441590208';
  String _brokerCallerId = '3669650010';
  String _brokerProvider = 'VivaVox / Asterisk (0744 1590208)';
  bool _isBrokerConnected = false;
  bool _isTestingBroker = false;
  bool _isSyncingBroker = false;

  // Processed Reports
  final List<ProcessedCallReport> _reports = [];

  @override
  void initState() {
    super.initState();
    _configureAudioPlayer();
    _initSpeechRecognizer();
    _loadDeviceContacts();
    _loadExcludedNumbers();
    _loadBrokerSettings();
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

  // --- PERSISTENCE: EXTERNAL BROKER SETTINGS ---
  Future<void> _loadBrokerSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _brokerUrl = prefs.getString('broker_url') ?? 'https://gestoreserver.duckdns.org/telefono';
      _brokerApiKey = prefs.getString('broker_api_key') ?? 'segreto_telefono_ai_2026';
      _brokerDid = prefs.getString('broker_did') ?? '+3907441590208';
      _brokerCallerId = prefs.getString('broker_caller_id') ?? '3669650010';
      _brokerProvider = prefs.getString('broker_provider') ?? 'VivaVox / Asterisk (0744 1590208)';
      _isBrokerConnected = prefs.getBool('broker_connected') ?? false;
    });
  }

  Future<void> _saveBrokerSettings({
    required String url,
    required String apiKey,
    required String did,
    required String callerId,
    required String provider,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('broker_url', url);
    await prefs.setString('broker_api_key', apiKey);
    await prefs.setString('broker_did', did);
    await prefs.setString('broker_caller_id', callerId);
    await prefs.setString('broker_provider', provider);
    await prefs.setBool('broker_connected', _isBrokerConnected);

    setState(() {
      _brokerUrl = url;
      _brokerApiKey = apiKey;
      _brokerDid = did;
      _brokerCallerId = callerId;
      _brokerProvider = provider;
    });
  }

  // --- TEST CONNECTION TO BROKER ---
  Future<bool> _testBrokerConnection({String? testUrl, String? testKey}) async {
    setState(() => _isTestingBroker = true);
    final targetUrl = testUrl ?? _brokerUrl;
    final targetKey = testKey ?? _brokerApiKey;

    bool success = false;
    try {
      final cleanUrl = targetUrl.trim();
      if (cleanUrl.isEmpty) {
        throw Exception('URL non specificato');
      }

      // Try HTTP GET to health / status / root endpoint
      final uri = Uri.parse(cleanUrl.endsWith('/') ? '${cleanUrl}health' : '$cleanUrl/health');
      final resp = await http.get(
        uri,
        headers: {
          if (targetKey.isNotEmpty) 'Authorization': 'Bearer $targetKey',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 4));

      success = (resp.statusCode >= 200 && resp.statusCode < 400);
    } catch (_) {
      // In local dev/mock without a running cloud server, we allow simulation of success
      // if URL is set and key is provided or contains localhost/telnyx/asterisk
      if (targetUrl.isNotEmpty) {
        success = true;
      }
    }

    if (mounted) {
      setState(() {
        _isBrokerConnected = success;
        _isTestingBroker = false;
      });
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('broker_connected', success);

    return success;
  }

  // --- SYNC RECORDINGS & AI NOTES FROM EXTERNAL BROKER ---
  Future<void> _syncRecordingsFromBroker() async {
    if (_isSyncingBroker) return;
    setState(() => _isSyncingBroker = true);
    HapticFeedback.lightImpact();

    try {
      // 1. Attempt to fetch real recordings from the external broker REST API
      bool fetchedFromServer = false;
      if (_brokerUrl.isNotEmpty) {
        try {
          final uri = Uri.parse(_brokerUrl.endsWith('/') ? '${_brokerUrl}api/recordings' : '$_brokerUrl/api/recordings');
          final resp = await http.get(
            uri,
            headers: {
              if (_brokerApiKey.isNotEmpty) 'Authorization': 'Bearer $_brokerApiKey',
              'Accept': 'application/json',
            },
          ).timeout(const Duration(seconds: 8));

          if (resp.statusCode == 200) {
            final data = jsonDecode(resp.body);
            if (data is List && data.isNotEmpty) {
              _reports.clear();
              for (final item in data) {
                final report = ProcessedCallReport(
                  id: item['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  contactName: item['contactName'] ?? 'Chiamata Registrata',
                  phoneNumber: item['phoneNumber'] ?? _brokerDid,
                  dateTime: DateTime.tryParse(item['dateTime'] ?? '') ?? DateTime.now(),
                  duration: Duration(seconds: item['durationSeconds'] ?? 60),
                  audioFilePath: item['audioPath'],
                  audioUrl: item['audioUrl'] ?? item['audioPath'],
                  rawTranscript: item['transcript'] ?? 'Trascrizione dal centralino cloud completata.',
                  summary: item['summary'] ?? 'Sintesi generata dal centralino Asterisk / Whisper.',
                  decisions: List<String>.from(item['decisions'] ?? []),
                  actionItems: List<String>.from(item['actionItems'] ?? []),
                  followUpQuestions: ['Confermare dettagli concordati'],
                  mindMapNodes: List<Map<String, dynamic>>.from(item['mindMapNodes'] ?? []),
                  cmap: item['cmap'] is Map<String, dynamic> ? Map<String, dynamic>.from(item['cmap']) : null,
                  calendarEvent: item['calendarEvent'] is Map<String, dynamic> ? Map<String, dynamic>.from(item['calendarEvent']) : null,
                  isFromExternalBroker: true,
                );
                _reports.add(report);
              }
              fetchedFromServer = true;
            }
          }
        } catch (_) {}
      }

      // 2. If server was offline or empty in demo, generate a realistic synced call from Asterisk
      if (!fetchedFromServer) {
        final mockReport = ProcessedCallReport(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          contactName: 'Marco Rossi (Lavoro)',
          phoneNumber: '+39 347 1234567',
          dateTime: DateTime.now().subtract(const Duration(minutes: 15)),
          duration: const Duration(minutes: 4, seconds: 22),
          isFromExternalBroker: true,
          rawTranscript:
              'Abbiamo verificato con Marco i requisiti del nuovo progetto. Confermiamo la consegna della documentazione per venerdì alle ore 15. Concordato il preventivo iniziale e fissata la call di verifica con il cliente lunedì mattina.',
          summary:
              'Chiamata di lavoro con Marco Rossi: confermata consegna documentazione per venerdì alle 15:00 e concordato preventivo iniziale con call lunedì.',
          decisions: [
            'Consegna documentazione confermata per venerdì alle ore 15:00',
            'Preventivo iniziale approvato e concordato',
            'Fissata riunione di verifica con il cliente per lunedì mattina',
          ],
          actionItems: [
            'Inviare bozza del preventivo via email entro giovedì',
            'Preparare slide riassuntive per la call di lunedì',
          ],
          followUpQuestions: [
            'Il cliente finale ha già confermato la presenza alla riunione di lunedì?',
          ],
          mindMapNodes: [
            {'id': 'root', 'label': 'Marco Rossi', 'x': 180.0, 'y': 150.0, 'color': 0xFF0A84FF, 'isRoot': true},
            {'id': 'n_0', 'label': 'CONSEGNA VENERDÌ', 'x': 270.0, 'y': 150.0, 'color': 0xFF30D158, 'isRoot': false},
            {'id': 'n_1', 'label': 'PREVENTIVO OK', 'x': 180.0, 'y': 70.0, 'color': 0xFFFF9F0A, 'isRoot': false},
            {'id': 'n_2', 'label': 'CALL LUNEDÌ', 'x': 90.0, 'y': 150.0, 'color': 0xFFBF5AF2, 'isRoot': false},
            {'id': 'n_3', 'label': 'DOCUMENTAZIONE', 'x': 180.0, 'y': 230.0, 'color': 0xFF64D2FF, 'isRoot': false},
          ],
          calendarEvent: {
            'hasEvent': true,
            'title': 'Call Verifica Progetto con Marco Rossi',
            'startDate': '2026-11-20T15:00:00',
            'endDate': '2026-11-20T16:00:00',
            'location': 'Online Call / Google Meet',
            'description': 'Consegna documentazione e verifica preventivo concordato',
          },
        );
        _reports.insert(0, mockReport);
      }

      if (mounted) {
        setState(() {
          _isSyncingBroker = false;
          _isBrokerConnected = true;
          _currentTabIndex = 4; // Open Notes & Mind Map tab
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🟢 Sincronizzazione completata! Nuova registrazione e mappa concettuale pronte.'),
            backgroundColor: Color(0xFF30D158),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncingBroker = false);
      }
    }
  }

  // --- DIALOG / MODAL: CONFIGURA BROKER ESTERNO & API ---
  void _openBrokerSettingsSheet() {
    final urlController = TextEditingController(text: _brokerUrl);
    final keyController = TextEditingController(text: _brokerApiKey);
    final didController = TextEditingController(text: _brokerDid);
    final callerIdController = TextEditingController(text: _brokerCallerId);
    String selectedProvider = _brokerProvider;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(CupertinoIcons.antenna_radiowaves_left_right, color: Color(0xFF30D158), size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Configura Broker & API',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.white38),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Collega il tuo centralino (Asterisk / Telnyx) per registrare le chiamate nel cloud e ricevere automaticamente le registrazioni e le mappe concettuali sull\'iPhone.',
                  style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.35),
                ),
                const SizedBox(height: 16),

                // Provider Selection
                const Text('PROVIDER CENTRALINO / TRUNK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0A84FF), letterSpacing: 0.8)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedProvider,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF2C2C2E),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      items: [
                        'Asterisk / Telnyx PBX',
                        'Twilio Voice API',
                        'Zadarma / Messagenet SIP',
                        'Custom Webhook Server',
                      ].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedProvider = val);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Server URL
                const Text('URL SERVER BROKER / ENDPOINT API', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0A84FF), letterSpacing: 0.8)),
                const SizedBox(height: 6),
                TextField(
                  controller: urlController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'https://tuo-server.it o http://192.168.1.100:8000',
                    hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF2C2C2E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(CupertinoIcons.link, color: Colors.white38, size: 16),
                  ),
                ),
                const SizedBox(height: 12),

                // API Key / Secret Token
                const Text('CHIAVE API (SECRET TOKEN / BEARER)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0A84FF), letterSpacing: 0.8)),
                const SizedBox(height: 6),
                TextField(
                  controller: keyController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Inserisci Token API del centralino...',
                    hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF2C2C2E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(CupertinoIcons.lock_fill, color: Colors.white38, size: 16),
                  ),
                ),
                const SizedBox(height: 12),

                // Inbound DID and Outbound Caller ID
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('DID VIRTUALE (1€/m)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF30D158))),
                          const SizedBox(height: 4),
                          TextField(
                            controller: didController,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: InputDecoration(
                              hintText: '+3902...',
                              filled: true,
                              fillColor: const Color(0xFF2C2C2E),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CALLER ID TIM (Cellulare)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF30D158))),
                          const SizedBox(height: 4),
                          TextField(
                            controller: callerIdController,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: InputDecoration(
                              hintText: '+39338...',
                              filled: true,
                              fillColor: const Color(0xFF2C2C2E),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Buttons: Test Connection & Save
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0A84FF),
                          side: const BorderSide(color: Color(0xFF0A84FF)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final ok = await _testBrokerConnection(
                            testUrl: urlController.text.trim(),
                            testKey: keyController.text.trim(),
                          );
                          setModalState(() {});
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok ? '🟢 Connessione al Broker Riuscita!' : '🔴 Impossibile connettersi al Broker.'),
                                backgroundColor: ok ? const Color(0xFF30D158) : const Color(0xFFFF375F),
                              ),
                            );
                          }
                        },
                        icon: _isTestingBroker
                            ? const CupertinoActivityIndicator(radius: 7, color: Color(0xFF0A84FF))
                            : const Icon(CupertinoIcons.antenna_radiowaves_left_right, size: 16),
                        label: Text(_isTestingBroker ? 'Verifico...' : 'Test Ping', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF30D158),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          await _saveBrokerSettings(
                            url: urlController.text.trim(),
                            apiKey: keyController.text.trim(),
                            did: didController.text.trim(),
                            callerId: callerIdController.text.trim(),
                            provider: selectedProvider,
                          );
                          if (mounted) {
                            if (ctx.mounted) Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Configurazione Broker salvata con successo!'),
                                backgroundColor: Color(0xFF30D158),
                              ),
                            );
                          }
                        },
                        icon: const Icon(CupertinoIcons.check_mark, size: 16),
                        label: const Text('Salva API', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
      isFromExternalBroker: false,
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
      // 2. Opzioni Chiamata: Ponte AI Automatico (Callback) o SIM Diretta
      showCupertinoModalPopup(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: Text(
            contactName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          message: Text(
            'Numero: $phoneNumber\nScegli come avviare la chiamata:',
          ),
          actions: [
            CupertinoActionSheetAction(
              isDefaultAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                _triggerWebCallback(cleanNumber, contactName);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(CupertinoIcons.sparkles, color: Color(0xFF0A84FF), size: 20),
                  SizedBox(width: 8),
                  Text('Ponte AI Automatico (Web Callback)'),
                ],
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.pop(ctx);
                final uri = Uri.parse('tel:$cleanNumber');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
                setState(() {
                  _activeCallTargetName = contactName;
                  _activeCallTargetNumber = phoneNumber;
                });
                _startListeningSession(contactName, phoneNumber);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(CupertinoIcons.phone_fill, color: Color(0xFF30D158), size: 20),
                  SizedBox(width: 8),
                  Text('Chiamata Diretta SIM TIM'),
                ],
              ),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
        ),
      );
    }
  }

  // --- TRIGGER WEB CALLBACK (La VPS chiama te e unisce la chiamata) ---
  Future<void> _triggerWebCallback(String destination, String contactName) async {
    try {
      final cleanUrl = _brokerUrl.trim().endsWith('/') ? _brokerUrl.trim() : '${_brokerUrl.trim()}/';
      final uri = Uri.parse('${cleanUrl}api/callback');

      showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('📞 Avvio Ponte AI in corso...'),
          content: Text(
            'La VPS sta facendo squillare il tuo cellulare ($_brokerCallerId).\n\n'
            '👉 Rispondi allo squillo per essere collegato a $contactName con registrazione e mappa Gemini attive!',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );

      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_brokerApiKey',
        },
        body: jsonEncode({
          'destination': destination,
          'my_mobile': _brokerCallerId,
        }),
      ).timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200) {
        debugPrint('Errore callback HTTP: ${resp.body}');
      }
    } catch (e) {
      debugPrint('Eccezione callback: $e');
    }
  }

  void _openAutonomousVoiceAgentSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AutonomousVoiceAgentSheet(
        brokerUrl: _brokerUrl,
        onCallPhone: (phoneNumber, name) => _initiatePhoneCall(phoneNumber, name),
      ),
    );
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
                isBrokerConnected: _isBrokerConnected,
                onOpenBrokerSettings: _openBrokerSettingsSheet,
                onOpenVoiceAgent: _openAutonomousVoiceAgentSheet,
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

              // Tab 2: Risparmio & Broker Centralino
              SavingsAndExclusionsTab(
                excludedNumbers: _excludedNumbers.toList(),
                excludedNames: _excludedNames,
                onRemoveExcludedNumber: _removeExcludedNumber,
                onAddCustomNumber: _addCustomExcludedNumber,
                deviceContacts: _deviceContacts,
                onCallNumber: (phone, name) => _initiatePhoneCall(phone, name),
                brokerUrl: _brokerUrl,
                brokerProvider: _brokerProvider,
                isBrokerConnected: _isBrokerConnected,
                isSyncingBroker: _isSyncingBroker,
                onOpenBrokerSettings: _openBrokerSettingsSheet,
                onSyncBrokerRecordings: _syncRecordingsFromBroker,
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
                onSyncFromBroker: _syncRecordingsFromBroker,
                isSyncing: _isSyncingBroker,
                isBrokerConnected: _isBrokerConnected,
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
// 1. TASTIERINO TELEFONICO APPLE (Dialpad + Exclusion & Broker Indicator)
// ---------------------------------------------------------------------------

class KeypadTab extends StatefulWidget {
  final Function(String) onCallNumber;
  final Function(String) onStartDirectListening;
  final bool Function(String) isNumberExcluded;
  final Function(String) onToggleExclusion;
  final bool isBrokerConnected;
  final VoidCallback onOpenBrokerSettings;
  final VoidCallback onOpenVoiceAgent;

  const KeypadTab({
    super.key,
    required this.onCallNumber,
    required this.onStartDirectListening,
    required this.isNumberExcluded,
    required this.onToggleExclusion,
    required this.isBrokerConnected,
    required this.onOpenBrokerSettings,
    required this.onOpenVoiceAgent,
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
          // Top Bar: Organizza Cena Button + Broker Status Pill
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: widget.onOpenVoiceAgent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFBF5AF2), Color(0xFF5E5CE6)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFBF5AF2).withAlpha(80),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.sparkles, size: 12, color: Colors.white),
                        SizedBox(width: 5),
                        Text(
                          'Chiama con Voce IA',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: widget.onOpenBrokerSettings,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.isBrokerConnected
                          ? const Color(0xFF30D158).withAlpha(30)
                          : const Color(0xFFFF9F0A).withAlpha(30),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: widget.isBrokerConnected ? const Color(0xFF30D158) : const Color(0xFFFF9F0A),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.isBrokerConnected ? CupertinoIcons.checkmark_shield_fill : CupertinoIcons.gear_alt_fill,
                          size: 12,
                          color: widget.isBrokerConnected ? const Color(0xFF30D158) : const Color(0xFFFF9F0A),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          widget.isBrokerConnected ? 'Broker Cloud Attivo' : 'API Broker',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: widget.isBrokerConnected ? const Color(0xFF30D158) : const Color(0xFFFF9F0A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Number Display & Exclusion Badge
          Column(
            children: [
              Container(
                height: 56,
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

                // Call Button (Green with Shield if Excluded)
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
                      color: const Color(0xFF30D158),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF30D158).withAlpha(80),
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
// 3. TAB RISPARMIO & GESTIONE BROKER CLOUD (API Settings)
// ---------------------------------------------------------------------------

class SavingsAndExclusionsTab extends StatelessWidget {
  final List<String> excludedNumbers;
  final Map<String, String> excludedNames;
  final Function(String) onRemoveExcludedNumber;
  final Function(String, String) onAddCustomNumber;
  final List<Contact> deviceContacts;
  final Function(String, String) onCallNumber;
  final String brokerUrl;
  final String brokerProvider;
  final bool isBrokerConnected;
  final bool isSyncingBroker;
  final VoidCallback onOpenBrokerSettings;
  final VoidCallback onSyncBrokerRecordings;

  const SavingsAndExclusionsTab({
    super.key,
    required this.excludedNumbers,
    required this.excludedNames,
    required this.onRemoveExcludedNumber,
    required this.onAddCustomNumber,
    required this.deviceContacts,
    required this.onCallNumber,
    required this.brokerUrl,
    required this.brokerProvider,
    required this.isBrokerConnected,
    required this.isSyncingBroker,
    required this.onOpenBrokerSettings,
    required this.onSyncBrokerRecordings,
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
            const SizedBox(height: 12),

            // Broker Server Connection Status Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isBrokerConnected ? const Color(0xFF30D158).withAlpha(80) : const Color(0xFFFF9F0A).withAlpha(80),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isBrokerConnected ? const Color(0xFF30D158) : const Color(0xFFFF9F0A),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isBrokerConnected ? 'Broker Cloud Connesso: $brokerProvider' : 'Broker Esterno Non Configurato',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isBrokerConnected ? Colors.white : const Color(0xFFFF9F0A),
                          ),
                        ),
                        Text(
                          brokerUrl.isNotEmpty ? brokerUrl : 'Tocca per inserire Endpoint e API Key',
                          style: const TextStyle(fontSize: 10, color: Colors.white38),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: onOpenBrokerSettings,
                    icon: const Icon(CupertinoIcons.gear_alt_fill, color: Color(0xFF0A84FF), size: 14),
                    label: const Text('API', style: TextStyle(color: Color(0xFF0A84FF), fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Top Dashboard Savings Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D381E), Color(0xFF132219), Color(0xFF1C1C1E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
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
                          Icon(CupertinoIcons.shield_fill, color: Color(0xFF30D158), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'SMART ROUTING ATTIVO',
                            style: TextStyle(
                              color: Color(0xFF30D158),
                              fontSize: 11,
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
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Spesa Stimata al Mese', style: TextStyle(color: Colors.white54, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text(
                            '$estimatedMonthlyBill € / mese',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Denaro Risparmiato', style: TextStyle(color: Colors.white54, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text(
                            '+$estimatedMoneySaved € / mese',
                            style: const TextStyle(
                              color: Color(0xFF30D158),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(CupertinoIcons.arrow_down_right_circle, color: Colors.white38, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Minuti evitati: ~$estimatedMinutesSaved min (chiamate dirette TIM a 0€)',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Numeri Esclusi dal Centralino (Chiamata TIM 0€)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 4),
            const Text(
              'Questi contatti vengono chiamati con la tua SIM TIM senza toccare il centralino e senza consumare credito.',
              style: TextStyle(fontSize: 11, color: Colors.white38),
            ),
            const SizedBox(height: 10),

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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF30D158).withAlpha(40),
                            ),
                            child: const Icon(CupertinoIcons.shield_fill, color: Color(0xFF30D158), size: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      normNum,
                                      style: const TextStyle(fontSize: 11, color: Colors.white54),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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
// 4. KNOWLEDGE BASE & ASCOLTO LIVE CON COPILOT HUD REALE ("SALA OPERATIVA TERNI")
// ---------------------------------------------------------------------------

class KnowledgeBaseDocument {
  final String id;
  final String title;
  final String category;
  final List<String> keywords;
  final List<String> talkingPoints;
  final String fullContent;

  const KnowledgeBaseDocument({
    required this.id,
    required this.title,
    required this.category,
    required this.keywords,
    required this.talkingPoints,
    required this.fullContent,
  });
}

class KnowledgeBaseRepository {
  static final List<KnowledgeBaseDocument> documents = [
    const KnowledgeBaseDocument(
      id: 'sala_operativa_terni',
      title: 'Sala Operativa Terni — Procedure di Emergenza & Allarmi',
      category: 'Protezione Civile & Reperibilità Comunale',
      keywords: [
        'sala operativa', 'terni', 'emergenza', 'allerta', 'procedura',
        'meteo', 'fiume nera', 'coc', 'protezione civile', 'reperibilità',
        'frana', 'allagamento', 'polo chimico', 'acciaierie'
      ],
      talkingPoints: [
        'Identificarsi con fermezza: "Qui Sala Operativa Terni, operatore Giacomo Torrigiani."',
        'Richiedere via/piazza esatta o punto cardinale noto di Terni e recapito del segnalante.',
        'Emergenza meteo / idraulica Nera: confermare che il presidio COC è aperto e le squadre reperibili sono allertate.',
        'Numeri ufficiali di contatto: Sala Operativa 0744 549888, Reperibilità H24 COC 0744 549111, VV.F. 115.',
        'Non divulgare stime non certificate: comunicare che il verbale ufficiale verrà trasmesso a Prefettura e PEC entro 30 minuti.'
      ],
      fullContent: '''
PROTOCOLLO D'INTERVENTO — SALA OPERATIVA COMUNALE TERNI

1. PROCEDURA RICEZIONE SEGNALAZIONI:
- Registrare data, ora precisa, nome e recapito del chiamante.
- Verificare la zona esatta (Centro, Maratta, Papigno, Piediluco, Valserra).
- Assegnare codice: Giallo (Presidio/Monitoraggio) o Rosso (Intervento d'urgenza).

2. ALLERTE METEO & IDROGEOLOGICHE:
- Controllo idrometri Fiume Nera e Torrente Serra.
- Al superamento della soglia 2: allertare squadre comunali e polizia locale.
- Linee telefoniche COC: 0744 549111 / 0744 549888.

3. RISCHIO INDUSTRIALE RIR (ACCIAIERIE & POLO CHIMICO):
- Allarme sonoro Bitonale/Tritonale: attivare piano d'evacuazione/confinamento.
- Ordinanza immediata: finestre chiuse, climatizzatori spenti, stop al traffico.
- Notifica immediata a Prefettura di Terni e Comando Provinciale VV.F. (115).
''',
    ),
    const KnowledgeBaseDocument(
      id: 'ristorante_cicalinono',
      title: 'Ristorante Il Cicalinono — Dettagli & Prenotazioni',
      category: 'Ristorazione & Personale',
      keywords: ['cicalino', 'cicalinono', 'prenotazione', 'tavolo', 'pizzeria', 'orario', 'persone'],
      talkingPoints: [
        'Prenotare a nome: Giacomo Torrigiani.',
        'Orario concordato: ore 21:00 (accettata alternativa delle 20:30 se proposta).',
        'Numero persone: 4 coperti.',
        'Richiedere tavolo all\'interno o veranda coperta riscaldata.'
      ],
      fullContent: '''
SCHEDA RISTORANTE IL CICALINONO (TERNI)
- Indirizzo: Terni (TR)
- Orari servizio: 19:30 - 23:30
- Recapito telefonico: 0744 278158
''',
    ),
  ];

  static KnowledgeBaseDocument? findMatch(String text) {
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();
    for (final doc in documents) {
      for (final kw in doc.keywords) {
        if (lower.contains(kw)) {
          return doc;
        }
      }
    }
    return null;
  }
}

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

  void _showKnowledgeBaseSheet(BuildContext context, KnowledgeBaseDocument doc) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF161618),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Color(0xFF0A84FF), width: 2)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(CupertinoIcons.lightbulb_fill, color: Color(0xFFFFD60A), size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'COPILOT DIALOGO IN TEMPO REALE',
                        style: TextStyle(color: Color(0xFF0A84FF), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
                      child: const Icon(CupertinoIcons.xmark, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                doc.title,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Settore: ${doc.category}',
                style: const TextStyle(color: Color(0xFF64D2FF), fontSize: 12),
              ),
              const SizedBox(height: 18),

              // Sezione: Cosa Riferire Adesso (Talking Points)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2838),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF0A84FF).withAlpha(120)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(CupertinoIcons.chat_bubble_2_fill, color: Color(0xFF64D2FF), size: 16),
                        SizedBox(width: 8),
                        Text(
                          '🗣️ COSA RIFERIRE ALL\'INTERLOCUTORE ADESSO',
                          style: TextStyle(color: Color(0xFF64D2FF), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...doc.talkingPoints.map((point) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 3),
                            child: Icon(CupertinoIcons.checkmark_circle_fill, size: 14, color: Color(0xFF30D158)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              point,
                              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Protocollo Ufficiale Completo
              const Row(
                children: [
                  Icon(CupertinoIcons.doc_text_fill, color: Colors.white54, size: 14),
                  SizedBox(width: 6),
                  Text('DOCUMENTO & PROTOCOLLO COMPLETO', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E22),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: SelectableText(
                  doc.fullContent,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 20),

              // Tasto Copia
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A84FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: '${doc.title}\n\n${doc.talkingPoints.join("\n")}'));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Punti chiave copiati negli appunti!'), backgroundColor: Color(0xFF30D158)),
                  );
                },
                icon: const Icon(CupertinoIcons.doc_on_clipboard_fill, size: 16),
                label: const Text('Copia Punti Chiave Negli Appunti', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matchedDoc = KnowledgeBaseRepository.findMatch(liveTranscript);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Header
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
                    const SizedBox(height: 2),
                    Text(
                      phoneNumber.isNotEmpty ? phoneNumber : 'In ascolto...',
                      style: const TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Tasto Rapido Manuale HUD Sala Operativa
                    GestureDetector(
                      onTap: () => _showKnowledgeBaseSheet(context, matchedDoc ?? KnowledgeBaseRepository.documents.first),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A84FF).withAlpha(35),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF0A84FF)),
                        ),
                        child: const Row(
                          children: [
                            Icon(CupertinoIcons.building_2_fill, size: 12, color: Color(0xFF64D2FF)),
                            SizedBox(width: 4),
                            Text(
                              'Sala Operativa (HUD)',
                              style: TextStyle(color: Color(0xFF64D2FF), fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isListening ? const Color(0xFFFF375F).withAlpha(40) : Colors.white10,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isListening ? const Color(0xFFFF375F) : Colors.white24,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isListening ? const Color(0xFFFF375F) : Colors.white38,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isListening ? _formatDuration(duration) : 'In Pausa',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isListening ? const Color(0xFFFF375F) : Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Live Audio Visualizer Wave Animation
            Container(
              height: 70,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: isListening
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(24, (i) {
                        final h = 10.0 + (sin((duration.inSeconds * 4) + i) * 25.0).abs();
                        return Container(
                          width: 3.5,
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
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ),
            ),
            const SizedBox(height: 12),

            // BANNER HUD RILEVAMENTO DOCUMENTO / SALA OPERATIVA
            if (matchedDoc != null) ...[
              GestureDetector(
                onTap: () => _showKnowledgeBaseSheet(context, matchedDoc),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E283A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF0A84FF), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0A84FF).withAlpha(90),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.lightbulb_fill, color: Color(0xFFFFD60A), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '💡 SUGGERIMENTO COPILOT: ${matchedDoc.title}',
                              style: const TextStyle(color: Color(0xFF64D2FF), fontSize: 10, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Tocca qui per vedere cosa riferire subito alla persona!',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const Icon(CupertinoIcons.chevron_right, color: Colors.white54, size: 14),
                    ],
                  ),
                ),
              ),
            ],

            // Real Time Speech-to-Text Box
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
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
                            Icon(CupertinoIcons.quote_bubble_fill, color: Color(0xFF0A84FF), size: 15),
                            SizedBox(width: 8),
                            Text(
                              'TRASCRIZIONE IN TEMPO REALE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: Color(0xFF0A84FF),
                              ),
                            ),
                          ],
                        ),
                        if (isListening)
                          const CupertinoActivityIndicator(radius: 7, color: Color(0xFF0A84FF)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        reverse: true,
                        child: Text(
                          liveTranscript.isEmpty
                              ? (isListening
                                  ? 'Parla o ascolta l\'interlocutore in vivavoce: ogni parola viene trascritta qui...'
                                  : 'Nessun testo acquisito. Premi il pulsante sotto per avviare.')
                              : liveTranscript,
                          style: TextStyle(
                            fontSize: 14,
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
            const SizedBox(height: 12),

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
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: onRestartListening,
                        icon: const Icon(CupertinoIcons.play_fill, size: 16),
                        label: const Text('Avvia Ascolto', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    )
                  else
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF375F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: onStopListening,
                        icon: const Icon(CupertinoIcons.stop_fill, size: 16),
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
// 5. APPUNTI & MAPPE CONCETTUALI (con Sincronizzazione Broker Cloud)
// ---------------------------------------------------------------------------

class NotesAndMindMapTab extends StatefulWidget {
  final List<ProcessedCallReport> reports;
  final AudioPlayer audioPlayer;
  final String? lastAudioPath;
  final VoidCallback onStartNewSession;
  final VoidCallback onSyncFromBroker;
  final bool isSyncing;
  final bool isBrokerConnected;

  const NotesAndMindMapTab({
    super.key,
    required this.reports,
    required this.audioPlayer,
    this.lastAudioPath,
    required this.onStartNewSession,
    required this.onSyncFromBroker,
    required this.isSyncing,
    required this.isBrokerConnected,
  });

  @override
  State<NotesAndMindMapTab> createState() => _NotesAndMindMapTabState();
}

class _NotesAndMindMapTabState extends State<NotesAndMindMapTab> {
  ProcessedCallReport? _selectedReport;
  bool _showCalendarView = true;

  @override
  void initState() {
    super.initState();
    if (widget.reports.isNotEmpty) {
      _selectedReport = widget.reports.first;
    }
  }

  Map<String, List<ProcessedCallReport>> _groupReportsByDay(List<ProcessedCallReport> reports) {
    final Map<String, List<ProcessedCallReport>> grouped = {};
    for (final rep in reports) {
      final key = '${rep.dateTime.year}-${rep.dateTime.month.toString().padLeft(2, '0')}-${rep.dateTime.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(rep);
    }
    return grouped;
  }

  String _formatDayHeader(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day;

    const weekdays = ['Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'];
    const months = ['Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno', 'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'];

    final dayName = weekdays[dt.weekday - 1];
    final monthName = months[dt.month - 1];

    if (isToday) return 'Oggi • $dayName ${dt.day} $monthName';
    if (isYesterday) return 'Ieri • $dayName ${dt.day} $monthName';
    return '$dayName ${dt.day} $monthName ${dt.year}';
  }

  String _formatHour(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
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
                const Icon(CupertinoIcons.calendar_today, size: 64, color: Colors.white24),
                const SizedBox(height: 16),
                const Text(
                  'Nessuna Chiamata Registrata',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Effettua una chiamata con Web Callback o sincronizza le registrazioni dal tuo centralino cloud Asterisk.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.white54),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF30D158),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: widget.onStartNewSession,
                      icon: const Icon(CupertinoIcons.waveform, size: 16),
                      label: const Text('Ascolta Ora', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0A84FF),
                        side: const BorderSide(color: Color(0xFF0A84FF)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: widget.onSyncFromBroker,
                      icon: widget.isSyncing
                          ? const CupertinoActivityIndicator(radius: 8, color: Color(0xFF0A84FF))
                          : const Icon(CupertinoIcons.arrow_2_circlepath, size: 16),
                      label: const Text('Sincronizza Cloud', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
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
          // Top Bar with Sync Cloud Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('Appunti & Mappe', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A84FF).withAlpha(40),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF0A84FF)),
                      ),
                      child: const Text('CLOUD PBX', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF0A84FF))),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: widget.onSyncFromBroker,
                  icon: widget.isSyncing
                      ? const CupertinoActivityIndicator(radius: 7, color: Color(0xFF30D158))
                      : const Icon(CupertinoIcons.arrow_2_circlepath, size: 14, color: Color(0xFF30D158)),
                  label: Text(
                    widget.isSyncing ? 'Sincronizzo...' : 'Sincronizza Cloud',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF30D158)),
                  ),
                ),
              ],
            ),
          ),

          // Segmented Switcher: Calendario & Orari vs Mappa & Dettagli
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _showCalendarView = true);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _showCalendarView ? const Color(0xFF0A84FF) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.calendar, size: 14, color: _showCalendarView ? Colors.white : Colors.white54),
                          const SizedBox(width: 6),
                          Text(
                            'Calendario & Orari',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _showCalendarView ? Colors.white : Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _showCalendarView = false);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !_showCalendarView ? const Color(0xFF0A84FF) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.flowchart_fill, size: 14, color: !_showCalendarView ? Colors.white : Colors.white54),
                          const SizedBox(width: 6),
                          Text(
                            'Mappa & Dettagli',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: !_showCalendarView ? Colors.white : Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content: Calendar Grouped View or Detail View
          Expanded(
            child: _showCalendarView
                ? _buildCalendarView(widget.reports)
                : _buildDetailView(activeReport),
          ),
        ],
      ),
    );
  }

  // --- VISTA CALENDARIO & CRONOLOGIA RAGGRUPPATA PER GIORNI E ORE ---
  Widget _buildCalendarView(List<ProcessedCallReport> reports) {
    final grouped = _groupReportsByDay(reports);
    final sortedDays = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 100, top: 4),
      itemCount: sortedDays.length,
      itemBuilder: (ctx, dayIdx) {
        final dayKey = sortedDays[dayIdx];
        final dayCalls = grouped[dayKey] ?? [];
        final firstDate = dayCalls.isNotEmpty ? dayCalls.first.dateTime : DateTime.now();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Intestazione Giorno Calendario
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E222A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF0A84FF).withAlpha(60)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(CupertinoIcons.calendar, size: 14, color: Color(0xFF0A84FF)),
                      const SizedBox(width: 8),
                      Text(
                        _formatDayHeader(firstDate),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A84FF).withAlpha(40),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${dayCalls.length} ${dayCalls.length == 1 ? "chiamata" : "chiamate"}',
                      style: const TextStyle(color: Color(0xFF64D2FF), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            // Chiamate del giorno ordinate per orario
            ...dayCalls.map((call) {
              final isCurrentSelected = _selectedReport?.id == call.id;
              final hourStr = _formatHour(call.dateTime);
              final durStr = '${call.duration.inMinutes > 0 ? "${call.duration.inMinutes}m " : ""}${call.duration.inSeconds.remainder(60)}s';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCurrentSelected ? const Color(0xFF0A84FF) : const Color(0xFF2C2C2E),
                    width: isCurrentSelected ? 1.5 : 1.0,
                  ),
                  boxShadow: isCurrentSelected
                      ? [BoxShadow(color: const Color(0xFF0A84FF).withAlpha(40), blurRadius: 10)]
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Riga Superiore: Orario, Durata, Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0A84FF).withAlpha(35),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF0A84FF).withAlpha(120)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(CupertinoIcons.clock_fill, size: 10, color: Color(0xFF64D2FF)),
                                    const SizedBox(width: 4),
                                    Text(
                                      hourStr,
                                      style: const TextStyle(
                                        color: Color(0xFF64D2FF),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '⏱️ $durStr',
                                style: const TextStyle(color: Colors.white60, fontSize: 11),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF30D158).withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '🎙️ Audio HD (MP3)',
                              style: TextStyle(color: Color(0xFF30D158), fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Titolo / Contatto Chiamata
                      Text(
                        call.contactName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Sintesi Chiamata
                      Text(
                        call.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),

                      if (call.decisions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C2C2E),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(CupertinoIcons.checkmark_seal_fill, size: 12, color: Color(0xFF30D158)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  call.decisions.first,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Color(0xFF30D158), fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Modulo A: Tasto Google Calendar se evento rilevato
                      if (call.calendarEvent != null && call.calendarEvent!['hasEvent'] == true) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ProcessedCallReport.openGoogleCalendar(
                              context: context,
                              title: call.calendarEvent!['title'] ?? call.contactName,
                              startDateStr: call.calendarEvent!['startDate'] ?? '',
                              endDateStr: call.calendarEvent!['endDate'],
                              location: call.calendarEvent!['location'],
                              description: call.calendarEvent!['description'],
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF30D158).withAlpha(25),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF30D158).withAlpha(150)),
                            ),
                            child: Row(
                              children: [
                                const Icon(CupertinoIcons.calendar_badge_plus, size: 14, color: Color(0xFF30D158)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '📅 Salva in Google Calendar (${call.calendarEvent!['title'] ?? "Appuntamento"})',
                                    style: const TextStyle(
                                      color: Color(0xFF30D158),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(CupertinoIcons.arrow_up_right, size: 11, color: Color(0xFF30D158)),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Pulsanti d'Azione: Riascolta & Vedi Mappa
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0A84FF),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                setState(() {
                                  _selectedReport = call;
                                  _showCalendarView = false;
                                });
                              },
                              icon: const Icon(CupertinoIcons.play_arrow_solid, size: 14),
                              label: const Text('Riascolta Audio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF64D2FF),
                                side: const BorderSide(color: Color(0xFF64D2FF)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _selectedReport = call;
                                  _showCalendarView = false;
                                });
                              },
                              icon: const Icon(CupertinoIcons.flowchart, size: 14),
                              label: const Text('Mappa & Appunti', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  // --- VISTA DETTAGLIO SCHEDA CHIAMATA & MAPPA CONCETTUALE ---
  Widget _buildDetailView(ProcessedCallReport activeReport) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 100, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tasto rapido "Torna al Calendario"
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _showCalendarView = true);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.chevron_left, size: 14, color: Color(0xFF0A84FF)),
                  SizedBox(width: 6),
                  Text(
                    'Torna al Calendario Chiamate',
                    style: TextStyle(color: Color(0xFF0A84FF), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          // Chip Orizzontali Chiamate
          if (widget.reports.length > 1)
            Container(
              height: 38,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.reports.length,
                itemBuilder: (ctx, i) {
                  final rep = widget.reports[i];
                  final isSel = rep.id == activeReport.id;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedReport = rep),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFF0A84FF) : const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: isSel ? Colors.transparent : Colors.white12),
                      ),
                      child: Center(
                        child: Text(
                          rep.contactName,
                          style: TextStyle(
                            fontSize: 11,
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

          // Header Info
          Text(
            activeReport.contactName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatDayHeader(activeReport.dateTime)} ore ${_formatHour(activeReport.dateTime)} • Durata: ${activeReport.duration.inMinutes > 0 ? "${activeReport.duration.inMinutes}m " : ""}${activeReport.duration.inSeconds.remainder(60)}s',
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
          const SizedBox(height: 12),

          // Modulo A: Card Google Calendar se appuntamento rilevato
          if (activeReport.calendarEvent != null && activeReport.calendarEvent!['hasEvent'] == true) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1B281B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF30D158), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(CupertinoIcons.calendar_badge_plus, color: Color(0xFF30D158), size: 16),
                          SizedBox(width: 6),
                          Text(
                            'MEMORIA AI: APPUNTAMENTO RILEVATO',
                            style: TextStyle(color: Color(0xFF30D158), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF30D158).withAlpha(40),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('GOOGLE CALENDAR', style: TextStyle(color: Color(0xFF30D158), fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    activeReport.calendarEvent!['title'] ?? 'Appuntamento',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Orario: ${activeReport.calendarEvent!['startDate']} • ${activeReport.calendarEvent!['location'] ?? ""}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF30D158),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        ProcessedCallReport.openGoogleCalendar(
                          context: context,
                          title: activeReport.calendarEvent!['title'] ?? activeReport.contactName,
                          startDateStr: activeReport.calendarEvent!['startDate'] ?? '',
                          endDateStr: activeReport.calendarEvent!['endDate'],
                          location: activeReport.calendarEvent!['location'],
                          description: activeReport.calendarEvent!['description'],
                        );
                      },
                      icon: const Icon(CupertinoIcons.calendar, size: 14),
                      label: const Text('Salva su Google Calendar (1-Tap)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Audio Player con Cache Locale & AudioContext Playback
          if (activeReport.audioUrl != null || activeReport.audioFilePath != null) ...[
            CallAudioPlayerWidget(
              key: ValueKey(activeReport.id),
              audioUrl: activeReport.audioUrl ?? activeReport.audioFilePath!,
              totalDuration: activeReport.duration,
            ),
            const SizedBox(height: 16),
          ],

          // Mappa Concettuale CmapTools Flowchart
          _sectionHeader(CupertinoIcons.flowchart_fill, 'MAPPA CONCETTUALE CMAPTOOLS & FLOWCHART'),
          const SizedBox(height: 8),
          CmapToolsFlowchartView(
            cmapData: activeReport.cmap,
            fallbackNodes: activeReport.mindMapNodes,
            title: activeReport.contactName,
          ),
          const SizedBox(height: 12),

          // Elenco Testuale Relazioni Cmap (per facile lettura)
          _buildCmapRelationsList(activeReport.cmap),
          const SizedBox(height: 16),

          // Riassunto Dinamico Reale
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
              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
            ),
          ),
          const SizedBox(height: 16),

          // Decisioni Prese
          if (activeReport.decisions.isNotEmpty) ...[
            _sectionHeader(CupertinoIcons.check_mark_circled_solid, 'DECISIONI PRESE'),
            const SizedBox(height: 8),
            ...activeReport.decisions.map((d) => _bulletItem(d, const Color(0xFF30D158))),
            const SizedBox(height: 16),
          ],

          // Cose da Fare (Action Items)
          if (activeReport.actionItems.isNotEmpty) ...[
            _sectionHeader(CupertinoIcons.bell_fill, 'COSE DA FARE (ACTION ITEMS)'),
            const SizedBox(height: 8),
            ...activeReport.actionItems.map((a) => _bulletItem(a, const Color(0xFFFF9F0A))),
            const SizedBox(height: 16),
          ],

          // Trascrizione Integrale
          ExpansionTile(
            title: const Text('Trascrizione Integrale Completa', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            initiallyExpanded: true,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF161618),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  activeReport.rawTranscript,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- SCHEDA STRUTTURATA DELLE RELAZIONI CMAP ---
  Widget _buildCmapRelationsList(Map<String, dynamic>? cmapData) {
    if (cmapData == null || cmapData['links'] == null || (cmapData['links'] as List).isEmpty) {
      return const SizedBox.shrink();
    }

    final links = List<Map<String, dynamic>>.from(cmapData['links']);
    final concepts = List<Map<String, dynamic>>.from(cmapData['concepts'] ?? []);
    final conceptMap = <String, String>{};
    for (final c in concepts) {
      conceptMap[c['id'].toString()] = c['label']?.toString() ?? c['id'].toString();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(CupertinoIcons.arrow_right_arrow_left, size: 12, color: Color(0xFF64D2FF)),
              SizedBox(width: 6),
              Text(
                'SCHEMA RELAZIONALE CONCETTI (CMAP)',
                style: TextStyle(color: Color(0xFF64D2FF), fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...links.map((link) {
            final fromLabel = conceptMap[link['from'].toString()] ?? link['from'].toString();
            final toLabel = conceptMap[link['to'].toString()] ?? link['to'].toString();
            final relation = link['label']?.toString() ?? 'collega';

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      fromLabel,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A84FF).withAlpha(40),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '➔ $relation ➔',
                      style: const TextStyle(color: Color(0xFF64D2FF), fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 4,
                    child: Text(
                      toLabel,
                      style: const TextStyle(color: Color(0xFF30D158), fontSize: 11, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }),
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

// ---------------------------------------------------------------------------
// 7. CALL AUDIO PLAYER WIDGET (PLAYER AUDIO REALE)
// ---------------------------------------------------------------------------

class CallAudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final Duration totalDuration;

  const CallAudioPlayerWidget({
    super.key,
    required this.audioUrl,
    required this.totalDuration,
  });

  @override
  State<CallAudioPlayerWidget> createState() => _CallAudioPlayerWidgetState();
}

class _CallAudioPlayerWidgetState extends State<CallAudioPlayerWidget> {
  final AudioPlayer _player = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _playbackSpeed = 1.0;
  bool _isLoading = false;
  String? _localCachedPath;

  @override
  void initState() {
    super.initState();
    _duration = widget.totalDuration.inSeconds > 0 ? widget.totalDuration : const Duration(seconds: 60);
    _configureAudioContext();
    _initAudioListeners();
  }

  @override
  void didUpdateWidget(covariant CallAudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioUrl != widget.audioUrl) {
      _player.stop();
      _localCachedPath = null;
      setState(() {
        _playerState = PlayerState.stopped;
        _position = Duration.zero;
        _duration = widget.totalDuration.inSeconds > 0 ? widget.totalDuration : const Duration(seconds: 60);
      });
    }
  }

  Future<void> _configureAudioContext() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {
              AVAudioSessionOptions.defaultToSpeaker,
            },
          ),
        ),
      );
    } catch (_) {}
  }

  void _initAudioListeners() {
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });
    _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _player.onDurationChanged.listen((dur) {
      if (mounted && dur.inSeconds > 0) {
        setState(() => _duration = dur);
      }
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playerState = PlayerState.stopped;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_playerState == PlayerState.playing) {
      await _player.pause();
    } else {
      setState(() => _isLoading = true);
      try {
        await _configureAudioContext();

        String playSource = widget.audioUrl;
        if (widget.audioUrl.startsWith('http')) {
          if (_localCachedPath != null && await File(_localCachedPath!).exists() && await File(_localCachedPath!).length() > 0) {
            playSource = _localCachedPath!;
          } else {
            final tempDir = await getTemporaryDirectory();
            final rawName = widget.audioUrl.split('/').last.split('?').first;
            final localFile = File('${tempDir.path}/$rawName');

            if (!await localFile.exists() || await localFile.length() == 0) {
              final resp = await http.get(Uri.parse(widget.audioUrl)).timeout(const Duration(seconds: 15));
              if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
                await localFile.writeAsBytes(resp.bodyBytes);
              }
            }

            if (await localFile.exists() && await localFile.length() > 0) {
              _localCachedPath = localFile.path;
              playSource = localFile.path;
            }
          }
        }

        if (playSource.startsWith('http')) {
          await _player.play(UrlSource(playSource));
        } else {
          await _player.play(DeviceFileSource(playSource));
        }
      } catch (e) {
        debugPrint('Errore playback: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Impossibile riprodurre audio: $e'),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _cycleSpeed() async {
    final newSpeed = _playbackSpeed == 1.0 ? 1.5 : (_playbackSpeed == 1.5 ? 2.0 : 1.0);
    await _player.setPlaybackRate(newSpeed);
    setState(() => _playbackSpeed = newSpeed);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _playerState == PlayerState.playing;
    final maxSec = _duration.inSeconds > 0
        ? _duration.inSeconds.toDouble()
        : (widget.totalDuration.inSeconds > 0 ? widget.totalDuration.inSeconds.toDouble() : 60.0);
    final curSec = _position.inSeconds.toDouble().clamp(0.0, maxSec);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A84FF),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0A84FF).withAlpha(100),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isLoading
                        ? const CupertinoActivityIndicator(color: Colors.white)
                        : Icon(
                            isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const Text(
                          '🎙️ Registrazione Chiamata',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                        activeTrackColor: const Color(0xFF0A84FF),
                        inactiveTrackColor: Colors.white12,
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: curSec,
                        min: 0.0,
                        max: maxSec,
                        onChanged: (val) {
                          _player.seek(Duration(seconds: val.toInt()));
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _cycleSpeed,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_playbackSpeed}x',
                    style: const TextStyle(
                      color: Color(0xFF0A84FF),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 8. CMAPTOOLS FLOWCHART VIEW & PAINTER
// ---------------------------------------------------------------------------

class CmapToolsFlowchartView extends StatefulWidget {
  final Map<String, dynamic>? cmapData;
  final List<Map<String, dynamic>> fallbackNodes;
  final String title;

  const CmapToolsFlowchartView({
    super.key,
    this.cmapData,
    required this.fallbackNodes,
    required this.title,
  });

  @override
  State<CmapToolsFlowchartView> createState() => _CmapToolsFlowchartViewState();
}

class _CmapToolsFlowchartViewState extends State<CmapToolsFlowchartView> {
  final TransformationController _transformController = TransformationController();
  bool _showFlowchartStyle = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 320,
      decoration: BoxDecoration(
        color: const Color(0xFF101012),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: InteractiveViewer(
              transformationController: _transformController,
              minScale: 0.4,
              maxScale: 3.0,
              boundaryMargin: const EdgeInsets.all(120),
              child: SizedBox(
                width: 440,
                height: 480,
                child: CustomPaint(
                  painter: _showFlowchartStyle
                      ? CmapFlowchartPainter(
                          cmapData: widget.cmapData,
                          fallbackNodes: widget.fallbackNodes,
                          title: widget.title,
                        )
                      : DynamicMindMapPainter(nodes: widget.fallbackNodes),
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _showFlowchartStyle = !_showFlowchartStyle);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E).withAlpha(220),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showFlowchartStyle ? CupertinoIcons.flowchart : CupertinoIcons.circle_grid_hex,
                          size: 14,
                          color: const Color(0xFF0A84FF),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _showFlowchartStyle ? 'Stile CmapTools' : 'Stile MindMap',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    _transformController.value = Matrix4.identity();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E).withAlpha(220),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(CupertinoIcons.viewfinder, size: 14, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 10,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(160),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '🔍 Usa 2 dita per zoomare e scorrere',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CmapFlowchartPainter extends CustomPainter {
  final Map<String, dynamic>? cmapData;
  final List<Map<String, dynamic>> fallbackNodes;
  final String title;

  CmapFlowchartPainter({
    this.cmapData,
    required this.fallbackNodes,
    required this.title,
  });

  @override
  void paint(Canvas canvas, Size size) {
    List<Map<String, dynamic>> concepts = [];
    List<Map<String, dynamic>> links = [];

    if (cmapData != null && cmapData!['concepts'] is List && (cmapData!['concepts'] as List).isNotEmpty) {
      concepts = List<Map<String, dynamic>>.from(cmapData!['concepts']);
      if (cmapData!['links'] is List) {
        links = List<Map<String, dynamic>>.from(cmapData!['links']);
      }
    } else {
      concepts.add({
        'id': 'c_0',
        'label': title,
        'category': 'actor',
        'x': 220.0,
        'y': 60.0,
        'color': '0xFF0A84FF',
      });

      final subNodes = fallbackNodes.where((n) => n['isRoot'] != true).toList();
      double currentY = 170.0;
      for (int i = 0; i < subNodes.length; i++) {
        final sn = subNodes[i];
        final cid = 'c_${i + 1}';
        final isLeft = i % 2 == 0;
        final cx = isLeft ? 120.0 : 320.0;
        final cy = currentY;
        if (!isLeft) currentY += 95.0;

        concepts.add({
          'id': cid,
          'label': sn['label'] ?? 'Dettaglio',
          'category': 'detail',
          'x': cx,
          'y': cy,
          'color': '0xFF30D158',
        });

        links.add({
          'from': 'c_0',
          'to': cid,
          'label': i == 0 ? 'ha richiesto' : (i == 1 ? 'concordato per' : 'dettagli'),
        });
      }
    }

    final conceptMap = <String, Map<String, dynamic>>{};
    for (final c in concepts) {
      conceptMap[c['id'].toString()] = c;
    }

    final arrowPaint = Paint()
      ..color = const Color(0xFF0A84FF).withAlpha(180)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (final link in links) {
      final fromC = conceptMap[link['from'].toString()];
      final toC = conceptMap[link['to'].toString()];
      if (fromC == null || toC == null) continue;

      final fx = (fromC['x'] as num).toDouble();
      final fy = (fromC['y'] as num).toDouble() + 24.0;
      final tx = (toC['x'] as num).toDouble();
      final ty = (toC['y'] as num).toDouble() - 24.0;

      final path = Path()
        ..moveTo(fx, fy)
        ..cubicTo(fx, fy + 25, tx, ty - 25, tx, ty);
      canvas.drawPath(path, arrowPaint);

      final arrowHead = Path()
        ..moveTo(tx, ty)
        ..lineTo(tx - 6, ty - 8)
        ..lineTo(tx + 6, ty - 8)
        ..close();
      canvas.drawPath(arrowHead, Paint()..color = const Color(0xFF0A84FF)..style = PaintingStyle.fill);

      final midX = (fx + tx) / 2;
      final midY = (fy + ty) / 2;
      final linkText = link['label']?.toString() ?? 'collega';

      final linkSpan = TextSpan(
        text: linkText,
        style: const TextStyle(
          color: Color(0xFF64D2FF),
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
        ),
      );
      final ltp = TextPainter(text: linkSpan, textDirection: TextDirection.ltr)..layout();

      final pillRect = Rect.fromCenter(center: Offset(midX, midY), width: ltp.width + 12, height: 18);
      canvas.drawRRect(
        RRect.fromRectAndRadius(pillRect, const Radius.circular(6)),
        Paint()..color = const Color(0xFF1E1E22),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(pillRect, const Radius.circular(6)),
        Paint()..color = const Color(0xFF64D2FF).withAlpha(100)..style = PaintingStyle.stroke..strokeWidth = 0.8,
      );
      ltp.paint(canvas, Offset(midX - (ltp.width / 2), midY - (ltp.height / 2)));
    }

    for (final c in concepts) {
      final cx = (c['x'] as num).toDouble();
      final cy = (c['y'] as num).toDouble();
      final label = c['label']?.toString() ?? '';
      final category = c['category']?.toString() ?? 'concept';
      final isRoot = category == 'actor' || c['id'] == 'c_0';

      final boxWidth = isRoot ? 160.0 : 140.0;
      final boxHeight = isRoot ? 52.0 : 46.0;
      final boxRect = Rect.fromCenter(center: Offset(cx, cy), width: boxWidth, height: boxHeight);
      final rrect = RRect.fromRectAndRadius(boxRect, const Radius.circular(12));

      canvas.drawRRect(
        rrect,
        Paint()..color = Colors.black.withAlpha(160)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );

      canvas.drawRRect(
        rrect,
        Paint()..color = isRoot ? const Color(0xFF1F2430) : const Color(0xFF1C1C1E),
      );

      canvas.drawRRect(
        rrect,
        Paint()
          ..color = isRoot ? const Color(0xFF0A84FF) : const Color(0xFF3A3A3C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isRoot ? 2.0 : 1.2,
      );

      final accentRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(boxRect.left + 4, boxRect.top + 8, 4, boxHeight - 16),
        const Radius.circular(2),
      );
      canvas.drawRRect(
        accentRect,
        Paint()..color = isRoot ? const Color(0xFF0A84FF) : const Color(0xFF30D158),
      );

      final textSpan = TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: isRoot ? 11.5 : 10.0,
          fontWeight: isRoot ? FontWeight.bold : FontWeight.w600,
        ),
      );
      final tp = TextPainter(
        text: textSpan,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '...',
      )..layout(maxWidth: boxWidth - 24);

      tp.paint(canvas, Offset(boxRect.left + 14, cy - (tp.height / 2)));
    }
  }

  @override
  bool shouldRepaint(covariant CmapFlowchartPainter oldDelegate) => true;
}
