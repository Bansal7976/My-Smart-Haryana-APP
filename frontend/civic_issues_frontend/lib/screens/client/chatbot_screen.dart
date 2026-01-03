import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../providers/language_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _sessionId;
  bool _isRecording = false;
  bool _isTranscribing = false;
  final AudioRecorder _audioRecorder = AudioRecorder();
  String _selectedLanguage = 'en'; // Default to English

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _addWelcomeMessage() {
    _messages.add(ChatMessage(
      text:
          "🙏 Welcome to Smart Haryana Assistant!\nआपका स्वागत है स्मार्ट हरियाणा सहायक में!\n\nPlease select your language:\nकृपया अपनी भाषा चुनें:",
      isUser: false,
      timestamp: DateTime.now(),
      quickReplies: ["English", "हिन्दी", "ਪੰਜਾਬੀ"],
    ));
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // Add user message
    setState(() {
      _messages.add(ChatMessage(
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _messageController.clear();
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.token == null) {
        throw Exception('No authentication token available');
      }

      final response = await ApiService.chatWithBot(
        authProvider.token!,
        message,
        sessionId: _sessionId,
        preferredLanguage: _selectedLanguage,
      );

      setState(() {
        _messages.add(ChatMessage(
          text: response['response'] ??
              'Sorry, I couldn\'t process your request.',
          isUser: false,
          timestamp: DateTime.now(),
          quickReplies: response['quick_replies']?.cast<String>(),
        ));
        _sessionId = response['session_id'];
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text:
              'Sorry, there was an error processing your request. Please try again.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
    }
  }

  void _sendQuickReply(String reply) {
    // Check if this is language selection
    if (reply == "English" || reply == "हिन्दी" || reply == "ਪੰਜਾਬੀ") {
      _handleLanguageSelection(reply);
      return;
    }

    _messageController.text = reply;
    _sendMessage();
  }

  Future<void> _handleLanguageSelection(String language) async {
    // Update selected language for chatbot
    if (language == "हिन्दी") {
      _selectedLanguage = 'hi';
    } else if (language == "ਪੰਜਾਬੀ") {
      _selectedLanguage = 'pa';
    } else {
      _selectedLanguage = 'en';
    }

    // Update app language
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    if (language == "हिन्दी") {
      languageProvider.setLanguage('hi');
    } else if (language == "ਪੰਜਾਬੀ") {
      languageProvider.setLanguage('pa');
    } else {
      languageProvider.setLanguage('en');
    }

    // Add user message
    setState(() {
      _messages.add(ChatMessage(
        text: language,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _scrollToBottom();

    // Send welcome message in selected language with proper context
    final welcomeMessage = language == "हिन्दी"
        ? "नमस्ते! मैं स्मार्ट हरियाणा सहायक हूं। मैं आपकी कैसे मदद कर सकता हूं? मैं हरियाणा की सरकारी योजनाओं, नागरिक समस्याओं और ऐप की सुविधाओं के बारे में जानकारी दे सकता हूं।"
        : language == "ਪੰਜਾਬੀ"
        ? "ਸਤ ਸ੍ਰੀ ਅਕਾਲ! ਮੈਂ ਸਮਾਰਟ ਹਰਿਆਣਾ ਸਹਾਇਕ ਹਾਂ। ਮੈਂ ਅੱਜ ਤੁਹਾਡੀ ਕਿਵੇਂ ਮਦਦ ਕਰ ਸਕਦਾ ਹਾਂ? ਮੈਂ ਹਰਿਆਣਾ ਸਰਕਾਰੀ ਯੋਜਨਾਵਾਂ, ਨਾਗਰਿਕ ਮੁੱਦਿਆਂ ਅਤੇ ਐਪ ਦੀਆਂ ਸੁਵਿਧਾਵਾਂ ਬਾਰੇ ਜਾਣਕਾਰੀ ਦੇ ਸਕਦਾ ਹਾਂ।"
        : "Hello! I'm Smart Haryana Assistant. How can I help you today? I can provide information about Haryana government schemes, civic issues, and app features.";

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.token == null) {
        throw Exception('No authentication token');
      }

      // Send a proper welcome query to backend
      final welcomeQuery = language == "हिन्दी" 
          ? "नमस्ते, मैं हिंदी में बात करना चाहता हूं। कृपया मुझे स्मार्ट हरियाणा ऐप के बारे में बताएं।"
          : language == "ਪੰਜਾਬੀ"
          ? "ਸਤ ਸ੍ਰੀ ਅਕਾਲ, ਮੈਂ ਪੰਜਾਬੀ ਵਿੱਚ ਗੱਲ ਕਰਨਾ ਚਾਹੁੰਦਾ ਹਾਂ। ਕਿਰਪਾ ਕਰਕੇ ਮੈਨੂੰ ਸਮਾਰਟ ਹਰਿਆਣਾ ਐਪ ਬਾਰੇ ਦੱਸੋ।"
          : "Hello, I want to speak in English. Please tell me about the Smart Haryana app.";

      final response = await ApiService.chatWithBot(
        authProvider.token!,
        welcomeQuery,
        sessionId: _sessionId,
        preferredLanguage: _selectedLanguage,
      );

      setState(() {
        _messages.add(ChatMessage(
          text: response['response'] ?? welcomeMessage,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _sessionId = response['session_id'];
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      // Fallback to local welcome message if API fails
      setState(() {
        _messages.add(ChatMessage(
          text: welcomeMessage,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startStopRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    // Capture context references BEFORE any async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(languageProvider.getText(
                'Microphone permission denied', 'माइक्रोफ़ोन अनुमति अस्वीकृत')),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final Directory tempDir = await getTemporaryDirectory();
      final String filePath =
          '${tempDir.path}/chatbot_recording_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: filePath,
      );

      if (!mounted) return;
      setState(() {
        _isRecording = true;
      });
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to start recording: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    // Capture context references BEFORE any async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final String? path = await _audioRecorder.stop();

      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _isTranscribing = true;
      });

      if (path != null) {
        await _transcribeAudio(path);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _isTranscribing = false;
      });
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to stop recording: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _transcribeAudio(String audioPath) async {
    // Capture context references BEFORE any async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    try {
      if (authProvider.token == null) {
        throw Exception('No authentication token');
      }

      final result = await ApiService.convertVoiceToText(
        authProvider.token!,
        File(audioPath),
        language: languageProvider.currentLanguage == 'hi' ? 'hi-IN' : 'en-IN',
      );

      if (!mounted) return;

      if (result['text'] != null && result['text'].isNotEmpty) {
        setState(() {
          _messageController.text = result['text'];
        });

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(languageProvider.getText(
                'Voice converted to text!', 'आवाज टेक्स्ट में परिवर्तित हुई!')),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to convert voice: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isTranscribing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    languageProvider.getText(
                        'Smart Assistant', 'स्मार्ट सहायक'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    languageProvider.getText(
                        'AI-Powered Help', 'AI-संचालित सहायता'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: AppColors.primaryGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                _messages.clear();
                _sessionId = null;
                _addWelcomeMessage();
              });
            },
            tooltip: languageProvider.getText('New Chat', 'नई चैट'),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            onPressed: () {
              _showHelpDialog();
            },
            tooltip: languageProvider.getText('Help', 'सहायता'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List with enhanced background
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.02),
                    AppColors.background,
                  ],
                ),
              ),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16.0),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isLoading) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.primary),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  languageProvider.getText(
                                      'Thinking...', 'सोच रहा हूं...'),
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final message = _messages[index];
                  return _buildMessageBubble(message);
                },
              ),
            ),
          ),

          // Quick Replies
          if (_messages.isNotEmpty && _messages.last.quickReplies != null)
            _buildQuickReplies(_messages.last.quickReplies!),

          // Enhanced Input Area
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.border.withValues(alpha: 0.3)),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: AppColors.border.withValues(alpha: 0.5)),
                      ),
                      child: TextField(
                        controller: _messageController,
                        maxLines: 4,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: languageProvider.getText(
                              'Type your message...',
                              'अपना संदेश टाइप करें...'),
                          hintStyle: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Voice Input Button
                  if (_isTranscribing)
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: _isRecording
                            ? const LinearGradient(
                                colors: [AppColors.error, Color(0xFFFF6B6B)])
                            : LinearGradient(colors: [
                                AppColors.primary.withValues(alpha: 0.1),
                                AppColors.primary.withValues(alpha: 0.05)
                              ]),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isRecording
                              ? AppColors.error
                              : AppColors.primary.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: _isLoading ? null : _startStopRecording,
                          child: Icon(
                            _isRecording ? Icons.stop : Icons.mic,
                            color:
                                _isRecording ? Colors.white : AppColors.primary,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  // Send Button
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.primaryGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: _isLoading ? null : _sendMessage,
                        child: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.primaryGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(message.isUser ? 20 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 20),
                ),
                border: message.isUser
                    ? null
                    : Border.all(
                        color: AppColors.border.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: message.isUser ? 0.15 : 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color:
                          message.isUser ? Colors.white : AppColors.textPrimary,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: message.isUser
                            ? Colors.white70
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          color: message.isUser
                              ? Colors.white70
                              : AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 12),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
                border:
                    Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: const Icon(
                Icons.person,
                color: AppColors.primary,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickReplies(List<String> replies) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border.withValues(alpha: 0.3)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.touch_app,
                size: 16,
                color: AppColors.primary.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Text(
                Provider.of<LanguageProvider>(context, listen: false)
                    .getText('Quick Replies:', 'त्वरित उत्तर:'),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: replies.map((reply) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _sendQuickReply(reply),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.1),
                          AppColors.primary.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      reply,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient:
                    const LinearGradient(colors: AppColors.primaryGradient),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.help, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text(languageProvider.getText('How to Use', 'उपयोग कैसे करें')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpItem(
                Icons.chat,
                languageProvider.getText('Ask Questions', 'प्रश्न पूछें'),
                languageProvider.getText(
                    'Ask about app features, government schemes, or your issues',
                    'ऐप सुविधाओं, सरकारी योजनाओं या अपनी समस्याओं के बारे में पूछें'),
              ),
              _buildHelpItem(
                Icons.mic,
                languageProvider.getText('Voice Input', 'आवाज इनपुट'),
                languageProvider.getText(
                    'Tap the microphone to speak in Hindi or English',
                    'हिंदी या अंग्रेजी में बोलने के लिए माइक्रोफ़ोन पर टैप करें'),
              ),
              _buildHelpItem(
                Icons.language,
                languageProvider.getText(
                    'Bilingual Support', 'द्विभाषी समर्थन'),
                languageProvider.getText(
                    'Switch between English and Hindi anytime',
                    'कभी भी अंग्रेजी और हिंदी के बीच स्विच करें'),
              ),
              _buildHelpItem(
                Icons.smart_toy,
                languageProvider.getText('Smart Responses', 'स्मार्ट उत्तर'),
                languageProvider.getText(
                    'Get accurate answers about Haryana and civic issues',
                    'हरियाणा और नागरिक मुद्दों के बारे में सटीक उत्तर प्राप्त करें'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(languageProvider.getText('Got it!', 'समझ गया!')),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String>? quickReplies;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.quickReplies,
  });
}
