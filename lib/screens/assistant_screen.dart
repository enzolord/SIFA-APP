import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../l10n/l10n.dart';
import '../services/analytics.dart';
import '../services/voice_assistant.dart';
import '../theme/colors.dart';
import '../widgets/disclaimer.dart';

/// Conversation vocale avec l'assistant SIFA, en français ou en anglais.
/// L'éleveur parle (ou écrit), l'assistant répond par écrit et à voix haute.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _stt = SpeechToText();
  final _tts = FlutterTts();
  final _turns = <ChatTurn>[];
  final _ctl = TextEditingController();
  final _scroll = ScrollController();

  String _lang = L10n.instance.lang;
  bool _sttReady = false;
  bool _listening = false;
  bool _thinking = false;
  bool _speaking = false;
  bool _muted = false;
  bool _handsFree = false;
  bool _sentThisRound = false;
  String _partial = '';
  String? _note;

  static const _suggestions = <String, List<String>>{
    'fr': [
      'Mes poulets ont la diarrhée, que faire ?',
      'Quand vacciner contre Newcastle ?',
      'Comment garder la litière sèche ?',
    ],
    'en': [
      'My chickens have diarrhoea, what should I do?',
      'When should I vaccinate against Newcastle?',
      'How do I keep the litter dry?',
    ],
  };

  @override
  void initState() {
    super.initState();
    _initVoice();
  }

  Future<void> _initVoice() async {
    try {
      _tts.setCompletionHandler(_onSpoken);
      _tts.setCancelHandler(() {
        if (mounted) setState(() => _speaking = false);
      });
      _tts.setErrorHandler((_) {
        if (mounted) setState(() => _speaking = false);
      });
      await _tts.setSpeechRate(0.48);
    } catch (_) {}
    await _initStt();
  }

  Future<bool> _initStt() async {
    try {
      _sttReady = await _stt.initialize(onStatus: _onStatus, onError: _onError);
    } catch (_) {
      _sttReady = false;
    }
    if (!_sttReady && mounted) {
      setState(() => _note = 'Reconnaissance vocale indisponible : autorisez le micro dans les réglages, ou écrivez votre question.');
    }
    return _sttReady;
  }

  void _onStatus(String status) {
    if (!mounted) return;
    if (status == 'done' || status == 'notListening') {
      final pending = _partial.trim();
      setState(() => _listening = false);
      if (!_sentThisRound && pending.isNotEmpty) _submit(pending);
    }
  }

  void _onError(SpeechRecognitionError e) {
    if (!mounted) return;
    setState(() {
      _listening = false;
      if (e.errorMsg == 'error_permission' || e.permanent && e.errorMsg.contains('permission')) {
        _note = 'Le micro est refusé. Autorisez-le dans les réglages du téléphone, ou écrivez votre question.';
      } else if (e.errorMsg == 'error_no_match' || e.errorMsg == 'error_speech_timeout') {
        _note = "Je n'ai rien entendu. Touchez le micro et parlez de nouveau.";
      }
    });
  }

  void _onResult(SpeechRecognitionResult r) {
    if (!mounted) return;
    setState(() => _partial = r.recognizedWords);
    if (r.finalResult && r.recognizedWords.trim().isNotEmpty && !_sentThisRound) {
      _submit(r.recognizedWords.trim());
    }
  }

  Future<void> _listen() async {
    if (_thinking) return;
    await _tts.stop();
    if (!_sttReady && !await _initStt()) return;
    setState(() {
      _note = null;
      _partial = '';
      _sentThisRound = false;
      _speaking = false;
      _listening = true;
    });
    try {
      await _stt.listen(
        onResult: _onResult,
        localeId: _lang == 'en' ? 'en_US' : 'fr_FR',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        listenOptions: SpeechListenOptions(partialResults: true, cancelOnError: true, listenMode: ListenMode.dictation),
      );
    } catch (_) {
      if (mounted) setState(() => _listening = false);
    }
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _stt.stop();
    } else if (_speaking) {
      await _tts.stop();
      if (mounted) setState(() => _speaking = false);
    } else {
      await _listen();
    }
  }

  Future<void> _submit(String text) async {
    final q = text.trim();
    if (q.isEmpty || _thinking) return;
    _sentThisRound = true;
    _ctl.clear();
    Analytics.instance.action('assistant:question');
    setState(() {
      _turns.add(ChatTurn(true, q));
      _partial = '';
      _note = null;
      _thinking = true;
    });
    _scrollDown();
    try {
      final answer = await VoiceAssistant.ask(_turns, _lang);
      if (!mounted) return;
      setState(() => _turns.add(ChatTurn(false, answer)));
      _scrollDown();
      if (!_muted) await _speak(answer);
    } on AssistantException catch (e) {
      if (mounted) setState(() => _note = e.message);
    } finally {
      if (mounted) setState(() => _thinking = false);
    }
  }

  Future<void> _speak(String text) async {
    try {
      final voiceOk = await _tts.isLanguageAvailable(_lang == 'en' ? 'en-US' : 'fr-FR');
      if (voiceOk == false) {
        if (mounted) setState(() => _note = 'Voix indisponible pour cette langue. Installez-la dans Réglages > Synthèse vocale.');
        return;
      }
      await _tts.setLanguage(_lang == 'en' ? 'en-US' : 'fr-FR');
      if (mounted) setState(() => _speaking = true);
      await _tts.speak(VoiceAssistant.speakable(text));
    } catch (_) {
      if (mounted) setState(() => _speaking = false);
    }
  }

  void _onSpoken() {
    if (!mounted) return;
    setState(() => _speaking = false);
    if (_handsFree) _listen();
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });

  Future<void> _setLang(String l) async {
    if (l == _lang) return;
    await _stt.cancel();
    await _tts.stop();
    setState(() {
      _lang = l;
      _listening = false;
      _speaking = false;
      _partial = '';
    });
  }

  @override
  void dispose() {
    _stt.cancel();
    _tts.stop();
    _ctl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final fr = _lang == 'fr';
    return Scaffold(
      appBar: AppBar(
        title: const Tx('Assistant vocal'),
        actions: [
          IconButton(
            tooltip: tr(_muted ? 'Activer la voix' : 'Couper la voix'),
            icon: Icon(_muted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
            onPressed: () {
              setState(() => _muted = !_muted);
              if (_muted) _tts.stop();
            },
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'fr', label: Text('Français')),
              ButtonSegment(value: 'en', label: Text('English')),
            ],
            selected: {_lang},
            onSelectionChanged: (s) => _setLang(s.first),
          ),
        ),
        Expanded(
          child: _turns.isEmpty
              ? ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 8), children: [
                  Text(
                    fr
                        ? 'Touchez le micro et posez votre question sur vos poulets.'
                        : 'Tap the microphone and ask your question about your chickens.',
                    style: t.titleMedium,
                  ),
                  const SizedBox(height: 14),
                  for (final s in _suggestions[_lang]!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ActionChip(label: Text(s), onPressed: () => _submit(s)),
                    ),
                  const SizedBox(height: 12),
                  const Disclaimer(),
                ])
              : ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  children: [
                    for (final m in _turns) _Bubble(m),
                    if (_thinking) const _Bubble(ChatTurn(false, '…')),
                  ],
                ),
        ),
        if (_note != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: SifaColors.warnSoft, borderRadius: BorderRadius.circular(12)),
            child: Tx(_note!, style: t.bodySmall?.copyWith(color: SifaColors.ink)),
          ),
        if (_listening || _partial.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Text(
              _partial.isEmpty ? (fr ? 'Je vous écoute…' : "I'm listening…") : _partial,
              style: t.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _ctl,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _submit,
                    decoration: InputDecoration(
                      hintText: fr ? 'Ou écrivez votre question' : 'Or type your question',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: tr('Envoyer'),
                  icon: const Icon(Icons.send_rounded),
                  onPressed: _thinking ? null : () => _submit(_ctl.text),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Tx('Mains libres'),
                    subtitle: const Tx("Le micro se rouvre après chaque réponse"),
                    value: _handsFree,
                    onChanged: (v) => setState(() => _handsFree = v),
                  ),
                ),
                const SizedBox(width: 12),
                _MicButton(listening: _listening, speaking: _speaking, busy: _thinking, onTap: _toggleMic),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.listening, required this.speaking, required this.busy, required this.onTap});
  final bool listening, speaking, busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = listening || speaking;
    return Semantics(
      button: true,
      label: tr(listening ? "Arrêter l'écoute" : speaking ? 'Arrêter la lecture' : 'Parler'),
      child: Material(
        color: active ? SifaColors.danger : SifaColors.brand,
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: busy ? null : onTap,
          child: SizedBox(
            width: 72,
            height: 72,
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(22),
                    child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                  )
                : Icon(listening ? Icons.stop_rounded : speaking ? Icons.volume_off_rounded : Icons.mic_rounded,
                    color: Colors.white, size: 34),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.turn);
  final ChatTurn turn;

  @override
  Widget build(BuildContext context) {
    final me = turn.fromUser;
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        decoration: BoxDecoration(
          color: me ? SifaColors.brand : SifaColors.brandSoft,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          turn.text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: me ? Colors.white : SifaColors.ink, height: 1.4),
        ),
      ),
    );
  }
}
