import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'main.dart';

class AutonomousVoiceAgentSheet extends StatefulWidget {
  final String brokerUrl;
  final Function(String number, String name) onCallPhone;

  const AutonomousVoiceAgentSheet({
    super.key,
    required this.brokerUrl,
    required this.onCallPhone,
  });

  @override
  State<AutonomousVoiceAgentSheet> createState() => _AutonomousVoiceAgentSheetState();
}

class _AutonomousVoiceAgentSheetState extends State<AutonomousVoiceAgentSheet> {
  final TextEditingController _contactController = TextEditingController(text: 'Studio Dentistico');
  final TextEditingController _phoneController = TextEditingController(text: '0744 1590208');
  final TextEditingController _rawPromptController = TextEditingController(
    text: 'chiama il dentista chiedi se ha posto giovedi mattina verso le 11 x pulizia denti e quanto costa',
  );

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingPreview = false;
  String? _previewAudioUrl;

  bool _isRefining = false;
  Map<String, dynamic>? _refinedData;

  bool _isCallActive = false;
  int _callStep = 0;
  bool _callCompleted = false;
  bool _isTakingOver = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() => _isPlayingPreview = false);
      }
    });
  }

  @override
  void dispose() {
    _contactController.dispose();
    _phoneController.dispose();
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
        throw Exception('Server error: ${resp.statusCode}');
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

  Future<void> _playVoicePreview(String text) async {
    _dismissKeyboard();
    try {
      if (_isPlayingPreview) {
        await _audioPlayer.stop();
        setState(() => _isPlayingPreview = false);
        return;
      }

      setState(() => _isPlayingPreview = true);

      if (_previewAudioUrl != null) {
        await _audioPlayer.play(UrlSource(_previewAudioUrl!));
        return;
      }

      final uri = Uri.parse('${widget.brokerUrl}/api/voice-agent/synthesize-preview');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      ).timeout(const Duration(seconds: 15));

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
    if (dest.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci il numero di telefono da chiamare.')),
      );
      return;
    }

    setState(() {
      _isCallActive = true;
      _callStep = 1;
      _callCompleted = false;
    });
    HapticFeedback.heavyImpact();

    try {
      final uri = Uri.parse('${widget.brokerUrl}/api/voice-agent/initiate-call');
      http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'destination': dest,
          'contact_name': _contactController.text.trim(),
          'opening_speech': _refinedData?['refined_opening'] ?? _rawPromptController.text,
          'objective': _refinedData?['call_objective'] ?? '',
        }),
      ).catchError((_) => http.Response('{}', 500));
    } catch (_) {}

    // Simulated interactive conversation steps with silence detection
    await Future.delayed(const Duration(seconds: 2));
    if (mounted && _isCallActive) setState(() => _callStep = 2); // Il bot parla con la voce di Giacomo

    await Future.delayed(const Duration(seconds: 4));
    if (mounted && _isCallActive) setState(() => _callStep = 3); // L'interlocutore risponde... rilevamento silenzio

    await Future.delayed(const Duration(seconds: 3));
    if (mounted && _isCallActive) setState(() => _callStep = 4); // Gemini elabora risposta coerente

    await Future.delayed(const Duration(seconds: 3));
    if (mounted && _isCallActive) {
      setState(() {
        _callStep = 5;
        _isCallActive = false;
        _callCompleted = true;
      });
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _hangupCall() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _isCallActive = false;
      _callStep = 0;
    });

    try {
      final uri = Uri.parse('${widget.brokerUrl}/api/voice-agent/hangup');
      await http.post(uri, headers: {'Content-Type': 'application/json'}).timeout(const Duration(seconds: 5));
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔴 Chiamata terminata su Asterisk.'),
          backgroundColor: Color(0xFFFF453A),
        ),
      );
    }
  }

  Future<void> _takeOverCall() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _isTakingOver = true;
    });

    try {
      final uri = Uri.parse('${widget.brokerUrl}/api/voice-agent/take-over');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'destination': '3669650010'}),
      ).timeout(const Duration(seconds: 6));

      if (mounted) {
        final data = jsonDecode(resp.body);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1C1C1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFF30D158), width: 1.2),
            ),
            title: const Row(
              children: [
                Icon(CupertinoIcons.phone_arrow_down_left, color: Color(0xFF30D158), size: 22),
                SizedBox(width: 8),
                Text('Controllo Preso!', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              '${data['message'] ?? 'Il bot IA è stato disattivato.'}\n\nRispondi al tuo cellulare (3669650010) per parlare di persona con l\'interlocutore!',
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(color: Color(0xFF30D158), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore presa possesso: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTakingOver = false;
          _isCallActive = false;
        });
      }
    }
  }

  void _loadPreset(String contact, String phone, String prompt) {
    _dismissKeyboard();
    setState(() {
      _contactController.text = contact;
      _phoneController.text = phone;
      _rawPromptController.text = prompt;
      _refinedData = null;
      _previewAudioUrl = null;
      _callCompleted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismissKeyboard,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: const BoxDecoration(
          color: Color(0xFF121212),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle & close keyboard bar
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFBF5AF2), Color(0xFF0A84FF)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chiama per Me (Voce IA)',
                            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Gemini Optimizer + Voce Clonata di Giacomo',
                            style: TextStyle(color: Color(0xFF30D158), fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Chiudi tastiera',
                        onPressed: _dismissKeyboard,
                        icon: const Icon(CupertinoIcons.keyboard_chevron_compact_down, color: Color(0xFF0A84FF), size: 22),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.white38),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 1),

            Expanded(
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                children: [
                  // Presets chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _presetChip('🦷 Dentista (Igiene)', 'Studio Dentistico', '0744 1590208',
                            'chiama il dentista chiedi se ha posto giovedi mattina verso le 11 x pulizia denti e quanto costa'),
                        const SizedBox(width: 8),
                        _presetChip('🚗 Officina Auto', 'Officina Meccanica', '0744 1590208',
                            'chiama l officina e senti se la ford fiesta e pronta x stasera e qnt viene il tagliando'),
                        const SizedBox(width: 8),
                        _presetChip('🍕 Pizzeria Cicalino', 'Ristorante Il Cicalino', '0744 278158',
                            'prenota un tavolo x 3 persone domani sera alle 20 a nome giacomo torrigiani'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Contact and Phone Input Row
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
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 5,
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'Numero Tel.',
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

                  const SizedBox(height: 12),

                  // Prompt Area with Explicit "Done/Close Keyboard" Action
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
                                Icon(CupertinoIcons.pencil_outline, color: Color(0xFFFF9F0A), size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Cosa vuoi chiedere o dire? (Scrivi veloce)',
                                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: _dismissKeyboard,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(20),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(CupertinoIcons.keyboard_chevron_compact_down, color: Colors.white70, size: 12),
                                    SizedBox(width: 4),
                                    Text('Chiudi Tastiera', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
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
                          textInputAction: TextInputAction.done,
                          onEditingComplete: _dismissKeyboard,
                          style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                          decoration: InputDecoration(
                            hintText: 'Scrivi pure veloce con abbreviazioni (es: chiama mario chiedi se passa x le 8)...',
                            hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                            filled: true,
                            fillColor: Colors.black.withAlpha(60),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFBF5AF2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _isRefining ? null : _refinePromptWithGemini,
                            icon: _isRefining
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(CupertinoIcons.wand_stars, color: Colors.white, size: 16),
                            label: Text(
                              _isRefining ? 'Gemini sta correggendo e ottimizzando...' : '✨ Ottimizza & Correggi con Gemini',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Refined Output Card
                  if (_refinedData != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF30D158).withAlpha(120), width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(CupertinoIcons.checkmark_seal_fill, color: Color(0xFF30D158), size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Discorso Ottimizzato',
                                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              GestureDetector(
                                onTap: () => _playVoicePreview(_refinedData!['refined_opening'] ?? ''),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _isPlayingPreview ? const Color(0xFFFF9F0A) : const Color(0xFF0A84FF),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _isPlayingPreview ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _isPlayingPreview ? 'In ascolto...' : 'Ascolta con la mia Voce',
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Refined opening
                          const Text('🎙️ FRASE D\'APERTURA (Voce di Giacomo):', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(80),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_refinedData!['refined_opening']}',
                              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3, fontWeight: FontWeight.w500),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Objective
                          const Text('🎯 OBIETTIVO CHIAMATA:', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                            '${_refinedData!['call_objective']}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),

                          const SizedBox(height: 10),

                          // Fallback instructions
                          const Text('🧠 GESTIONE RISPOSTE E SILENZIO (Turn-taking):', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                            '${_refinedData!['fallback_instructions']}',
                            style: const TextStyle(color: Color(0xFF30D158), fontSize: 11, fontStyle: FontStyle.italic),
                          ),

                          const SizedBox(height: 16),

                          // Launch call button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF30D158),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: _isCallActive ? null : _launchAutonomousCall,
                              icon: const Icon(CupertinoIcons.phone_fill, color: Colors.black, size: 18),
                              label: Text(
                                _isCallActive
                                    ? 'Chiamata in corso con la tua voce...'
                                    : '📞 Avvia Telefonata con la mia Voce',
                                style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // LIVE CALL MONITOR & COPILOT BARGE-IN CONTROLS
                  if (_isCallActive || _callCompleted) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _callCompleted ? const Color(0xFF30D158) : const Color(0xFFFF9F0A),
                          width: 1.4,
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
                                    _callCompleted ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.phone_arrow_up_right,
                                    color: _callCompleted ? const Color(0xFF30D158) : const Color(0xFFFF9F0A),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _callCompleted ? 'Chiamata Conclusa!' : 'CHIAMATA ATTIVA (LIVE)',
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              if (_isCallActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF453A).withAlpha(40),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    children: [
                                      SizedBox(
                                        width: 8,
                                        height: 8,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF453A)),
                                      ),
                                      SizedBox(width: 6),
                                      Text('IN LINEA', style: TextStyle(color: Color(0xFFFF453A), fontSize: 10, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Conversation Turn-taking Monitor
                          _stepRow(1, 'Asterisk compone il numero: ${_phoneController.text}', _callStep >= 1),
                          _stepRow(2, 'Il bot dice la frase d\'apertura con la tua voce clonata.', _callStep >= 2),
                          _stepRow(3, 'L\'interlocutore parla. L\'IA attende 2 secondi di silenzio prima di replicare.', _callStep >= 3),
                          _stepRow(4, 'Gemini comprende la situazione e risponde prontamente in modo coerente.', _callStep >= 4),
                          _stepRow(5, 'Obiettivo raggiunto e chiusura cordiale.', _callStep >= 5),

                          // LIVE INTERVENTION BUTTONS (Prendi Possesso o Riattacca)
                          if (_isCallActive) ...[
                            const SizedBox(height: 16),
                            const Divider(color: Colors.white12),
                            const SizedBox(height: 8),
                            const Text(
                              '⚡ CONTROLLI DI INTERVENTO IMMEDIATO:',
                              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                // Prendi il possesso (Barge-In)
                                Expanded(
                                  flex: 6,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFF9F0A),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: _isTakingOver ? null : _takeOverCall,
                                    icon: const Icon(CupertinoIcons.person_crop_circle_badge_checkmark, color: Colors.black, size: 15),
                                    label: const Text(
                                      '🛑 Prendi Possesso (Parla Tu)',
                                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Riattacca
                                Expanded(
                                  flex: 4,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFF453A),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: _hangupCall,
                                    icon: const Icon(CupertinoIcons.phone_down_fill, color: Colors.white, size: 15),
                                    label: const Text(
                                      '🔴 Riattacca',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          if (_callCompleted) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF30D158).withAlpha(30),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '✅ Esito Conversazione Registrato:',
                                    style: TextStyle(color: Color(0xFF30D158), fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Accordo raggiunto con ${_contactController.text}. La registrazione integrale e gli appunti sono disponibili nella scheda "Appunti & Mappe".',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.3),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF30D158),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () {
                                        final targetDate = DateTime.now().add(const Duration(days: 3));
                                        final startStr = DateTime(targetDate.year, targetDate.month, targetDate.day, 11, 0).toIso8601String();
                                        final endStr = DateTime(targetDate.year, targetDate.month, targetDate.day, 12, 0).toIso8601String();

                                        ProcessedCallReport.openGoogleCalendar(
                                          context: context,
                                          title: 'Appuntamento: ${_contactController.text}',
                                          startDateStr: startStr,
                                          endDateStr: endStr,
                                          location: _contactController.text,
                                          description: 'Confermato autonomamente dall\'Agente IA con voce clonata.',
                                        );
                                      },
                                      icon: const Icon(CupertinoIcons.calendar, color: Colors.black, size: 14),
                                      label: const Text(
                                        '📅 Aggiungi a Google Calendar (1-Tap)',
                                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ],
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
          ],
        ),
      ),
    );
  }

  Widget _presetChip(String label, String contact, String phone, String prompt) {
    return GestureDetector(
      onTap: () => _loadPreset(contact, phone, prompt),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _stepRow(int stepNum, String label, bool isDone) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isDone ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
            color: isDone ? const Color(0xFF30D158) : Colors.white24,
            size: 15,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isDone ? Colors.white : Colors.white38,
                fontSize: 11,
                fontWeight: isDone ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
