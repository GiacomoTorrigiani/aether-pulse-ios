import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'main.dart';

class DinnerVoiceAgentModal extends StatefulWidget {
  final String brokerUrl;
  final Function(String number, String name) onCallPhone;

  const DinnerVoiceAgentModal({
    super.key,
    required this.brokerUrl,
    required this.onCallPhone,
  });

  @override
  State<DinnerVoiceAgentModal> createState() => _DinnerVoiceAgentModalState();
}

class _DinnerVoiceAgentModalState extends State<DinnerVoiceAgentModal> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingKey;
  bool _isPlayingAudio = false;

  final List<Map<String, dynamic>> _contacts = [
    {'name': 'Mario Rossi', 'phone': '340 1234567', 'status': 'attesa', 'answer': ''},
    {'name': 'Matteo Bianchi', 'phone': '347 9876543', 'status': 'attesa', 'answer': ''},
    {'name': 'Elena Verdi', 'phone': '333 4567890', 'status': 'attesa', 'answer': ''},
  ];

  bool _isCampaignRunning = false;
  bool _restaurantBooked = false;

  final String _voiceId = 'xEzOS5e97wrbq2qesDb4';

  final List<Map<String, String>> _audioSamples = [
    {
      'key': 'test',
      'title': 'Test Vocale Clonato',
      'desc': '"Ciao, questa è una prova con la mia voce clonata per prenotare la cena."',
      'filename': 'giacomo_voice_test.mp3',
    },
    {
      'key': 'mario',
      'title': 'Invito Mario (Cena al Cicalino)',
      'desc': '"Ciao Mario! Senti, ci saresti domani alle venti in pizzeria al Cicalino?"',
      'filename': 'giacomo_invito_mario.mp3',
    },
    {
      'key': 'cicalino',
      'title': 'Prenotazione Ristorante Il Cicalino',
      'desc': '"Buonasera! Vorrei prenotare un tavolo per 3 persone per domani sera alle venti..."',
      'filename': 'giacomo_prenotazione_ristorante.mp3',
    },
  ];

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
          _currentlyPlayingKey = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playSample(String key, String filename) async {
    try {
      if (_currentlyPlayingKey == key && _isPlayingAudio) {
        await _audioPlayer.stop();
        setState(() {
          _isPlayingAudio = false;
          _currentlyPlayingKey = null;
        });
        return;
      }

      setState(() {
        _currentlyPlayingKey = key;
        _isPlayingAudio = true;
      });

      final url = '${widget.brokerUrl}/api/audio/$filename';
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore riproduzione audio: $e')),
        );
        setState(() {
          _isPlayingAudio = false;
          _currentlyPlayingKey = null;
        });
      }
    }
  }

  Future<void> _startOutboundSequence() async {
    setState(() {
      _isCampaignRunning = true;
      _restaurantBooked = false;
    });

    for (int i = 0; i < _contacts.length; i++) {
      setState(() {
        _contacts[i]['status'] = 'chiamata';
      });
      HapticFeedback.lightImpact();

      await Future.delayed(const Duration(milliseconds: 1800));

      setState(() {
        if (_contacts[i]['name'].toString().contains('Elena')) {
          _contacts[i]['status'] = 'no';
          _contacts[i]['answer'] = 'No, domani non riesco!';
        } else {
          _contacts[i]['status'] = 'si';
          _contacts[i]['answer'] = 'Sì! Ci sono alle 20:00!';
        }
      });
      HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 600));
    }

    setState(() {
      _isCampaignRunning = false;
    });

    if (mounted) {
      _showDecisionPopup();
    }
  }

  void _showDecisionPopup() {
    final accepted = _contacts.where((c) => c['status'] == 'si').map((c) => c['name'] as String).toList();
    final declined = _contacts.where((c) => c['status'] == 'no').map((c) => c['name'] as String).toList();
    final totalPersone = accepted.length + 1; // +1 Giacomo

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF30D158), width: 1.2),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF30D158).withAlpha(40),
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.phone_arrow_up_right, color: Color(0xFF30D158), size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Risposte Inviti Raccolte!',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final name in accepted)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.checkmark_circle_fill, color: Color(0xFF30D158), size: 14),
                          const SizedBox(width: 6),
                          Text('$name: SÌ ci sarà', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                  for (final name in declined)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.xmark_circle_fill, color: Color(0xFFFF453A), size: 14),
                          const SizedBox(width: 6),
                          Text('$name: NO non può', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Totale confermati: $totalPersone persone (Giacomo, ${accepted.join(', ')}).\n\nVuoi che effettui la chiamata a "Cicalino Terni" alle 20:00 e prenoto?',
              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Modifica Dettagli', style: TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF30D158),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _bookRestaurant();
            },
            icon: const Icon(CupertinoIcons.phone_fill, color: Colors.black, size: 16),
            label: const Text(
              'SÌ, PROCEDI CON LA MIA VOCE',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _bookRestaurant() async {
    // Play cloned reservation audio
    await _playSample('cicalino', 'giacomo_prenotazione_ristorante.mp3');

    await Future.delayed(const Duration(seconds: 4));

    if (mounted) {
      setState(() {
        _restaurantBooked = true;
      });
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFBF5AF2), Color(0xFF5E5CE6)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Agente Outbound Vocale',
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Voce Clonata: Giacomo ($_voiceId)',
                          style: const TextStyle(color: Color(0xFF30D158), fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.white38),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              children: [
                // Voice status banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBF5AF2).withAlpha(80)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(CupertinoIcons.waveform_circle_fill, color: Color(0xFFBF5AF2), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Campioni Audio della tua Voce Clonata',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      for (final sample in _audioSamples)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(80),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => _playSample(sample['key']!, sample['filename']!),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (_currentlyPlayingKey == sample['key'] && _isPlayingAudio)
                                        ? const Color(0xFFFF9F0A)
                                        : const Color(0xFF0A84FF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    (_currentlyPlayingKey == sample['key'] && _isPlayingAudio)
                                        ? CupertinoIcons.pause_fill
                                        : CupertinoIcons.play_fill,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sample['title']!,
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      sample['desc']!,
                                      style: const TextStyle(color: Colors.white60, fontSize: 10),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Outbound dinner campaign section
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
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(CupertinoIcons.person_3_fill, color: Color(0xFF30D158), size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Amici da Invitare a Cena',
                                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Text(
                            'Cicalino • 20:00',
                            style: TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      for (final c in _contacts)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(60),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: c['status'] == 'si'
                                  ? const Color(0xFF30D158).withAlpha(120)
                                  : c['status'] == 'no'
                                      ? const Color(0xFFFF453A).withAlpha(120)
                                      : c['status'] == 'chiamata'
                                          ? const Color(0xFFFF9F0A).withAlpha(150)
                                          : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c['name'] as String,
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    c['phone'] as String,
                                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                                  ),
                                  if (c['answer'] != '')
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        '💬 "${c['answer']}"',
                                        style: TextStyle(
                                          color: c['status'] == 'si' ? const Color(0xFF30D158) : const Color(0xFFFF453A),
                                          fontSize: 10,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (c['status'] == 'chiamata')
                                const Row(
                                  children: [
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF9F0A)),
                                    ),
                                    SizedBox(width: 6),
                                    Text('In chiamata...', style: TextStyle(color: Color(0xFFFF9F0A), fontSize: 11)),
                                  ],
                                )
                              else if (c['status'] == 'si')
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF30D158).withAlpha(40),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(CupertinoIcons.checkmark_alt, color: Color(0xFF30D158), size: 12),
                                      SizedBox(width: 4),
                                      Text('SÌ (Confermato)', style: TextStyle(color: Color(0xFF30D158), fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                )
                              else if (c['status'] == 'no')
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF453A).withAlpha(40),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(CupertinoIcons.xmark, color: Color(0xFFFF453A), size: 12),
                                      SizedBox(width: 4),
                                      Text('NO (Non può)', style: TextStyle(color: Color(0xFFFF453A), fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                )
                              else
                                const Text('In attesa', style: TextStyle(color: Colors.white38, fontSize: 11)),
                            ],
                          ),
                        ),

                      const SizedBox(height: 14),

                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0A84FF),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _isCampaignRunning ? null : _startOutboundSequence,
                          icon: _isCampaignRunning
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(CupertinoIcons.phone_arrow_up_right, color: Colors.white, size: 18),
                          label: Text(
                            _isCampaignRunning
                                ? 'Chiamate in corso con la tua voce...'
                                : '🚀 Avvia Chiamate RSVP con la mia Voce',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_restaurantBooked) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF30D158).withAlpha(25),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF30D158), width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(CupertinoIcons.checkmark_seal_fill, color: Color(0xFF30D158), size: 22),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '🎉 Prenotazione Ristorante Effettuata!',
                                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tavolo per 3 persone confermato per domani alle 20:00 al Ristorante Il Cicalino (Terni) a nome Giacomo Torrigiani.',
                          style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF30D158),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              final tomorrow = DateTime.now().add(const Duration(days: 1));
                              final startStr = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 20, 0).toIso8601String();
                              final endStr = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 22, 30).toIso8601String();

                              ProcessedCallReport.openGoogleCalendar(
                                context: context,
                                title: 'Cena Ristorante Il Cicalino (3 Persone)',
                                startDateStr: startStr,
                                endDateStr: endStr,
                                location: 'Ristorante Il Cicalino, Via Cicalino, Terni',
                                description: 'Prenotazione confermata autonomamente con voce clonata per Giacomo, Mario e Matteo.',
                              );
                            },
                            icon: const Icon(CupertinoIcons.calendar, color: Colors.black, size: 16),
                            label: const Text(
                              '📅 Aggiungi a Google Calendar (1-Tap)',
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
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
      ),
    );
  }
}
