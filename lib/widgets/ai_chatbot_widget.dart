import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/chatgpt_service.dart';
import '../utils/app_state.dart';

class Message {
  final String id;
  final String text;
  final bool isBot;
  final DateTime timestamp;
  final String? action;
  final String? actionData;

  Message({
    required this.id,
    required this.text,
    required this.isBot,
    required this.timestamp,
    this.action,
    this.actionData,
  });
}

class AIChatbotWidget extends StatefulWidget {
  const AIChatbotWidget({
    super.key,
    this.apiEndpoint,
    this.apiKey,
    this.additionalResponses,
  });

  final String? apiEndpoint;
  final String? apiKey;
  final Map<String, String>? additionalResponses;

  static const Map<String, String> defaultResponses = {
    // Donation-related questions
    'how do i donate': "To make a donation, simply click on any campaign card, then click 'Donate Now'. Enter your desired amount in ETH and optionally add a message. Your transaction will be processed securely on the blockchain.",
    'what is eth': "ETH (Ether) is the native cryptocurrency of the Ethereum blockchain. It's used to pay for transactions and donations on our platform. You can buy ETH from exchanges like Coinbase or Binance.",
    'minimum donation': 'The minimum donation amount is 0.001 ETH. This helps ensure that transaction fees do not exceed your donation amount.',
    'donation fees': "Our platform does not charge fees for donations. You'll only pay the standard Ethereum network gas fees, which are typically very low.",
    'how donations work': "When you donate, your ETH is sent directly to the charity's verified wallet address via a smart contract. This ensures transparency and that your donation reaches its intended recipient.",

    // Blockchain-related questions
    'what is blockchain': 'Blockchain is a decentralized digital ledger that records transactions across multiple computers. It ensures transparency, security, and immutability—perfect for charitable donations where trust is essential.',
    'why blockchain': 'Blockchain ensures your donations are transparent, traceable, and reach their intended recipients. Every transaction is recorded permanently and can be verified on the blockchain explorer.',
    'is it safe': 'Yes! Blockchain technology is extremely secure. All transactions are encrypted and verified by the network.',

    // Wallet-related questions
    'wallet': "You will need a crypto wallet like MetaMask to make donations. A wallet stores your ETH and allows you to send transactions on the blockchain.",
    'metamask': 'MetaMask is a popular browser extension wallet. Install it from metamask.io, create an account, and you can connect it to our platform to start donating.',
    'connect wallet': "Click the 'Connect Wallet' button in the top-right corner and select your wallet provider. Follow the prompts to authorize the connection.",

    // Charity verification
    'verified charities': 'All charities on our platform go through a rigorous verification process. We check their legal status, financial transparency, and impact metrics before listing them.',
    'how charities verified': 'We verify charity registration documents, tax-exempt status, financial reports, and conduct background checks before allowing them on our platform.',

    // Platform features
    'track donation': "After donating, you will receive a transaction hash. Use this on Etherscan.io or click 'View on Etherscan' in your receipt to track your donation on the blockchain.",
    'donation history': 'Access your donation history through your profile. You can view all past donations, amounts, and transaction details.',
    'receipt': 'After each donation, you will receive a digital receipt with transaction details, including the blockchain transaction hash for verification.',

    // Getting started
    'get started': 'First, set up a crypto wallet like MetaMask. Buy some ETH from an exchange, transfer it to your wallet, then connect your wallet to our platform to start donating!',
    'first time': "Welcome! If you're new to crypto donations, start by setting up a MetaMask wallet, getting some ETH, and exploring our verified campaigns.",

    // Troubleshooting
    'transaction failed': 'Transaction failures usually occur due to insufficient ETH for gas fees or network congestion. Ensure you have enough ETH to cover both the donation and gas fees.',
    'slow transaction': 'Blockchain transactions can take a few minutes during network congestion. You can check status using your transaction hash on Etherscan.io.',
  };

  @override
  State<AIChatbotWidget> createState() => _AIChatbotWidgetState();
}

class _AIChatbotWidgetState extends State<AIChatbotWidget> with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  final List<Message> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  late AnimationController _fabAnimationController;
  late final Map<String, String> _trainedResponses;
  final ChatGPTService _chatGPTService = ChatGPTService();
  final List<Map<String, String>> _conversationHistory = [];

  @override
  void initState() {
    super.initState();
    _trainedResponses = _buildResponseBank();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  void _toggleChat() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _fabAnimationController.forward();
        if (_messages.isEmpty) {
          _generateInitialGreeting();
        }
      } else {
        _fabAnimationController.reverse();
      }
    });
  }

  Future<void> _generateInitialGreeting() async {
    setState(() => _isTyping = true);
    
    try {
      final response = await _chatGPTService.getChatResponse(
        'Generate a brief, friendly greeting message (1-2 sentences) for a charity donation platform chatbot. Make it welcoming and mention that you can help with donations and charities.',
        conversationHistory: [],
      );
      
      if (mounted) {
        _addMessage(
          response['text'] ?? "Hello! I'm here to help you with donations and charity information.",
          isBot: true,
        );
      }
    } catch (e) {
      if (mounted) {
        _addMessage(
          "Hello! I'm here to help you with donations and charity information.",
          isBot: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTyping = false);
      }
    }
  }

  void _addMessage(String text, {required bool isBot, String? action, String? actionData}) {
    if (!mounted) return;
    setState(() {
      _messages.add(
        Message(
          id: '${isBot ? 'bot' : 'user'}-${DateTime.now().millisecondsSinceEpoch}',
          text: text,
          isBot: isBot,
          timestamp: DateTime.now().toUtc().add(const Duration(hours: 8)),
          action: action,
          actionData: actionData,
        ),
      );
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  String _findBestResponse(String userMessage) {
    final lowerMessage = userMessage.toLowerCase();

    for (final entry in _trainedResponses.entries) {
      if (lowerMessage.contains(entry.key)) {
        return entry.value;
      }
    }

    if (RegExp(r'^(hi|hello|hey|good\s+(morning|afternoon|evening)).*$').hasMatch(lowerMessage)) {
      return "Hello! I'm here to help you with donations and answer any questions about our platform. What would you like to know?";
    }

    return "I'd be happy to help! I can answer questions about making donations, blockchain technology, wallet setup, charity verification, or general platform features. Could you please rephrase your question or ask about one of these topics?";
  }

  Future<void> _handleSendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isTyping) return;

    _addMessage(text, isBot: false);
    _inputController.clear();

    setState(() => _isTyping = true);
    await _respond(text);
  }

  Future<void> _respond(String userMessage) async {
    await Future.delayed(const Duration(milliseconds: 600));
    
    // Try ChatGPT first
    String replyText;
    String? action;
    String? actionData;
    
    try {
      final response = await _chatGPTService.getChatResponse(
        userMessage,
        conversationHistory: _conversationHistory,
      );
      
      replyText = response['text'] as String;
      action = response['action'] as String?;
      actionData = response['actionData'] as String?;
      
      // Add to conversation history for context
      _conversationHistory.add({'role': 'user', 'content': userMessage});
      _conversationHistory.add({'role': 'assistant', 'content': replyText});
      
      // Keep only last 10 messages (5 exchanges) for context
      if (_conversationHistory.length > 10) {
        _conversationHistory.removeRange(0, _conversationHistory.length - 10);
      }
    } catch (e) {
      // Fallback to pattern matching if ChatGPT fails
      print('ChatGPT failed, using fallback: $e');
      replyText = _findBestResponse(userMessage);
      action = null;
      actionData = null;
    }

    if (!mounted) return;
    _addMessage(replyText, isBot: true, action: action, actionData: actionData);
    if (mounted) {
      setState(() => _isTyping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final height = media.size.height;
    final bool isCompact = width < 640;
    final bool isDesktop = width >= 1024;
    final double horizontalPadding = isCompact ? 32 : 48;
    final double availableWidth = math.max(width - horizontalPadding, 280);
    final double targetWidth = isCompact
      ? availableWidth
      : width * (isDesktop ? 0.28 : 0.4);
    final double chatWidth = targetWidth.clamp(320.0, math.min(availableWidth, isCompact ? 420.0 : 520.0));
    final double maxChatHeight = math.min(height * 0.72, isCompact ? 520.0 : 640.0);
    final double bubbleMaxWidth = math.min(chatWidth * 0.85, isCompact ? chatWidth - 32 : 360);

    return Stack(
      children: [
        // Backdrop when chat is open
        if (_isOpen)
          GestureDetector(
            onTap: _toggleChat,
            child: Container(
              color: Colors.black.withValues(alpha: 0.2),
            ),
          ),
        
        // Chat window
        if (_isOpen)
          Align(
            alignment: Alignment.bottomRight,
            child: SafeArea(
              top: false,
              child: Container(
                margin: EdgeInsets.only(
                  bottom: 24,
                  right: isCompact ? 16 : 32,
                  left: isCompact ? 16 : 0,
                ),
                width: chatWidth,
                child: _buildChatWindow(maxChatHeight, bubbleMaxWidth, isCompact),
              ),
            ),
          ),
        
        // FAB Button
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: _toggleChat,
            backgroundColor: Colors.transparent,
            elevation: 6,
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF16A34A)], // blue-600 to green-600
                ),
                shape: BoxShape.circle,
              ),
              child: RotationTransition(
                turns: Tween(begin: 0.0, end: 0.5).animate(_fabAnimationController),
                child: Icon(
                  _isOpen ? Icons.close : Icons.message,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Map<String, String> _buildResponseBank() {
    final normalized = <String, String>{};

    void addEntries(Map<String, String> source) {
      for (final entry in source.entries) {
        final key = entry.key.toLowerCase().trim();
        normalized[key] = entry.value;
      }
    }

    addEntries(AIChatbotWidget.defaultResponses);
    if (widget.additionalResponses != null) {
      addEntries(widget.additionalResponses!);
    }
    return normalized;
  }

  Widget _buildChatWindow(double maxHeight, double bubbleMaxWidth, bool isCompact) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxHeight,
        minHeight: math.min(maxHeight, 360),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(isCompact ? 16 : 20), bottom: const Radius.circular(20)),
        child: Material(
          color: Colors.white,
          elevation: 12,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF16A34A)],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Assistant',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Here to help with donations & blockchain',
                            style: TextStyle(
                              color: Color(0xFFDBEAFE),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: _toggleChat,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_isTyping && index == _messages.length) {
                      return _buildTypingIndicator(bubbleMaxWidth);
                    }
                    return _buildMessageBubble(_messages[index], bubbleMaxWidth);
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Ask a question...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        enabled: !_isTyping,
                        onSubmitted: (_) => _handleSendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF16A34A)],
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _isTyping ? null : _handleSendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Message message, double maxBubbleWidth) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: message.isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: maxBubbleWidth,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: message.isBot
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF16A34A)],
                    ),
              color: message.isBot ? const Color(0xFFF1F5F9) : null, // slate-100
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: message.isBot ? const Radius.circular(4) : const Radius.circular(16),
                bottomRight: message.isBot ? const Radius.circular(16) : const Radius.circular(4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: TextStyle(
                    fontSize: 14,
                    color: message.isBot ? const Color(0xFF1E293B) : Colors.white, // slate-800
                    height: 1.5,
                  ),
                ),
                // Action button if present
                if (message.isBot && message.action != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _buildActionButton(message),
                  ),
                const SizedBox(height: 4),
                Text(
                  '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 11,
                    color: message.isBot ? const Color(0xFF64748B) : const Color(0xFFDBEAFE), // slate-500 : blue-100
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(Message message) {
    String buttonText = 'View';
    IconData icon = Icons.arrow_forward;
    
    if (message.action == 'VIEW_CATEGORY') {
      buttonText = 'View ${message.actionData} 🎯';
      icon = Icons.category;
    } else if (message.action == 'VIEW_ALL') {
      buttonText = 'View All Campaigns 📋';
      icon = Icons.grid_view;
    }
    
    return ElevatedButton.icon(
      onPressed: () => _handleAction(message.action!, message.actionData),
      icon: Icon(icon, size: 16),
      label: Text(buttonText),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
  
  void _handleAction(String action, String? actionData) {
    // Import app_state to navigate
    final appState = context.read<AppState>();
    
    if (action == 'VIEW_CATEGORY') {
      appState.selectCategory(actionData);
      appState.navigateTo(Screen.dashboard);
      _toggleChat(); // Close chatbot
    } else if (action == 'VIEW_ALL') {
      appState.selectCategory(null);
      appState.navigateTo(Screen.dashboard);
      _toggleChat(); // Close chatbot
    }
  }

  Widget _buildTypingIndicator(double maxBubbleWidth) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9), // slate-100
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                3,
                (index) => Padding(
                  padding: EdgeInsets.only(left: index > 0 ? 4 : 0),
                  child: _BouncingDot(delay: index * 150),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BouncingDot extends StatefulWidget {
  final int delay;

  const _BouncingDot({required this.delay});

  @override
  State<_BouncingDot> createState() => _BouncingDotState();
}

class _BouncingDotState extends State<_BouncingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);
    
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xFF94A3B8), // slate-400
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
