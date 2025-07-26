import 'package:flutter/material.dart';

class ConversationScreen extends StatefulWidget {
  final Map<String, dynamic> conversation;
  
  const ConversationScreen({
    super.key,
    required this.conversation,
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _loadFakeMessages();
  }

  void _loadFakeMessages() {
    final conversation = widget.conversation;
    final adTitle = conversation['adTitle'] as String;
    final adPrice = conversation['adPrice'] as int;
    final userName = conversation['userName'] as String;
    
    // Messages fake basés sur le type de conversation
    if (conversation['id'] == '1') { // Marie Dubois - Canapé
      _messages.addAll([
        {
          'id': '1',
          'text': 'Bonjour, votre canapé est-il toujours disponible ?',
          'isMe': false,
          'time': DateTime.now().subtract(const Duration(minutes: 10)),
        },
        {
          'id': '2',
          'text': 'Oui, il est toujours disponible ! Il est en très bon état.',
          'isMe': true,
          'time': DateTime.now().subtract(const Duration(minutes: 8)),
        },
        {
          'id': '3',
          'text': 'Parfait ! Pouvez-vous me dire quelles sont les dimensions ?',
          'isMe': false,
          'time': DateTime.now().subtract(const Duration(minutes: 5)),
        },
      ]);
    } else if (conversation['id'] == '2') { // Thomas Martin - iPhone
      _messages.addAll([
        {
          'id': '1',
          'text': 'Bonjour, je suis intéressé par votre iPhone 13 Pro',
          'isMe': false,
          'time': DateTime.now().subtract(const Duration(hours: 2)),
        },
        {
          'id': '2',
          'text': 'Bonjour ! Oui, il est en parfait état, acheté il y a 6 mois',
          'isMe': true,
          'time': DateTime.now().subtract(const Duration(hours: 1, minutes: 55)),
        },
        {
          'id': '3',
          'text': 'Je peux passer ce soir à 19h pour le voir ?',
          'isMe': false,
          'time': DateTime.now().subtract(const Duration(hours: 1)),
        },
      ]);
    } else { // Conversation générique
      _messages.addAll([
        {
          'id': '1',
          'text': 'Bonjour, je suis intéressé par votre annonce "$adTitle"',
          'isMe': false,
          'time': DateTime.now().subtract(const Duration(hours: 1)),
        },
        {
          'id': '2',
          'text': 'Bonjour ! Oui, elle est toujours disponible au prix de $adPrice€',
          'isMe': true,
          'time': DateTime.now().subtract(const Duration(minutes: 55)),
        },
        {
          'id': '3',
          'text': 'Pouvez-vous me donner plus de détails ?',
          'isMe': false,
          'time': DateTime.now().subtract(const Duration(minutes: 30)),
        },
      ]);
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    setState(() {
      _messages.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'text': _messageController.text.trim(),
        'isMe': true,
        'time': DateTime.now(),
      });
    });

    _messageController.clear();
    _scrollToBottom();

    // Simuler une réponse après 2 secondes
    setState(() {
      _isTyping = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add({
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'text': _getFakeResponse(),
            'isMe': false,
            'time': DateTime.now(),
          });
        });
        _scrollToBottom();
      }
    });
  }

  String _getFakeResponse() {
    final responses = [
      'D\'accord, merci pour l\'information !',
      'Parfait, je vais y réfléchir',
      'Pouvez-vous me donner plus de détails ?',
      'Le prix est-il négociable ?',
      'Quand pouvez-vous me le montrer ?',
      'Avez-vous d\'autres photos ?',
      'Merci pour votre réponse',
      'Je vous recontacte bientôt',
    ];
    return responses[DateTime.now().millisecond % responses.length];
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

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final conversation = widget.conversation;
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: NetworkImage(conversation['userAvatar'] as String),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation['userName'] as String,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    conversation['adTitle'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => _buildOptionsSheet(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // En-tête avec l'annonce
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.image, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conversation['adTitle'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${conversation['adPrice']}€',
                        style: const TextStyle(
                          color: Color(0xFFF15A22),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 16),
                  onPressed: () {
                    // Navigation vers l'annonce
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Navigation vers l\'annonce')),
                    );
                  },
                ),
              ],
            ),
          ),
          
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return _buildTypingIndicator();
                }
                
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          
          // Zone de saisie
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Tapez votre message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF15A22),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMe = message['isMe'] as bool;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 12,
              backgroundImage: NetworkImage(widget.conversation['userAvatar'] as String),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFFF15A22) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message['text'] as String,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message['time'] as DateTime),
                    style: TextStyle(
                      fontSize: 11,
                      color: isMe ? Colors.white70 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundImage: NetworkImage(widget.conversation['userAvatar'] as String),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade600),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'En train d\'écrire...',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
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

  Widget _buildOptionsSheet() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('Bloquer l\'utilisateur'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Utilisateur bloqué')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.report),
            title: const Text('Signaler'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Conversation signalée')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Supprimer la conversation'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Conversation supprimée')),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
} 