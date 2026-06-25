import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/services/db_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme.dart';
import '../auth/splash_screen.dart';

class AdminChatListScreen extends StatefulWidget {
  const AdminChatListScreen({Key? key}) : super(key: key);

  @override
  _AdminChatListScreenState createState() => _AdminChatListScreenState();
}

class _AdminChatListScreenState extends State<AdminChatListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openChatThread(BuildContext context, String patientId, String patientName, String adminId, String adminName, DbService db) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => AdminChatThreadScreen(
          patientId: patientId,
          patientName: patientName,
          adminId: adminId,
          adminName: adminName,
          db: db,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final db = Provider.of<DbService>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text("Clinic Chatroom Support"),
      ),
      body: Column(
        children: [
          // Search box
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withOpacity(0.03)),
              ),
              child: TextFormField(
                controller: _searchController,
                style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor),
                decoration: InputDecoration(
                  hintText: "Search patients...",
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = "");
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim().toLowerCase());
                },
              ),
            ),
          ),
          
          Expanded(
            child: StreamBuilder<List<ChatRoomItem>>(
              stream: db.streamChatRooms(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final chatRooms = snap.data ?? [];
                
                // Filter based on search query
                final filteredRooms = chatRooms.where((room) {
                  return room.patientName.toLowerCase().contains(_searchQuery);
                }).toList();

                if (filteredRooms.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.forum_outlined, size: 64, color: AppTheme.textSecondaryColor.withOpacity(0.3)),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty ? "No matching chats found." : "No support chats active.",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondaryColor),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: filteredRooms.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final room = filteredRooms[index];
                    final hasUnread = room.doctorRead == false; // DoctorRead acts as clinicRead for both doctor/admin
                    final timeStr = DateFormat('hh:mm a').format(room.lastMessageTime);

                    return Card(
                      color: Colors.white,
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: hasUnread ? AppTheme.primaryColor.withOpacity(0.3) : Colors.black.withOpacity(0.03),
                          width: hasUnread ? 1.5 : 1.0,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                          child: Text(
                            room.patientName.isNotEmpty ? room.patientName[0].toUpperCase() : "P",
                            style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          room.patientName,
                          style: TextStyle(
                            fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                            color: AppTheme.textPrimaryColor,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          room.lastMessageText.isNotEmpty ? room.lastMessageText : "Tap to open chat",
                          style: TextStyle(
                            color: hasUnread ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(timeStr, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor)),
                            const SizedBox(height: 4),
                            if (hasUnread)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  "New",
                                  style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        onTap: () {
                          db.markChatAsRead(room.patientId, 'doctor');
                          _openChatThread(
                            context,
                            room.patientId,
                            room.patientName,
                            auth.currentUser!.uid,
                            auth.currentUser!.name ?? "Receptionist",
                            db,
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AdminChatThreadScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String adminId;
  final String adminName;
  final DbService db;

  const AdminChatThreadScreen({
    Key? key,
    required this.patientId,
    required this.patientName,
    required this.adminId,
    required this.adminName,
    required this.db,
  }) : super(key: key);

  @override
  _AdminChatThreadScreenState createState() => _AdminChatThreadScreenState();
}

class _AdminChatThreadScreenState extends State<AdminChatThreadScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // slate background
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.patientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Text("Patient Support Desk", style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppTheme.textPrimaryColor),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: widget.db.streamChatMessages(widget.patientId),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snap.data ?? [];

                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      "No messages in thread yet. Reply to start the conversation.",
                      style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (ctx, idx) {
                    final msg = messages[idx];
                    final bool isMe = msg.senderId == widget.adminId;
                    final timeStr = DateFormat('hh:mm a').format(msg.timestamp);

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isMe ? AppTheme.primaryColor : Colors.white,
                          borderRadius: BorderRadius.circular(16).copyWith(
                            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
                            bottomLeft: !isMe ? const Radius.circular(0) : const Radius.circular(16),
                          ),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 4, offset: const Offset(0, 2))
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg.text,
                              style: TextStyle(color: isMe ? Colors.white : AppTheme.textPrimaryColor, fontSize: 13.5),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 8.5,
                                color: isMe ? Colors.white70 : AppTheme.textSecondaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // Chat input bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _msgController,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor),
                        decoration: const InputDecoration(
                          hintText: "Type support reply...",
                          hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: AppTheme.primaryColor),
                    onPressed: () async {
                      final text = _msgController.text.trim();
                      if (text.isEmpty) return;
                      _msgController.clear();
                      
                      await widget.db.sendChatMessage(
                        widget.patientId,
                        widget.adminId,
                        widget.adminName,
                        text,
                      );
                      
                      _scrollController.animateTo(
                        0.0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    },
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
