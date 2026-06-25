import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/localization_service.dart';
import '../../core/services/db_service.dart';
import '../../core/utils.dart';
import '../../core/services/pdf_service.dart';
import '../auth/splash_screen.dart';
import '../../core/widgets/connectivity_banner.dart';
import 'admin_finance_screen.dart';
import 'admin_broadcast_screen.dart';
import 'admin_chat_list_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  StreamSubscription<DocumentSnapshot>? _sessionSubscription;

  final List<Widget> _tabs = const [
    _AdminDashboardTab(),
    _AdminQueueTab(),
    _AdminAppointmentsTab(),
    _AdminPatientsTab(),
    _AdminSettingsTab(),
  ];

  @override
  void initState() {
    super.initState();
    _setupSessionSecurityListener();
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    super.dispose();
  }

  void _setupSessionSecurityListener() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    String platformName = Theme.of(context).platform.toString().split('.').last;
    if (platformName == 'android') {
      platformName = 'Android Device';
    } else if (platformName == 'iOS') {
      platformName = 'iOS Device';
    } else {
      platformName = '${platformName[0].toUpperCase()}${platformName.substring(1)} Device';
    }

    final prefs = await SharedPreferences.getInstance();
    final uid = auth.currentUser?.uid ?? "";

    if (uid.isNotEmpty) {
      // 1. Ensure daily OTP session duration (24h)
      final verifiedUntil = prefs.getInt('medique_2fa_$uid') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (verifiedUntil > 0 && verifiedUntil <= now) {
        auth.signOut();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const SplashScreen()),
            (route) => false,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Session expired. Daily authentication required.")),
          );
        }
        return;
      }

      // 2. Local device session identifier registration
      String? localSessionToken = prefs.getString('device_session_token');
      if (localSessionToken == null) {
        localSessionToken = 'sess_${DateTime.now().millisecondsSinceEpoch}_${uid.hashCode}';
        await prefs.setString('device_session_token', localSessionToken);
      }

      final docRef = FirebaseFirestore.instance.doc("artifacts/${auth.appId}/public/data/staff/$uid");
      final userDoc = await docRef.get();
      
      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        
        Map<String, dynamic> activeSessions = {};
        if (data['activeSessions'] != null) {
          activeSessions = Map<String, dynamic>.from(data['activeSessions']);
        } else if (data['activeSessionId'] != null) {
          activeSessions[data['activeSessionId']] = {
            'deviceName': 'Legacy Device',
            'loginTime': DateTime.now().toIso8601String(),
          };
        }

        // Filter other sessions
        final otherSessions = Map<String, dynamic>.from(activeSessions)
          ..remove(localSessionToken);

        if (otherSessions.isNotEmpty) {
          // There is another active session. Ask user which device to log off
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showSessionSelectionDialog(docRef, activeSessions, otherSessions, localSessionToken!, platformName);
          });
        } else {
          // No other active sessions, add current session and continue
          activeSessions[localSessionToken] = {
            'deviceName': platformName,
            'loginTime': DateTime.now().toIso8601String(),
          };
          await docRef.update({
            'activeSessions': activeSessions,
            'activeSessionId': localSessionToken,
          });
          _startRealtimeSessionListener(docRef, localSessionToken);
        }
      } else {
        await docRef.set({
          'activeSessions': {
            localSessionToken: {
              'deviceName': platformName,
              'loginTime': DateTime.now().toIso8601String(),
            }
          },
          'activeSessionId': localSessionToken,
        }, SetOptions(merge: true));
        _startRealtimeSessionListener(docRef, localSessionToken);
      }
    }
  }

  void _showSessionSelectionDialog(
    DocumentReference docRef,
    Map<String, dynamic> activeSessions,
    Map<String, dynamic> otherSessions,
    String localSessionToken,
    String platformName,
  ) {
    final auth = Provider.of<AuthService>(context, listen: false);
    String? selectedSessionKey = otherSessions.keys.first;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                "Active Sessions Detected",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "You are currently logged in on another device. Select the session to terminate in order to log on here:",
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
                  ),
                  const SizedBox(height: 12),
                  ...otherSessions.entries.map((entry) {
                    final sessionData = entry.value as Map<String, dynamic>;
                    final devName = sessionData['deviceName'] ?? 'Unknown Device';
                    final logTimeStr = sessionData['loginTime'] ?? '';
                    String formattedTime = 'Unknown Time';
                    try {
                      if (logTimeStr.isNotEmpty) {
                        final dt = DateTime.parse(logTimeStr);
                        formattedTime = DateFormat('dd MMM, hh:mm a').format(dt.toLocal());
                      }
                    } catch (_) {}

                    return RadioListTile<String>(
                      activeColor: AppTheme.primaryColor,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        devName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        "Logged in: $formattedTime",
                        style: const TextStyle(fontSize: 11),
                      ),
                      value: entry.key,
                      groupValue: selectedSessionKey,
                      onChanged: (val) {
                        setDialogState(() {
                          selectedSessionKey = val;
                        });
                      },
                    );
                  }).toList(),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    auth.signOut();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const SplashScreen()),
                      (route) => false,
                    );
                  },
                  child: const Text(
                    "Cancel",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    if (selectedSessionKey != null) {
                      Navigator.of(ctx).pop();
                      
                      // Remove selected session
                      activeSessions.remove(selectedSessionKey);
                      
                      // Add current session
                      activeSessions[localSessionToken] = {
                        'deviceName': platformName,
                        'loginTime': DateTime.now().toIso8601String(),
                      };

                      await docRef.update({
                        'activeSessions': activeSessions,
                        'activeSessionId': localSessionToken,
                      });

                      _startRealtimeSessionListener(docRef, localSessionToken);
                    }
                  },
                  child: const Text(
                    "Log Off & Continue",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _startRealtimeSessionListener(DocumentReference docRef, String localSessionToken) {
    final auth = Provider.of<AuthService>(context, listen: false);
    _sessionSubscription = docRef.snapshots().listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      final data = snapshot.data() as Map<String, dynamic>? ?? {};
      
      bool isSessionValid = false;
      if (data['activeSessions'] != null) {
        final activeSessions = Map<String, dynamic>.from(data['activeSessions']);
        isSessionValid = activeSessions.containsKey(localSessionToken);
      } else {
        isSessionValid = (data['activeSessionId'] == localSessionToken);
      }

      if (!isSessionValid) {
        _sessionSubscription?.cancel();
        auth.signOut();
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text("Session Terminated", style: TextStyle(fontWeight: FontWeight.bold)),
              content: const Text("This device has been logged off from another session/device."),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const SplashScreen()),
                      (route) => false,
                    );
                  },
                  child: const Text("Dismiss", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                ),
              ],
            ),
          );
        }
      }
    });
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutBack,
            padding: EdgeInsets.symmetric(
              horizontal: isSelected ? 18 : 12,
              vertical: isSelected ? 8 : 6,
            ),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isSelected ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
              size: isSelected ? 22 : 20,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF9CA3AF),
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEFFDFB), Color(0xFFF8FAFC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            const ConnectivityBanner(),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: _tabs,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        height: 76,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.88),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            )
          ]
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.dashboard_rounded, "Dashboard"),
                  _buildNavItem(1, Icons.people_alt_rounded, "Queue"),
                  _buildNavItem(2, Icons.calendar_month_rounded, "Bookings"),
                  _buildNavItem(3, Icons.assignment_ind_rounded, "Patients"),
                  _buildNavItem(4, Icons.settings_rounded, "Settings"),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- TAB 1: OPERATIONAL DASHBOARD ---
class _AdminDashboardTab extends StatefulWidget {
  const _AdminDashboardTab({Key? key}) : super(key: key);

  @override
  __AdminDashboardTabState createState() => __AdminDashboardTabState();
}

class __AdminDashboardTabState extends State<_AdminDashboardTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  void _showNotificationPanel(AuthService auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("artifacts/${auth.appId}/public/data/staff/${auth.currentUser?.uid}/notifications")
                  .orderBy("createdAt", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Notification Hub",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                          if (docs.any((d) => d.get('status') == 'unread'))
                            TextButton(
                              onPressed: () async {
                                final batch = FirebaseFirestore.instance.batch();
                                for (var doc in docs) {
                                  if (doc.get('status') == 'unread') {
                                    batch.update(doc.reference, {'status': 'read'});
                                  }
                                }
                                await batch.commit();
                              },
                              child: const Text(
                                "Mark all as read",
                                style: TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (docs.isEmpty)
                        const Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.notifications_off_outlined,
                                  size: 48,
                                  color: AppTheme.textSecondaryColor,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  "No notifications yet",
                                  style: TextStyle(
                                    color: AppTheme.textSecondaryColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            controller: scrollController,
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final doc = docs[index];
                              final data = doc.data() as Map<String, dynamic>;
                              final title = data['title'] ?? '';
                              final body = data['body'] ?? '';
                              final category = data['category'] ?? 'update';
                              final status = data['status'] ?? 'unread';
                              final Timestamp? createdAt = data['createdAt'] as Timestamp?;

                              IconData categoryIcon;
                              Color iconColor;
                              switch (category) {
                                case 'billing':
                                  categoryIcon = Icons.receipt_long_rounded;
                                  iconColor = AppTheme.successColor;
                                  break;
                                case 'emergency':
                                  categoryIcon = Icons.warning_amber_rounded;
                                  iconColor = AppTheme.errorColor;
                                  break;
                                case 'registration':
                                  categoryIcon = Icons.person_add_alt_1_rounded;
                                  iconColor = AppTheme.primaryColor;
                                  break;
                                default:
                                  categoryIcon = Icons.info_outline_rounded;
                                  iconColor = Colors.indigo;
                              }

                              final isUnread = status == 'unread';

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                color: isUnread ? AppTheme.primaryColor.withOpacity(0.04) : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isUnread
                                        ? AppTheme.primaryColor.withOpacity(0.15)
                                        : Colors.black.withOpacity(0.04),
                                  ),
                                ),
                                elevation: 0,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: iconColor.withOpacity(0.1),
                                    child: Icon(categoryIcon, color: iconColor),
                                  ),
                                  title: Text(
                                    title,
                                    style: TextStyle(
                                      fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                      fontSize: 13,
                                      color: AppTheme.textPrimaryColor,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        body,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondaryColor,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        createdAt != null
                                            ? DateFormat.yMMMd().add_jm().format(createdAt.toDate())
                                            : '',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppTheme.textSecondaryColor.withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () async {
                                    if (isUnread) {
                                      await doc.reference.update({'status': 'read'});
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildKPICard(String label, String value, IconData icon, Color color, {String? subtitle, Duration? delay, double? progress}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.12), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 15),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 9.5, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (subtitle.contains('↓') ? Colors.green : Colors.orange).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 8,
                  color: subtitle.contains('↓') ? Colors.green.shade700 : Colors.orange.shade700,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress ?? 0.6,
              minHeight: 3,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: delay ?? Duration.zero, duration: 300.ms).slideY(begin: 0.12, end: 0, curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final db = Provider.of<DbService>(context);
    final auth = Provider.of<AuthService>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text("MediQue Hub"),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("artifacts/${auth.appId}/public/data/staff/${auth.currentUser?.uid}/notifications")
                .where("status", isEqualTo: "unread")
                .snapshots(),
            builder: (context, unreadSnap) {
              final unreadCount = unreadSnap.data?.docs.length ?? 0;
              return IconButton(
                icon: unreadCount > 0
                    ? Badge(
                        label: Text("$unreadCount"),
                        child: const Icon(Icons.notifications_outlined),
                      )
                    : const Icon(Icons.notifications_outlined),
                onPressed: () => _showNotificationPanel(auth),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<QueueItem>>(
        stream: db.streamReceptionistQueue(),
        builder: (ctx, snap) {
          final items = snap.data ?? [];
          final waiting = items.where((i) => i.status == 'waiting' || i.status == 'pre_registered').length;
          final consult = items.where((i) => i.status == 'calling').length;
          final pending = items.where((i) => i.status == 'pending_payment').length;
          final done = items.where((i) => i.status == 'seen').length;
          
          double revenue = 0.0;
          for (var item in items) {
            if (item.status == 'seen' && item.fee != null) {
              revenue += item.fee!;
            }
          }

          return StreamBuilder<double>(
            stream: db.streamAverageConsultationTime(),
            builder: (ctx, waitSnap) {
              final avgWait = waitSnap.data ?? 12.0;

              return RefreshIndicator(
                onRefresh: () async {
                  setState(() {});
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 100.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "Clinic Control & Live Performance Indicators",
                        style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13, fontWeight: FontWeight.w500),
                      ).animate().fadeIn(duration: 350.ms).slideX(begin: -0.05, end: 0, curve: Curves.easeOut),
                      const SizedBox(height: 16),

                       FutureBuilder<List<QueueItem>>(
                        future: db.getYesterdayQueue(),
                        builder: (context, ySnap) {
                          final yesterdayItems = ySnap.data ?? [];
                          
                          // Calculate today's average wait time
                          final seenToday = items.where((i) => i.status == 'seen' && i.joinedAt != null && i.completedAt != null).toList();
                          double todayAvgWait = 0.0;
                          if (seenToday.isNotEmpty) {
                            double totalWait = 0.0;
                            for (var item in seenToday) {
                              totalWait += item.completedAt!.difference(item.joinedAt!).inMinutes;
                            }
                            todayAvgWait = totalWait / seenToday.length;
                          } else {
                            todayAvgWait = avgWait;
                          }
                          
                          // Calculate yesterday's average wait time
                          final seenYesterday = yesterdayItems.where((i) => i.joinedAt != null && i.completedAt != null).toList();
                          double yesterdayAvgWait = 0.0;
                          if (seenYesterday.isNotEmpty) {
                            double totalWait = 0.0;
                            for (var item in seenYesterday) {
                              totalWait += item.completedAt!.difference(item.joinedAt!).inMinutes;
                            }
                            yesterdayAvgWait = totalWait / seenYesterday.length;
                          } else {
                            yesterdayAvgWait = 15.0; // fallback standard wait
                          }
                          
                          // Calculate comparison %
                          String comparisonText = "No prev data";
                          if (yesterdayAvgWait > 0) {
                            final diff = todayAvgWait - yesterdayAvgWait;
                            final pct = (diff / yesterdayAvgWait) * 100;
                            if (pct < 0) {
                              comparisonText = "${pct.abs().toStringAsFixed(1)}% ↓ vs yesterday";
                            } else {
                              comparisonText = "${pct.toStringAsFixed(1)}% ↑ vs yesterday";
                            }
                          }
                          
                          return GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            childAspectRatio: 1.55,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            children: [
                              _buildKPICard("Waiting Patients", "$waiting", Icons.hourglass_empty_rounded, Colors.blue, delay: 0.ms, progress: (waiting / (waiting + consult + pending + done + 1)).clamp(0.0, 1.0)),
                              _buildKPICard("In Consultation", "$consult", Icons.medical_services_rounded, const Color(0xFF4F46E5), delay: 50.ms, progress: (consult / (waiting + consult + pending + done + 1)).clamp(0.0, 1.0)),
                              _buildKPICard("Pending Payments", "$pending", Icons.payment_rounded, const Color(0xFFF59E0B), delay: 100.ms, progress: pending > 0 ? (pending / (waiting + consult + pending + done + 1)).clamp(0.1, 1.0) : 0.05),
                              _buildKPICard("Completed Today", "$done", Icons.check_circle_rounded, const Color(0xFF22C55E), delay: 150.ms, progress: (done / (waiting + consult + pending + done + 1)).clamp(0.0, 1.0)),
                              _buildKPICard("Revenue Today", "₹${revenue.toStringAsFixed(0)}", Icons.currency_rupee_rounded, const Color(0xFF0F9D8A), delay: 200.ms, progress: (revenue / (revenue + 1000)).clamp(0.0, 1.0)),
                              _buildKPICard(
                                "Avg Wait Time",
                                "${todayAvgWait.toStringAsFixed(0)} mins",
                                Icons.timer_rounded,
                                Colors.cyan,
                                subtitle: comparisonText,
                                delay: 250.ms,
                                progress: (todayAvgWait / 30).clamp(0.0, 1.0),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),

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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Finance Console", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimaryColor)),
                                Icon(Icons.show_chart_rounded, color: AppTheme.primaryColor),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildFinanceStat("Today's Revenue", "₹${revenue.toStringAsFixed(0)}", Colors.green),
                                _buildFinanceStat("Est. Profit (80%)", "₹${(revenue * 0.8).toStringAsFixed(0)}", AppTheme.primaryColor),
                                _buildFinanceStat("Unpaid Bills", "$pending", Colors.orange),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const AdminFinanceScreen()),
                                );
                              },
                              icon: const Icon(Icons.show_chart_rounded, size: 16),
                              label: const Text("Open Finance Console", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                foregroundColor: AppTheme.primaryColor,
                                elevation: 0,
                                minimumSize: const Size(double.infinity, 38),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 300.ms, duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
                      const SizedBox(height: 20),

                      _SmartAnalyticsSection(todayQueueItems: items, appId: auth.appId),
                      const SizedBox(height: 20),

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
                            const Text("Live Operations Ticker", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimaryColor)),
                            const Divider(height: 20),
                            _buildLogEntry("Walk-in registration", "New patient checked in at front desk", "1 min ago"),
                            _buildLogEntry("Consultation completed", "Dr. Verma finished consulting patient T-2", "8 mins ago"),
                            _buildLogEntry("Queue update", "Emergency Patient prioritized at index 0", "12 mins ago"),
                            _buildLogEntry("Payment confirmed", "Payment of ₹250 verified via UPI", "20 mins ago"),
                          ],
                        ),
                      ).animate().fadeIn(delay: 500.ms, duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFinanceStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }

  Widget _buildLogEntry(String action, String details, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(action, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimaryColor)),
                Text(details, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor)),
              ],
            ),
          ),
          Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _SmartAnalyticsSection extends StatelessWidget {
  final List<QueueItem> todayQueueItems;
  final String appId;

  const _SmartAnalyticsSection({
    Key? key,
    required this.todayQueueItems,
    required this.appId,
  }) : super(key: key);

  void _showAuditDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppTheme.primaryColor),
              SizedBox(width: 10),
              Text("Analytics Audit Log", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Calculation Formulas:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor)),
                const SizedBox(height: 6),
                _buildFormulaRow("Peak Doctor", "Mode(doctorName) from today's completed visits"),
                _buildFormulaRow("Busiest Hour", "Mode(Hour(joinedAt)) from all queue check-ins today"),
                _buildFormulaRow("No-Show Rate", "(Cancelled appointments / Total appointments) * 100"),
                _buildFormulaRow("Avg Satisfaction", "Average(docSatisfaction & appOverall) from feedback"),
                _buildFormulaRow("Avg Wait Time Today", "Average(completedAt - joinedAt) for completed items today"),
                const Divider(height: 24),
                const Text("Data Sources (Firestore Paths):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor)),
                const SizedBox(height: 6),
                _buildFormulaRow("Queue Records", "artifacts/{appId}/public/data/queue"),
                _buildFormulaRow("Appointments", "artifacts/{appId}/public/data/appointments"),
                _buildFormulaRow("Feedback Data", "artifacts/{appId}/public/data/feedback"),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Last Computed:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textSecondaryColor)),
                    Text(
                      DateFormat('hh:mm:ss a').format(DateTime.now()),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textPrimaryColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Close", style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFormulaRow(String metric, String formula) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(metric, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.textPrimaryColor)),
          Text(formula, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
        ],
      ),
    );
  }

  void _showFeedbackInsightsBottomSheet(
    BuildContext context,
    double docClarity,
    double docBehavior,
    double appEase,
    double appWaitAccuracy,
    int praiseCount,
    int complaintCount,
    List<String> praiseComments,
    List<String> complaintComments,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text("Feedback Insights Panel", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimaryColor)),
                  const Divider(),
                  const SizedBox(height: 10),
                  
                  // Category Scores
                  const Text("Category Ratings Breakdown (Average)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor)),
                  const SizedBox(height: 12),
                  _buildRatingProgressRow("Doctor Explanation Clarity", docClarity),
                  _buildRatingProgressRow("Doctor Behavior & Empathy", docBehavior),
                  _buildRatingProgressRow("Mobile App Interface Ease", appEase),
                  _buildRatingProgressRow("Wait Time Estimate Accuracy", appWaitAccuracy),
                  
                  const SizedBox(height: 24),
                  
                  // Praise vs Complaints summary
                  const Text("Feedback Comments Sentiment Summaries", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade100),
                          ),
                          child: Column(
                            children: [
                              Text("$praiseCount", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green)),
                              const Text("Praise Sentiment", style: TextStyle(fontSize: 11, color: Colors.green)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade100),
                          ),
                          child: Column(
                            children: [
                              Text("$complaintCount", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.red)),
                              const Text("Complaint / Issue", style: TextStyle(fontSize: 11, color: Colors.red)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Praise comments
                  if (praiseComments.isNotEmpty) ...[
                    const Text("Recent Praise Comments Summary:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green)),
                    const SizedBox(height: 6),
                    ...praiseComments.take(3).map((comment) => _buildCommentBullet(comment, Colors.green)),
                    const SizedBox(height: 16),
                  ],
                  
                  // Complaint comments
                  if (complaintComments.isNotEmpty) ...[
                    const Text("Recent Complaints / Issues Summary:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red)),
                    const SizedBox(height: 6),
                    ...complaintComments.take(3).map((comment) => _buildCommentBullet(comment, Colors.red)),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRatingProgressRow(String label, double rating) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textPrimaryColor)),
              Text("${rating.toStringAsFixed(1)} / 5.0", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rating / 5.0,
              backgroundColor: Colors.grey.shade100,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentBullet(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "\"$text\"",
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textSecondaryColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showWhatsAppLogsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("artifacts/$appId/public/data/whatsappLogs")
                  .orderBy("sentAt", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const Text(
                        "WhatsApp Dispatch Logs",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimaryColor),
                      ),
                      const SizedBox(height: 12),
                      if (docs.isEmpty)
                        const Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.mark_chat_read_rounded, size: 48, color: AppTheme.textSecondaryColor),
                                SizedBox(height: 12),
                                Text(
                                  "No WhatsApp logs found",
                                  style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            controller: scrollController,
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final doc = docs[index];
                              final data = doc.data() as Map<String, dynamic>;
                              final patientName = data['patientName'] ?? data['recipientName'] ?? 'Patient';
                              final phone = data['phone'] ?? data['recipientMobile'] ?? 'N/A';
                              final message = data['message'] ?? data['content'] ?? '';
                              final status = data['status'] ?? 'queued';
                              final Timestamp? sentAt = data['sentAt'] as Timestamp?;

                              final timeStr = sentAt != null
                                  ? DateFormat.yMMMd().add_jm().format(sentAt.toDate())
                                  : 'Pending';

                              Color statusColor;
                              switch (status) {
                                case 'sent':
                                  statusColor = Colors.green;
                                  break;
                                case 'failed':
                                  statusColor = Colors.red;
                                  break;
                                case 'queued':
                                default:
                                  statusColor = Colors.orange;
                              }

                              final displayPhone = phone.toString();
                              return GestureDetector(
                                onTap: () async {
                                  if (displayPhone != 'N/A' && displayPhone.isNotEmpty) {
                                    String cleanPhone = displayPhone.replaceAll(RegExp(r'\D'), '');
                                    if (cleanPhone.length == 10) {
                                      cleanPhone = '91$cleanPhone';
                                    }
                                    final url = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}");
                                    if (await canLaunchUrl(url)) {
                                      await launchUrl(url, mode: LaunchMode.externalApplication);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Could not launch WhatsApp")),
                                      );
                                    }
                                  }
                                },
                                child: Card(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.black.withOpacity(0.04)),
                                  ),
                                  elevation: 0,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            patientName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              status.toUpperCase(),
                                              style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Phone: $phone",
                                        style: const TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        message,
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textPrimaryColor),
                                      ),
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.bottomRight,
                                        child: Text(
                                          timeStr,
                                          style: TextStyle(fontSize: 9, color: AppTheme.textSecondaryColor.withOpacity(0.6)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DbService>(context, listen: false);

    // 1. Calculate Peak Doctor
    String peakDoctor = "N/A";
    if (todayQueueItems.isNotEmpty) {
      final Map<String, int> docCounts = {};
      for (var item in todayQueueItems) {
        if (item.doctorName != null && item.doctorName!.isNotEmpty) {
          docCounts[item.doctorName!] = (docCounts[item.doctorName!] ?? 0) + 1;
        }
      }
      if (docCounts.isNotEmpty) {
        peakDoctor = docCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      }
    }

    // 2. Calculate Busiest Hour
    String busiestHour = "N/A";
    if (todayQueueItems.isNotEmpty) {
      final Map<int, int> hourCounts = {};
      for (var item in todayQueueItems) {
        if (item.joinedAt != null) {
          final hr = item.joinedAt!.hour;
          hourCounts[hr] = (hourCounts[hr] ?? 0) + 1;
        }
      }
      if (hourCounts.isNotEmpty) {
        final peakHr = hourCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
        final startLabel = peakHr == 0 ? "12 AM" : peakHr > 12 ? "${peakHr - 12} PM" : peakHr == 12 ? "12 PM" : "$peakHr AM";
        final nextHr = peakHr + 1;
        final endLabel = nextHr == 24 ? "12 AM" : nextHr > 12 ? "${nextHr - 12} PM" : nextHr == 12 ? "12 PM" : "$nextHr AM";
        busiestHour = "$startLabel - $endLabel";
      }
    }

    return StreamBuilder<List<AppointmentItem>>(
      stream: db.streamClinicAppointments(),
      builder: (context, apptSnap) {
        final appts = apptSnap.data ?? [];
        
        // 3. Calculate No-Show Rate
        final now = DateTime.now();
        final startOfToday = DateTime(now.year, now.month, now.day);
        final todayAppts = appts.where((a) => a.appointmentAt.isAfter(startOfToday)).toList();
        
        double noShowRate = 0.0;
        if (todayAppts.isNotEmpty) {
          final cancelled = todayAppts.where((a) => a.status.toLowerCase() == 'cancelled').length;
          noShowRate = (cancelled / todayAppts.length) * 100;
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection("artifacts/$appId/public/data/feedback").snapshots(),
          builder: (context, feedbackSnap) {
            final feedbackDocs = feedbackSnap.data?.docs ?? [];
            
            // 4. Calculate Average Satisfaction Score and breakdowns
            double avgSatisfaction = 0.0;
            int satisfactionCount = 0;
            int praiseCount = 0;
            int complaintCount = 0;
            
            double docClarityAvg = 0.0;
            double docBehaviorAvg = 0.0;
            double appEaseAvg = 0.0;
            double appWaitAccuracyAvg = 0.0;
            
            final List<String> praiseKeywords = ['good', 'great', 'excellent', 'fast', 'nice', 'helpful', 'polite', 'best', 'satisfied', 'quick', 'superb', 'awesome'];
            final List<String> complaintKeywords = ['delay', 'slow', 'wait', 'rude', 'bad', 'worst', 'issue', 'error', 'bug', 'late', 'expensive', 'crowd'];
            
            final List<String> praiseComments = [];
            final List<String> complaintComments = [];

            for (var doc in feedbackDocs) {
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final ratings = data['ratings'] as Map<String, dynamic>?;
              if (ratings != null) {
                final int? docSat = ratings['docSatisfaction'] ?? ratings['docClarity'] ?? ratings['docBehavior'];
                
                final int? clarity = ratings['docClarity'];
                final int? behavior = ratings['docBehavior'];
                final int? ease = ratings['appEase'];
                final int? waitAcc = ratings['appWaitAccuracy'];
                
                if (docSat != null) {
                  avgSatisfaction += docSat;
                  satisfactionCount++;
                }
                
                if (clarity != null) docClarityAvg += clarity;
                if (behavior != null) docBehaviorAvg += behavior;
                if (ease != null) appEaseAvg += ease;
                if (waitAcc != null) appWaitAccuracyAvg += waitAcc;
              }
              
              final String comments = (data['comments'] ?? '').toString().toLowerCase();
              if (comments.isNotEmpty) {
                bool matchedPraise = false;
                bool matchedComplaint = false;
                for (var kw in praiseKeywords) {
                  if (comments.contains(kw)) {
                    matchedPraise = true;
                    break;
                  }
                }
                for (var kw in complaintKeywords) {
                  if (comments.contains(kw)) {
                    matchedComplaint = true;
                    break;
                  }
                }
                
                if (matchedPraise) {
                  praiseCount++;
                  praiseComments.add(data['comments']);
                }
                if (matchedComplaint) {
                  complaintCount++;
                  complaintComments.add(data['comments']);
                }
              }
            }
            
            if (satisfactionCount > 0) {
              avgSatisfaction = avgSatisfaction / satisfactionCount;
              docClarityAvg = docClarityAvg / satisfactionCount;
              docBehaviorAvg = docBehaviorAvg / satisfactionCount;
              appEaseAvg = appEaseAvg / satisfactionCount;
              appWaitAccuracyAvg = appWaitAccuracyAvg / satisfactionCount;
            } else {
              avgSatisfaction = 4.8;
              docClarityAvg = 4.7;
              docBehaviorAvg = 4.9;
              appEaseAvg = 4.6;
              appWaitAccuracyAvg = 4.5;
            }

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.03)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Smart Operations Console",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimaryColor),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.info_outline_rounded, color: AppTheme.textSecondaryColor, size: 20),
                            onPressed: () => _showAuditDetailsDialog(context),
                          ),
                          const Icon(Icons.analytics_outlined, color: Colors.teal),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 10),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      _buildMetricTile("Peak Doctor", peakDoctor, Icons.star_border_rounded, Colors.purple),
                      _buildMetricTile("Busiest Hour", busiestHour, Icons.access_time_filled_rounded, Colors.orange),
                      _buildMetricTile("No-Show Rate", "${noShowRate.toStringAsFixed(1)}%", Icons.person_off_rounded, Colors.red),
                      _buildMetricTile("Avg Satisfaction", "${avgSatisfaction.toStringAsFixed(1)} / 5.0", Icons.thumb_up_rounded, Colors.green),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showFeedbackInsightsBottomSheet(
                            context,
                            docClarityAvg,
                            docBehaviorAvg,
                            appEaseAvg,
                            appWaitAccuracyAvg,
                            praiseCount,
                            complaintCount,
                            praiseComments,
                            complaintComments,
                          ),
                          icon: const Icon(Icons.rate_review_rounded, size: 16),
                          label: const Text("Feedback Insights", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showWhatsAppLogsBottomSheet(context),
                          icon: const Icon(Icons.chat_rounded, size: 16),
                          label: const Text("WhatsApp Logs", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            side: BorderSide(color: Colors.green.withOpacity(0.3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 400.ms, duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut);
          },
        );
      },
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 9, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- TAB 2: QUEUE CONTROL ---
class _AdminQueueTab extends StatefulWidget {
  const _AdminQueueTab({Key? key}) : super(key: key);

  @override
  __AdminQueueTabState createState() => __AdminQueueTabState();
}

class __AdminQueueTabState extends State<_AdminQueueTab> with AutomaticKeepAliveClientMixin {
  final Map<String, String> _selectedPaymentMethods = {};
  final Map<String, TextEditingController> _feeControllers = {};
  final _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _feeControllers.forEach((_, controller) => controller.dispose());
    _searchController.dispose();
    super.dispose();
  }

  void _showUpiQrCodeDialog(BuildContext context, DbService db, QueueItem p, double feeVal) {
    bool hasPopped = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return StreamBuilder<ClinicSettings>(
              stream: db.streamSettings(),
              builder: (context, settingsSnap) {
                final upiId = settingsSnap.data?.upiId ?? "prajansanjayko@okaxis";
                final String upiUrl = "upi://pay"
                    "?pa=${Uri.encodeComponent(upiId)}"
                    "&pn=${Uri.encodeComponent("MediQueue Clinic")}"
                    "&mc=8011"
                    "&tn=${Uri.encodeComponent("Clinic Token ${p.token}")}"
                    "&am=${Uri.encodeComponent(feeVal.toString())}"
                    "&cu=INR";

                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  backgroundColor: Colors.white,
                  title: Row(
                    children: [
                      const Icon(Icons.qr_code_2, color: Color(0xFF4F46E5), size: 28),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          "UPI QR Code",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Scan to pay ₹${feeVal.toStringAsFixed(0)}",
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200, width: 2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: QrImageView(
                            data: upiUrl,
                            version: QrVersions.auto,
                            size: 200,
                          ),
                        ),
                      ),
                    ],
                  ),
                  actionsAlignment: MainAxisAlignment.spaceBetween,
                  actions: [
                    TextButton(
                      onPressed: () {
                        if (!hasPopped) {
                          hasPopped = true;
                          Navigator.of(dialogCtx).pop();
                        }
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (!hasPopped) {
                          hasPopped = true;
                          await db.confirmManualPayment(p.id, feeVal, 'upi');
                          await PdfService.generateAndPrintInvoice(
                            patientName: p.name,
                            doctorName: p.doctorName ?? "General Physician",
                            amount: feeVal,
                            paymentMethod: "upi",
                            token: p.token ?? "T-N/A",
                            reason: p.issue,
                          );
                          if (dialogCtx.mounted) {
                            Navigator.of(dialogCtx).pop();
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Mark as Paid", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showWalkInDialog(DbService db) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return _WalkInCheckInDialog(db: db);
      },
    );
  }

  Widget _buildQueueSkeleton() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE2E8F0),
      highlightColor: const Color(0xFFF1F5F9),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final db = Provider.of<DbService>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text("Clinic Queue Manager"),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80.0),
        child: FloatingActionButton.extended(
          onPressed: () => _showWalkInDialog(db),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.add),
          label: const Text("New Walk-In Patient", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search patient by name...",
                hintStyle: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondaryColor, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppTheme.textSecondaryColor, size: 20),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = "";
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.black.withOpacity(0.05)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.black.withOpacity(0.05)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
            ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.05, end: 0, curve: Curves.easeOut),
          ),

          Expanded(
            child: StreamBuilder<List<QueueItem>>(
              stream: db.streamReceptionistQueue(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return _buildQueueSkeleton();
                }

                final allQueueItems = snap.data ?? [];
                
                final waiting = allQueueItems.where((q) => q.status == 'waiting' || q.status == 'pre_registered').length;
                final consulting = allQueueItems.where((q) => q.status == 'calling').length;

                var activeQueue = allQueueItems.where((q) => q.status != 'seen').toList();

                if (_searchQuery.isNotEmpty) {
                  activeQueue = activeQueue.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
                }

                activeQueue.sort((a, b) {
                  final int pA = a.id.contains("emergency") || a.issue.toUpperCase().contains("EMERGENCY") ? 1 : 0;
                  final int pB = b.id.contains("emergency") || b.issue.toUpperCase().contains("EMERGENCY") ? 1 : 0;
                  if (pA != pB) return pB.compareTo(pA);

                  if (a.joinedAt == null) return 1;
                  if (b.joinedAt == null) return -1;
                  return a.joinedAt!.compareTo(b.joinedAt!);
                });

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          _buildQueuePill("Waiting: $waiting", Colors.blue),
                          const SizedBox(width: 8),
                          _buildQueuePill("In Consult: $consulting", const Color(0xFF4F46E5)),
                          const Spacer(),
                          const Text("Pull to refresh", style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor)),
                        ],
                      ),
                    ).animate().fadeIn(delay: 100.ms, duration: 300.ms).slideX(begin: -0.05, end: 0, curve: Curves.easeOut),
                    const SizedBox(height: 12),

                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          setState(() {});
                        },
                        child: activeQueue.isEmpty
                            ? ListView(
                                children: [
                                  SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                                  Center(
                                    child: Column(
                                      children: [
                                        Icon(Icons.people_outline_rounded, size: 64, color: AppTheme.textSecondaryColor.withOpacity(0.3)),
                                        const SizedBox(height: 12),
                                        Text(
                                          _searchQuery.isNotEmpty ? "No matching patients." : "Queue is empty.",
                                          style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  )
                                ],
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                                itemCount: activeQueue.length,
                                itemBuilder: (ctx, idx) {
                                  final p = activeQueue[idx];
                                  final bool isEmergency = p.issue.toUpperCase().contains("EMERGENCY");
                                  final bool isCalling = p.status == 'calling';
                                  final bool isPendingPayment = p.status == 'pending_payment';
                                  final bool upiRequested = p.paymentRequestStatus == 'requested';

                                  if (!_selectedPaymentMethods.containsKey(p.id)) {
                                    _selectedPaymentMethods[p.id] = "cash";
                                  }
                                  if (!_feeControllers.containsKey(p.id)) {
                                    _feeControllers[p.id] = TextEditingController(text: (p.fee ?? 250.0).toStringAsFixed(0));
                                  }

                                  final String selectedMethod = _selectedPaymentMethods[p.id]!;
                                  final TextEditingController feeController = _feeControllers[p.id]!;

                                  final arrival = p.joinedAt != null ? DateFormat('hh:mm a').format(p.joinedAt!) : '--:--';
                                  final duration = p.joinedAt != null ? "${DateTime.now().difference(p.joinedAt!).inMinutes}m ago" : "Just now";

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isEmergency ? AppTheme.errorColor.withOpacity(0.2) : Colors.black.withOpacity(0.03),
                                        width: isEmergency ? 1.5 : 1.0,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.015),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        )
                                      ]
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.primaryColor.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    p.token ?? "T--",
                                                    style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primaryColor, fontSize: 12),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                if (isEmergency)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.errorColor.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: const Text(
                                                      "EMERGENCY",
                                                      style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.errorColor, fontSize: 9),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            Text(
                                              isPendingPayment ? "Checkout Pending" : p.status.toUpperCase(),
                                              style: TextStyle(
                                                color: isPendingPayment ? Colors.orange : (isCalling ? Colors.indigo : AppTheme.primaryColor),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),

                                        Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimaryColor)),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(Icons.phone_iphone_rounded, size: 13, color: AppTheme.textSecondaryColor),
                                            const SizedBox(width: 4),
                                            Text(p.mobile, style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12)),
                                            const SizedBox(width: 12),
                                            const Icon(Icons.timer_rounded, size: 13, color: AppTheme.textSecondaryColor),
                                            const SizedBox(width: 4),
                                            Text("Arrived: $arrival ($duration)", style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12)),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Assigned to: Dr. ${p.doctorName ?? 'Not Assigned'} (${p.specialty ?? 'General'})",
                                          style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12, fontWeight: FontWeight.w500),
                                        ),
                                        Text(
                                          "Chief complaint: ${p.issue}",
                                          style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12, fontStyle: FontStyle.italic),
                                        ),

                                        const SizedBox(height: 12),
                                        const Divider(height: 10),
                                        const SizedBox(height: 8),
                                        if (isPendingPayment) ...[
                                          Row(
                                            children: [
                                              const Text("Fee: ₹", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor)),
                                              const SizedBox(width: 4),
                                              SizedBox(
                                                width: 60,
                                                height: 32,
                                                child: TextField(
                                                  controller: feeController,
                                                  keyboardType: TextInputType.number,
                                                  style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor),
                                                  decoration: const InputDecoration(
                                                    contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                    border: OutlineInputBorder(),
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              if (upiRequested) ...[
                                                ElevatedButton(
                                                  onPressed: () {
                                                    final feeVal = double.tryParse(feeController.text) ?? 250.0;
                                                    _showUpiQrCodeDialog(context, db, p, feeVal);
                                                  },
                                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white, elevation: 0),
                                                  child: const Text("Show QR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                                ),
                                                const SizedBox(width: 6),
                                                ElevatedButton(
                                                  onPressed: () async {
                                                    final feeVal = double.tryParse(feeController.text) ?? 250.0;
                                                    await db.confirmManualPayment(p.id, feeVal, 'upi');
                                                    await PdfService.generateAndPrintInvoice(
                                                      patientName: p.name,
                                                      doctorName: p.doctorName ?? "General Physician",
                                                      amount: feeVal,
                                                      paymentMethod: "upi",
                                                      token: p.token ?? "T-N/A",
                                                      reason: p.issue,
                                                    );
                                                  },
                                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, elevation: 0),
                                                  child: const Text("Confirm Paid", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                                ),
                                              ] else ...[
                                                DropdownButton<String>(
                                                  value: selectedMethod,
                                                  style: const TextStyle(color: AppTheme.textPrimaryColor, fontSize: 13),
                                                  items: const [
                                                    DropdownMenuItem(value: "cash", child: Text("Cash")),
                                                    DropdownMenuItem(value: "card", child: Text("Card")),
                                                    DropdownMenuItem(value: "upi", child: Text("UPI")),
                                                  ],
                                                  onChanged: (val) {
                                                    setState(() {
                                                      _selectedPaymentMethods[p.id] = val!;
                                                    });
                                                  },
                                                ),
                                                const SizedBox(width: 8),
                                                ElevatedButton(
                                                  onPressed: () async {
                                                    final feeVal = double.tryParse(feeController.text) ?? 250.0;
                                                    if (selectedMethod == 'upi') {
                                                      await db.requestUpiPayment(p.id, feeVal);
                                                      if (context.mounted) {
                                                        _showUpiQrCodeDialog(context, db, p, feeVal);
                                                      }
                                                    } else {
                                                      await db.confirmManualPayment(p.id, feeVal, selectedMethod);
                                                      await PdfService.generateAndPrintInvoice(
                                                        patientName: p.name,
                                                        doctorName: p.doctorName ?? "General Physician",
                                                        amount: feeVal,
                                                        paymentMethod: selectedMethod,
                                                        token: p.token ?? "T-N/A",
                                                        reason: p.issue,
                                                      );
                                                    }
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: selectedMethod == 'upi' ? const Color(0xFF4F46E5) : AppTheme.primaryColor,
                                                    foregroundColor: Colors.white,
                                                    elevation: 0,
                                                  ),
                                                  child: Text(selectedMethod == 'upi' ? "Request UPI" : "Confirm", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ] else ...[
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              TextButton(
                                                onPressed: () async {
                                                  await FirebaseFirestore.instance.doc("artifacts/${db.appId}/public/data/queue/${p.id}").update({'status': 'cancelled'});
                                                },
                                                style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
                                                child: const Text("Cancel Visit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                              ),
                                              const SizedBox(width: 8),
                                              if (p.status == 'waiting')
                                                ElevatedButton(
                                                  onPressed: () async {
                                                    await FirebaseFirestore.instance.doc("artifacts/${db.appId}/public/data/queue/${p.id}").update({
                                                      'status': 'calling',
                                                      'calledAt': FieldValue.serverTimestamp(),
                                                    });
                                                  },
                                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, elevation: 0),
                                                  child: const Text("Call Next", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                                ),
                                              if (isCalling)
                                                ElevatedButton(
                                                  onPressed: () async {
                                                    await FirebaseFirestore.instance.doc("artifacts/${db.appId}/public/data/queue/${p.id}").update({
                                                      'status': 'pending_payment',
                                                      'consultationCompletedAt': FieldValue.serverTimestamp(),
                                                    });
                                                  },
                                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white, elevation: 0),
                                                  child: const Text("Complete Consult", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                                ),
                                            ],
                                          )
                                        ],
                                      ],
                                    ),
                                  ).animate().fadeIn(delay: (idx % 6 * 50).ms, duration: 250.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut);
                                },
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueuePill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

// --- TAB 3: BOOKINGS / APPOINTMENTS ---
class _AdminAppointmentsTab extends StatefulWidget {
  const _AdminAppointmentsTab({Key? key}) : super(key: key);

  @override
  __AdminAppointmentsTabState createState() => __AdminAppointmentsTabState();
}

class __AdminAppointmentsTabState extends State<_AdminAppointmentsTab> with AutomaticKeepAliveClientMixin {
  String _activeFilter = "today";

  @override
  bool get wantKeepAlive => true;

  Widget _buildFilterPill(String label, String filterKey) {
    final bool isActive = _activeFilter == filterKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeFilter = filterKey;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? AppTheme.primaryColor : Colors.black.withOpacity(0.05)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppTheme.textSecondaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final db = Provider.of<DbService>(context);
    final format = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text("Appointments Board"),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                _buildFilterPill("Today", "today"),
                _buildFilterPill("Tomorrow", "tomorrow"),
                _buildFilterPill("Upcoming", "upcoming"),
                _buildFilterPill("Completed", "completed"),
                _buildFilterPill("Cancelled", "cancelled"),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<List<AppointmentItem>>(
              stream: db.streamClinicAppointments(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final list = snap.data ?? [];
                final now = DateTime.now();
                final todayDate = DateTime(now.year, now.month, now.day);
                final tomorrowDate = todayDate.add(const Duration(days: 1));

                var filtered = list.where((appt) {
                  final apptDate = DateTime(appt.appointmentAt.year, appt.appointmentAt.month, appt.appointmentAt.day);

                  if (_activeFilter == "today") {
                    return apptDate.isAtSameMomentAs(todayDate) && appt.status != 'declined' && appt.status != 'completed';
                  } else if (_activeFilter == "tomorrow") {
                    return apptDate.isAtSameMomentAs(tomorrowDate) && appt.status != 'declined' && appt.status != 'completed';
                  } else if (_activeFilter == "upcoming") {
                    return apptDate.isAfter(tomorrowDate) && appt.status != 'declined' && appt.status != 'completed';
                  } else if (_activeFilter == "completed") {
                    return appt.status == 'completed' || appt.status == 'checked_in';
                  } else {
                    return appt.status == 'declined' || appt.status == 'cancelled';
                  }
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy_rounded, size: 64, color: AppTheme.textSecondaryColor.withOpacity(0.3)),
                        const SizedBox(height: 12),
                        Text(
                          "No appointments found.",
                          style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, idx) {
                    final appt = filtered[idx];
                    final dateStr = format.format(appt.appointmentAt);

                    Color statusColor = Colors.grey;
                    if (appt.status == 'pending') statusColor = Colors.orange;
                    if (appt.status == 'confirmed') statusColor = AppTheme.primaryColor;
                    if (appt.status == 'checked_in') statusColor = Colors.cyan;
                    if (appt.status == 'completed') statusColor = Colors.green;
                    if (appt.status == 'declined') statusColor = AppTheme.errorColor;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black.withOpacity(0.03)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.01),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(appt.patientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimaryColor)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: statusColor.withOpacity(0.2)),
                                ),
                                child: Text(appt.status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.medical_services_outlined, size: 14, color: AppTheme.textSecondaryColor),
                              const SizedBox(width: 6),
                              Text("Doctor: Dr. ${appt.doctorName}", style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 14, color: AppTheme.textSecondaryColor),
                              const SizedBox(width: 6),
                              Text(dateStr, style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12)),
                            ],
                          ),
                          if (appt.reason.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text("Note: ${appt.reason}", style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12, fontStyle: FontStyle.italic)),
                          ],

                          if (appt.status == 'pending' || appt.status == 'confirmed') ...[
                            const SizedBox(height: 12),
                            const Divider(height: 10),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (appt.status == 'pending') ...[
                                  TextButton(
                                    onPressed: () async {
                                      await db.updateAppointmentStatus(appt.id, 'declined');
                                    },
                                    style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
                                    child: const Text("Decline", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () async {
                                      await db.updateAppointmentStatus(appt.id, 'confirmed');
                                    },
                                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, elevation: 0),
                                    child: const Text("Confirm", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                ],
                                if (appt.status == 'confirmed') ...[
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      await db.checkInAppointment(
                                        apptId: appt.id,
                                        patientId: appt.patientId,
                                        patientName: appt.patientName,
                                        doctorId: appt.doctorId,
                                        doctorName: appt.doctorName,
                                        specialty: appt.specialty,
                                        reason: appt.reason,
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text("${appt.patientName} has been checked into the queue!")),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.login, size: 14),
                                    label: const Text("Check In Patient", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, elevation: 0),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ).animate().fadeIn(delay: (idx % 6 * 50).ms, duration: 250.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut);
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

// --- TAB 4: PATIENTS DATABASE ---
class _AdminPatientsTab extends StatefulWidget {
  const _AdminPatientsTab({Key? key}) : super(key: key);

  @override
  __AdminPatientsTabState createState() => __AdminPatientsTabState();
}

class __AdminPatientsTabState extends State<_AdminPatientsTab> with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  String _searchQuery = "";

  StreamSubscription<QuerySnapshot>? _usersSubscription;
  StreamSubscription<QuerySnapshot>? _patientsSubscription;
  
  final Map<String, Map<String, dynamic>> _mergedPatients = {};
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupPatientsListeners();
  }

  void _setupPatientsListeners() {
    final db = Provider.of<DbService>(context);
    
    _usersSubscription?.cancel();
    _patientsSubscription?.cancel();
    
    _usersSubscription = FirebaseFirestore.instance
        .collection("artifacts/${db.appId}/users")
        .snapshots()
        .listen((snap) {
      _processSnapshot(snap);
    }, onError: (err) {
      debugPrint("Error listening to users: $err");
    });

    _patientsSubscription = FirebaseFirestore.instance
        .collection("artifacts/${db.appId}/public/data/patients")
        .snapshots()
        .listen((snap) {
      _processSnapshot(snap);
    }, onError: (err) {
      debugPrint("Error listening to patients: $err");
    });
  }

  void _processSnapshot(QuerySnapshot snap) {
    if (!mounted) return;
    setState(() {
      for (var change in snap.docChanges) {
        final doc = change.doc;
        final id = doc.id;
        if (change.type == DocumentChangeType.removed) {
          _mergedPatients.remove(id);
        } else {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final role = data['role'];
          if (role == 'doctor' || role == 'receptionist' || role == 'admin') {
            _mergedPatients.remove(id);
            continue;
          }

          final existing = _mergedPatients[id] ?? {};
          final merged = <String, dynamic>{
            'id': id,
            ...existing,
            ...data,
          };
          if (merged['name'] == null || merged['name'].toString().isEmpty) {
            merged['name'] = data['name'] ?? existing['name'] ?? "Unknown Patient";
          }
          if (merged['mobile'] == null || merged['mobile'].toString().isEmpty) {
            merged['mobile'] = data['mobile'] ?? existing['mobile'] ?? "";
          }
          _mergedPatients[id] = merged;
        }
      }
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _usersSubscription?.cancel();
    _patientsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _showPatientProfile(String patientId, String name) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return _PatientProfileOverlay(patientId: patientId, name: name);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final patientsList = _mergedPatients.values.where((p) {
      final name = (p['name'] ?? "").toString().toLowerCase();
      final mobile = (p['mobile'] ?? "").toString();
      if (_searchQuery.isNotEmpty) {
        return name.contains(_searchQuery) || mobile.contains(_searchQuery);
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text("Patient Registry"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search patient registry...",
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),

          Expanded(
            child: _isLoading && _mergedPatients.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : patientsList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded, size: 64, color: AppTheme.textSecondaryColor.withOpacity(0.3)),
                            const SizedBox(height: 12),
                            const Text("No patients registered.", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondaryColor)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                        itemCount: patientsList.length,
                        itemBuilder: (ctx, idx) {
                          final data = patientsList[idx];
                          final id = data['id'] ?? "";
                          final name = data['name'] ?? "Unknown Patient";
                          final age = data['age'] ?? "N/A";
                          final gender = data['gender'] ?? "N/A";
                          final mobile = data['mobile'] ?? "N/A";

                          return Card(
                            color: Colors.white,
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.black.withOpacity(0.03)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                child: const Icon(Icons.person, color: AppTheme.primaryColor),
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimaryColor)),
                              subtitle: Text("$age yrs • ${gender.toString().toUpperCase()} • $mobile", style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor)),
                              trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondaryColor),
                              onTap: () => _showPatientProfile(id, name),
                            ),
                          ).animate().fadeIn(delay: (idx % 6 * 50).ms, duration: 250.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// --- PATIENT PROFILE OVERLAY PAGE ---
class _PatientProfileOverlay extends StatefulWidget {
  final String patientId;
  final String name;

  const _PatientProfileOverlay({Key? key, required this.patientId, required this.name}) : super(key: key);

  @override
  State<_PatientProfileOverlay> createState() => _PatientProfileOverlayState();
}

class _PatientProfileOverlayState extends State<_PatientProfileOverlay> {
  final _historyController = TextEditingController();
  final _allergiesController = TextEditingController();
  bool _isSaving = false;
  Map<String, dynamic> _demographics = {};

  @override
  void initState() {
    super.initState();
    _loadMedicalHistory();
  }

  void _loadMedicalHistory() async {
    final db = Provider.of<DbService>(context, listen: false);
    final doc1 = await FirebaseFirestore.instance.doc("artifacts/${db.appId}/users/${widget.patientId}").get();
    final doc2 = await FirebaseFirestore.instance.doc("artifacts/${db.appId}/public/data/patients/${widget.patientId}").get();
    
    Map<String, dynamic> data = {};
    if (doc1.exists) data.addAll(doc1.data() ?? {});
    if (doc2.exists) data.addAll(doc2.data() ?? {});

    if (mounted) {
      setState(() {
        _historyController.text = data['medicalHistory'] ?? "";
        _allergiesController.text = data['allergies'] ?? "";
        _demographics = data;
      });
    }
  }

  void _saveDetails() async {
    final db = Provider.of<DbService>(context, listen: false);
    setState(() => _isSaving = true);
    try {
      final updates = {
        'medicalHistory': _historyController.text.trim(),
        'allergies': _allergiesController.text.trim(),
      };
      await FirebaseFirestore.instance.doc("artifacts/${db.appId}/users/${widget.patientId}").set(updates, SetOptions(merge: true));
      await FirebaseFirestore.instance.doc("artifacts/${db.appId}/public/data/patients/${widget.patientId}").set(updates, SetOptions(merge: true));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Medical information updated successfully!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DbService>(context);

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimaryColor)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Demographics & Medical Record", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black.withOpacity(0.04)),
                    ),
                    child: Column(
                      children: [
                        _buildDemoRow("Mobile", _demographics['mobile'] ?? "N/A"),
                        _buildDemoRow("Email", _demographics['email'] ?? "N/A"),
                        _buildDemoRow("Age", _demographics['age'] ?? "N/A"),
                        _buildDemoRow("DOB", _demographics['dob'] ?? "N/A"),
                        _buildDemoRow("Gender", _demographics['gender'] ?? "N/A"),
                        _buildDemoRow("Profession", _demographics['profession'] ?? "N/A"),
                        _buildDemoRow("Address", _demographics['address'] ?? "N/A"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  TextFormField(
                    controller: _historyController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor),
                    decoration: InputDecoration(
                      labelText: "Chronic Medical History (e.g. Hypertension)",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  TextFormField(
                    controller: _allergiesController,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor),
                    decoration: InputDecoration(
                      labelText: "Known Allergies (e.g. Penicillin)",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveDetails,
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, elevation: 0),
                    child: _isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white)) : const Text("Save Medical Info"),
                  ),
                  const SizedBox(height: 20),

                  const Text("Consultation & Prescription History", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),

                  StreamBuilder<List<VisitItem>>(
                    stream: db.streamPatientHistory(widget.patientId),
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final visits = snap.data ?? [];
                      if (visits.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: Text("No past consultation visits recorded.", style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12))),
                        );
                      }

                      return SizedBox(
                        height: 250,
                        child: ListView.builder(
                          itemCount: visits.length,
                          itemBuilder: (ctx, idx) {
                            final v = visits[idx];
                            final formatted = DateFormat('dd MMM yyyy').format(v.visitedAt);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: AppTheme.backgroundColor,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(formatted, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimaryColor)),
                                        Text("Dr. ${v.doctor}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.primaryColor)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text("Diagnosis: ${v.notes}", style: const TextStyle(fontSize: 12, color: AppTheme.textPrimaryColor)),
                                    if (v.patientInstructions.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text("Instructions: ${v.patientInstructions}", style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDemoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.textSecondaryColor),
            ),
          ),
          Expanded(
            child: Text(
              value.toString().isEmpty ? "N/A" : value.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimaryColor),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _historyController.dispose();
    _allergiesController.dispose();
    super.dispose();
  }
}

// --- TAB 5: CLINIC CONFIGURATION ---
class _AdminSettingsTab extends StatefulWidget {
  const _AdminSettingsTab({Key? key}) : super(key: key);

  @override
  __AdminSettingsTabState createState() => __AdminSettingsTabState();
}

class __AdminSettingsTabState extends State<_AdminSettingsTab> with AutomaticKeepAliveClientMixin {
  final _upiController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _drNameController = TextEditingController();
  bool _isSaving = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _upiController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _drNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final doc = await FirebaseFirestore.instance.doc("artifacts/${auth.appId}/public/data/clinicSettings/settings").get();
    if (doc.exists && mounted) {
      final settings = ClinicSettings.fromFirestore(doc);
      setState(() {
        _upiController.text = settings.upiId;
        _latController.text = settings.latitude.toString();
        _lngController.text = settings.longitude.toString();
        _drNameController.text = settings.doctorName;
      });
    }
  }

  Future<void> _detectLocation() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Detecting location coordinates...")));
    try {
      final pos = await AppUtils.determinePosition();
      if (mounted) {
        setState(() {
          _latController.text = pos.latitude.toStringAsFixed(6);
          _lngController.text = pos.longitude.toStringAsFixed(6);
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location locked. Click Save to apply settings.")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _saveSettings() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.doc("artifacts/${auth.appId}/public/data/clinicSettings/settings").set({
        'upiId': _upiController.text.trim(),
        'latitude': _latController.text.trim(),
        'longitude': _lngController.text.trim(),
        'doctorName': _drNameController.text.trim(),
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Settings updated successfully!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to save: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = Provider.of<AuthService>(context);

    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService.instance.localeNotifier,
      builder: (context, currentLang, _) {
        return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text("Clinic Configuration"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 120.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isSaving) const LinearProgressIndicator(color: AppTheme.primaryColor),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.03)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.qr_code_2, color: AppTheme.primaryColor, size: 28),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Clinic Check-in QR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text("Clinic Code: ${auth.clinicCode}", style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor)),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Center(
                    child: QrImageView(
                      data: auth.clinicCode,
                      version: QrVersions.auto,
                      size: 140,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: auth.clinicCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Clinic Code copied to clipboard!")),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text("Copy Code", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
                      ),
                      const SizedBox(width: 16),
                      TextButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("New clinic entry code generated!")));
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text("Regenerate", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
                      ),
                    ],
                  )
                ],
              ),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 16),

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
                  const Text("Clinic Info & Display", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _drNameController,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor),
                    decoration: InputDecoration(
                      labelText: "Display Name (Doctor or Clinic)",
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _upiController,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor),
                    decoration: InputDecoration(
                      labelText: "Merchant UPI ID (for QR payment requests)",
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 100.ms, duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 16),

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
                  const Text("Location Coordinates (Geofencing)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _latController,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor),
                          decoration: InputDecoration(
                            labelText: "Latitude",
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lngController,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor),
                          decoration: InputDecoration(
                            labelText: "Longitude",
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _detectLocation,
                    icon: const Icon(Icons.my_location, size: 16),
                    label: const Text("Detect Coordinates"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.backgroundColor,
                      foregroundColor: AppTheme.textPrimaryColor,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 38),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 20),

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
                  const Text("Administrative & Support Tools", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFEFF6FF),
                      child: Icon(Icons.people_rounded, color: Colors.blue),
                    ),
                    title: const Text("Staff Directory Management", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text("Register and manage roles for clinic personnel", style: TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffManagementScreen()));
                    },
                  ),
                  const Divider(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFECFDF5),
                      child: Icon(Icons.show_chart_rounded, color: Colors.green),
                    ),
                    title: const Text("Finance & P&L Console", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text("Review gross earnings, register expenses, and export PDFs", style: TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFinanceScreen()));
                    },
                  ),
                  const Divider(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFDF2F8),
                      child: Icon(Icons.campaign_rounded, color: Colors.pink),
                    ),
                    title: const Text("Announcements & Broadcast Center", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text("Publish global news notices and send emergency alerts", style: TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminBroadcastScreen()));
                    },
                  ),
                  const Divider(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFFF7ED),
                      child: Icon(Icons.chat_bubble_rounded, color: Colors.orange),
                    ),
                    title: const Text("Support Chatroom Desk", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text("Exchange messages and assist waiting patients", style: TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminChatListScreen()));
                    },
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 300.ms, duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _isSaving ? null : _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                  : const Text("Save Configuration Details", style: TextStyle(fontWeight: FontWeight.bold)),
            ).animate().fadeIn(delay: 350.ms, duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 24),

            // Language selector card
            ValueListenableBuilder<String>(
              valueListenable: LocalizationService.instance.localeNotifier,
              builder: (context, currentLang, _) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black.withOpacity(0.03)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.language, color: AppTheme.primaryColor),
                          const SizedBox(width: 12),
                          Text(
                            LocalizationService.instance.translate('language'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: currentLang,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: const [
                          DropdownMenuItem(value: "en", child: Text("English")),
                          DropdownMenuItem(value: "ta", child: Text("தமிழ் (Tamil)")),
                          DropdownMenuItem(value: "te", child: Text("తెలుగు (Telugu)")),
                          DropdownMenuItem(value: "hi", child: Text("हिन्दी (Hindi)")),
                          DropdownMenuItem(value: "kn", child: Text("ಕನ್ನಡ (Kannada)")),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            LocalizationService.instance.saveUserLanguage(
                              auth.currentUser!.uid,
                              val,
                              isStaff: true,
                              appId: auth.appId,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 400.ms, duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut);
              },
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.errorColor.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("Danger Zone", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.errorColor)),
                  const SizedBox(height: 8),
                  const Text("Sign out of the administrator panel. This will clear the active login session.", style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await auth.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const SplashScreen()),
                          (route) => false,
                        );
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: Text(LocalizationService.instance.translate('logout')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      side: const BorderSide(color: AppTheme.errorColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 500.ms, duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
          ],
        ),
      ),
    );
      },
    );
  }
}

// --- NEW WALK-IN PATIENT CHECK-IN DIALOG ---
class _WalkInCheckInDialog extends StatefulWidget {
  final DbService db;
  const _WalkInCheckInDialog({Key? key, required this.db}) : super(key: key);

  @override
  __WalkInCheckInDialogState createState() => __WalkInCheckInDialogState();
}

class __WalkInCheckInDialogState extends State<_WalkInCheckInDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _issueController = TextEditingController();
  final _addressController = TextEditingController();
  final _occupationController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _dobController = TextEditingController();

  int _calculatedAge = 0;
  String _selectedGender = "male";
  String? _selectedDoctorId;
  String? _selectedDoctorName;
  String? _selectedSpecialty;
  String _selectedPriority = "normal";
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _issueController.dispose();
    _addressController.dispose();
    _occupationController.dispose();
    _emergencyContactController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  void _calculateAgeFromDob(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    setState(() {
      _calculatedAge = age;
      _dobController.text = DateFormat('yyyy-MM-dd').format(dob);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      height: MediaQuery.of(context).size.height * 0.85,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("New Walk-In Registration", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 12),
              
              TextFormField(
                controller: _nameController,
                style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor),
                decoration: InputDecoration(
                  labelText: "Patient Full Name",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "Name is required" : null,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dobController,
                      readOnly: true,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor),
                      decoration: InputDecoration(
                        labelText: "Date of Birth",
                        suffixIcon: const Icon(Icons.calendar_today_rounded, size: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().subtract(const Duration(days: 365 * 30)),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          _calculateAgeFromDob(date);
                        }
                      },
                      validator: (val) => val == null || val.isEmpty ? "DOB is required" : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 80,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "Age: $_calculatedAge",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _selectedGender,
                style: const TextStyle(color: AppTheme.textPrimaryColor, fontSize: 13),
                decoration: InputDecoration(
                  labelText: "Gender",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: const [
                  DropdownMenuItem(value: "male", child: Text("Male")),
                  DropdownMenuItem(value: "female", child: Text("Female")),
                  DropdownMenuItem(value: "other", child: Text("Other")),
                ],
                onChanged: (val) => setState(() => _selectedGender = val!),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor),
                decoration: InputDecoration(
                  labelText: "10-Digit Mobile Number",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return "Mobile is required";
                  if (!RegExp(r'^\d{10}$').hasMatch(val.trim())) return "Enter exactly 10 digits";
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _addressController,
                style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor),
                decoration: InputDecoration(
                  labelText: "Residential Address",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _occupationController,
                style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor),
                decoration: InputDecoration(
                  labelText: "Occupation / Profession",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _emergencyContactController,
                style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor),
                decoration: InputDecoration(
                  labelText: "Emergency Contact Phone",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _issueController,
                style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor),
                decoration: InputDecoration(
                  labelText: "Chief Complaint / Reason for Visit",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "Reason is required" : null,
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _selectedPriority,
                style: const TextStyle(color: AppTheme.textPrimaryColor, fontSize: 13),
                decoration: InputDecoration(
                  labelText: "Clinical Priority Override",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: const [
                  DropdownMenuItem(value: "normal", child: Text("Normal")),
                  DropdownMenuItem(value: "senior_citizen", child: Text("Senior Citizen")),
                  DropdownMenuItem(value: "pregnant", child: Text("Pregnant")),
                  DropdownMenuItem(value: "emergency", child: Text("Emergency (Queue Jump)")),
                ],
                onChanged: (val) => setState(() => _selectedPriority = val!),
              ),
              const SizedBox(height: 12),

              FutureBuilder<List<Map<String, dynamic>>>(
                future: widget.db.getActiveDoctors(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final doctors = snapshot.data ?? [];
                  if (doctors.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text("No online doctors available currently.", style: TextStyle(color: AppTheme.errorColor, fontSize: 12)),
                    );
                  }
                  return DropdownButtonFormField<String>(
                    style: const TextStyle(color: AppTheme.textPrimaryColor, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: "Assign Consultant Doctor",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    value: _selectedDoctorId,
                    items: doctors.map((doc) {
                      return DropdownMenuItem<String>(
                        value: doc['id'] as String,
                        child: Text("Dr. ${doc['name']} (${doc['specialization'] ?? 'General'})"),
                      );
                    }).toList(),
                    onChanged: (val) {
                      final chosen = doctors.firstWhere((d) => d['id'] == val);
                      setState(() {
                        _selectedDoctorId = val;
                        _selectedDoctorName = chosen['name'] ?? 'Doctor';
                        _selectedSpecialty = chosen['specialization'] ?? 'General';
                      });
                    },
                    validator: (val) => val == null ? "Please assign a doctor" : null,
                  );
                },
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _isSaving ? null : () async {
                  if (!_formKey.currentState!.validate()) return;
                  setState(() => _isSaving = true);

                  try {
                    final bool isEmergency = _selectedPriority == "emergency";
                    
                    await widget.db.checkInWalkInPatient(
                      name: _nameController.text.trim(),
                      mobile: _mobileController.text.trim(),
                      issue: _issueController.text.trim(),
                      doctorId: _selectedDoctorId!,
                      doctorName: _selectedDoctorName!,
                      specialty: _selectedSpecialty!,
                      isEmergency: isEmergency,
                    );

                    final patientId = 'walkin_${DateTime.now().millisecondsSinceEpoch}';
                    final walkInData = {
                      'name': _nameController.text.trim(),
                      'mobile': _mobileController.text.trim(),
                      'dob': _dobController.text,
                      'age': _calculatedAge.toString(),
                      'gender': _selectedGender,
                      'address': _addressController.text.trim(),
                      'profession': _occupationController.text.trim(),
                      'emergencyContact': _emergencyContactController.text.trim(),
                      'role': 'patient',
                      'createdAt': FieldValue.serverTimestamp(),
                    };
                    await FirebaseFirestore.instance.doc("artifacts/${widget.db.appId}/users/$patientId").set(walkInData);
                    await FirebaseFirestore.instance.doc("artifacts/${widget.db.appId}/public/data/patients/$patientId").set(walkInData);

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Walk-in patient registered and queued successfully!")));
                    }
                  } catch (e) {
                    setState(() => _isSaving = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error checking in: $e")));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                    : const Text("Register & Check-In", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// --- STAFF MANAGEMENT OVERVIEW SCREEN ---
class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({Key? key}) : super(key: key);

  @override
  _StaffManagementScreenState createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _role = "doctor";
  bool _isSaving = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _specialtyController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _showAddStaffDialog(DbService db, AuthService auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Register Clinic Staff", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor)),
                          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 8),

                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor),
                        decoration: InputDecoration(
                          labelText: "Staff Full Name",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? "Name is required" : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _emailController,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor),
                        decoration: InputDecoration(
                          labelText: "Email Address",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? "Email is required" : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor),
                        decoration: InputDecoration(
                          labelText: "Contact Phone Number",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? "Phone number is required" : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor),
                        decoration: InputDecoration(
                          labelText: "Password credentials",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (val) => val == null || val.trim().length < 6 ? "Password must be >= 6 chars" : null,
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        value: _role,
                        style: const TextStyle(color: AppTheme.textPrimaryColor, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: "Staff Role",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: const [
                          DropdownMenuItem(value: "doctor", child: Text("Doctor / Physician")),
                          DropdownMenuItem(value: "receptionist", child: Text("Receptionist / Front Desk")),
                          DropdownMenuItem(value: "nurse", child: Text("Clinical Nurse")),
                          DropdownMenuItem(value: "assistant", child: Text("Assistant")),
                        ],
                        onChanged: (val) {
                          setModalState(() {
                            _role = val!;
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      if (_role == "doctor") ...[
                        TextFormField(
                          controller: _specialtyController,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor),
                          decoration: InputDecoration(
                            labelText: "Clinical Specialization",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      ElevatedButton(
                        onPressed: _isSaving ? null : () async {
                          if (!_formKey.currentState!.validate()) return;
                          setModalState(() {
                            _isSaving = true;
                          });

                          try {
                            FirebaseApp tempApp = await Firebase.initializeApp(
                              name: 'TempAuthApp',
                              options: Firebase.app().options,
                            );

                            FirebaseAuth tempAuth = FirebaseAuth.instanceFor(app: tempApp);
                            UserCredential creds = await tempAuth.createUserWithEmailAndPassword(
                              email: _emailController.text.trim(),
                              password: _passwordController.text.trim(),
                            );
                            final String staffUid = creds.user!.uid;
                            await tempApp.delete();

                            final dbRef = FirebaseFirestore.instance;
                            await dbRef.doc("artifacts/${auth.appId}/public/data/staff/$staffUid").set({
                              'name': _nameController.text.trim(),
                              'email': _emailController.text.trim(),
                              'phone': _phoneController.text.trim(),
                              'role': _role,
                              'specialization': _specialtyController.text.trim().isEmpty ? "General" : _specialtyController.text.trim(),
                              'isActive': true,
                              'joinedAt': FieldValue.serverTimestamp(),
                            });

                            await dbRef.doc("artifacts/${auth.appId}/users/$staffUid").set({
                              'name': _nameController.text.trim(),
                              'email': _emailController.text.trim(),
                              'role': _role,
                            });

                            setModalState(() {
                              _isSaving = false;
                            });
                            
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Staff user created successfully!")));
                              
                              _nameController.clear();
                              _emailController.clear();
                              _phoneController.clear();
                              _passwordController.clear();
                              _specialtyController.clear();
                            }
                          } catch (e) {
                            setModalState(() {
                              _isSaving = false;
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                        child: _isSaving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                            : const Text("Register Staff User"),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DbService>(context);
    final auth = Provider.of<AuthService>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text("Manage Staff Overview"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddStaffDialog(db, auth),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("artifacts/${db.appId}/public/data/staff").snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline_rounded, size: 64, color: AppTheme.textSecondaryColor.withOpacity(0.3)),
                  const SizedBox(height: 12),
                  const Text("No staff members listed.", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondaryColor)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: docs.length,
            itemBuilder: (ctx, idx) {
              final id = docs[idx].id;
              final data = docs[idx].data() as Map<String, dynamic>? ?? {};
              final name = data['name'] ?? "Anonymous";
              final phone = data['phone'] ?? "N/A";
              final role = data['role'] ?? "staff";
              final specialty = data['specialization'] ?? "N/A";
              final isActive = data['isActive'] ?? true;

              return Card(
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.black.withOpacity(0.03)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isActive ? AppTheme.primaryColor.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                        child: Text(name[0].toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? AppTheme.primaryColor : Colors.grey)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimaryColor)),
                            const SizedBox(height: 2),
                            Text("${role.toUpperCase()} • $specialty", style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.bold)),
                            Text("Phone: $phone", style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
                          ],
                        ),
                      ),
                      Switch(
                        value: isActive,
                        activeColor: AppTheme.primaryColor,
                        onChanged: (val) async {
                          await FirebaseFirestore.instance.doc("artifacts/${db.appId}/public/data/staff/$id").update({
                            'isActive': val,
                          });
                        },
                      ),
                    ],
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
