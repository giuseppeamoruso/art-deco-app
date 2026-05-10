import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];
  final firebase_auth.User? user = firebase_auth.FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // Recupera user_id
      final userRecord = await supabase
          .from('USERS')
          .select('id')
          .eq('uid', user!.uid)
          .single();

      final userId = userRecord['id'] as int;

      // Recupera notifiche
      final response = await supabase
          .from('user_notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      setState(() {
        _notifications = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });

      // Marca tutte come lette
      await supabase
          .from('user_notifications')
          .update({'read': true})
          .eq('user_id', userId)
          .eq('read', false);

    } catch (e) {
      print('❌ Errore caricamento notifiche: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Ora';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m fa';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h fa';
      } else if (difference.inDays == 1) {
        return 'Ieri';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}g fa';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return dateTimeString;
    }
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'appointment_modified':
        return Icons.edit_calendar;
      case 'appointment_reminder':
        return Icons.notifications_active;
      case 'appointment_cancelled':
        return Icons.cancel;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'appointment_modified':
        return Colors.orange;
      case 'appointment_reminder':
        return Colors.blue;
      case 'appointment_cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2d2d2d),
        elevation: 0,
        title: const Text(
          'Notifiche',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              onPressed: _showDeleteAllDialog,
              tooltip: 'Cancella tutte',
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
          child: CircularProgressIndicator(color: Colors.white),
        )
            : _notifications.isEmpty
            ? _buildEmptyState()
            : _buildNotificationsList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Nessuna notifica',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Le tue notifiche appariranno qui',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return _buildNotificationCard(notification);
      },
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final type = notification['type'] as String?;
    final read = notification['read'] as bool;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: read ? const Color(0xFF2d2d2d) : const Color(0xFF3d3d3d),
        elevation: read ? 2 : 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: read
              ? BorderSide.none
              : BorderSide(color: Colors.blue.withOpacity(0.3), width: 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Eventualmente naviga all'appuntamento
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icona
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getNotificationColor(type).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getNotificationIcon(type),
                    color: _getNotificationColor(type),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Contenuto
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification['title'],
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: read ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification['message'],
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatDateTime(notification['created_at']),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge non letto
                if (!read)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        title: const Text(
          'Cancella tutte le notifiche?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Questa azione non può essere annullata.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAllNotifications();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Cancella'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAllNotifications() async {
    try {
      final supabase = Supabase.instance.client;
      final userRecord = await supabase
          .from('USERS')
          .select('id')
          .eq('uid', user!.uid)
          .single();

      await supabase
          .from('user_notifications')
          .delete()
          .eq('user_id', userRecord['id']);

      setState(() => _notifications = []);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notifiche cancellate'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Errore cancellazione: $e');
    }
  }
}