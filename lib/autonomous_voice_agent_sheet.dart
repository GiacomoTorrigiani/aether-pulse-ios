import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

class AutonomousVoiceAgentSheet extends StatefulWidget {
  final String brokerUrl;
  final String? myMobile;
  final String? initialDestination;
  final String? initialContactName;
  final Function(String number, String name) onCallPhone;

  const AutonomousVoiceAgentSheet({
    super.key,
    required this.brokerUrl,
    this.myMobile,
    this.initialDestination,
    this.initialContactName,
    required this.onCallPhone,
  });

  @override
  State<AutonomousVoiceAgentSheet> createState() => _AutonomousVoiceAgentSheetState();
}

class _AutonomousVoiceAgentSheetState extends State<AutonomousVoiceAgentSheet> {
  late final TextEditingController _contactController;
  late final TextEditingController _phoneController;
  late final TextEditingController _myMobileController;
  late final TextEditingController _rawPromptController;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingPreview = false;
  String? _previewAudioUrl;

  bool _isRefining = false;
  Map<String, dynamic>? _refinedData;

  // Real Call state
  bool _isInitiatingCall = false;
  bool _isCallActive = false;
  bool _isServerChannelActive = false;
  bool _callCompleted = false;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _contactController = TextEditingController(text: widget.initialContactName ?? 'La Mia Ragazza');
    _phoneController = TextEditingController(text: widget.initialDestination ?? '+393381764701');
    _myMobileController = TextEditingController(text: widget.myMobile ?? '3669650010');
    _rawPromptController = TextEditingController(
      text: 'chiama la mia ragazza dille che arrivo per le 20 e 30 e chiedile cosa preferisce per cena stasera',
    );

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() => _isPlayingPreview = false);
      }
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _contactController.dispose();
    _phoneController.dispose();
    _myMobileController.dispose();
    _rawPromptController.dispose();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  Future<void> _refinePromptWithGemini() async {
    _dismissKeyboard();
    final rawText = _rawPromptController.text.trim();
    if (rawText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci prima cosa deve dire o chiedere l\'assistente.')),
      );
      return;
    }

    setState(() {
      _isRefining = true;
      _previewAudioUrl = null;
    });
    HapticFeedback.lightImpact();

    try {
      final uri = Uri.parse('${widget.brokerUrl}/api/voice-agent/refine-prompt');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'raw_prompt': rawText,
          'contact_name': _contactController.text.trim(),
          'contact_number': _phoneController.text.trim(),
        }),
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        setState(() {
          _refinedData = data;
        });
        HapticFeedback.mediumImpact();
      } else {
        throw Exception('Server error ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore ottimizzazione Gemini: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefining = false);
      }
    }
  }

  Future<void> _playVoicePreview() async {
    _dismissKeyboard();
    if (_isPlayingPreview) {
      await _audioPlayer.stop();
      setState(() => _isPlayingPreview = false);
      return;
    }

    final textToSpeak = _refinedData?['refined_opening'] ?? _rawPromptController.text.trim();
    if (textToSpeak.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci il testo prima di ascoltare l\'anteprima.')),
      );
      return;
    }

    setState(() => _isPlayingPreview = true);
    HapticFeedback.lightImpact();

    try {
      if (_previewAudioUrl != null) {
        await _audioPlayer.play(UrlSource(_previewAudioUrl!));
        return;
      }

      final uri = Uri.parse('${widget.brokerUrl}/api/voice-agent/synthesize-preview');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': textToSpeak,
          'stability': 0.5,
          'similarity_boost': 0.85,
        }),
      ).timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['status'] == 'ok' && data['audio_url'] != null) {
          _previewAudioUrl = data['audio_url'];
          await _audioPlayer.play(UrlSource(_previewAudioUrl!));
        } else {
          throw Exception(data['message'] ?? 'Errore sintesi');
        }
      } else {
        throw Exception('Status code ${resp.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore anteprima vocale: $e')),
        );
        setState(() => _isPlayingPreview = false);
      }
    }
  }

  Future<void> _launchAutonomousCall() async {
    _dismissKeyboard();
    final dest = _phoneController.text.trim();
    final myMobile = _myMobileController.text.trim();

    if (dest.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci il numero di telefono da chiamare.')),
      );
      return;
    }

    if (myMobile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci il tuo cellulare (su cui squillerà la VPS).')),
      );
      return;
    }

    final openingSpeech = _refinedData?['refined_opening'] ?? _rawPromptController.text.trim();
    if (openingSpeech.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci cosa dire prima di avviare la telefonata.')),
      );
      return;
    }

    setState(() {
      _isInitiatingCall = true;
      _isCallActive = false;
      _isServerChannelActive = false;
      _callCompleted = false;
    });
    HapticFeedback.heavyImpact();

    try {
      final uri = Uri.parse('${widget.brokerUrl}/api/voice-agent/initiate-call');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'destination': dest,
          'my_mobile': myMobile,
          'contact_name': _contactController.text.trim(),
          'opening_speech': openingSpeech,
          'objective': _refinedData?['call_objective'] ?? '',
        }),
      ).timeout(const Duration(seconds: 30));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['status'] == 'ok') {
          setState(() {
            _isInitiatingCall = false;
            _isCallActive = true;
          });
          HapticFeedback.heavyImpact();
          _startRealCallPolling();
        } else {
          throw Exception(data['message'] ?? 'Errore avvio');
        }
      } else {
        throw Exception('Status code ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitiatingCall = false;
          _isCallActive = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore avvio chiamata ponte: $e')),
        );
      }
    }
  }

  void _startRealCallPolling() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!mounted || !_isCallActive) {
        timer.cancel();
        return;
      }
      try {
        final uri = Uri.parse('${widget.brokerUrl}/api/voice-agent/status');
        final resp = await http.get(uri).timeout(const Duration(seconds: 3));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          final bool isChanActive = data['is_active'] == true;
          if (mounted) {
            if (isChanActive && !_isServerChannelActive) {
              // Channels bridged!
              setState(() {
                _isServerChannelActive = true;
              });
              HapticFeedback.mediumImpact();
            } else if (!isChanActive && _isServerChannelActive) {
              // Call finished!
              timer.cancel();
              setState(() {
                _isCallActive = false;
                _isServerChannelActive = false;
                _callCompleted = true;
              });
              HapticFeedback.heavyImpact();
            }
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _hangupCall() async {
    _statusTimer?.cancel();
    HapticFeedback.heavyImpact();
    setState(() {
      _isCallActive = false;
      _isServerChannelActive = false;
      _callCompleted = true;
    });

    try {
      final uri = Uri.parse('${widget.brokerUrl}/api/voice-agent/hangup');
      await http.post(uri, headers: {'Content-Type': 'application/json'}).timeout(const Duration(seconds: 5));
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔴 Chiamata terminata con successo.'),
          backgroundColor: Color(0xFFFF453A),
        ),
      );
    }
  }

  void _applyQuickPreset(String contact, String phone, String prompt) {
    setState(() {
      _contactController.text = contact;
      _phoneController.text = phone;
      _rawPromptController.text = prompt;
      _refinedData = null;
      _previewAudioUrl = null;
    });
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = bottomInset > 0;

    return GestureDetector(
      onTap: _dismissKeyboard,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.94,
        decoration: const BoxDecoration(
          color: Color(0xFF000000),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle Bar
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 12),

            // Header Row with Title and [ Chiudi Tastiera ] or [ X ]
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0A84FF), Color(0xFF5E5CE6)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chiama con la Mia Voce IA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Ponte VoIP • Voce Clonata ElevenLabs • Ascolto Live',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (isKeyboardOpen)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF0A84FF).withAlpha(40),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _dismissKeyboard,
                      icon: const Icon(CupertinoIcons.keyboard_chevron_compact_down, color: Color(0xFF0A84FF), size: 16),
                      label: const Text(
                        'Chiudi',
                        style: TextStyle(color: Color(0xFF0A84FF), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.white38, size: 24),
                      onPressed: () => Navigator.pop(context),
                    ),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 16),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // How it works banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(CupertinoIcons.info_circle_fill, color: Color(0xFF0A84FF), size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Come funziona: La VPS fa squillare prima il tuo iPhone. Tu rispondi, e la VPS chiama subito il destinatario trasmettendo il messaggio clonato con la tua vera voce. Sei già in linea per ascoltare tutto in tempo reale e intervenire a voce quando vuoi!',
                              style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Quick Scenario Presets
                    const Text(
                      'SCENARI RAPIDI:',
                      style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _presetChip(
                            label: '❤️ Cena con la Ragazza',
                            onTap: () => _applyQuickPreset(
                              'La Mia Ragazza',
                              '+393381764701',
                              'ciao amore arrivo per le otto e mezza cosa preferisci che prendo per cena stasera',
                            ),
                          ),
                          _presetChip(
                            label: '🦷 Studio Dentistico',
                            onTap: () => _applyQuickPreset(
                              'Studio Dentistico',
                              '0744 1590208',
                              'salve vorrei prenotare una pulizia dei denti giovedi mattina verso le 11',
                            ),
                          ),
                          _presetChip(
                            label: '🍝 Ristorante',
                            onTap: () => _applyQuickPreset(
                              'Ristorante Il Cicalino',
                              '0744 278158',
                              'buonasera vorrei prenotare un tavolo per 4 persone a nome Giacomo per sabato sera alle 21',
                            ),
                          ),
                          _presetChip(
                            label: '🚗 Officina Auto',
                            onTap: () => _applyQuickPreset(
                              'Officina Auto',
                              '0744 1590208',
                              'salve vorrei sapere se la mia macchina è pronta per il ritiro stasera',
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Contact & Phone Inputs
                    Row(
                      children: [
                        Expanded(
                          flex: 6,
                          child: TextField(
                            controller: _contactController,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Chi vuoi chiamare?',
                              labelStyle: const TextStyle(color: Colors.white60, fontSize: 11),
                              prefixIcon: const Icon(CupertinoIcons.person_fill, color: Color(0xFF0A84FF), size: 16),
                              filled: true,
                              fillColor: const Color(0xFF1C1C1E),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 5,
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Destinatario',
                              labelStyle: const TextStyle(color: Colors.white60, fontSize: 11),
                              prefixIcon: const Icon(CupertinoIcons.phone_fill, color: Color(0xFF30D158), size: 16),
                              filled: true,
                              fillColor: const Color(0xFF1C1C1E),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // My Mobile callback row
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.device_phone_portrait, color: Color(0xFFFF9F0A), size: 16),
                          const SizedBox(width: 8),
                          const Text(
                            'Il Tuo iPhone:',
                            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _myMobileController,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(color: Color(0xFFFF9F0A), fontSize: 12, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: '3669650010',
                                hintStyle: TextStyle(color: Colors.white30, fontSize: 12),
                                contentPadding: EdgeInsets.symmetric(vertical: 4),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9F0A).withAlpha(40),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Squilla prima qui',
                              style: TextStyle(color: Color(0xFFFF9F0A), fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Prompt Box
                    Container(
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
                              const Row(
                                children: [
                                  Icon(CupertinoIcons.mic_fill, color: Color(0xFF0A84FF), size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'COSA VUOI CHE DICA IL BOT:',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              if (isKeyboardOpen)
                                GestureDetector(
                                  onTap: _dismissKeyboard,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0A84FF),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(CupertinoIcons.checkmark, color: Colors.white, size: 11),
                                        SizedBox(width: 4),
                                        Text('Fatto', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _rawPromptController,
                            maxLines: 3,
                            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
                            decoration: const InputDecoration(
                              hintText: 'Scrivi pure veloce con abbreviazioni o errori, Gemini capirà e formulerà una telefonata perfetta...',
                              hintStyle: TextStyle(color: Colors.white30, fontSize: 12),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Gemini refine button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0A84FF),
                                side: const BorderSide(color: Color(0xFF0A84FF), width: 1.2),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _isRefining ? null : _refinePromptWithGemini,
                              icon: _isRefining
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0A84FF)),
                                    )
                                  : const Icon(CupertinoIcons.wand_stars, size: 16),
                              label: Text(
                                _isRefining ? 'Gemini sta ottimizzando il testo...' : '✨ Ottimizza & Correggi con Gemini',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Gemini Refined Speech Preview Card
                    if (_refinedData != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF0A84FF).withAlpha(30),
                              const Color(0xFF5E5CE6).withAlpha(30),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF0A84FF).withAlpha(80), width: 1.2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(CupertinoIcons.waveform_path_badge_plus, color: Color(0xFF30D158), size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'FRASE D\'APERTURA (CLONATA CON LA TUA VOCE):',
                                  style: TextStyle(color: Color(0xFF30D158), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '"${_refinedData!['refined_opening']}"',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Audio preview button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isPlayingPreview ? const Color(0xFFFF453A) : const Color(0xFF0A84FF),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                onPressed: _playVoicePreview,
                                icon: Icon(
                                  _isPlayingPreview ? CupertinoIcons.stop_fill : CupertinoIcons.play_arrow_solid,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                label: Text(
                                  _isPlayingPreview ? 'Ferma Anteprima' : '▶️ Ascolta con la mia Voce (ElevenLabs)',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Always visible LAUNCH CALL BUTTON
                    if (!_isCallActive && !_callCompleted) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF30D158),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 4,
                          ),
                          onPressed: _isInitiatingCall ? null : _launchAutonomousCall,
                          icon: _isInitiatingCall
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : const Icon(CupertinoIcons.phone_fill, color: Colors.black, size: 20),
                          label: Text(
                            _isInitiatingCall
                                ? 'Sintesi & Creazione Ponte in corso...'
                                : '📞 Avvia Telefonata con la Mia Voce IA',
                            style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],

                    // LIVE CALL REAL DASHBOARD
                    if (_isCallActive || _callCompleted || _isInitiatingCall) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _callCompleted
                                ? const Color(0xFF30D158)
                                : (_isServerChannelActive ? const Color(0xFF30D158) : const Color(0xFFFF9F0A)),
                            width: 1.5,
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
                                    Icon(
                                      _callCompleted
                                          ? CupertinoIcons.checkmark_seal_fill
                                          : (_isServerChannelActive
                                              ? CupertinoIcons.waveform_circle_fill
                                              : CupertinoIcons.phone_arrow_up_right),
                                      color: _callCompleted
                                          ? const Color(0xFF30D158)
                                          : (_isServerChannelActive
                                              ? const Color(0xFF30D158)
                                              : const Color(0xFFFF9F0A)),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _callCompleted
                                          ? 'CHIAMATA CONCLUSA'
                                          : (_isServerChannelActive ? '🟢 SEI IN LINEA (LIVE)' : '📞 SQUILLO IN ARRIVO'),
                                      style: TextStyle(
                                        color: _callCompleted
                                            ? const Color(0xFF30D158)
                                            : (_isServerChannelActive
                                                ? const Color(0xFF30D158)
                                                : const Color(0xFFFF9F0A)),
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_isCallActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: (_isServerChannelActive
                                              ? const Color(0xFF30D158)
                                              : const Color(0xFFFF9F0A))
                                          .withAlpha(40),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 8,
                                          height: 8,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: _isServerChannelActive
                                                ? const Color(0xFF30D158)
                                                : const Color(0xFFFF9F0A),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _isServerChannelActive ? 'LIVE' : 'SQUILLO',
                                          style: TextStyle(
                                            color: _isServerChannelActive
                                                ? const Color(0xFF30D158)
                                                : const Color(0xFFFF9F0A),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Phase 1: Waiting for Giacomo to answer
                            if (_isCallActive && !_isServerChannelActive) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF9F0A).withAlpha(20),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFF9F0A).withAlpha(60)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(CupertinoIcons.phone_arrow_up_right, color: Color(0xFFFF9F0A), size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Squillo in arrivo su: ${_myMobileController.text}',
                                            style: const TextStyle(
                                                color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      '👉 Rispondi alla chiamata in arrivo sul tuo iPhone dalla VPS (0744 1590208) per attivare subito il ponte verso il destinatario con la tua voce clonata!',
                                      style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (_isCallActive && _isServerChannelActive) ...[
                              // Phase 2: Live connected
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF30D158).withAlpha(20),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF30D158).withAlpha(60)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(CupertinoIcons.waveform_path, color: Color(0xFF30D158), size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Collegato con: ${_phoneController.text} (${_contactController.text})',
                                            style: const TextStyle(
                                                color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      '🎙️ Sei in linea! Stai ascoltando la telefonata in diretta dal tuo iPhone.\nParla direttamente al microfono per intervenire a voce, o ascolta in vivavoce.',
                                      style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Hangup button
                            if (_isCallActive) ...[
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF453A),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: _hangupCall,
                                  icon: const Icon(CupertinoIcons.phone_down_fill, color: Colors.white, size: 18),
                                  label: const Text(
                                    '🔴 Riattacca Telefonata',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ),
                            ],

                            // Completed summary
                            if (_callCompleted) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF30D158).withAlpha(20),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF30D158).withAlpha(60)),
                                ),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(CupertinoIcons.check_mark_circled_solid, color: Color(0xFF30D158), size: 18),
                                        SizedBox(width: 8),
                                        Text(
                                          'Registrazione completata!',
                                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'La telefonata è stata registrata su Asterisk. Gemini sta elaborando la trascrizione e gli appuntamenti, che troverai nella scheda "Appunti & Mappe".',
                                      style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white24),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _callCompleted = false;
                                      _isCallActive = false;
                                    });
                                  },
                                  child: const Text('Prepara un\'altra chiamata'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetChip({required String label, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ActionChip(
        backgroundColor: const Color(0xFF1C1C1E),
        side: const BorderSide(color: Colors.white12),
        label: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
        ),
        onPressed: onTap,
      ),
    );
  }
}
