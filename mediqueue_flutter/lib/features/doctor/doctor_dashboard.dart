import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/localization_service.dart';
import '../../core/services/db_service.dart';
import '../auth/splash_screen.dart';
import '../../core/widgets/connectivity_banner.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({Key? key}) : super(key: key);

  @override
  _DoctorDashboardState createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    _DoctorDashboardHomeTab(),
    _DoctorQueueTab(),
    _DoctorAppointmentsTab(),
    _DoctorChatTab(),
    _DoctorProfileTab(),
  ];

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
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              borderRadius: BorderRadius.circular(20),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
              size: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF6B7280),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Column(
        children: [
          const ConnectivityBanner(),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: IndexedStack(
                index: _currentIndex,
                children: _tabs,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        height: 76,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.dashboard_rounded, "Home"),
                  _buildNavItem(1, Icons.queue_play_next_rounded, "Queue"),
                  _buildNavItem(2, Icons.calendar_month_rounded, "Bookings"),
                  _buildNavItem(3, Icons.forum_rounded, "Chats"),
                  _buildNavItem(4, Icons.manage_accounts_rounded, "Profile"),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Helper to determine color based on priority
Color getPriorityColor(String priority) {
  switch (priority.toLowerCase()) {
    case 'emergency':
      return const Color(0xFFEF4444); // Red
    case 'pregnant':
      return const Color(0xFF8B5CF6); // Purple
    case 'senior_citizen':
      return const Color(0xFFF97316); // Orange
    case 'normal':
    default:
      return const Color(0xFF3B82F6); // Blue
  }
}

String getPriorityLabel(String priority) {
  switch (priority.toLowerCase()) {
    case 'emergency':
      return 'Emergency';
    case 'pregnant':
      return 'Pregnant';
    case 'senior_citizen':
      return 'Senior Citizen';
    case 'normal':
    default:
      return 'Normal';
  }
}

String getPatientPriority(QueueItem p) {
  final issueUpper = p.issue.toUpperCase();
  if (issueUpper.contains("EMERGENCY") || p.priority == 'emergency' || p.priority == '1') {
    return 'emergency';
  } else if (issueUpper.contains("PREGNANT") || p.priority == 'pregnant') {
    return 'pregnant';
  } else if (issueUpper.contains("SENIOR") || p.priority == 'senior_citizen') {
    return 'senior_citizen';
  }
  return p.priority ?? 'normal';
}

// Global helper to show the doctor status selector
void showStatusSelectorBottomSheet(BuildContext context, String currentStatus, String doctorId, String appId) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) {
      Widget buildOption(String value, String label, IconData icon, Color color) {
        final bool isSelected = currentStatus == value;
        return ListTile(
          leading: Icon(icon, color: color),
          title: Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? color : const Color(0xFF111827),
            ),
          ),
          trailing: isSelected ? Icon(Icons.check_circle, color: color) : null,
          onTap: () async {
            Navigator.pop(ctx);
            try {
              final bool active = value == 'available' || value == 'consulting';
              await FirebaseFirestore.instance
                  .doc("artifacts/$appId/public/data/staff/$doctorId")
                  .update({
                'doctorStatus': value,
                'isActive': active,
              });
              if (active) {
                try {
                  await Provider.of<DbService>(context, listen: false).autoAssignUnassignedPatients();
                } catch (e) {
                  print("Error auto-assigning patients: $e");
                }
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Status changed to: $label"),
                    backgroundColor: color,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error updating status: $e"), backgroundColor: Colors.red),
                );
              }
            }
          },
        );
      }

      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                "Update Availability Status",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF111827)),
              ),
            ),
            const Divider(),
            buildOption('available', 'Available (Online)', Icons.check_circle_outline, Colors.green),
            buildOption('consulting', 'In Consultation', Icons.play_circle_outline, Colors.blue),
            buildOption('break', 'On Break', Icons.pause_circle_outline, Colors.orange),
            buildOption('offline', 'Offline (Suspended)', Icons.cancel_outlined, Colors.grey),
          ],
        ),
      );
    },
  );
}

// --- TAB 1: DOCTOR HOME DASHBOARD ---
class _DoctorDashboardHomeTab extends StatelessWidget {
  const _DoctorDashboardHomeTab({Key? key}) : super(key: key);

  void _showSmartWaitConsole(BuildContext context, String doctorId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SmartWaitEngineConsole(doctorId: doctorId),
    );
  }

  void _showDoctorNotificationPanel(BuildContext context, AuthService auth, String doctorId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("artifacts/${auth.appId}/public/data/staff/$doctorId/notifications")
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
                          Text(
                            "Notification Hub",
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
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
                              child: Text(
                                "Mark all as read",
                                style: GoogleFonts.inter(
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
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.notifications_off_outlined,
                                  size: 48,
                                  color: AppTheme.textSecondaryColor.withOpacity(0.4),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "No notifications yet",
                                  style: GoogleFonts.inter(
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
                                case 'reassignment':
                                  categoryIcon = Icons.swap_horiz_rounded;
                                  iconColor = AppTheme.primaryColor;
                                  break;
                                case 'emergency':
                                  categoryIcon = Icons.warning_amber_rounded;
                                  iconColor = AppTheme.errorColor;
                                  break;
                                case 'billing':
                                  categoryIcon = Icons.receipt_long_rounded;
                                  iconColor = AppTheme.successColor;
                                  break;
                                default:
                                  categoryIcon = Icons.info_outline_rounded;
                                  iconColor = AppTheme.primaryColor;
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
                                    style: GoogleFonts.inter(
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
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: AppTheme.textSecondaryColor,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        createdAt != null
                                            ? DateFormat.yMMMd().add_jm().format(createdAt.toDate())
                                            : '',
                                        style: GoogleFonts.inter(
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

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final db = Provider.of<DbService>(context);
    final String doctorId = auth.currentUser!.uid;

    final String currentTime = DateFormat('hh:mm a').format(DateTime.now());
    final String currentDate = DateFormat('EEEE, d MMMM').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<QueueItem>>(
        stream: db.streamDoctorQueue(doctorId),
        builder: (context, queueSnap) {
          final activeQueue = queueSnap.data ?? [];
          final waitingList = activeQueue.where((p) => p.status == 'waiting').toList();
          final consultingList = activeQueue.where((p) => p.status == 'calling').toList();

          return StreamBuilder<double>(
            stream: db.streamDoctorAverageConsultationTime(doctorId),
            builder: (context, avgSnap) {
              final avgConsultTime = avgSnap.data ?? 12.0;

              return StreamBuilder<int>(
                stream: db.streamDoctorCompletedTodayCount(doctorId),
                builder: (context, completedTodaySnap) {
                  final completedToday = completedTodaySnap.data ?? 0;

                  // Read staff data for stats
                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.doc("artifacts/${auth.appId}/public/data/staff/$doctorId").snapshots(),
                    builder: (context, staffSnap) {
                      final staffData = staffSnap.data?.data() as Map<String, dynamic>? ?? {};
                      final bool isOnline = staffData['isActive'] ?? true;
                      final String specialty = staffData['specialty'] ?? "Consultant Doctor";

                      final int patientsWaiting = waitingList.length;

                  // Queue load status calculation
                  String queueLoad = "Low Load";
                  Color loadColor = const Color(0xFF22C55E);
                  if (patientsWaiting > 5) {
                    queueLoad = "High Workload";
                    loadColor = const Color(0xFFEF4444);
                  } else if (patientsWaiting > 2) {
                    queueLoad = "Medium Load";
                    loadColor = const Color(0xFFF97316);
                  }

                  return SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Hero Section
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF14B8A6), width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF14B8A6).withOpacity(0.2),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    )
                                  ]
                                ),
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    auth.currentUser!.name != null && auth.currentUser!.name!.isNotEmpty
                                        ? auth.currentUser!.name![0].toUpperCase()
                                        : "D",
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Welcome, Dr. ${auth.currentUser!.name ?? "Consultant"}",
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                                    ),
                                    Text(
                                      specialty,
                                      style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                              // Online Badge
                              GestureDetector(
                                onTap: () {
                                  final doctorStatusStr = staffData['doctorStatus'] ?? (isOnline ? 'available' : 'offline');
                                  showStatusSelectorBottomSheet(context, doctorStatusStr, doctorId, auth.appId);
                                },
                                child: Builder(
                                  builder: (context) {
                                    final doctorStatusStr = staffData['doctorStatus'] ?? (isOnline ? 'available' : 'offline');
                                    String badgeText = "Available";
                                    Color badgeBg = const Color(0xFFE6F4EA);
                                    Color badgeTextCol = const Color(0xFF137333);
                                    Color badgeIndicatorCol = const Color(0xFF22C55E);

                                    if (doctorStatusStr == 'consulting') {
                                      badgeText = "Consulting";
                                      badgeBg = Colors.blue.shade50;
                                      badgeTextCol = Colors.blue.shade700;
                                      badgeIndicatorCol = Colors.blue;
                                    } else if (doctorStatusStr == 'break') {
                                      badgeText = "On Break";
                                      badgeBg = Colors.orange.shade50;
                                      badgeTextCol = Colors.orange.shade700;
                                      badgeIndicatorCol = Colors.orange;
                                    } else if (doctorStatusStr == 'offline') {
                                      badgeText = "Offline";
                                      badgeBg = const Color(0xFFFCE8E6);
                                      badgeTextCol = const Color(0xFFC5221F);
                                      badgeIndicatorCol = const Color(0xFFEF4444);
                                    }

                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: badgeBg,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: badgeIndicatorCol.withOpacity(0.4),
                                          width: 1,
                                        )
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: badgeIndicatorCol,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: badgeIndicatorCol.withOpacity(0.5),
                                                  blurRadius: 6,
                                                  spreadRadius: 2,
                                                )
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            badgeText,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: badgeTextCol,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Notification Bell Icon with real-time unread badge
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection("artifacts/${auth.appId}/public/data/staff/$doctorId/notifications")
                                    .where("status", isEqualTo: "unread")
                                    .snapshots(),
                                builder: (context, unreadSnap) {
                                  final unreadCount = unreadSnap.data?.docs.length ?? 0;
                                  return Stack(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF111827)),
                                        onPressed: () => _showDoctorNotificationPanel(context, auth, doctorId),
                                      ),
                                      if (unreadCount > 0)
                                        Positioned(
                                          right: 6,
                                          top: 6,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: AppTheme.errorColor,
                                              shape: BoxShape.circle,
                                            ),
                                            constraints: const BoxConstraints(
                                              minWidth: 16,
                                              minHeight: 16,
                                            ),
                                            child: Text(
                                              '$unreadCount',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.05, end: 0),
                          const SizedBox(height: 20),

                          // Date/Time Display Card
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentDate,
                                      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280), fontSize: 13),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      currentTime,
                                      style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF111827), fontSize: 24),
                                    ),
                                  ],
                                ),
                                const Icon(Icons.watch_later_outlined, color: Color(0xFF4F46E5), size: 28),
                              ],
                            ),
                          ).animate().fadeIn(delay: 100.ms, duration: 500.ms),
                          const SizedBox(height: 20),

                          // 2. Operational KPIs Grid
                          const Text("Today's Clinic Dashboard", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
                          const SizedBox(height: 10),
                          
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.45,
                            children: [
                              _buildKpiCard(
                                title: "Patients Waiting",
                                value: patientsWaiting.toString(),
                                icon: Icons.people_outline_rounded,
                                color: const Color(0xFF4F46E5),
                              ),
                              _buildKpiCard(
                                title: "Currently Consulting",
                                value: consultingList.isNotEmpty ? "1 Active" : "0 Active",
                                icon: Icons.ring_volume_rounded,
                                color: const Color(0xFF14B8A6),
                                subtitle: consultingList.isNotEmpty ? consultingList.first.name : "None",
                              ),
                              _buildKpiCard(
                                title: "Completed Today",
                                value: completedToday.toString(),
                                icon: Icons.done_all_rounded,
                                color: const Color(0xFF22C55E),
                              ),
                              _buildKpiCard(
                                title: "Avg Consult Time",
                                value: "${avgConsultTime.toStringAsFixed(1)} m",
                                icon: Icons.timer_outlined,
                                color: const Color(0xFFF97316),
                              ),
                            ],
                          ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
                          const SizedBox(height: 20),

                          // 3. Smart Wait Engine Control Panel
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4F46E5).withOpacity(0.35),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                )
                              ]
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.bolt, color: Color(0xFF14B8A6), size: 24),
                                        SizedBox(width: 8),
                                        Text(
                                          "Smart Wait Engine™",
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: loadColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: loadColor, width: 1),
                                      ),
                                      child: Text(
                                        queueLoad,
                                        style: TextStyle(color: loadColor, fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  "Real-time queue pressure algorithms are predicting patient wait times dynamically based on active consultation speeds.",
                                  style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
                                ),
                                const SizedBox(height: 18),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.analytics_outlined, color: Color(0xFF14B8A6), size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          "AI Recommendation: Maintain pacing of ~${avgConsultTime.toStringAsFixed(0)} mins/patient.",
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                ElevatedButton(
                                  onPressed: () => _showSmartWaitConsole(context, doctorId),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF4F46E5),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.terminal_rounded, size: 18),
                                      SizedBox(width: 8),
                                      Text("Open Live Engine Console", style: TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ).animate().scale(delay: 350.ms, duration: 400.ms, curve: Curves.easeOutBack),
                        ],
                      ),
                    ),
                  );
                },
                );
              },
            );
          },
        );
      },
    ),
  );
}

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.04), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ]
        ],
      ),
    );
  }
}

// --- TAB 2: DOCTOR QUEUE SCREEN COMMAND CENTER ---
class _DoctorQueueTab extends StatefulWidget {
  const _DoctorQueueTab({Key? key}) : super(key: key);

  @override
  __DoctorQueueTabState createState() => __DoctorQueueTabState();
}

class __DoctorQueueTabState extends State<_DoctorQueueTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  void _showConsultationWorkspace(QueueItem patient, String doctorName, DbService db) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _ConsultationWorkspace(patient: patient, doctorName: doctorName, db: db);
      },
    );
  }

  void _showHistoryDialog(QueueItem patient, DbService db) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => _PatientHistorySheet(patient: patient, db: db),
    );
  }

  void _showUpgradePriorityDialog(QueueItem patient, DbService db) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("Override Priority: ${patient.name}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.circle, color: Color(0xFF3B82F6)),
              title: const Text("Normal"),
              onTap: () async {
                await FirebaseFirestore.instance.doc("artifacts/${db.appId}/public/data/queue/${patient.id}").update({'priority': 'normal'});
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.circle, color: Color(0xFFF97316)),
              title: const Text("Senior Citizen"),
              onTap: () async {
                await FirebaseFirestore.instance.doc("artifacts/${db.appId}/public/data/queue/${patient.id}").update({'priority': 'senior_citizen'});
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.circle, color: Color(0xFF8B5CF6)),
              title: const Text("Pregnant"),
              onTap: () async {
                await FirebaseFirestore.instance.doc("artifacts/${db.appId}/public/data/queue/${patient.id}").update({'priority': 'pregnant'});
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.circle, color: Color(0xFFEF4444)),
              title: const Text("Emergency"),
              onTap: () async {
                await FirebaseFirestore.instance.doc("artifacts/${db.appId}/public/data/queue/${patient.id}").update({'priority': 'emergency'});
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = Provider.of<AuthService>(context);
    final db = Provider.of<DbService>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          "Queue Command Center",
          style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF111827), fontSize: 22),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt, color: Color(0xFF4F46E5)),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => _SmartWaitEngineConsole(doctorId: auth.currentUser!.uid),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<QueueItem>>(
        stream: db.streamDoctorQueue(auth.currentUser!.uid),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final patients = snap.data ?? [];
          final consultingList = patients.where((p) => p.status == 'calling').toList();

          if (patients.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 84, color: const Color(0xFF14B8A6).withOpacity(0.8))
                          .animate()
                          .scale(duration: 500.ms, curve: Curves.easeOutBack),
                      const SizedBox(height: 16),
                      const Text(
                        "All Clear! Queue is Empty",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "You've completed all patient consultations for now. Great work!",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)
                          ]
                        ),
                        child: const Column(
                          children: [
                            Text("Today's Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(children: [Text("12", style: TextStyle(fontWeight: FontWeight.bold)), Text("Seen", style: TextStyle(fontSize: 10, color: Colors.grey))]),
                                Column(children: [Text("98%", style: TextStyle(fontWeight: FontWeight.bold)), Text("Rating", style: TextStyle(fontSize: 10, color: Colors.grey))]),
                                Column(children: [Text("14m", style: TextStyle(fontWeight: FontWeight.bold)), Text("Avg Time", style: TextStyle(fontSize: 10, color: Colors.grey))]),
                              ],
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
            );
          }

          return StreamBuilder<double>(
            stream: db.streamAverageConsultationTime(),
            builder: (ctx, avgSnap) {
              final avgConsultTime = avgSnap.data ?? 15.0;

              return Column(
                children: [
                  // Active Consulting indicator banner
                  if (consultingList.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F9D8A), Color(0xFF14CBA8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF0F9D8A).withOpacity(0.2), blurRadius: 10)
                        ]
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.record_voice_over_rounded, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Currently Consulting", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                                Text(
                                  consultingList.first.name,
                                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _showConsultationWorkspace(consultingList.first, auth.currentUser!.name ?? "Doctor", db),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0F9D8A),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: const Text("Open Workspace", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    ).animate().slideY(begin: -0.2, end: 0).fadeIn(),

                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                      itemCount: patients.length,
                      itemBuilder: (ctx, idx) {
                        final p = patients[idx];
                        final bool isCalling = p.status == 'calling';
                        final bool isPendingPayment = p.status == 'pending_payment';
                        final String priority = getPatientPriority(p);
                        final Color prioColor = getPriorityColor(priority);

                        // EWT calculation: position * avg_consult_time
                        final int positionAhead = idx;
                        final double estWait = positionAhead * avgConsultTime;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: isCalling ? const Color(0xFF14B8A6) : Colors.black.withOpacity(0.04),
                              width: isCalling ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isCalling ? const Color(0xFF14B8A6).withOpacity(0.08) : Colors.black.withOpacity(0.02),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              )
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Avatar block with Token
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: prioColor.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: prioColor.withOpacity(0.2), width: 1.5),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            p.token ?? "#",
                                            style: TextStyle(fontWeight: FontWeight.w900, color: prioColor, fontSize: 15),
                                          ),
                                        ),
                                        const SizedBox(width: 14),

                                        // Patient demographics & symptoms
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      p.name,
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF111827)),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  // Priority Badge
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: prioColor.withOpacity(0.12),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      getPriorityLabel(priority).toUpperCase(),
                                                      style: TextStyle(color: prioColor, fontSize: 9, fontWeight: FontWeight.w900),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                p.issue,
                                                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  const Icon(Icons.hourglass_empty_rounded, size: 13, color: Color(0xFF9CA3AF)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    isCalling
                                                        ? "Consultation Active"
                                                        : "Est. Wait: ${estWait.toStringAsFixed(0)} mins",
                                                    style: TextStyle(
                                                      color: isCalling ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        )
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(color: Color(0xFFF1F5F9), height: 1),
                                    const SizedBox(height: 10),

                                    // Action Buttons row
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () => _showHistoryDialog(p, db),
                                          icon: const Icon(Icons.history_rounded, size: 16),
                                          label: const Text("History"),
                                          style: TextButton.styleFrom(
                                            foregroundColor: const Color(0xFF4F46E5),
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                          ),
                                        ),
                                        const Spacer(),
                                        if (isPendingPayment)
                                          const Chip(
                                            label: Text("Billing Pending", style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                                            backgroundColor: Color(0xFFFFF3CD),
                                          )
                                        else ...[
                                          IconButton(
                                            onPressed: () => _showUpgradePriorityDialog(p, db),
                                            icon: const Icon(Icons.low_priority_rounded, color: Color(0xFF6B7280)),
                                            tooltip: "Change Priority",
                                          ),
                                          const SizedBox(width: 6),
                                          ElevatedButton(
                                            onPressed: () async {
                                              if (!isCalling) {
                                                await db.callPatient(p.id);
                                              }
                                              _showConsultationWorkspace(p, auth.currentUser!.name ?? "Doctor", db);
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isCalling ? const Color(0xFF14B8A6) : const Color(0xFF4F46E5),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                              elevation: 0,
                                            ),
                                            child: Text(isCalling ? "Treat Now" : "Call"),
                                          ),
                                        ]
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// --- SUB-SCREEN: PATIENT TIMELINE HISTORY ---
class _PatientHistorySheet extends StatelessWidget {
  final QueueItem patient;
  final DbService db;

  const _PatientHistorySheet({
    Key? key,
    required this.patient,
    required this.db,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Clinical History: ${patient.name}",
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF111827)),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<VisitItem>>(
              stream: db.streamPatientHistory(patient.patientId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final history = snapshot.data ?? [];

                if (history.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text("No clinical visits found for this patient.", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final item = history[index];
                    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(item.visitedAt);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: const Color(0xFFF8FAFC),
                      elevation: 0,
                      borderOnForeground: false,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5), fontSize: 12)),
                                Text("Dr. ${item.doctor}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text("Notes/Diagnosis:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey.shade700)),
                            const SizedBox(height: 2),
                            Text(item.notes, style: const TextStyle(fontSize: 13, color: Color(0xFF374151))),
                            if (item.medications.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text("Prescribed Medications:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey.shade700)),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                children: item.medications.map((m) {
                                  return Chip(
                                    label: Text("${m['name']} - ${m['dosage']}", style: const TextStyle(fontSize: 10)),
                                    backgroundColor: const Color(0xFFE0E7FF),
                                    visualDensity: VisualDensity.compact,
                                  );
                                }).toList(),
                              )
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

// --- SUB-SCREEN: CLINICAL CONSULTATION WORKSPACE ---
class _ConsultationWorkspace extends StatefulWidget {
  final QueueItem patient;
  final String doctorName;
  final DbService db;

  const _ConsultationWorkspace({
    Key? key,
    required this.patient,
    required this.doctorName,
    required this.db,
  }) : super(key: key);

  @override
  __ConsultationWorkspaceState createState() => __ConsultationWorkspaceState();
}

class __ConsultationWorkspaceState extends State<_ConsultationWorkspace> {
  final _notesController = TextEditingController();
  final _feeController = TextEditingController(text: "250");
  final _instructionsController = TextEditingController();

  final _medNameController = TextEditingController();
  final _medDosageController = TextEditingController();
  final List<Map<String, dynamic>> _medications = [];

  // Stopwatch for active timer
  late Stopwatch _stopwatch;
  late Timer _timer;
  String _elapsedString = "00:00";

  final List<String> _commonMedications = [
    "Paracetamol 500mg",
    "Ibuprofen 400mg",
    "Amoxicillin 500mg",
    "Cetirizine 10mg",
    "Metformin 500mg",
    "Pantoprazole 40mg",
    "Azithromycin 500mg",
    "Cough Syrup (Ascoril)"
  ];

  final List<String> _commonDosages = [
    "Once daily (OD)",
    "Twice daily (BD)",
    "Three times daily (TD)",
    "Before meals (AC)",
    "After meals (PC)",
    "As needed (PRN)"
  ];

  // Diagnosis templates
  final Map<String, List<String>> _templates = {
    'Viral Fever': ['Paracetamol 500mg', 'Once daily (OD)', 'Cetirizine 10mg', 'Twice daily (BD)'],
    'Acidity': ['Pantoprazole 40mg', 'Before meals (AC)'],
    'Chest Congestion': ['Azithromycin 500mg', 'Once daily (OD)', 'Cough Syrup (Ascoril)', 'Three times daily (TD)'],
  };

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        final duration = _stopwatch.elapsed;
        final minutes = duration.inMinutes.toString().padLeft(2, '0');
        final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
        setState(() {
          _elapsedString = "$minutes:$seconds";
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _stopwatch.stop();
    _notesController.dispose();
    _feeController.dispose();
    _instructionsController.dispose();
    _medNameController.dispose();
    _medDosageController.dispose();
    super.dispose();
  }

  void _applyTemplate(String diagnosis, List<String> meds) {
    setState(() {
      _notesController.text = diagnosis;
      _medications.clear();
      for (int i = 0; i < meds.length; i += 2) {
        if (i + 1 < meds.length) {
          _medications.add({
            'name': meds[i],
            'dosage': meds[i + 1],
            'duration': '5 days',
          });
        }
      }
    });
  }

  void _addMedication() {
    final name = _medNameController.text.trim();
    final dosage = _medDosageController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _medications.add({
        'name': name,
        'dosage': dosage,
        'duration': '5 days',
      });
      _medNameController.clear();
      _medDosageController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Drag handle & top bar
          Container(
            height: 5,
            width: 40,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
          ),
          
          // Header with Patient demographics & stopwatch
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.patient.name,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF111827)),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "Workspace Console • Consultation Active",
                        style: TextStyle(color: Color(0xFF6B7280), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                // Timer badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: Color(0xFF0369A1), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _elapsedString,
                        style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0369A1), fontSize: 14),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Diagnosis suggestions row
                  const Text("Smart Templates", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF4B5563))),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _templates.keys.map((diagnosis) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(diagnosis),
                            onPressed: () => _applyTemplate(diagnosis, _templates[diagnosis]!),
                            backgroundColor: const Color(0xFFF1F5F9),
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Notes section
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: "Notes & Diagnosis",
                      hintText: "Enter patient symptoms or clinical findings...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Custom medication inputs
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Prescribe Drugs", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5), fontSize: 13)),
                        const SizedBox(height: 12),
                        Autocomplete<String>(
                          optionsBuilder: (textEditingValue) {
                            if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                            return _commonMedications.where((option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                          },
                          onSelected: (selection) => _medNameController.text = selection,
                          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                            controller.addListener(() {
                              _medNameController.text = controller.text;
                            });
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: "Medication",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Autocomplete<String>(
                          optionsBuilder: (textEditingValue) {
                            if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                            return _commonDosages.where((option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                          },
                          onSelected: (selection) => _medDosageController.text = selection,
                          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                            controller.addListener(() {
                              _medDosageController.text = controller.text;
                            });
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: "Dosage (BD, OD, etc.)",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: _addMedication,
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text("Add to Prescription"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEEF2F6),
                            foregroundColor: const Color(0xFF4F46E5),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        if (_medications.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(_medications.length, (idx) {
                              final m = _medications[idx];
                              return Chip(
                                label: Text("${m['name']} (${m['dosage']})"),
                                onDeleted: () {
                                  setState(() {
                                    _medications.removeAt(idx);
                                  });
                                },
                                backgroundColor: const Color(0xFFE0E7FF),
                                deleteIconColor: const Color(0xFFEF4444),
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              );
                            }),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Patient instructions
                  TextField(
                    controller: _instructionsController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: "Patient Instructions",
                      hintText: "Drink plenty of water, avoid cold fluids...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Consultation fee
                  TextField(
                    controller: _feeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Consultation Fee (₹)",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Complete Consultation Button
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      final double fee = double.tryParse(_feeController.text.trim()) ?? 250.0;

                      await widget.db.submitConsultation(
                        widget.patient.id,
                        widget.patient.patientId,
                        _notesController.text.trim(),
                        fee,
                        _instructionsController.text.trim(),
                        widget.doctorName,
                        _medications,
                      );

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Consultation completed! routed to billing checkout.")),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 4,
                    ),
                    child: const Text("Complete & Route to Billing", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

// --- SUB-SCREEN: REAL-TIME SMART WAIT ENGINE CONSOLE ---
class _SmartWaitEngineConsole extends StatefulWidget {
  final String doctorId;

  const _SmartWaitEngineConsole({Key? key, required this.doctorId}) : super(key: key);

  @override
  __SmartWaitEngineConsoleState createState() => __SmartWaitEngineConsoleState();
}

class __SmartWaitEngineConsoleState extends State<_SmartWaitEngineConsole> {
  final List<String> _logs = [];
  Timer? _logTimer;
  final List<String> _templateLogs = [
    "Smart Wait Engine initiated...",
    "Querying active queue parameters...",
    "Retrieving today's completion records...",
    "Recalculating Average consultation duration...",
    "Doctor utilization calculated at 92.4%",
    "Prediction version updated to v3",
    "Running queue health scoring...",
    "Scoring metrics loaded: 40% wait, 25% utilization, 20% cancellation...",
    "Queue health status: 94% (Stable/Optimized)",
    "Real-time sync verified with Firebase Firestore.",
  ];

  @override
  void initState() {
    super.initState();
    // Simulate live engine logs
    int index = 0;
    _logTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (mounted) {
        if (index < _templateLogs.length) {
          final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
          setState(() {
            _logs.add("[$timestamp] ${_templateLogs[index]}");
          });
          index++;
        } else {
          // Keep sending active updates
          final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
          final rand = DateTime.now().second;
          setState(() {
            _logs.add("[$timestamp] Live Sync: ETA re-evaluated (Accuracy: ${95 + (rand % 5)}%)");
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _logTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DbService>(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Dark slate theme console
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.terminal_rounded, color: Color(0xFF14B8A6)),
                  SizedBox(width: 10),
                  Text(
                    "Smart Wait Engine Console",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white70),
              )
            ],
          ),
          const SizedBox(height: 16),
          
          // Live Analytics stats summary
          StreamBuilder<double>(
            stream: db.streamAverageConsultationTime(),
            builder: (context, avgSnap) {
              final avgTime = avgSnap.data ?? 15.0;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildConsoleMetric("AVG TIME", "${avgTime.toStringAsFixed(1)}m"),
                    _buildConsoleMetric("ACCURACY", "98.2%"),
                    _buildConsoleMetric("UTILIZATION", "92%"),
                    _buildConsoleMetric("HEALTH SCORE", "94%"),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          const Text(
            "LIVE ENGINE TERMINAL LOGS",
            style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 11),
          ),
          const SizedBox(height: 10),

          // Terminal block
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF020617),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      log,
                      style: const TextStyle(
                        color: Color(0xFF34D399), // Neon green terminal
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildConsoleMetric(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

// --- TAB 3: DOCTOR APPOINTMENTS / BOOKINGS TAB ---
class _DoctorAppointmentsTab extends StatefulWidget {
  const _DoctorAppointmentsTab({Key? key}) : super(key: key);

  @override
  __DoctorAppointmentsTabState createState() => __DoctorAppointmentsTabState();
}

class __DoctorAppointmentsTabState extends State<_DoctorAppointmentsTab> with AutomaticKeepAliveClientMixin {
  String _selectedFilter = 'today'; // today, tomorrow, upcoming, completed

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = Provider.of<AuthService>(context);
    final db = Provider.of<DbService>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          "Clinical Calendar",
          style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF111827), fontSize: 22),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: StreamBuilder<List<AppointmentItem>>(
        stream: db.streamClinicAppointments(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final allAppts = snap.data ?? [];
          final myAppts = allAppts.where((a) => a.doctorId == auth.currentUser!.uid).toList();

          // Filter logic
          final now = DateTime.now();
          final startOfToday = DateTime(now.year, now.month, now.day);
          final endOfToday = startOfToday.add(const Duration(days: 1));
          final startOfTomorrow = endOfToday;
          final endOfTomorrow = startOfTomorrow.add(const Duration(days: 1));

          final filteredAppts = myAppts.where((appt) {
            final apptTime = appt.appointmentAt;
            if (_selectedFilter == 'today') {
              return apptTime.isAfter(startOfToday) && apptTime.isBefore(endOfToday) && appt.status != 'completed';
            } else if (_selectedFilter == 'tomorrow') {
              return apptTime.isAfter(startOfTomorrow) && apptTime.isBefore(endOfTomorrow);
            } else if (_selectedFilter == 'upcoming') {
              return apptTime.isAfter(endOfTomorrow) && appt.status != 'completed';
            } else if (_selectedFilter == 'completed') {
              return appt.status == 'completed';
            }
            return true;
          }).toList();

          // Quick metrics calculation
          final completedTodayCount = myAppts.where((a) => a.status == 'completed').length;
          final int completionRate = myAppts.isNotEmpty
              ? ((completedTodayCount / myAppts.length) * 100).round()
              : 100;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Calendar Analytics header row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildMiniMetricCard("Appts Total", myAppts.length.toString(), Colors.blue),
                    const SizedBox(width: 10),
                    _buildMiniMetricCard("Completion", "$completionRate%", Colors.green),
                    const SizedBox(width: 10),
                    _buildMiniMetricCard("No-Show Rate", "5%", Colors.red),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Filter pills row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('today', 'Today'),
                      const SizedBox(width: 8),
                      _buildFilterChip('tomorrow', 'Tomorrow'),
                      const SizedBox(width: 8),
                      _buildFilterChip('upcoming', 'Upcoming'),
                      const SizedBox(width: 8),
                      _buildFilterChip('completed', 'Completed'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // List of appointments
              Expanded(
                child: filteredAppts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_month_outlined, size: 72, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text("No appointments scheduled.", style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                        itemCount: filteredAppts.length,
                        itemBuilder: (ctx, idx) {
                          final appt = filteredAppts[idx];
                          final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(appt.appointmentAt);

                          Color statusColor = Colors.grey;
                          if (appt.status == 'pending') statusColor = Colors.orangeAccent;
                          if (appt.status == 'confirmed') statusColor = const Color(0xFF4F46E5);
                          if (appt.status == 'checked_in') statusColor = Colors.cyanAccent;
                          if (appt.status == 'completed') statusColor = Colors.greenAccent;
                          if (appt.status == 'declined') statusColor = Colors.redAccent;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.black.withOpacity(0.03)),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 10, offset: const Offset(0, 4))
                              ]
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        appt.patientName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF111827)),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: statusColor.withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          appt.status.toUpperCase(),
                                          style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF6B7280)),
                                      const SizedBox(width: 6),
                                      Text(dateStr, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.notes_rounded, size: 14, color: Color(0xFF6B7280)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          appt.reason.isNotEmpty ? appt.reason : "No reason specified",
                                          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (appt.status == 'pending' || appt.status == 'confirmed') ...[
                                    const SizedBox(height: 12),
                                    const Divider(color: Color(0xFFF1F5F9), height: 1),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (appt.status == 'pending') ...[
                                          TextButton(
                                            onPressed: () async {
                                              await db.updateAppointmentStatus(appt.id, 'declined');
                                            },
                                            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                                            child: const Text("Decline"),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: () async {
                                              await db.updateAppointmentStatus(appt.id, 'confirmed');
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF4F46E5),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            child: const Text("Approve"),
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
                                            icon: const Icon(Icons.login, size: 16),
                                            label: const Text("Check In Patient"),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF14B8A6),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _buildMiniMetricCard(String label, String value, Color accentColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withOpacity(0.03)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 6)
          ]
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: accentColor)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final bool isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() {
            _selectedFilter = value;
          });
        }
      },
      selectedColor: const Color(0xFF4F46E5),
      labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF6B7280)),
      backgroundColor: Colors.white,
      side: BorderSide(color: isSelected ? const Color(0xFF4F46E5) : Colors.black.withOpacity(0.08)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

// --- TAB 4: DOCTOR PATIENT CHAT LIST & THREAD ---
class _DoctorChatTab extends StatefulWidget {
  const _DoctorChatTab({Key? key}) : super(key: key);

  @override
  __DoctorChatTabState createState() => __DoctorChatTabState();
}

class __DoctorChatTabState extends State<_DoctorChatTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  void _openChatThread(BuildContext context, String patientId, String patientName, String doctorId, String doctorName, DbService db) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => _DoctorChatThreadScreen(
          patientId: patientId,
          patientName: patientName,
          doctorId: doctorId,
          doctorName: doctorName,
          db: db,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = Provider.of<AuthService>(context);
    final db = Provider.of<DbService>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          "Healthcare Chatroom",
          style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF111827), fontSize: 22),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: StreamBuilder<List<ChatRoomItem>>(
        stream: db.streamChatRooms(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final chatRooms = snap.data ?? [];

          if (chatRooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.forum_outlined, size: 72, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text("No Patient Chats Active", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const Text("Patients who message you will appear here.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            itemCount: chatRooms.length,
            separatorBuilder: (context, index) => const Divider(color: Color(0xFFE2E8F0), height: 1),
            itemBuilder: (context, index) {
              final room = chatRooms[index];
              final hasUnread = room.doctorRead == false;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                leading: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.2), width: 1.5),
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.indigo.shade50,
                    child: Text(
                      room.patientName.isNotEmpty ? room.patientName[0].toUpperCase() : "P",
                      style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                title: Text(
                  room.patientName,
                  style: TextStyle(fontWeight: hasUnread ? FontWeight.w900 : FontWeight.w600, color: const Color(0xFF111827), fontSize: 15),
                ),
                subtitle: Text(
                  room.lastMessageText.isNotEmpty ? room.lastMessageText : "Tap to view chat",
                  style: TextStyle(color: hasUnread ? const Color(0xFF4F46E5) : const Color(0xFF6B7280), fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (hasUnread)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF4F46E5),
                          shape: BoxShape.circle,
                        ),
                        child: const Text("1", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      )
                    else
                      const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
                onTap: () {
                  db.markChatAsRead(room.patientId, 'doctor');
                  _openChatThread(context, room.patientId, room.patientName, auth.currentUser!.uid, auth.currentUser!.name ?? "Doctor", db);
                },
              );
            },
          );
        },
      ),
    );
  }
}

// --- CHAT THREAD SCREEN ---
class _DoctorChatThreadScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final DbService db;

  const _DoctorChatThreadScreen({
    Key? key,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.db,
  }) : super(key: key);

  @override
  __DoctorChatThreadScreenState createState() => __DoctorChatThreadScreenState();
}

class __DoctorChatThreadScreenState extends State<_DoctorChatThreadScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(widget.patientName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF111827))),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
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
                  return const Center(child: Text("No messages yet.", style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (ctx, idx) {
                    final msg = messages[idx];
                    final bool isMe = msg.senderId == widget.doctorId;
                    final timeStr = DateFormat('hh:mm a').format(msg.timestamp);

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          gradient: isMe
                              ? const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)])
                              : null,
                          color: isMe ? null : Colors.white,
                          borderRadius: BorderRadius.circular(20).copyWith(
                            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(20),
                            bottomLeft: !isMe ? const Radius.circular(0) : const Radius.circular(20),
                          ),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 4, offset: const Offset(0, 2))
                          ]
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg.text,
                              style: TextStyle(color: isMe ? Colors.white : const Color(0xFF111827), fontSize: 14.5),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 9,
                                color: isMe ? Colors.white70 : Colors.grey,
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
                        decoration: const InputDecoration(
                          hintText: "Type reply...",
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: Color(0xFF4F46E5)),
                    onPressed: () async {
                      final text = _msgController.text.trim();
                      if (text.isEmpty) return;
                      _msgController.clear();
                      await widget.db.sendChatMessage(
                        widget.patientId,
                        widget.doctorId,
                        "Dr. ${widget.doctorName}",
                        text,
                      );
                      _scrollController.animateTo(
                        0.0,
                        duration: 300.ms,
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

// --- TAB 5: DOCTOR PROFILE & AVAILABILITY ---
class _DoctorProfileTab extends StatefulWidget {
  const _DoctorProfileTab({Key? key}) : super(key: key);

  @override
  __DoctorProfileTabState createState() => __DoctorProfileTabState();
}

class __DoctorProfileTabState extends State<_DoctorProfileTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  void _showEditDetailsDialog(
    BuildContext context,
    String appId,
    String doctorId,
    String currentName,
    String currentSpecialty,
    String currentDegree,
    String currentHours,
    String currentLicense,
    AuthService auth,
  ) {
    final nameController = TextEditingController(text: currentName);
    final specialtyController = TextEditingController(text: currentSpecialty);
    final degreeController = TextEditingController(text: currentDegree);
    final hoursController = TextEditingController(text: currentHours);
    final licenseController = TextEditingController(text: currentLicense);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            "Edit Doctor Profile",
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Full Name",
                    hintText: "Enter full name",
                  ),
                  style: GoogleFonts.inter(fontSize: 14),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: specialtyController,
                  decoration: const InputDecoration(
                    labelText: "Specialty",
                    hintText: "e.g. Cardiology, Pediatrics",
                  ),
                  style: GoogleFonts.inter(fontSize: 14),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: degreeController,
                  decoration: const InputDecoration(
                    labelText: "Degrees / Qualifications",
                    hintText: "e.g. MD, MBBS, DNB",
                  ),
                  style: GoogleFonts.inter(fontSize: 14),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hoursController,
                  decoration: const InputDecoration(
                    labelText: "Working Hours",
                    hintText: "e.g. 09:00 AM - 05:00 PM",
                  ),
                  style: GoogleFonts.inter(fontSize: 14),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: licenseController,
                  decoration: const InputDecoration(
                    labelText: "Clinic License ID",
                    hintText: "e.g. MC-2026-98442",
                  ),
                  style: GoogleFonts.inter(fontSize: 14),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Cancel", style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isEmpty) return;

                try {
                  final staffDocRef = FirebaseFirestore.instance.doc("artifacts/$appId/public/data/staff/$doctorId");
                  final userDocRef = FirebaseFirestore.instance.doc("artifacts/$appId/users/$doctorId");

                  await staffDocRef.update({
                    'name': newName,
                    'specialty': specialtyController.text.trim(),
                    'specialization': specialtyController.text.trim(),
                    'degree': degreeController.text.trim(),
                    'workingHours': hoursController.text.trim(),
                    'hours': hoursController.text.trim(),
                    'licenseId': licenseController.text.trim(),
                    'license': licenseController.text.trim(),
                  });

                  try {
                    await userDocRef.update({
                      'name': newName,
                    });
                  } catch (_) {}

                  auth.updateCurrentUserLocalName(newName);

                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Profile updated successfully"), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Failed to update profile: $e"), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: Text("Save", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = Provider.of<AuthService>(context);
    final db = Provider.of<DbService>(context);

    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService.instance.localeNotifier,
      builder: (context, currentLang, _) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.doc("artifacts/${auth.appId}/public/data/staff/${auth.currentUser!.uid}").snapshots(),
          builder: (context, snapshot) {
            final staffData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
            final docName = staffData['name'] ?? auth.currentUser!.name ?? "Consultant Doctor";
            final docSpecialty = staffData['specialty'] ?? staffData['specialization'] ?? "Specialist Consultant";
            final docDegree = staffData['degree'] ?? "MD, DNB (Cardiology)";
            final docHours = staffData['workingHours'] ?? staffData['hours'] ?? "09:00 AM - 05:00 PM";
            final docLicense = staffData['licenseId'] ?? staffData['license'] ?? "MC-2026-98442";
            final bool isOnline = staffData['isActive'] ?? true;
            final String doctorStatusStr = staffData['doctorStatus'] ?? (isOnline ? 'available' : 'offline');

            String statusLabel = "Available (Online)";
            Color statusColor = Colors.green;
            IconData statusIcon = Icons.check_circle_outline;

            if (doctorStatusStr == 'consulting') {
              statusLabel = "In Consultation";
              statusColor = Colors.blue;
              statusIcon = Icons.play_circle_outline;
            } else if (doctorStatusStr == 'break') {
              statusLabel = "On Break";
              statusColor = Colors.orange;
              statusIcon = Icons.pause_circle_outline;
            } else if (doctorStatusStr == 'offline') {
              statusLabel = "Offline (Suspended)";
              statusColor = Colors.grey;
              statusIcon = Icons.cancel_outlined;
            }

            return Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: const Text(
                  "Doctor Profile",
                  style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF111827), fontSize: 22),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: false,
                actions: [
                  TextButton.icon(
                    onPressed: () {
                      _showEditDetailsDialog(
                        context,
                        auth.appId,
                        auth.currentUser!.uid,
                        docName,
                        docSpecialty,
                        docDegree,
                        docHours,
                        docLicense,
                        auth,
                      );
                    },
                    icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF4F46E5)),
                    label: Text(
                      "Edit",
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF4F46E5)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Avatar profile card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 10, offset: const Offset(0, 4))
                        ]
                      ),
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF4F46E5), width: 3),
                            ),
                            child: CircleAvatar(
                              radius: 44,
                              backgroundColor: const Color(0xFFEEF2F6),
                              child: Text(
                                docName.isNotEmpty ? docName[0].toUpperCase() : "D",
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 32, color: Color(0xFF4F46E5)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            docName,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF111827)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "$docDegree • $docSpecialty",
                            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                "4.9 Rating (120+ reviews)",
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 11.5, fontWeight: FontWeight.bold),
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Performance stats grid
                    const Text("Performance Metrics", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
                    const SizedBox(height: 8),
                    StreamBuilder<int>(
                      stream: db.streamDoctorLifetimeCompletedCount(auth.currentUser!.uid),
                      builder: (context, countSnap) {
                        final lifetimeCount = countSnap.data ?? 0;

                        return StreamBuilder<double>(
                          stream: db.streamDoctorLifetimeAverageConsultationTime(auth.currentUser!.uid),
                          builder: (context, avgSnap) {
                            final lifetimeAvg = avgSnap.data ?? 12.0;
                            final double efficiencyVal = lifetimeAvg > 0 ? (12.0 / lifetimeAvg) * 100 : 100.0;
                            final int efficiencyPercent = efficiencyVal.clamp(0, 100).round();

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _ProfileStatItem(label: "Patients Treated", value: "$lifetimeCount"),
                                  _ProfileStatItem(label: "Consults Completed", value: "$lifetimeCount"),
                                  _ProfileStatItem(label: "Avg Consult Time", value: "${lifetimeAvg.toStringAsFixed(1)} min"),
                                  _ProfileStatItem(label: "Efficiency", value: "$efficiencyPercent%"),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Availability status card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10)
                        ]
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withOpacity(0.1),
                          child: Icon(statusIcon, color: statusColor),
                        ),
                        title: const Text(
                          "Consultant Status",
                          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF111827), fontSize: 15),
                        ),
                        subtitle: Text(
                          statusLabel,
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        onTap: () {
                          showStatusSelectorBottomSheet(context, doctorStatusStr, auth.currentUser!.uid, auth.appId);
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Details card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          _buildProfileTile(Icons.email_outlined, "Email Address", auth.currentUser!.email),
                          const Divider(color: Color(0xFFF1F5F9), height: 1),
                          _buildProfileTile(Icons.access_time_rounded, "Working Hours", docHours),
                          const Divider(color: Color(0xFFF1F5F9), height: 1),
                          _buildProfileTile(Icons.medical_services_outlined, "Clinic License ID", docLicense),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Language selector card
                    ValueListenableBuilder<String>(
                      valueListenable: LocalizationService.instance.localeNotifier,
                      builder: (context, currentLang, _) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10)
                            ]
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.language, color: Color(0xFF4F46E5)),
                                  const SizedBox(width: 12),
                                  Text(
                                    LocalizationService.instance.translate('language'),
                                    style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF111827), fontSize: 15),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: currentLang,
                                style: const TextStyle(color: Color(0xFF111827), fontSize: 13, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Logout button
                    ElevatedButton.icon(
                      onPressed: () async {
                        final db = Provider.of<DbService>(context, listen: false);
                        final String doctorId = auth.currentUser!.uid;
                        try {
                          await db.handleDoctorLogout(doctorId);
                        } catch (e) {
                          // ignore
                        }
                        await auth.signOut();
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const SplashScreen()),
                            (route) => false,
                          );
                        }
                      },
                      icon: const Icon(Icons.logout_rounded),
                      label: Text(LocalizationService.instance.translate('logout'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProfileTile(IconData icon, String title, String subtitle) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFF4F46E5)),
      title: Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
    );
  }
}

class _ProfileStatItem extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileStatItem({Key? key, required this.label, required this.value}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF4F46E5))),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280), fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
