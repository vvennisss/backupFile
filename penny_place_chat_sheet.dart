import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../services/penny_place_qa_service.dart';

/// Floating modal sheet allowing the traveler to ask Penny questions
/// about their current landmark (history, culture, local stories, tips),
/// with voice reading aloud, pause/resume, and shortcut-tailored thinking feedback.
class PennyPlaceChatSheet extends StatefulWidget {
  final String placeName;
  final String area;

  const PennyPlaceChatSheet({
    super.key,
    required this.placeName,
    required this.area,
  });

  static Future<void> show(BuildContext context, {
    required String placeName,
    required String area,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PennyPlaceChatSheet(
        placeName: placeName,
        area: area,
      ),
    );
  }

  @override
  State<PennyPlaceChatSheet> createState() => _PennyPlaceChatSheetState();
}

class _PennyPlaceChatSheetState extends State<PennyPlaceChatSheet> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  String _selectedLanguage = 'en'; // 'en' or 'zh'
  String _activeLoadingQuery = ''; // For shortcut-tailored thinking display

  // TTS State Management
  late final FlutterTts _flutterTts;
  int? _activeAudioMessageIndex;
  bool _isSpeaking = false;
  bool _isPaused = false;
  List<String> _ttsSentences = [];
  int _currentSentenceIndex = 0;

  @override
  void initState() {
    super.initState();
    _initTts();

    // Initial welcoming message from Penny
    _messages.add(
      _ChatMessage(
        isUser: false,
        text: _getWelcomeText(_selectedLanguage),
        time: TimeOfDay.now(),
      ),
    );
  }

  void _initTts() {
    _flutterTts = FlutterTts();
    _flutterTts.setSpeechRate(0.5);
    _flutterTts.setVolume(1.0);
    _flutterTts.setPitch(1.0);

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        _playNextSentence();
      }
    });

    _flutterTts.setErrorHandler((msg) {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _isPaused = false;
        });
      }
    });
  }

  String _getWelcomeText(String lang) {
    if (lang == 'zh') {
      return '哈罗哈罗！🌸 我是小粉（Penny）！欢迎来到 ${widget.placeName}！\n\n'
          '很高兴能陪你一起探索！关于这里的历史背景、建筑风貌、文化传统、民间秘密或是绝佳摄影打卡位，随时都可以问我哦！你想先了解什么呢？';
    }
    return 'Hello hello! 🌸 Penny here! Welcome to ${widget.placeName}!\n\n'
        'I\'m excited to be here with you! Feel free to ask me anything about the history, architecture, '
        'cultural significance, or local legends of this special landmark. What would you like to discover first?';
  }

  String _getThinkingMessage(String query, String lang) {
    final qLower = query.toLowerCase();
    final isZh = lang == 'zh';

    if (qLower.contains('贴士') ||
        qLower.contains('建议') ||
        qLower.contains('tip') ||
        qLower.contains('etiquette') ||
        qLower.contains('rule')) {
      return isZh
          ? '小粉正在为你整理游览贴士与实用建议... 💡'
          : 'Penny is gathering visiting tips & handy advice... 💡';
    } else if (qLower.contains('摄影') ||
        qLower.contains('拍照') ||
        qLower.contains('打卡') ||
        qLower.contains('photo') ||
        qLower.contains('spot') ||
        qLower.contains('camera')) {
      return isZh
          ? '小粉正在寻找绝佳拍摄机位与光线建议... 📸'
          : 'Penny is scouting the best photo spots & angles... 📸';
    } else if (qLower.contains('美食') ||
        qLower.contains('吃') ||
        qLower.contains('food') ||
        qLower.contains('eat') ||
        qLower.contains('snack')) {
      return isZh
          ? '小粉正在搜罗周边最地道的美食小吃... 🍜'
          : 'Penny is hunting down the tastiest local eats nearby... 🍜';
    } else if (qLower.contains('历史') ||
        qLower.contains('渊源') ||
        qLower.contains('history') ||
        qLower.contains('origin') ||
        qLower.contains('past')) {
      return isZh
          ? '小粉正在翻阅百年历史与开拓故事... 🏛️'
          : 'Penny is recalling the heritage & origins... 🏛️';
    } else if (qLower.contains('文化') ||
        qLower.contains('习俗') ||
        qLower.contains('传统') ||
        qLower.contains('culture') ||
        qLower.contains('tradition') ||
        qLower.contains('meaning')) {
      return isZh
          ? '小粉正在梳理宗亲民俗与传统文化... 🏮'
          : 'Penny is exploring cultural customs & traditions... 🏮';
    } else if (qLower.contains('传说') ||
        qLower.contains('秘密') ||
        qLower.contains('folklore') ||
        qLower.contains('secret') ||
        qLower.contains('legend')) {
      return isZh
          ? '小粉正在探寻鲜为人知的传说与秘密... ✨'
          : 'Penny is uncovering local legends & secrets... ✨';
    } else {
      return isZh
          ? '小粉正在认真思考，马上为你解答... 🌸'
          : 'Penny is thinking and will answer shortly... 🌸';
    }
  }

  void _switchLanguage(String lang) {
    if (_selectedLanguage == lang) return;
    _stopTts();
    setState(() {
      _selectedLanguage = lang;
      // If only the initial welcome message exists, update it to match the chosen language
      if (_messages.length == 1 && !_messages.first.isUser) {
        _messages[0] = _ChatMessage(
          isUser: false,
          text: _getWelcomeText(lang),
          time: TimeOfDay.now(),
        );
      }
    });
  }

  int get _lastAiMessageIndex {
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (!_messages[i].isUser) return i;
    }
    return -1;
  }

  // --- TTS Helpers ---
  String _cleanTextForTts(String raw) {
    var text = raw;
    text = text.replaceAll(RegExp(r'\*\*|\*|__|_|#|`'), '');
    text = text.replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}|\u{2600}-\u{26FF}|\u{2700}-\u{27BF}]', unicode: true), '');
    text = text.replaceAll(RegExp(r'\n+'), '，');
    return text.trim();
  }

  List<String> _splitIntoSentences(String text) {
    final clean = _cleanTextForTts(text);
    final parts = clean.split(RegExp(r'(?<=[。！？!?.])'));
    return parts.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  }

  Future<void> _startTts(int index, String text) async {
    await _stopTts();
    final sentences = _splitIntoSentences(text);
    if (sentences.isEmpty) return;

    final langCode = _selectedLanguage == 'zh' ? 'zh-CN' : 'en-US';
    await _flutterTts.setLanguage(langCode);

    setState(() {
      _activeAudioMessageIndex = index;
      _ttsSentences = sentences;
      _currentSentenceIndex = 0;
      _isSpeaking = true;
      _isPaused = false;
    });

    await _flutterTts.speak(_ttsSentences[0]);
  }

  void _playNextSentence() async {
    if (!_isSpeaking || _isPaused) return;

    if (_currentSentenceIndex + 1 < _ttsSentences.length) {
      _currentSentenceIndex++;
      final nextSentence = _ttsSentences[_currentSentenceIndex];
      await _flutterTts.speak(nextSentence);
    } else {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _isPaused = false;
          _currentSentenceIndex = 0;
        });
      }
    }
  }

  Future<void> _pauseTts() async {
    await _flutterTts.stop();
    setState(() {
      _isSpeaking = false;
      _isPaused = true;
    });
  }

  Future<void> _resumeTts() async {
    if (_activeAudioMessageIndex == null || _ttsSentences.isEmpty) return;
    if (_currentSentenceIndex >= _ttsSentences.length) {
      _currentSentenceIndex = 0;
    }

    final langCode = _selectedLanguage == 'zh' ? 'zh-CN' : 'en-US';
    await _flutterTts.setLanguage(langCode);

    setState(() {
      _isSpeaking = true;
      _isPaused = false;
    });

    await _flutterTts.speak(_ttsSentences[_currentSentenceIndex]);
  }

  Future<void> _restartTts(int index, String text) async {
    await _stopTts();
    await _startTts(index, text);
  }

  Future<void> _stopTts() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _isPaused = false;
      });
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty || _isLoading) return;

    // Immediately stop any active TTS playback
    await _stopTts();

    setState(() {
      _activeLoadingQuery = cleanQuery;
      _messages.add(_ChatMessage(isUser: true, text: cleanQuery, time: TimeOfDay.now()));
      _isLoading = true;
    });
    _textController.clear();
    _scrollToBottom();

    final response = await PennyPlaceQAService.instance.askPenny(
      placeName: widget.placeName,
      area: widget.area,
      userQuestion: cleanQuery,
      modelPreference: 'gemma4:cloud',
      language: _selectedLanguage,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _messages.add(_ChatMessage(isUser: false, text: response, time: TimeOfDay.now()));
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isZh = _selectedLanguage == 'zh';

    final promptChips = isZh
        ? [
            '🏛️ 探索历史渊源',
            '🏮 传统文化与习俗',
            '✨ 本地传说与秘密',
            '📸 最佳摄影打卡点',
            '🍜 周边地道美食',
            '💡 游览贴士与建议',
          ]
        : [
            '🏛️ Tell me the history here',
            '🏮 Cultural traditions & meaning',
            '✨ Local folklore & secrets',
            '📸 Best spots to photograph',
            '🍜 What to eat nearby',
            '💡 Visiting tips & etiquette',
          ];

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                // Mascot avatar
                Container(
                  width: 46,
                  height: 46,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEEF0),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFFB6C1), width: 1.5),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/pink_bird_mascot.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Image.asset(
                        'assets/images/pink_bird_mascot.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context2, error2, stackTrace2) => const Center(
                          child: Text('🌸', style: TextStyle(fontSize: 22)),
                        ),
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
                        children: [
                          Flexible(
                            child: Text(
                              'Penny @ ${widget.placeName}',
                              style: const TextStyle(
                                fontFamily: 'SF Pro',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF303030),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'HERE NOW',
                              style: TextStyle(
                                fontFamily: 'SF Pro',
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isZh
                            ? '历史文化、民间故事与打卡攻略 (${widget.area})'
                            : 'Heritage, culture & local stories (${widget.area})',
                        style: TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 11.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Model Display & Language Picker Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: [
                // 1. Model Display Badge (Fixed on Gemma 4 Cloud)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFC7D2FE), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.psychology_rounded, size: 14, color: Color(0xFF304FFE)),
                      SizedBox(width: 5),
                      Text(
                        'Model: Gemma 4 (Cloud)',
                        style: TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF304FFE),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                // 2. Language Selector Button beside
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLanguageBtn(
                        code: 'en',
                        label: 'English',
                        icon: Icons.language_rounded,
                      ),
                      const SizedBox(width: 2),
                      _buildLanguageBtn(
                        code: 'zh',
                        label: '中文',
                        icon: Icons.translate_rounded,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Quick Suggested Question Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: promptChips.map((chipText) => _buildPromptChip(chipText)).toList(),
            ),
          ),

          const Divider(height: 1, thickness: 0.8),

          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return _buildLoadingBubble(isZh: isZh);
                }
                return _buildMessageBubble(index, _messages[index]);
              },
            ),
          ),

          // Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _textController,
                        style: const TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: isZh
                              ? '问问小粉关于 ${widget.placeName} 的事...'
                              : 'Ask Penny about ${widget.placeName}...',
                          hintStyle: TextStyle(
                            fontFamily: 'SF Pro',
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                          border: InputBorder.none,
                        ),
                        onSubmitted: _sendMessage,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFF304FFE), // Indigo accent
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                      onPressed: () => _sendMessage(_textController.text),
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

  Widget _buildLanguageBtn({
    required String code,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedLanguage == code;
    return GestureDetector(
      onTap: () => _switchLanguage(code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF304FFE) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12.5,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptChip(String text) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ActionChip(
        backgroundColor: const Color(0xFFFFF9C4), // Soft yellow highlight
        side: BorderSide(color: const Color(0xFFFFD54F).withValues(alpha: 0.6)),
        label: Text(
          text,
          style: const TextStyle(
            fontFamily: 'SF Pro',
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        onPressed: () => _sendMessage(text),
      ),
    );
  }

  Widget _buildMessageBubble(int index, _ChatMessage message) {
    final isUser = message.isUser;
    final isLatestAi = !isUser && (index == _lastAiMessageIndex);
    final isThisPlaying = (!isUser && _activeAudioMessageIndex == index && _isSpeaking);
    final isThisPaused = (!isUser && _activeAudioMessageIndex == index && _isPaused);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(right: 8, top: 2),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFEEF0),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('🌸', style: TextStyle(fontSize: 14)),
                  ),
                ),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFF304FFE) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
                      bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      fontFamily: 'SF Pro',
                      fontSize: 13.5,
                      height: 1.4,
                      color: isUser ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Audio Speaker Control Bar for AI responses
          if (!isUser) ...[
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: _buildAudioControlBar(
                index: index,
                text: message.text,
                isLatest: isLatestAi,
                isPlaying: isThisPlaying,
                isPaused: isThisPaused,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAudioControlBar({
    required int index,
    required String text,
    required bool isLatest,
    required bool isPlaying,
    required bool isPaused,
  }) {
    final isZh = _selectedLanguage == 'zh';

    // If not the latest AI message, previous audio button is DISABLED
    if (!isLatest) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.volume_off_rounded, size: 13, color: Colors.grey.shade400),
            const SizedBox(width: 4),
            Text(
              isZh ? '语音已结束' : 'Audio ended',
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 10.5,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      );
    }

    // Active state: Playing
    if (isPlaying) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF93C5FD)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔊', style: TextStyle(fontSize: 11)),
            const SizedBox(width: 5),
            Text(
              isZh ? '正在朗读...' : 'Reading...',
              style: const TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1D4ED8),
              ),
            ),
            const SizedBox(width: 8),
            // Pause button (to stop at that point)
            InkWell(
              onTap: _pauseTts,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.pause_rounded, size: 12, color: Color(0xFF1D4ED8)),
                    const SizedBox(width: 2),
                    Text(
                      isZh ? '暂停' : 'Pause',
                      style: const TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 5),
            // Restart button
            InkWell(
              onTap: () => _restartTts(index, text),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.replay_rounded, size: 12, color: Color(0xFF1D4ED8)),
                    const SizedBox(width: 2),
                    Text(
                      isZh ? '重播' : 'Restart',
                      style: const TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1D4ED8),
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

    // Active state: Paused (allows resume or start again)
    if (isPaused) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFCD34D)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⏸️', style: TextStyle(fontSize: 11)),
            const SizedBox(width: 5),
            Text(
              isZh ? '已暂停' : 'Paused',
              style: const TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF92400E),
              ),
            ),
            const SizedBox(width: 8),
            // Resume button (continues from current sentence)
            InkWell(
              onTap: _resumeTts,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE68A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow_rounded, size: 12, color: Color(0xFF92400E)),
                    const SizedBox(width: 2),
                    Text(
                      isZh ? '继续' : 'Resume',
                      style: const TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 5),
            // Start again button
            InkWell(
              onTap: () => _restartTts(index, text),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE68A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.replay_rounded, size: 12, color: Color(0xFF92400E)),
                    const SizedBox(width: 2),
                    Text(
                      isZh ? '从头开始' : 'Start again',
                      style: const TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E),
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

    // Active state: Idle (ready to speak out)
    return InkWell(
      onTap: () => _startTts(index, text),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFC7D2FE)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.volume_up_rounded, size: 14, color: Color(0xFF304FFE)),
            const SizedBox(width: 4),
            Text(
              isZh ? '听小粉朗读' : 'Read aloud',
              style: const TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF304FFE),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBubble({required bool isZh}) {
    final thinkingText = _getThinkingMessage(_activeLoadingQuery, _selectedLanguage);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('🌸', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.pink.shade100, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.pink.shade400),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      thinkingText,
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
}

class _ChatMessage {
  final bool isUser;
  final String text;
  final TimeOfDay time;

  _ChatMessage({
    required this.isUser,
    required this.text,
    required this.time,
  });
}
