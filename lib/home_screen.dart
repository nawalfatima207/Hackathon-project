import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'app_colors.dart';
import 'library_screen.dart';
import 'conversation_store.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage(this.text, this.isUser);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _summaryRequestCount = 0;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  String? _errorText;

  static const String _baseUrl = 'http://10.0.2.2:8000';

  String? _currentVideoTitle;
  String? _currentSummary;
  String? _currentDuration;
  bool _saveDialogShown = false;

  bool _isLoading = false;
  String? _statusText;

  final List<String> _modelOptions = ['Qwen 2.5', 'Gemini'];
  String _selectedModel = 'Qwen 2.5';

  final TextEditingController _preferenceController = TextEditingController();
  String _responsePreference = '';

  bool get _hasStarted => _messages.isNotEmpty;
  bool get hasUnsavedConversation => _currentVideoTitle != null && !_saveDialogShown;

  void resetChat() {
    setState(() {
      _messages.clear();
      _errorText = null;
      _controller.clear();
      _currentVideoTitle = null;
      _currentSummary = null;
      _currentDuration = null;
      _statusText = null;
      _saveDialogShown = false;
      _summaryRequestCount = 0;
    });
  }

  void markSaveDialogSeen() {
    _saveDialogShown = true;
  }

  void loadLecture(LectureItem item) {
    setState(() {
      _messages
        ..clear()
        ..addAll(item.messages.map((m) => ChatMessage(m['text'] as String, m['isUser'] as bool)));
      _errorText = null;
      _controller.clear();
      _currentVideoTitle = item.title;
      _currentSummary = item.summary;
      _currentDuration = item.duration;
      _summaryRequestCount = item.summaryRequestCount;
      _saveDialogShown = true;
    });
  }

  Future<void> saveCurrentConversation() async {
    print('saveCurrentConversation called, videoTitle: $_currentVideoTitle');
    if (_currentVideoTitle == null) {
      print('No video title, aborting save.');
      return;
    }
    try {
      await ConversationStore.instance.save(LectureItem(
        title: _currentVideoTitle!,
        summary: _currentSummary,
        summaryRequestCount: _summaryRequestCount,
        messages: _messages.map((m) => {'text': m.text, 'isUser': m.isUser}).toList(),
        duration: _currentDuration ?? '0:00',
        savedAt: DateTime.now(),
        tagColor: AppColors.accent,
      ));
      print('Save succeeded.');
    } catch (e, stack) {
  if (e is FirebaseException) {
  print('Save FAILED - code: ${e.code}, message: ${e.message}');
  } else {
  print('Save FAILED - unknown error type: ${e.runtimeType}');
  }
  }
    _saveDialogShown = true;
  }

  void showPreferencesSheet() {
    _preferenceController.text = _responsePreference;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Response Preferences',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tell it how you\'d like explanations — e.g. "explain things simply" or "be detailed and technical."',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _preferenceController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Any preference for how I explain things?',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    setState(() => _responsePreference = _preferenceController.text.trim());
                    Navigator.pop(context);
                  },
                  child: const Text('Save Preference', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showModelPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('AI Version', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                const SizedBox(height: 12),
                ..._modelOptions.map((model) => RadioListTile<String>(
                  value: model,
                  groupValue: _selectedModel,
                  activeColor: AppColors.accent,
                  title: Text(model, style: const TextStyle(color: AppColors.textDark)),
                  onChanged: (value) {
                    setState(() => _selectedModel = value!);
                    Navigator.pop(context);
                  },
                )),
              ],
            ),
          ),
        );
      },
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

    final modelChoice = _selectedModel == 'Gemini' ? 'gemini' : 'ollama';

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
          body: jsonEncode({'url': text, 'model_choice': modelChoice}),
        );
        final data = jsonDecode(response.body);

        if (data['error'] != null) {
          setState(() => _messages.add(ChatMessage(data['error'], false)));
        } else {
          _currentVideoTitle = data['video_title'];
          _currentDuration = data['duration'];
          setState(() {
            _messages.add(ChatMessage("Your video is ready — go ahead and ask questions, or ask for a summary.", false));
          });
        }
      } else {
        final isSummaryRequest = text.toLowerCase().contains('summary') || text.toLowerCase().contains('summarize');

        if (isSummaryRequest) {
          final response = await http.post(
            Uri.parse('$_baseUrl/summarize'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'video_title': _currentVideoTitle, 'model_choice': modelChoice}),
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
              'model_choice': modelChoice,
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
    }

    _scrollToBottom();
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
    final double inputRestingTop = screenHeight * 0.5;

    return Stack(
      children: [
        Positioned(
          top: 8, left: 60, right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('AI STUDY ASSISTANT', style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
              Text('Home', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            ],
          ),
        ),

        Positioned.fill(
          top: 90, bottom: 100,
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: msg.isUser ? AppColors.accent : AppColors.card,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(msg.text, style: TextStyle(color: msg.isUser ? Colors.white : AppColors.textDark)),
                  ),
                );
              },
            ),
          ),
        ),

        AnimatedPositioned(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          top: _hasStarted ? -150 : inputRestingTop - 100,
          left: 24, right: 24,
          child: AnimatedOpacity(
            opacity: _hasStarted ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: const [
                Text('Ready to study?', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                SizedBox(height: 6),
                Text('Paste a lecture link below to get a summary, or ask a question.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
              ],
            ),
          ),
        ),

        AnimatedPositioned(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          left: 20, right: 20,
          top: _hasStarted ? null : inputRestingTop,
          bottom: _hasStarted ? 16 : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorText != null)
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 6),
                  child: Text(_errorText!, style: const TextStyle(color: AppColors.accent, fontSize: 12)),
                ),
              if (_isLoading && _statusText != null)
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: Text(
                    _statusText!,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: _showModelPicker,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_selectedModel, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                            const Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.textMuted),
                          ],
                        ),
                      ),
                    ),
                    Container(width: 1, height: 20, color: AppColors.textMuted.withOpacity(0.2)),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: !_isLoading,
                        decoration: const InputDecoration(
                          hintText: 'Paste a link or ask something',
                          hintStyle: TextStyle(color: AppColors.textMuted),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onSubmitted: (_) => _handleSubmit(),
                      ),
                    ),
                    IconButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      icon: const Icon(Icons.arrow_upward),
                      style: IconButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}