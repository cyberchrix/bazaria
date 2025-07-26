import 'package:flutter/material.dart';
import 'conversation_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final List<Map<String, dynamic>> _conversations = [
    {
      'id': '1',
      'userName': 'Marie Dubois',
      'userAvatar': 'https://i.pravatar.cc/150?img=1',
      'lastMessage': 'Bonjour, votre canapé est-il toujours disponible ?',
      'time': DateTime.now().subtract(const Duration(minutes: 5)),
      'unreadCount': 2,
      'adTitle': 'Canapé cuir marron',
      'adPrice': 450,
    },
    {
      'id': '2',
      'userName': 'Thomas Martin',
      'userAvatar': 'https://i.pravatar.cc/150?img=2',
      'lastMessage': 'Je peux passer ce soir à 19h pour voir l\'iPhone',
      'time': DateTime.now().subtract(const Duration(hours: 1)),
      'unreadCount': 1,
      'adTitle': 'iPhone 13 Pro',
      'adPrice': 750,
    },
    {
      'id': '3',
      'userName': 'Sophie Bernard',
      'userAvatar': 'https://i.pravatar.cc/150?img=3',
      'lastMessage': 'Parfait, je confirme pour demain à 14h',
      'time': DateTime.now().subtract(const Duration(hours: 3)),
      'unreadCount': 0,
      'adTitle': 'MacBook Air M1',
      'adPrice': 1200,
    },
    {
      'id': '4',
      'userName': 'Lucas Petit',
      'userAvatar': 'https://i.pravatar.cc/150?img=4',
      'lastMessage': 'Le prix est-il négociable ?',
      'time': DateTime.now().subtract(const Duration(hours: 6)),
      'unreadCount': 0,
      'adTitle': 'Vélo de course',
      'adPrice': 350,
    },
    {
      'id': '5',
      'userName': 'Emma Roux',
      'userAvatar': 'https://i.pravatar.cc/150?img=5',
      'lastMessage': 'Merci pour la transaction !',
      'time': DateTime.now().subtract(const Duration(days: 1)),
      'unreadCount': 0,
      'adTitle': 'Table basse design',
      'adPrice': 120,
    },
    {
      'id': '6',
      'userName': 'Pierre Moreau',
      'userAvatar': 'https://i.pravatar.cc/150?img=6',
      'lastMessage': 'Avez-vous d\'autres photos de la voiture ?',
      'time': DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      'unreadCount': 0,
      'adTitle': 'Peugeot 208',
      'adPrice': 8500,
    },
    {
      'id': '7',
      'userName': 'Julie Leroy',
      'userAvatar': 'https://i.pravatar.cc/150?img=7',
      'lastMessage': 'Je suis intéressée par votre annonce',
      'time': DateTime.now().subtract(const Duration(days: 2)),
      'unreadCount': 0,
      'adTitle': 'PlayStation 5',
      'adPrice': 400,
    },
  ];

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return 'Hier';
    } else {
      return 'Il y a ${difference.inDays}j';
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _conversations.fold<int>(0, (sum, conv) => sum + (conv['unreadCount'] as int));

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          color: Colors.white,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Spacer(),
                  Text(
                    'Messages${unreadCount > 0 ? ' ($unreadCount)' : ''}',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.black,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  const Spacer(),
                  if (unreadCount > 0)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          for (var conversation in _conversations) {
                            conversation['unreadCount'] = 0;
                          }
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tous les messages marqués comme lus'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: const Text(
                        'Tout marquer comme lu',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _conversations.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.message_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Aucun message',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Vos conversations apparaîtront ici',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _conversations.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final conversation = _conversations[index];
                final unreadCount = conversation['unreadCount'] as int;
                final isUnread = unreadCount > 0;

                return ListTile(
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundImage: NetworkImage(conversation['userAvatar'] as String),
                        onBackgroundImageError: (exception, stackTrace) {
                          // Fallback si l'image ne charge pas
                        },
                      ),
                      if (isUnread)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF15A22),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation['userName'] as String,
                          style: TextStyle(
                            fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                            color: isUnread ? Colors.black : Colors.grey.shade700,
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(conversation['time'] as DateTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: isUnread ? Color(0xFFF15A22) : Colors.grey.shade500,
                          fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        conversation['lastMessage'] as String,
                        style: TextStyle(
                          color: isUnread ? Colors.black87 : Colors.grey.shade600,
                          fontSize: 13,
                          fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              conversation['adTitle'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${conversation['adPrice']}€',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFFF15A22),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    // Marquer comme lu si non lu
                    if (isUnread) {
                      setState(() {
                        conversation['unreadCount'] = 0;
                      });
                    }
                    
                    // Naviguer vers la conversation
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ConversationScreen(
                          conversation: conversation,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
} 