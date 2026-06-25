import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/services/db_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme.dart';
import '../auth/splash_screen.dart';

class AdminBroadcastScreen extends StatefulWidget {
  const AdminBroadcastScreen({Key? key}) : super(key: key);

  @override
  _AdminBroadcastScreenState createState() => _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends State<AdminBroadcastScreen> {
  final _newsFormKey = GlobalKey<FormState>();
  final _newsTitleController = TextEditingController();
  final _newsSubtitleController = TextEditingController();
  final _newsTextController = TextEditingController();
  bool _newsActive = false;
  bool _isSavingNews = false;

  final _msgFormKey = GlobalKey<FormState>();
  final _msgTextController = TextEditingController();
  bool _isSendingMsg = false;

  @override
  void dispose() {
    _newsTitleController.dispose();
    _newsSubtitleController.dispose();
    _newsTextController.dispose();
    _msgTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DbService>(context);
    final auth = Provider.of<AuthService>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text("Broadcast Center"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section 1: Global News configuration
            StreamBuilder<DocumentSnapshot>(
              stream: db.streamBroadcastNews(),
              builder: (context, snap) {
                if (snap.hasData && snap.data != null && snap.data!.exists) {
                  final data = snap.data!.data() as Map<String, dynamic>? ?? {};
                  // Initial fill if controllers are empty
                  if (_newsTitleController.text.isEmpty && _newsTextController.text.isEmpty) {
                    _newsTitleController.text = data['pageTitle'] ?? 'Clinic News';
                    _newsSubtitleController.text = data['pageSubtitle'] ?? 'Important updates for everyone';
                    _newsTextController.text = data['text'] ?? '';
                    _newsActive = data['active'] ?? false;
                  }
                }

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black.withOpacity(0.03)),
                  ),
                  child: Form(
                    key: _newsFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Global News Banner",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimaryColor),
                            ),
                            Switch(
                              value: _newsActive,
                              activeColor: AppTheme.primaryColor,
                              onChanged: (val) {
                                setState(() => _newsActive = val);
                              },
                            ),
                          ],
                        ),
                        const Text(
                          "Configure the sticky announcement card that appears on all patient apps.",
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
                        ),
                        const Divider(height: 24),
                        TextFormField(
                          controller: _newsTitleController,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor),
                          decoration: InputDecoration(
                            labelText: "Banner Title",
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? "Title is required" : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _newsSubtitleController,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor),
                          decoration: InputDecoration(
                            labelText: "Banner Subtitle",
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _newsTextController,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor),
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: "Banner Announcement Text",
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? "Message body is required" : null,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _isSavingNews
                              ? null
                              : () async {
                                  if (!_newsFormKey.currentState!.validate()) return;
                                  setState(() => _isSavingNews = true);
                                  try {
                                    await db.updateBroadcastNews(
                                      _newsTextController.text.trim(),
                                      _newsTitleController.text.trim(),
                                      _newsSubtitleController.text.trim(),
                                      _newsActive,
                                      auth.currentUser?.uid ?? 'admin',
                                    );
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Global news updated successfully!")),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text("Error updating news: $e")),
                                      );
                                    }
                                  } finally {
                                    if (mounted) setState(() => _isSavingNews = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 40),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: _isSavingNews
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                              : const Text("Save & Publish Banner", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 20),

            // Section 2: Timeline Broadcast Dispatcher
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.03)),
              ),
              child: Form(
                key: _msgFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Send Instant Alert Message",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimaryColor),
                    ),
                    const Text(
                      "Publish a new notification update in the clinic broadcast feed for all patient home screens.",
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
                    ),
                    const Divider(height: 24),
                    TextFormField(
                      controller: _msgTextController,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor),
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: "Alert Message text...",
                        hintText: "E.g., Dr. Verma will be delayed by 15 mins today due to emergency surgery.",
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? "Message text is required" : null,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isSendingMsg
                          ? null
                          : () async {
                              if (!_msgFormKey.currentState!.validate()) return;
                              setState(() => _isSendingMsg = true);
                              try {
                                await db.sendBroadcastMessage(
                                  _msgTextController.text.trim(),
                                  auth.currentUser?.uid ?? 'admin',
                                );
                                _msgTextController.clear();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Broadcast alert sent to all patients!")),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Failed to send: $e")),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _isSendingMsg = false);
                              }
                            },
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text("Broadcast Message", style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 100.ms, duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 20),

            // Section 3: Broadcast History Logs
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.03)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Recent Dispatch Logs",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimaryColor),
                  ),
                  const Divider(height: 20),
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: db.streamBroadcastHistory(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final logs = snap.data ?? [];
                      if (logs.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              "No recent broadcasts sent.",
                              style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: logs.length > 5 ? 5 : logs.length,
                        separatorBuilder: (ctx, idx) => const Divider(height: 16),
                        itemBuilder: (ctx, idx) {
                          final log = logs[idx];
                          final text = log['text'] ?? '';
                          final createdAt = log['createdAt'] is Timestamp
                              ? (log['createdAt'] as Timestamp).toDate()
                              : (log['createdAt'] as DateTime? ?? DateTime.now());
                          final timeStr = DateFormat('dd MMM, hh:mm a').format(createdAt);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(text, style: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimaryColor, height: 1.4)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.history_toggle_off_rounded, size: 12, color: AppTheme.textSecondaryColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    timeStr,
                                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
          ],
        ),
      ),
    );
  }
}
