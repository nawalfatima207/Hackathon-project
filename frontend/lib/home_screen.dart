import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'app_colors.dart';
import 'library_screen.dart';
import 'conversation_store.dart';
import 'voice_screen.dart';
import 'widgets/glass.dart';
import 'widgets/custom_icons.dart';
import 'widgets/bot_avatar.dart';
import 'widgets/zylo_logo.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage(this.text, this.isUser);
}

/// One selectable option in either model picker (transcription or Q&A).
class PickerOption {
  final String label;
  final String requestValue;
  final AppGlyph glyph;
  const PickerOption(this.label, this.requestValue, this.glyph);
}

class HomeScreen extends StatefulWidget {
  final String userName;
  final VoidCallback? onViewLibrary;

  const HomeScreen({super.key, this.userName = 'there', this.onViewLibrary});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _summaryRequestCount = 0;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  String? _errorText;

  static const String _baseUrl = 'http://localhost:8000';

  String? _currentVideoTitle;
  String? _currentSummary;
  String? _currentDuration;
  String? _currentConversationId;

  bool get hasUnsavedConversation => false;

  bool _isLoading = false;
  String? _statusText;

  // Transcription is handled separately from question-answering: Groq's
  // hosted Whisper, or a local faster-whisper run. This only affects the
  // very first /process call for a new lecture link.
  static const List<PickerOption> _transcriptionOptions = [
    PickerOption('Groq Whisper', 'groq', AppGlyph.waveform),
    PickerOption('Faster-Whisper (local)', 'faster_whisper', AppGlyph.mic),
  ];
  PickerOption _selectedTranscription = _transcriptionOptions.first;

  // Question-answering / summarization model -- unrelated to transcription.
  static const List<PickerOption> _qaOptions = [
    PickerOption('Gemini', 'gemini', AppGlyph.sparkle),
    PickerOption('Qwen 2.5', 'ollama', AppGlyph.brain),
  ];
  PickerOption _selectedQaModel = _qaOptions.first;

  final TextEditingController _preferenceController = TextEditingController();
  String _responsePreference = '';

  bool get _hasStarted => _messages.isNotEmpty;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _preferenceController.dispose();
    super.dispose();
  }

  void resetChat() {
    setState(() {
      _messages.clear();
      _errorText = null;
      _controller.clear();
      _currentVideoTitle = null;
      _currentSummary = null;
      _currentDuration = null;
      _statusText = null;
      _summaryRequestCount = 0;
      _currentConversationId = null;
    });
  }

  void loadLecture(LectureItem item) {
    setState(() {
      _messages
        ..clear()
        ..addAll(
          item.messages.map(
            (m) => ChatMessage(
              m['text'] as String,
              m['isUser'] as bool,
            ),
          ),
        );

      _errorText = null;
      _controller.clear();

      _currentVideoTitle = item.title;
      _currentSummary = item.summary;
      _currentDuration = item.duration;
      _summaryRequestCount = item.summaryRequestCount;
      _currentConversationId = item.documentId;
    });
  }

  Future<void> saveCurrentConversation() async {
    if (_currentVideoTitle == null) return;

    try {
      final documentId = await ConversationStore.instance.save(
        LectureItem(
          documentId: _currentConversationId,
          title: _currentVideoTitle!,
          summary: _currentSummary,
          summaryRequestCount: _summaryRequestCount,
          messages: _messages.map((m) => {'text': m.text, 'isUser': m.isUser}).toList(),
          duration: _currentDuration ?? '0:00',
          savedAt: DateTime.now(),
          tagColor: AppColors.accent,
        ),
        documentId: _currentConversationId,
      );

      if (documentId != null) {
        _currentConversationId = documentId;
      }
    } catch (e) {
      // Swallow -- conversation auto-save is best-effort.
    }
  }

  void showPreferencesSheet() {
    _preferenceController.text = _responsePreference;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _DarkSheet(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Response Preferences',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                const SizedBox(height: 4),
                const Text(
                  'Tell it how you\'d like explanations -- e.g. "explain things simply" or "be detailed and technical."',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _preferenceController,
                  maxLines: 3,
                  style: const TextStyle(color: AppColors.textDark),
                  decoration: InputDecoration(
                    hintText: 'Any preference for how I explain things?',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.glassFill,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: GlassGradientButton(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    onTap: () {
                      setState(() => _responsePreference = _preferenceController.text.trim());
                      Navigator.pop(context);
                    },
                    child: const Center(
                      child: Text('Save Preference',
                          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Generic bottom sheet used by both the transcription and Q&A pickers.
  void _showPickerSheet({
    required String title,
    required String subtitle,
    required List<PickerOption> options,
    required PickerOption selected,
    required ValueChanged<PickerOption> onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _DarkSheet(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const SizedBox(height: 14),
                  ...options.map((option) {
                    final isSelected = option.requestValue == selected.requestValue;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassCard(
                        borderRadius: BorderRadius.circular(16),
                        fill: isSelected ? AppColors.glassFillStrong : AppColors.glassFill,
                        onTap: () {
                          onSelect(option);
                          Navigator.pop(context);
                        },
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: AppColors.accentGradient),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: AppIcon(option.glyph, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(option.label,
                                  style: const TextStyle(
                                      color: AppColors.textDark, fontWeight: FontWeight.w600, fontSize: 14)),
                            ),
                            if (isSelected) const AppIcon(AppGlyph.sparkle, color: AppColors.accentSoft, size: 16),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTranscriptionPicker() {
    _showPickerSheet(
      title: 'Transcription Engine',
      subtitle: 'Used once, when a new lecture link is first processed.',
      options: _transcriptionOptions,
      selected: _selectedTranscription,
      onSelect: (option) => setState(() => _selectedTranscription = option),
    );
  }

  void _showQaModelPicker() {
    _showPickerSheet(
      title: 'Answers & Summaries',
      subtitle: 'Used for every question you ask and every summary you request.',
      options: _qaOptions,
      selected: _selectedQaModel,
      onSelect: (option) => setState(() => _selectedQaModel = option),
    );
  }

  bool _isValidLink(String text) {
    final uri = Uri.tryParse(text);
    return uri != null &&
        (uri.isScheme('HTTP') || uri.isScheme('HTTPS')) &&
        (text.contains('youtube.com') || text.contains('youtu.be'));
  }

  Future<void> _pollProgress() async {
    while (_isLoading) {
      try {
        final response = await http.get(Uri.parse('$_baseUrl/progress'));
        final data = jsonDecode(response.body);
        if (!mounted) return;
        final log = List<String>.from(data['log'] ?? []);
        setState(() {
          _statusText = log.isNotEmpty ? log.last : null;
        });
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 600));
    }
    if (mounted) setState(() => _statusText = null);
  }

  Future<void> _handleSubmit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (_currentVideoTitle == null && !_isValidLink(text)) {
      setState(() => _errorText = 'Please paste a valid YouTube link to get started.');
      return;
    }

    setState(() {
      _errorText = null;
      _messages.add(ChatMessage(text, true));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();
    _pollProgress();

    try {
      if (_currentVideoTitle == null) {
        final response = await http.post(
          Uri.parse('$_baseUrl/process'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'url': text,
            'transcription_model': _selectedTranscription.requestValue,
          }),
        );
        final data = jsonDecode(response.body);

        if (data['error'] != null) {
          setState(() => _messages.add(ChatMessage(data['error'], false)));
        } else {
          _currentVideoTitle = data['video_title'];
          _currentDuration = data['duration'];
          setState(() {
            _messages.add(ChatMessage("Your video is ready -- go ahead and ask questions, or ask for a summary.", false));
          });
        }
      } else {
        final isSummaryRequest = text.toLowerCase().contains('summary') || text.toLowerCase().contains('summarize');

        if (isSummaryRequest) {
          final response = await http.post(
            Uri.parse('$_baseUrl/summarize'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'video_title': _currentVideoTitle, 'model_choice': _selectedQaModel.requestValue}),
          );
          final data = jsonDecode(response.body);
          _currentSummary = data['summary'];
          _summaryRequestCount++;
          setState(() => _messages.add(ChatMessage(data['summary'] ?? data['error'] ?? 'Something went wrong.', false)));
        } else {
          final response = await http.post(
            Uri.parse('$_baseUrl/ask'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'video_title': _currentVideoTitle,
              'question': text,
              'model_choice': _selectedQaModel.requestValue,
              'user_preferences': _responsePreference,
            }),
          );
          final data = jsonDecode(response.body);
          setState(() => _messages.add(ChatMessage(data['answer'] ?? data['error'] ?? 'Something went wrong.', false)));
        }
      }
    } catch (e) {
      setState(() => _messages.add(ChatMessage('Error: could not reach the server. Is it running?', false)));
    } finally {
      setState(() => _isLoading = false);
      await saveCurrentConversation();
    }

    _scrollToBottom();
  }

  Future<void> _openVoiceScreen() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const VoiceScreen()),
    );
    if (result != null && result.trim().isNotEmpty) {
      setState(() => _controller.text = result.trim());
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final double inputRestingTop = screenHeight * 0.60;

    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.6),
          radius: 1.3,
          colors: AppColors.backgroundGradient,
        ),
      ),
      child: Stack(
        children: [
          // ---- Header: Zylo brand + greeting + notification bell ----
          // Left inset of 60 clears the menu button RootShell overlays on
          // top-left of every tab (44px button + 8px inset + 8px gap).
          Positioned(
            top: 8,
            left: 60,
            right: 16,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ZYLO',
                          style: TextStyle(
                              color: AppColors.accentSoft, fontSize: 11, letterSpacing: 2.4, fontWeight: FontWeight.w700)),
                      Text('Hey ${widget.userName}!',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    ],
                  ),
                ),
                GlassIconButton(
                  size: 38,
                  icon: const AppIcon(AppGlyph.bell, color: AppColors.textDark, size: 16),
                  onTap: showPreferencesSheet,
                ),
              ],
            ),
          ),

          // ---- Chat transcript ----
          Positioned.fill(
            top: 90,
            bottom: 100,
            child: AnimatedOpacity(
              opacity: _hasStarted ? 1 : 0,
              duration: const Duration(milliseconds: 400),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return Align(
                    alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                      child: msg.isUser
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: AppColors.accentGradient),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(msg.text, style: const TextStyle(color: Colors.white)),
                            )
                          : GlassSurface(
                              borderRadius: BorderRadius.circular(18),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Text(msg.text, style: const TextStyle(color: AppColors.textDark)),
                            ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ---- Idle hero: bot mascot + heading ----
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            top: _hasStarted ? -220 : inputRestingTop - 230,
            left: 24,
            right: 24,
            child: AnimatedOpacity(
              opacity: _hasStarted ? 0 : 1,
              duration: const Duration(milliseconds: 300),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const BotAvatar(size: 140),
                  const SizedBox(height: 8),
                  const Text('Ready to study?',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  const SizedBox(height: 6),
                  const Text('Paste a lecture link below to get a summary, or ask a question.',
                      textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                ],
              ),
            ),
          ),

          // ---- Composer: status, search bar (with logo slot), model chips ----
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            left: 20,
            right: 20,
            top: _hasStarted ? null : inputRestingTop,
            bottom: _hasStarted ? 16 : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 6),
                    child: Text(_errorText!, style: const TextStyle(color: AppColors.magenta, fontSize: 12)),
                  ),
                if (_isLoading)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentSoft),
                        ),
                        if (_statusText != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _statusText!,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                GlassSurface(
                  borderRadius: BorderRadius.circular(28),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      // Reserved space for the Zylo logo asset -- see widgets/zylo_logo.dart.
                      const ZyloMark(size: 32),
                      const SizedBox(width: 8),
                      Container(width: 1, height: 20, color: AppColors.glassBorder),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          enabled: !_isLoading,
                          style: const TextStyle(color: AppColors.textDark),
                          decoration: const InputDecoration(
                            hintText: 'Paste a link and get started',
                            hintStyle: TextStyle(color: AppColors.textMuted),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onSubmitted: (_) => _handleSubmit(),
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _isLoading ? null : _openVoiceScreen,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: AppIcon(AppGlyph.mic, color: AppColors.textMuted, size: 18),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(left: 2),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: AppColors.accentGradient),
                        ),
                        child: IconButton(
                          onPressed: _isLoading ? null : _handleSubmit,
                          icon: const AppIcon(AppGlyph.send, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),

                // Claude-style model-picker chips, directly under the search bar.
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _ModelChip(
                        prefix: 'Transcribe',
                        option: _selectedTranscription,
                        onTap: _showTranscriptionPicker,
                      ),
                      const SizedBox(width: 8),
                      _ModelChip(
                        prefix: 'Answers',
                        option: _selectedQaModel,
                        onTap: _showQaModelPicker,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelChip extends StatelessWidget {
  final String prefix;
  final PickerOption option;
  final VoidCallback onTap;

  const _ModelChip({required this.prefix, required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: BorderRadius.circular(20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(option.glyph, color: AppColors.accentSoft, size: 13),
                const SizedBox(width: 6),
                Text('$prefix: ',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
                Text(option.label,
                    style: const TextStyle(color: AppColors.textDark, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(width: 4),
                const AppIcon(AppGlyph.chevronDown, size: 11, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared dark, blurred bottom-sheet backdrop.
class _DarkSheet extends StatelessWidget {
  final Widget child;
  const _DarkSheet({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: GlassSurface(
        borderRadius: BorderRadius.zero,
        fill: AppColors.cardAlt.withOpacity(0.96),
        border: Colors.transparent,
        child: child,
      ),
    );
  }
}
