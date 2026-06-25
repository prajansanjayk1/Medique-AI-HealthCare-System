import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../core/services/notification_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/db_service.dart';
import '../../core/services/pdf_service.dart';
import '../../core/services/localization_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../auth/splash_screen.dart';
import '../../core/widgets/connectivity_banner.dart';
import 'package:marquee/marquee.dart' as marquee;

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({Key? key}) : super(key: key);

  @override
  _PatientDashboardState createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  int _currentIndex = 0;
  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      _DashboardTab(onTabChange: (index) {
        setState(() {
          _currentIndex = index;
        });
      }),
      const _BookSlotTab(),
      const _HistoryTab(),
      const _ChatTab(),
      const _ProfileTab(),
      const _BroadcastTab(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupNotifications();
    });
  }

  Future<void> _setupNotifications() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final db = Provider.of<DbService>(context, listen: false);
    
    // Handle foreground/background notification tap
    NotificationService.instance.setOnNotificationTapped((payload) {
      debugPrint("Notification tapped, switching to queue tab. Payload: $payload");
      if (mounted) {
        setState(() {
          _currentIndex = 0;
        });
      }
    });

    if (auth.currentUser != null && auth.currentUser!.role == UserRole.patient) {
      try {
        FirebaseMessaging messaging = FirebaseMessaging.instance;
        
        NotificationSettings settings = await messaging.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );

        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          String? token = await messaging.getToken();
          if (token != null) {
            await db.updateUserPushToken(auth.currentUser!.uid, token);
            debugPrint("FCM Push Token successfully registered: $token");
          }
        }
      } catch (e) {
        debugPrint("FCM Push Token registration error: $e");
      }
    }
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
              horizontal: isSelected ? 16 : 12,
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
              size: isSelected ? 20 : 19,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: GoogleFonts.inter(
              fontSize: 9.5,
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
    final auth = Provider.of<AuthService>(context);
    if (auth.currentUser == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    return Scaffold(
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
          borderRadius: BorderRadius.circular(28),
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
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.analytics_outlined, "Live Queue"),
                  _buildNavItem(1, Icons.calendar_today_outlined, "Book Slot"),
                  _buildNavItem(2, Icons.receipt_long_outlined, "History"),
                  _buildNavItem(3, Icons.chat_bubble_outline, "Chats"),
                  _buildNavItem(4, Icons.person_outline, "Profile"),
                  _buildNavItem(5, Icons.campaign_outlined, "Broadcast"),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- TAB 1: LIVE QUEUE DASHBOARD ---
class _DashboardTab extends StatefulWidget {
  final Function(int)? onTabChange;
  const _DashboardTab({Key? key, this.onTabChange}) : super(key: key);

  @override
  __DashboardTabState createState() => __DashboardTabState();
}

class __DashboardTabState extends State<_DashboardTab> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final _issueController = TextEditingController();
  bool _isJoining = false;
  String? _lastStatus;
  QueueItem? _lastActiveItem;
  bool _upiPaymentFailed = false;
  QueueItem? _paidActiveItem;

  static const _platform = MethodChannel('com.mediqueue.app/upi_payment');
  bool _isUpiPaying = false;

  Timer? _timer;
  late final DateTime _bootTime;
  StreamSubscription<QuerySnapshot>? _notificationsSubscription;

  @override
  void initState() {
    super.initState();
    _bootTime = DateTime.now();
    _listenToForegroundNotifications();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _notificationsSubscription?.cancel();
    _issueController.dispose();
    super.dispose();
  }

  bool _isInitialNotificationLoad = true;

  void _listenToForegroundNotifications() {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.currentUser == null) return;
    
    final uid = auth.currentUser!.uid;
    final appId = auth.appId;
    
    _notificationsSubscription = FirebaseFirestore.instance
        .collection("artifacts/$appId/users/$uid/notifications")
        .snapshots()
        .listen((snapshot) {
      
      if (_isInitialNotificationLoad) {
        _isInitialNotificationLoad = false;
        return;
      }
      
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            final category = data['category'] ?? 'update';
            final title = data['title'] ?? 'MediQue Update';
            final body = data['body'] ?? '';
            
            // Show local notification which handles sound/vibrate
            NotificationService.instance.showLocalNotification(
              id: change.doc.id.hashCode,
              title: title,
              body: body,
              category: category,
              payload: 'live_queue',
            );
          }
        }
      }
    });
  }



  Future<void> _handleDownloadReceipt(Map<String, dynamic> details, {bool isShare = false}) async {
    try {
      await PdfService.generatePremiumReceipt(
        clinicName: details['clinicName'] ?? "MediQue Clinic",
        patientName: details['patientName'] ?? "Patient",
        doctorName: details['doctorName'] ?? "Doctor",
        invoiceId: details['invoiceId'] ?? "INV-N/A",
        amountPaid: details['amountPaid'] ?? 250.0,
        paymentMethod: details['paymentMethod'] ?? "UPI",
        txnRef: details['txnRef'] ?? "",
        approvalRefNo: details['approvalRefNo'] ?? "",
        responseCode: details['responseCode'] ?? "",
        transactionId: details['transactionId'] ?? "",
        paidAt: details['paidAt'] ?? DateTime.now(),
        selectedUpiApp: details['selectedUpiApp'] ?? "UPI App",
        isShare: isShare,
      );
    } catch (e) {
      debugPrint("Error generating premium receipt PDF: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error generating receipt: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }



  Widget _buildBillingRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondaryColor),
          ),
          Text(
            "₹${amount.toStringAsFixed(2)}",
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isActive,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? AppTheme.successColor
                    : (isActive ? AppTheme.primaryColor : Colors.grey.shade200),
                border: Border.all(
                  color: isCompleted
                      ? AppTheme.successColor
                      : (isActive ? AppTheme.primaryColor : Colors.grey.shade300),
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 10, color: Colors.white)
                  : (isActive
                      ? Center(
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : null),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                color: isCompleted ? AppTheme.successColor : Colors.grey.shade200,
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontWeight: isActive || isCompleted ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                  color: isActive || isCompleted ? AppTheme.textPrimaryColor : AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: isActive ? AppTheme.primaryColor : AppTheme.textSecondaryColor.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline(QueueItem activeItem, int position, String doctorStatusText, int estimatedWait) {
    final status = activeItem.status;
    final hasDoc = activeItem.doctorId != null && 
        activeItem.doctorId!.isNotEmpty && 
        activeItem.doctorId != 'unassigned' && 
        activeItem.doctorId != 'unasigned';
    
    final step1Completed = true;
    final step2Completed = hasDoc;
    final step3Completed = hasDoc && (status == 'calling' || status == 'pending_payment' || status == 'seen');
    final step4Completed = status == 'pending_payment' || status == 'seen';
    final step5Completed = status == 'seen';

    final step1Active = status == 'pre_registered';
    final step2Active = !hasDoc;
    final step3Active = hasDoc && status == 'waiting';
    final step4Active = status == 'calling';
    final step5Active = status == 'pending_payment';

    String aheadText = position > 1 ? "${position - 1} patients ahead" : "Next patient";
    if (!hasDoc) aheadText = "Awaiting assignment";
    if (status == 'calling') aheadText = "Doctor is calling you now";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Live Status Timeline",
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 16),
          _buildTimelineStep(
            title: "Checked In",
            subtitle: "Registered and assigned token #${activeItem.token ?? ''}",
            isCompleted: step1Completed,
            isActive: step1Active,
          ),
          _buildTimelineStep(
            title: "Assigned Doctor",
            subtitle: hasDoc ? "Assigned to Dr. ${activeItem.doctorName}" : "Awaiting assignment",
            isCompleted: step2Completed,
            isActive: step2Active,
          ),
          _buildTimelineStep(
            title: "Waiting Room",
            subtitle: status == 'waiting' 
                ? "Queue status: $aheadText (Est: $estimatedWait mins)"
                : "Completed waiting in lobby",
            isCompleted: step3Completed,
            isActive: step3Active,
          ),
          _buildTimelineStep(
            title: "Consultation Started",
            subtitle: status == 'calling' 
                ? "Your turn: proceed to Doctor Cabin. (Doctor: $doctorStatusText)" 
                : (step4Completed ? "Consultation completed" : "Awaiting turn"),
            isCompleted: step4Completed,
            isActive: step4Active,
          ),
          _buildTimelineStep(
            title: "Billing & Checkout",
            subtitle: status == 'pending_payment' 
                ? "Checkout generated: ₹${activeItem.totalAmount ?? activeItem.fee ?? 250.0} due" 
                : (step5Completed ? "Payment confirmed. Thank you!" : "Awaiting checkout"),
            isCompleted: step5Completed,
            isActive: step5Active,
            isLast: true,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  void _showFeedbackDialog(QueueItem activeItem, DbService db) {
    double docBehavior = 5;
    double docQuality = 5;
    double docClarity = 5;
    double docSatisfaction = 5;
    
    double appEase = 5;
    double appTransparency = 5;
    double appWaitAccuracy = 5;
    double appOverall = 5;
    
    final TextEditingController commentController = TextEditingController();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Widget buildStarRow(String label, double rating, Function(double) onRatingChanged) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondaryColor),
                      ),
                    ),
                    Row(
                      children: List.generate(5, (index) {
                        final starVal = index + 1.0;
                        return GestureDetector(
                          onTap: () => onRatingChanged(starVal),
                          child: Icon(
                            starVal <= rating ? Icons.star : Icons.star_border,
                            color: starVal <= rating ? Colors.amber : Colors.grey.shade300,
                            size: 20,
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              );
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Column(
                children: [
                  Text(
                    "Share Your Feedback",
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimaryColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Rate your experience today",
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondaryColor),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "DOCTOR RATINGS",
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 10, color: AppTheme.primaryColor, letterSpacing: 1.1),
                    ),
                    const SizedBox(height: 6),
                    buildStarRow("Behavior & Empathy", docBehavior, (val) => setState(() => docBehavior = val)),
                    buildStarRow("Quality of Care", docQuality, (val) => setState(() => docQuality = val)),
                    buildStarRow("Clarity of Instructions", docClarity, (val) => setState(() => docClarity = val)),
                    buildStarRow("Overall Satisfaction", docSatisfaction, (val) => setState(() => docSatisfaction = val)),
                    const Divider(height: 24),
                    Text(
                      "APP RATINGS",
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 10, color: AppTheme.primaryColor, letterSpacing: 1.1),
                    ),
                    const SizedBox(height: 6),
                    buildStarRow("Ease of Use", appEase, (val) => setState(() => appEase = val)),
                    buildStarRow("Queue Transparency", appTransparency, (val) => setState(() => appTransparency = val)),
                    buildStarRow("Wait Time Accuracy", appWaitAccuracy, (val) => setState(() => appWaitAccuracy = val)),
                    buildStarRow("Overall App Experience", appOverall, (val) => setState(() => appOverall = val)),
                    const Divider(height: 24),
                    Text(
                      "Comments (Optional)",
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 10, color: AppTheme.textSecondaryColor),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: commentController,
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textPrimaryColor),
                      decoration: InputDecoration(
                        hintText: "Write your reviews...",
                        hintStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade400),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryColor)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Skip", style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      final Map<String, int> ratings = {
                        'docBehavior': docBehavior.toInt(),
                        'docQuality': docQuality.toInt(),
                        'docClarity': docClarity.toInt(),
                        'docSatisfaction': docSatisfaction.toInt(),
                        'appEase': appEase.toInt(),
                        'appTransparency': appTransparency.toInt(),
                        'appWaitAccuracy': appWaitAccuracy.toInt(),
                        'appOverall': appOverall.toInt(),
                      };
                      
                      await db.submitPatientFeedback(
                        doctorId: activeItem.doctorId ?? "default_doctor",
                        doctorName: activeItem.doctorName ?? "Dr. Admin",
                        patientId: activeItem.patientId,
                        ratings: ratings,
                        comments: commentController.text,
                      );
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Thank you for your feedback!"), backgroundColor: AppTheme.successColor),
                        );
                      }
                    } catch (e) {
                      print("Submit feedback error: $e");
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text("Submit", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;

  void _showJoinQueueDialog(AuthService auth, DbService db) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            "Join Live Queue",
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
          ),
          content: TextField(
            controller: _issueController,
            style: GoogleFonts.inter(color: AppTheme.textPrimaryColor),
            decoration: InputDecoration(
              labelText: "Describe your medical issue",
              labelStyle: GoogleFonts.inter(color: AppTheme.textSecondaryColor),
              hintText: "e.g., Fever, General checkup, Headache",
              hintStyle: GoogleFonts.inter(color: AppTheme.textSecondaryColor.withOpacity(0.5)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                "Cancel",
                style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                setState(() => _isJoining = true);
                try {
                  await db.joinQueue(
                    auth.currentUser!.name ?? "Patient",
                    auth.currentUser!.email,
                    _issueController.text.trim(),
                    auth.currentUser!.uid,
                    false,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Checked in successfully! You are now in the queue."),
                        backgroundColor: AppTheme.successColor,
                      ),
                    );
                  }
                } catch (e) {
                  _showErrorDialog(e.toString().replaceAll("Exception:", ""));
                } finally {
                  if (mounted) {
                    setState(() => _isJoining = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                "Join",
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Check-In Error",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.errorColor),
        ),
        content: Text(
          msg,
          style: GoogleFonts.inter(color: AppTheme.textPrimaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              "OK",
              style: GoogleFonts.inter(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showNotificationCenter(BuildContext context, AuthService auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        final appId = auth.appId;
        final uid = auth.currentUser?.uid;
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("artifacts/$appId/users/$uid/notifications")
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
                            "Notification Center",
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
                                case 'turn':
                                  categoryIcon = Icons.alarm_rounded;
                                  iconColor = AppTheme.warningColor;
                                  break;
                                case 'billing':
                                  categoryIcon = Icons.receipt_long_rounded;
                                  iconColor = AppTheme.successColor;
                                  break;
                                case 'emergency':
                                  categoryIcon = Icons.warning_amber_rounded;
                                  iconColor = AppTheme.errorColor;
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
                                          color: AppTheme.textSecondaryColor.withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: isUnread
                                      ? Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: AppTheme.primaryColor,
                                            shape: BoxShape.circle,
                                          ),
                                        )
                                      : null,
                                  onTap: () {
                                    if (isUnread) {
                                      doc.reference.update({'status': 'read'});
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

  Future<bool> _checkInAppointmentUser(AuthService auth, DbService db) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snap = await FirebaseFirestore.instance
        .collection("artifacts/${auth.appId}/public/data/appointments")
        .where("patientId", isEqualTo: auth.currentUser!.uid)
        .where("appointmentAt", isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where("appointmentAt", isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    final confirmedAppts = snap.docs.where((d) => d.data()['status'] == 'confirmed').toList();
    if (confirmedAppts.isEmpty) return false;

    final apptDoc = confirmedAppts.first;
    final apptData = apptDoc.data();

    await db.checkInAppointment(
      apptId: apptDoc.id,
      patientId: auth.currentUser!.uid,
      patientName: auth.currentUser!.name ?? "Patient",
      doctorId: apptData['doctorId'] ?? "",
      doctorName: apptData['doctorName'] ?? "Doctor",
      specialty: apptData['specialty'] ?? "General",
      reason: apptData['reason'] ?? "Appointment Check-in",
    );
    return true;
  }

  Future<bool> _checkInPreRegisteredUser(AuthService auth, DbService db) async {
    final snap = await FirebaseFirestore.instance
        .collection("artifacts/${auth.appId}/public/data/queue")
        .where("patientId", isEqualTo: auth.currentUser!.uid)
        .where("status", isEqualTo: "pre_registered")
        .get();

    if (snap.docs.isEmpty) return false;

    final queueDoc = snap.docs.first;
    await queueDoc.reference.update({
      'status': 'waiting',
      'joinedAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  void _showCheckInOptions(AuthService auth, DbService db) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Self Check-In",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimaryColor),
              ),
              const SizedBox(height: 8),
              Text(
                "Scan the QR code displayed at the clinic counter or enter the daily passcode to check in.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 13),
              ),
              const SizedBox(height: 24),
              
              // Scan QR Code Button
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openQRScanner(auth, db);
                },
                icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
                label: Text("Scan Clinic QR Code", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 12),
              
              // Enter Code Manually Button
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showPasscodeCheckInDialog(auth, db);
                },
                icon: const Icon(Icons.keyboard_rounded, color: AppTheme.primaryColor),
                label: Text("Enter Passcode Manually", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _openQRScanner(AuthService auth, DbService db) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QRScannerScreen(
          onScan: (scannedText) async {
            // Process scanned text
            String passcode = scannedText.trim();
            if (passcode.contains("pass=")) {
              try {
                final uri = Uri.parse(passcode);
                passcode = uri.queryParameters['pass'] ?? passcode;
              } catch (_) {
                // fallback if not a valid URL
              }
            }
            passcode = passcode.toUpperCase();

            // Verify passcode
            setState(() => _isJoining = true);
            try {
              final statusSnap = await FirebaseFirestore.instance
                  .doc("artifacts/${auth.appId}/public/data/clinicStatus/status")
                  .get();
              final correct = statusSnap.data()?['remotePasscode']?.toString().toUpperCase();
              if (correct == null || passcode != correct) {
                _showErrorDialog("Invalid QR code or passcode. Please check again.");
                return;
              }

              // 1. Try Appointment check-in
              final apptChecked = await _checkInAppointmentUser(auth, db);
              if (apptChecked) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Checked in via Appointment! You are now in the live queue."),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
                return;
              }

              // 2. Try Pre-registered check-in
              final preRegChecked = await _checkInPreRegisteredUser(auth, db);
              if (preRegChecked) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Checked in successfully! You are now active in the queue."),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
                return;
              }

              // 3. Fallback: prompt to join queue
              _showJoinQueueDialog(auth, db);
            } catch (e) {
              _showErrorDialog(e.toString());
            } finally {
              setState(() => _isJoining = false);
            }
          },
        ),
      ),
    );
  }

  void _showPasscodeCheckInDialog(AuthService auth, DbService db) {
    final passcodeController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            "Clinic Check-in",
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Enter daily passcode displayed on the clinic check-in screen:",
                style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passcodeController,
                maxLength: 6,
                style: GoogleFonts.inter(fontSize: 20, letterSpacing: 4, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: "6-character Passcode",
                  labelStyle: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  counterText: "",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                "Cancel",
                style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final code = passcodeController.text.trim().toUpperCase();
                Navigator.of(ctx).pop();
                setState(() => _isJoining = true);
                try {
                  final statusSnap = await FirebaseFirestore.instance
                      .doc("artifacts/${auth.appId}/public/data/clinicStatus/status")
                      .get();
                  final correct = statusSnap.data()?['remotePasscode']?.toString().toUpperCase();
                  if (correct == null || code != correct) {
                    _showErrorDialog("Invalid passcode. Please check again.");
                    return;
                  }

                  // 1. Try Appointment check-in
                  final apptChecked = await _checkInAppointmentUser(auth, db);
                  if (apptChecked) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Checked in via Appointment! You are now in the live queue."),
                        backgroundColor: AppTheme.successColor,
                      ),
                    );
                    return;
                  }

                  // 2. Try Pre-registered check-in
                  final preRegChecked = await _checkInPreRegisteredUser(auth, db);
                  if (preRegChecked) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Checked in successfully! You are now active in the queue."),
                        backgroundColor: AppTheme.successColor,
                      ),
                    );
                    return;
                  }

                  // 3. Fallback: prompt to join queue
                  _showJoinQueueDialog(auth, db);
                } catch (e) {
                  _showErrorDialog(e.toString());
                } finally {
                  setState(() => _isJoining = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                "Verify",
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
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

    if (auth.currentUser == null) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }



    // Premium greeting header — glassmorphic card
    Widget buildGreetingHeader() {
      final hour = DateTime.now().hour;
      final greeting = hour < 12 ? "Good Morning" : hour < 17 ? "Good Afternoon" : "Good Evening";
      final greetingEmoji = hour < 12 ? "☀️" : hour < 17 ? "🌤️" : "🌙";
      return Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.7), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Gradient ring avatar
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF0F9D8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF4F46E5).withOpacity(0.1),
                  child: Text(
                    (auth.currentUser?.name ?? "P").substring(0, 1).toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF4F46E5),
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
                  Text(
                    "$greetingEmoji $greeting",
                    style: GoogleFonts.inter(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    auth.currentUser?.name ?? "Patient",
                    style: GoogleFonts.inter(
                      color: AppTheme.textPrimaryColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            // Clinic badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.domain_rounded, color: Colors.white, size: 11),
                  const SizedBox(width: 4),
                  Text(
                    auth.clinicCode,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 450.ms).slideY(begin: -0.08, end: 0, curve: Curves.easeOut);
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          "MediQue",
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppTheme.textPrimaryColor, letterSpacing: 0.5),
        ),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        centerTitle: false,
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("artifacts/${auth.appId}/users/${auth.currentUser?.uid}/notifications")
                .where("status", isEqualTo: "unread")
                .snapshots(),
            builder: (context, snapshot) {
              int unreadCount = 0;
              if (snapshot.hasData) {
                unreadCount = snapshot.data!.docs.length;
              }
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded, color: AppTheme.textPrimaryColor),
                    onPressed: () => _showNotificationCenter(context, auth),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 6,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          Container(
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12, left: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: Center(
                child: Text(
                  "LIVE",
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.0),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: db.streamBroadcastNews(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                final active = data['active'] == true;
                final text = data['text'] as String? ?? "";
                if (active && text.isNotEmpty) {
                  return Container(
                    height: 36,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      border: Border(
                        bottom: BorderSide(color: AppTheme.primaryColor.withOpacity(0.2), width: 1),
                      ),
                    ),
                    child: marquee.Marquee(
                      text: " 📢  " + text + "   •   ",
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
                      scrollAxis: Axis.horizontal,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      blankSpace: 40.0,
                      velocity: 40.0,
                      pauseAfterRound: const Duration(seconds: 0),
                      startPadding: 10.0,
                      accelerationDuration: const Duration(seconds: 1),
                      accelerationCurve: Curves.linear,
                      decelerationDuration: const Duration(milliseconds: 500),
                      decelerationCurve: Curves.easeOut,
                    ),
                  );
                }
              }
              return const SizedBox.shrink();
            },
          ),
          Expanded(
            child: _isJoining
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<List<QueueItem>>(
                    stream: db.streamPatientActiveQueue(auth.currentUser!.uid),
                    builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return _buildShimmerSkeleton();
                }
                
                final queueItems = snap.data ?? [];
                
                if (queueItems.isEmpty) {
                  return Container(
                    decoration: AppTheme.gradientDecoration,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            buildGreetingHeader(),
                            const Spacer(),
                            // Glowing medical heart/shield icon
                            Center(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.15), width: 1.5),
                                    ),
                                  ).animate(onPlay: (c) => c.repeat())
                                   .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 2500.ms, curve: Curves.easeOut)
                                   .fadeOut(duration: 2500.ms),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Image.asset(
                                      'assets/logo.png',
                                      width: 72,
                                      height: 72,
                                    ),
                                  ).animate(onPlay: (c) => c.repeat(reverse: true))
                                   .scale(begin: const Offset(0.96, 0.96), end: const Offset(1.04, 1.04), duration: 1800.ms),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                             Text(
                              "Welcome to MediQue",
                              style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimaryColor, letterSpacing: 0.2),
                              textAlign: TextAlign.center,
                            ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
                            const SizedBox(height: 10),
                            Text(
                              "You are not currently in the queue.\nJoin instantly for smart clinical care.",
                              style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 14, height: 1.5),
                              textAlign: TextAlign.center,
                            ).animate().fadeIn(delay: 150.ms, duration: 450.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
                            const Spacer(),
                            Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryColor.withOpacity(0.2),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () => _showJoinQueueDialog(auth, db),
                                icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
                                label: Text("Check-In / Join Queue", style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ).animate().fadeIn(delay: 300.ms, duration: 350.ms).slideY(begin: 0.2, end: 0, duration: 350.ms, curve: Curves.easeOut),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => _showCheckInOptions(auth, db),
                              icon: const Icon(Icons.qr_code_scanner, color: AppTheme.primaryColor),
                              label: Text("Self Check-In at Clinic", style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryColor,
                                side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ).animate().fadeIn(delay: 400.ms, duration: 350.ms).slideY(begin: 0.2, end: 0, duration: 350.ms, curve: Curves.easeOut),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // Transition detector for checkout completion (e.g. cash payment completed by receptionist)
                if (queueItems.isEmpty) {
                  if (_lastStatus == 'pending_payment' && _lastActiveItem != null) {
                    final tempItem = _lastActiveItem!;
                    _lastStatus = null;
                    _lastActiveItem = null;
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      _showFeedbackDialog(tempItem, db);
                      
                      // 1. Generate & print PDF invoice
                      try {
                        await PdfService.generateAndPrintInvoice(
                          patientName: tempItem.name,
                          doctorName: tempItem.doctorName ?? "Doctor",
                          amount: tempItem.fee ?? 250.0,
                          paymentMethod: tempItem.paymentMethod ?? "upi",
                          token: tempItem.token ?? "",
                          reason: tempItem.issue,
                        );
                      } catch (e) {
                        debugPrint("Auto receipt generation failed: $e");
                      }

                      // 2. Save receipt metadata to user profile
                      try {
                        await FirebaseFirestore.instance
                            .collection("artifacts/${auth.appId}/users/${tempItem.patientId}/receipts")
                            .add({
                          'patientName': tempItem.name,
                          'doctorName': tempItem.doctorName ?? "Doctor",
                          'amount': tempItem.fee ?? 250.0,
                          'paymentMethod': tempItem.paymentMethod ?? "upi",
                          'token': tempItem.token ?? "",
                          'reason': tempItem.issue,
                          'timestamp': FieldValue.serverTimestamp(),
                        });
                      } catch (e) {
                        debugPrint("Failed to store receipt metadata: $e");
                      }

                      // 3. Simulated WhatsApp dispatch
                      try {
                        await FirebaseFirestore.instance
                            .collection("artifacts/${auth.appId}/public/data/whatsappLogs")
                            .add({
                          'patientId': tempItem.patientId,
                          'patientName': tempItem.name,
                          'phone': tempItem.mobile,
                          'message': "Hi ${tempItem.name}, your payment of ₹${(tempItem.fee ?? 250.0).toStringAsFixed(0)} at MediQue is successful. Attached is your invoice. Thank you!",
                          'sentAt': FieldValue.serverTimestamp(),
                          'status': 'sent',
                        });
                      } catch (e) {
                        debugPrint("Simulated WhatsApp dispatch failed: $e");
                      }
                    });
                  }
                } else {
                  final activeItem = queueItems.first;
                  if (activeItem.status == 'pending_payment') {
                    _lastStatus = 'pending_payment';
                    _lastActiveItem = activeItem;
                  } else {
                    _lastStatus = activeItem.status;
                    _lastActiveItem = null;
                  }
                }

                if (queueItems.isEmpty) {
                  return Container(); // Fallback handled by outer check
                }

                final QueueItem activeItem = queueItems.first;

                if (activeItem.status == 'pending_payment') {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        buildGreetingHeader(),
                        
                        // Itemized Bill Details Card
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.black.withOpacity(0.04)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ]
                          ),
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Consultation Bill",
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryColor),
                                  ),
                                  Text(
                                    "₹${activeItem.totalAmount ?? activeItem.fee ?? 250.0}",
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.primaryColor),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        Container(
                          padding: const EdgeInsets.all(24.0),
                          decoration: AppTheme.glassCardDecoration,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.payment_rounded, color: Colors.orange, size: 32),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "Payment Pending",
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: AppTheme.textPrimaryColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Your consultation is complete. Please proceed to the receptionist desk to complete payment and checkout.",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppTheme.textSecondaryColor,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final bool isCalling = activeItem.status == 'calling';
                final bool hasDoctorId = activeItem.doctorId != null &&
                    activeItem.doctorId!.isNotEmpty &&
                    activeItem.doctorId != "unassigned" &&
                    activeItem.doctorId != "unasigned";

                final String docPath = hasDoctorId 
                    ? "artifacts/${auth.appId}/public/data/staff/${activeItem.doctorId}" 
                    : "artifacts/${auth.appId}/public/data/staff/dummy_non_existent";

                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.doc(docPath).snapshots(),
                  builder: (context, doctorSnap) {
                    final doctorData = doctorSnap.data?.data() as Map<String, dynamic>? ?? {};
                    final doctorStatusStr = doctorData['doctorStatus'] ?? (doctorData['isActive'] == false ? 'offline' : 'available');
                    
                    String doctorStatusText = "Available";
                    Color doctorStatusColor = Colors.green;
                    if (doctorStatusStr == 'consulting') {
                      doctorStatusText = "In Consultation";
                      doctorStatusColor = Colors.blue;
                    } else if (doctorStatusStr == 'break') {
                      doctorStatusText = "On Break";
                      doctorStatusColor = Colors.orange;
                    } else if (doctorStatusStr == 'offline') {
                      doctorStatusText = "Offline";
                      doctorStatusColor = Colors.grey;
                    }

                    if (!hasDoctorId) {
                      doctorStatusText = "Awaiting Assignment";
                      doctorStatusColor = Colors.orange;
                    }

                    return StreamBuilder<double>(
                      stream: db.streamDoctorAverageConsultationTime(hasDoctorId ? activeItem.doctorId! : ""),
                      builder: (context, avgTimeSnap) {
                        final avgTime = avgTimeSnap.data ?? 12.0;
                        
                        return StreamBuilder<List<QueueItem>>(
                          stream: db.streamDoctorQueue(hasDoctorId ? activeItem.doctorId! : ""),
                          builder: (context, doctorQueueSnap) {
                            final doctorQueue = doctorQueueSnap.data ?? [];
                            final position = hasDoctorId ? (doctorQueue.indexWhere((q) => q.id == activeItem.id) + 1) : 0;
                            
                            QueueItem? callingItem;
                            try {
                              callingItem = doctorQueue.firstWhere((q) => q.status == 'calling');
                            } catch (_) {}

                            int waitTime = activeItem.predictedWait ?? 0;
                            if (waitTime == 0) {
                              if (!hasDoctorId) {
                                waitTime = 15;
                              } else if (doctorStatusStr == 'offline' || doctorStatusStr == 'break') {
                                waitTime = avgTime.round();
                              } else {
                                final bool isDoctorBusy = callingItem != null && callingItem.id != activeItem.id;
                                final int patientsAhead = position > 0 ? (position - 1 + (isDoctorBusy ? 1 : 0)) : 0;
                                waitTime = patientsAhead * avgTime.round();
                                if (waitTime == 0 && isDoctorBusy) {
                                  waitTime = avgTime.round();
                                }
                              }
                            }
                            final String currentTokenServing = callingItem != null ? (callingItem.token ?? 'None') : 'None';

                            Widget mainCard = Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isCalling
                                      ? [const Color(0xFF4F46E5), const Color(0xFF7C3AED), const Color(0xFF0F9D8A)]
                                      : [const Color(0xFF0F9D8A), const Color(0xFF0B7264), const Color(0xFF064E3B)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  stops: const [0.0, 0.6, 1.0],
                                ),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: isCalling
                                      ? const Color(0xFF7C3AED).withOpacity(0.6)
                                      : const Color(0xFF14CBA8).withOpacity(0.4),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isCalling ? const Color(0xFF4F46E5) : AppTheme.primaryColor).withOpacity(0.35),
                                    blurRadius: 28,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 10),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(27),
                                child: Stack(
                                  children: [
                                    // Subtle pattern overlay
                                    Positioned(
                                      right: -20,
                                      bottom: -20,
                                      child: Container(
                                        width: 120,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withOpacity(0.04),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 30,
                                      top: -30,
                                      child: Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withOpacity(0.04),
                                        ),
                                      ),
                                    ),
                                    // Main content
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                                      child: Column(
                                        children: [
                                          // Status chip with glass effect
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  isCalling ? "🔔  IT'S YOUR TURN" : "⏳  IN QUEUE",
                                                  style: GoogleFonts.inter(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 10,
                                                    letterSpacing: 1.2,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 6,
                                                      height: 6,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: doctorStatusColor,
                                                        boxShadow: [
                                                          BoxShadow(color: doctorStatusColor.withOpacity(0.6), blurRadius: 4),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 5),
                                                    Text(
                                                      "Dr. Status: $doctorStatusText",
                                                      style: GoogleFonts.inter(
                                                        color: Colors.white.withOpacity(0.92),
                                                        fontSize: 9.5,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            isCalling ? "PROCEED NOW" : "#${activeItem.token ?? 'Waiting'}",
                                            style: GoogleFonts.inter(
                                              fontSize: isCalling ? 34 : 60,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              letterSpacing: isCalling ? 1.5 : -1,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.black.withOpacity(0.15),
                                                  offset: const Offset(0, 3),
                                                  blurRadius: 8,
                                                ),
                                              ],
                                            ),
                                          ).animate(key: ValueKey(activeItem.token)).scale(duration: 300.ms, curve: Curves.elasticOut),
                                          if (!isCalling) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              "Currently Serving: Token $currentTokenServing",
                                              style: GoogleFonts.inter(
                                                color: Colors.white.withOpacity(0.88),
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 6),
                                          Text(
                                            isCalling ? "Please enter the doctor's cabin." : "Status: ${activeItem.status.toUpperCase()}",
                                            style: GoogleFonts.inter(
                                              color: Colors.white.withOpacity(0.85),
                                              fontWeight: FontWeight.w500,
                                              fontSize: 13,
                                            ),
                                          ),
                                          if (!isCalling && position > 0) ...[
                                            const SizedBox(height: 20),
                                            Divider(color: Colors.white.withOpacity(0.18)),
                                            const SizedBox(height: 14),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                                              children: [
                                                _StatPill(label: "Position", value: "#$position", icon: Icons.pin_rounded),
                                                _StatPill(label: "Ahead", value: "${position - 1}", icon: Icons.people_outline_rounded),
                                                _StatPill(label: "Wait", value: "~$waitTime min", icon: Icons.timer_outlined),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: LinearProgressIndicator(
                                                value: doctorQueue.isNotEmpty ? (doctorQueue.length - position + 1) / doctorQueue.length : 0,
                                                backgroundColor: Colors.white.withOpacity(0.18),
                                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                                minHeight: 5,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );

                            if (isCalling) {
                              mainCard = mainCard.animate(onPlay: (controller) => controller.repeat(reverse: true))
                                  .boxShadow(
                                    end: const BoxShadow(color: AppTheme.secondaryColor, blurRadius: 28, spreadRadius: 6),
                                    duration: 1000.ms,
                                  );
                            }

                            return SingleChildScrollView(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  buildGreetingHeader(),
                                  mainCard,
                                  const SizedBox(height: 20),
                                  _buildTimeline(activeItem, position, doctorStatusText, waitTime),
                                ],
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
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Stat Pill Widget for queue card
class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatPill({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.75), size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
        ),
        Text(
          label,
          style: GoogleFonts.inter(color: Colors.white.withOpacity(0.65), fontSize: 10),
        ),
      ],
    );
  }
}



// --- TAB 2: BOOK APPOINTMENT SLOT ---
class _BookSlotTab extends StatefulWidget {
  const _BookSlotTab({Key? key}) : super(key: key);

  @override
  __BookSlotTabState createState() => __BookSlotTabState();
}

class __BookSlotTabState extends State<_BookSlotTab> with AutomaticKeepAliveClientMixin {
  DateTime _selectedDate = DateTime.now();
  String? _selectedDoctorId;
  String? _selectedDoctorName;
  String? _selectedDoctorSpecialty;
  String? _selectedSlot;
  final _reasonController = TextEditingController();
  bool _isBooking = false;
  bool _isLoadingSlots = false;
  List<String> _availableSlots = [];
  List<Map<String, dynamic>> _doctors = [];
  List<String> _leaveDates = [];
  bool _isDayOff = false;
  bool _isLeaveDay = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    final db = Provider.of<DbService>(context, listen: false);
    try {
      final docs = await db.getActiveDoctors();
      setState(() {
        _doctors = docs;
        if (docs.isNotEmpty) {
          _selectedDoctorId = docs[0]['id'];
          _selectedDoctorName = docs[0]['name'] ?? "Doctor";
          _selectedDoctorSpecialty = docs[0]['specialization'] ?? "General";
        }
      });
      _loadAvailableSlots();
    } catch (e) {
      debugPrint("Error loading doctors: $e");
    }
  }

  Future<void> _loadAvailableSlots() async {
    if (_selectedDoctorId == null) return;
    setState(() {
      _isLoadingSlots = true;
      _availableSlots = [];
      _selectedSlot = null;
    });

    final db = Provider.of<DbService>(context, listen: false);
    try {
      final appId = db.appId;
      
      final leaveDoc = await FirebaseFirestore.instance
          .doc("artifacts/$appId/public/data/clinicSettings/leaveDates")
          .get();
      List<String> localLeaves = [];
      if (leaveDoc.exists) {
        final data = leaveDoc.data() ?? {};
        final datesVal = data['dates'];
        if (datesVal != null && datesVal is List) {
          localLeaves = datesVal.map((e) => e.toString()).toList();
        }
      }

      final schedDoc = await FirebaseFirestore.instance
          .doc("artifacts/$appId/public/data/clinicSettings/scheduling")
          .get();

      Map<String, dynamic> settings = {
        'start': "09:00",
        'end': "18:00",
        'lunchStart': "13:00",
        'lunchEnd': "14:00",
        'lunchEnabled': true,
        'slotDuration': 15,
      };

      bool isDayOff = false;
      if (schedDoc.exists) {
        final d = schedDoc.data() ?? {};
        final days = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
        final dayName = days[_selectedDate.weekday % 7];
        final schedule = d['schedule'] as Map<String, dynamic>?;
        final daySched = schedule != null ? schedule[dayName] as Map<String, dynamic>? : null;

        if (daySched != null) {
          isDayOff = daySched['isDayOff'] == true;
          settings['start'] = daySched['start'] ?? "09:00";
          settings['end'] = daySched['end'] ?? "18:00";
          settings['lunchStart'] = daySched['lunchStart'] ?? "13:00";
          settings['lunchEnd'] = daySched['lunchEnd'] ?? "14:00";
          settings['lunchEnabled'] = daySched['lunchEnabled'] ?? true;
        } else {
          final workingHours = d['workingHours'] as Map<String, dynamic>?;
          final lunchBreak = d['lunchBreak'] as Map<String, dynamic>?;
          if (workingHours != null) {
            settings['start'] = workingHours['start'] ?? "09:00";
            settings['end'] = workingHours['end'] ?? "18:00";
          }
          if (lunchBreak != null) {
            settings['lunchStart'] = lunchBreak['start'] ?? "13:00";
            settings['lunchEnd'] = lunchBreak['end'] ?? "14:00";
          }
          settings['lunchEnabled'] = true;
        }
        settings['slotDuration'] = int.tryParse(d['slotDuration']?.toString() ?? "") ?? 15;
      }

      final List<String> slots = [];
      final partsStart = settings['start'].split(':');
      final partsEnd = settings['end'].split(':');
      final partsLunchStart = settings['lunchStart'].split(':');
      final partsLunchEnd = settings['lunchEnd'].split(':');

      var curr = DateTime(2000, 1, 1, int.parse(partsStart[0]), int.parse(partsStart[1]));
      final end = DateTime(2000, 1, 1, int.parse(partsEnd[0]), int.parse(partsEnd[1]));
      final lunchStart = DateTime(2000, 1, 1, int.parse(partsLunchStart[0]), int.parse(partsLunchStart[1]));
      final lunchEnd = DateTime(2000, 1, 1, int.parse(partsLunchEnd[0]), int.parse(partsLunchEnd[1]));

      final int duration = settings['slotDuration'] as int;

      while (curr.isBefore(end)) {
        bool isLunch = false;
        if (settings['lunchEnabled'] == true) {
          if (curr.isAtSameMomentAs(lunchStart) || (curr.isAfter(lunchStart) && curr.isBefore(lunchEnd))) {
            isLunch = true;
          }
        }
        if (!isLunch) {
          final hour = curr.hour.toString().padLeft(2, '0');
          final minute = curr.minute.toString().padLeft(2, '0');
          slots.add("$hour:$minute");
        }
        curr = curr.add(Duration(minutes: duration));
      }

      final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final aptsSnap = await FirebaseFirestore.instance
          .collection("artifacts/$appId/public/data/appointments")
          .where("appointmentAt", isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where("appointmentAt", isLessThan: Timestamp.fromDate(endOfDay))
          .where("doctorId", isEqualTo: _selectedDoctorId)
          .where("status", whereIn: ["pending", "confirmed"])
          .get();

      final Set<String> takenSlots = {};
      for (var doc in aptsSnap.docs) {
        final time = (doc.data()['appointmentAt'] as Timestamp).toDate();
        final h = time.hour.toString().padLeft(2, '0');
        final m = time.minute.toString().padLeft(2, '0');
        takenSlots.add("$h:$m");
      }

      final List<String> available = [];
      final now = DateTime.now();
      final isToday = DateTime(now.year, now.month, now.day).isAtSameMomentAs(startOfDay);

      for (var slot in slots) {
        if (takenSlots.contains(slot)) continue;
        if (isToday) {
          final parts = slot.split(':');
          final slotDateTime = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
          if (slotDateTime.isBefore(now)) continue;
        }
        available.add(slot);
      }

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final bool isLeaveDay = localLeaves.contains(dateStr);

      setState(() {
        _leaveDates = localLeaves;
        _isDayOff = isDayOff;
        _isLeaveDay = isLeaveDay;
        _availableSlots = available;
        _isLoadingSlots = false;
      });
    } catch (e) {
      debugPrint("Error loading slots: $e");
      setState(() {
        _isLoadingSlots = false;
      });
    }
  }

  Future<void> _bookSlot() async {
    if (_selectedDoctorId == null || _selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a doctor and time slot"),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    setState(() {
      _isBooking = true;
    });

    final auth = Provider.of<AuthService>(context, listen: false);
    final db = Provider.of<DbService>(context, listen: false);

    try {
      final parts = _selectedSlot!.split(':');
      final apptDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );

      await db.bookAppointment(
        patientId: auth.currentUser!.uid,
        patientName: auth.currentUser!.name ?? "Patient",
        doctorId: _selectedDoctorId!,
        doctorName: _selectedDoctorName!,
        specialty: _selectedDoctorSpecialty!,
        appointmentAt: apptDateTime,
        reason: _reasonController.text.trim().isEmpty
            ? "General Consultation"
            : _reasonController.text.trim(),
      );

      _reasonController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Appointment request submitted successfully!"),
          backgroundColor: AppTheme.successColor,
        ),
      );
      _loadAvailableSlots();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll("Exception: ", "")),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      setState(() {
        _isBooking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = Provider.of<AuthService>(context);
    final db = Provider.of<DbService>(context);

    if (auth.currentUser == null) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text("Book Appointment", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor)),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Select Doctor
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.glassCardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "SELECT DOCTOR",
                    style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 10),
                  _doctors.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black.withOpacity(0.04)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedDoctorId,
                              dropdownColor: Colors.white,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor),
                              items: _doctors.map((doc) {
                                return DropdownMenuItem<String>(
                                  value: doc['id'],
                                  child: Text(
                                    "${doc['name'] ?? 'Doctor'} (${doc['specialization'] ?? 'General'})",
                                    style: GoogleFonts.inter(color: AppTheme.textPrimaryColor, fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  final doc = _doctors.firstWhere((d) => d['id'] == val);
                                  setState(() {
                                    _selectedDoctorId = val;
                                    _selectedDoctorName = doc['name'];
                                    _selectedDoctorSpecialty = doc['specialization'] ?? "General";
                                  });
                                  _loadAvailableSlots();
                                }
                              },
                            ),
                          ),
                        ),
                ],
              ),
            ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 16),

            // Select Date horizontal strip
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: AppTheme.glassCardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "SELECT DATE",
                      style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 76,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: 14,
                      itemBuilder: (context, index) {
                        final date = DateTime.now().add(Duration(days: index));
                        final bool isSelected = DateTime(date.year, date.month, date.day).isAtSameMomentAs(
                          DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
                        );
                        final daysShort = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
                        final dayStr = daysShort[date.weekday % 7];

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedDate = date;
                            });
                            _loadAvailableSlots();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: 56,
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const LinearGradient(
                                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: isSelected ? null : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF4F46E5).withOpacity(0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      )
                                    ]
                                  : [],
                              border: Border.all(
                                color: isSelected ? const Color(0xFF4F46E5) : Colors.black.withOpacity(0.02),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  dayStr,
                                  style: GoogleFonts.inter(
                                    color: isSelected ? Colors.white : AppTheme.textSecondaryColor,
                                    fontSize: 10,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  date.day.toString(),
                                  style: GoogleFonts.inter(
                                    color: isSelected ? Colors.white : AppTheme.textPrimaryColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 80.ms, duration: 350.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 16),

            if (_isLeaveDay || _isDayOff) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.errorColor.withOpacity(0.12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isLeaveDay
                            ? "Warning: The selected date is marked as a scheduled clinic leave day. Appointments may be cancelled or rescheduled."
                            : "Warning: The clinic is closed on this day (weekly day off). Booking slots might not be processed.",
                        style: GoogleFonts.inter(
                          color: AppTheme.errorColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Available Slots
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.glassCardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "AVAILABLE SLOTS",
                    style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 12),
                  _isLoadingSlots
                      ? const Center(child: CircularProgressIndicator())
                      : _availableSlots.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Text(
                                  "No slots available for this date",
                                  style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 13),
                                ),
                              ),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _availableSlots.map((slot) {
                                final bool isSelected = _selectedSlot == slot;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedSlot = slot;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                                    decoration: BoxDecoration(
                                      gradient: isSelected
                                          ? const LinearGradient(
                                              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                          : null,
                                      color: isSelected ? null : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF4F46E5) : Colors.black.withOpacity(0.04),
                                        width: isSelected ? 1.5 : 1.0,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF4F46E5).withOpacity(0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              )
                                            ]
                                          : [],
                                    ),
                                    child: Text(
                                      slot,
                                      style: GoogleFonts.inter(
                                        color: isSelected ? Colors.white : AppTheme.textPrimaryColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                ],
              ),
            ).animate().fadeIn(delay: 160.ms, duration: 350.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 16),

            // Reason field and CTA button card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.glassCardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "REASON FOR VISIT",
                    style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _reasonController,
                    style: GoogleFonts.inter(color: AppTheme.textPrimaryColor),
                    decoration: InputDecoration(
                      hintText: "Enter issue or reason",
                      hintStyle: GoogleFonts.inter(color: AppTheme.textSecondaryColor.withOpacity(0.5)),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.black.withOpacity(0.04)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.black.withOpacity(0.04)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _isBooking ? null : _bookSlot,
                      icon: const Icon(Icons.event_available_rounded, color: Colors.white, size: 18),
                      label: _isBooking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              "Confirm Appointment",
                              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 240.ms, duration: 350.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 24),

            // Active/Upcoming appointments list title
            Text(
              "MY APPOINTMENTS",
              style: GoogleFonts.inter(color: AppTheme.textPrimaryColor, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            StreamBuilder<List<AppointmentItem>>(
              stream: db.streamPatientAppointments(auth.currentUser!.uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final appts = snap.data ?? [];
                if (appts.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: AppTheme.glassCardDecoration,
                    child: Center(
                      child: Text(
                        "No appointments found",
                        style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 13),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: appts.length,
                  itemBuilder: (context, index) {
                    final appt = appts[index];
                    final dateStr = "${appt.appointmentAt.day}/${appt.appointmentAt.month}/${appt.appointmentAt.year}";
                    final timeStr = "${appt.appointmentAt.hour.toString().padLeft(2, '0')}:${appt.appointmentAt.minute.toString().padLeft(2, '0')}";

                    Color statusColor = AppTheme.warningColor;
                    if (appt.status == 'confirmed') statusColor = AppTheme.successColor;
                    if (appt.status == 'declined') statusColor = AppTheme.errorColor;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: statusColor.withOpacity(0.2), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(17),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(width: 5, color: statusColor),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              appt.doctorName,
                                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor, fontSize: 15),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              appt.specialty,
                                              style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 12),
                                            ),
                                            const SizedBox(height: 10),
                                            Row(
                                              children: [
                                                Icon(Icons.calendar_today_outlined, size: 14, color: AppTheme.textSecondaryColor),
                                                const SizedBox(width: 4),
                                                Text(
                                                  dateStr,
                                                  style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 11),
                                                ),
                                                const SizedBox(width: 14),
                                                Icon(Icons.access_time_outlined, size: 14, color: AppTheme.textSecondaryColor),
                                                const SizedBox(width: 4),
                                                Text(
                                                  timeStr,
                                                  style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 11),
                                                ),
                                              ],
                                            ),
                                            if (appt.reason.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Text(
                                                "Reason: ${appt.reason}",
                                                style: GoogleFonts.inter(color: AppTheme.textSecondaryColor.withOpacity(0.8), fontSize: 11),
                                              ),
                                            ]
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: statusColor.withOpacity(0.25)),
                                        ),
                                        child: Text(
                                          appt.status.toUpperCase(),
                                          style: GoogleFonts.inter(color: statusColor, fontSize: 9.5, fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: (index % 6 * 50).ms, duration: 250.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut);
                  },
                );
              },
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

// --- TAB 3: CONSULTATION HISTORY ---
class _HistoryTab extends StatefulWidget {
  const _HistoryTab({Key? key}) : super(key: key);

  @override
  __HistoryTabState createState() => __HistoryTabState();
}

class __HistoryTabState extends State<_HistoryTab> with AutomaticKeepAliveClientMixin {
  int _expandedIndex = -1;
  final _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedFilter = "All";
  final List<String> _filters = ["All", "Completed", "Upcoming", "Cancelled"];

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getSpecialty(String doctorName) {
    final name = doctorName.toLowerCase();
    if (name.contains('dentist') || name.contains('dent')) return 'Dentist';
    if (name.contains('cardio') || name.contains('heart')) return 'Cardiologist';
    if (name.contains('pediatr') || name.contains('child')) return 'Pediatrician';
    if (name.contains('derm') || name.contains('skin')) return 'Dermatologist';
    if (name.contains('ortho') || name.contains('bone')) return 'Orthopedist';
    return 'General Physician';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = Provider.of<AuthService>(context);
    final db = Provider.of<DbService>(context);

    if (auth.currentUser == null) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          "Consultation History",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
        ),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimaryColor),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Search & Filter Panel
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              children: [
                // Search field
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black.withOpacity(0.04)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.inter(color: AppTheme.textPrimaryColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "Search by doctor or clinical note...",
                      hintStyle: GoogleFonts.inter(color: AppTheme.textSecondaryColor.withOpacity(0.5), fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondaryColor, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim().toLowerCase();
                      });
                    },
                  ),
                ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
                const SizedBox(height: 12),
                
                // Horizontal chips
                SizedBox(
                  height: 32,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    itemBuilder: (ctx, i) {
                      final filter = _filters[i];
                      final isSel = _selectedFilter == filter;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedFilter = filter;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isSel ? AppTheme.primaryColor : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSel ? AppTheme.primaryColor : Colors.black.withOpacity(0.02)),
                          ),
                          child: Center(
                            child: Text(
                              filter,
                              style: GoogleFonts.inter(
                                color: isSel ? Colors.white : AppTheme.textSecondaryColor,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ).animate().fadeIn(delay: 100.ms, duration: 300.ms).slideX(begin: 0.1, end: 0, curve: Curves.easeOut),
              ],
            ),
          ),
          
          Expanded(
            child: StreamBuilder<List<VisitItem>>(
              stream: db.streamPatientHistory(auth.currentUser!.uid),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final allVisits = snap.data ?? [];
                
                // Filter matches
                final filteredVisits = allVisits.where((v) {
                  // Text search filter
                  final matchQuery = v.doctor.toLowerCase().contains(_searchQuery) ||
                      v.notes.toLowerCase().contains(_searchQuery);
                  
                  // Chip filter (since all items in this visits collection are completed)
                  if (_selectedFilter == "Upcoming" || _selectedFilter == "Cancelled") {
                    return false; // Visits collection only contains actual completed sessions
                  }
                  
                  return matchQuery;
                }).toList();

                if (filteredVisits.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_toggle_off, size: 48, color: AppTheme.textSecondaryColor.withOpacity(0.5)),
                          const SizedBox(height: 12),
                          Text(
                            _selectedFilter == "Upcoming" || _selectedFilter == "Cancelled"
                                ? "No $_selectedFilter sessions found.\nGo to 'Book Slot' to schedule slots."
                                : "No previous consultation records found.",
                            style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 14, height: 1.5),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  itemCount: filteredVisits.length,
                  itemBuilder: (ctx, idx) {
                    final v = filteredVisits[idx];
                    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(v.visitedAt);
                    final isExpanded = _expandedIndex == idx;
                    final specialty = _getSpecialty(v.doctor);
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: Colors.white,
                      elevation: 0,
                      clipBehavior: Clip.antiAlias,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black.withOpacity(0.04)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))
                          ],
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              onTap: () {
                                setState(() {
                                  _expandedIndex = isExpanded ? -1 : idx;
                                });
                              },
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      v.doctor,
                                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimaryColor),
                                    ),
                                  ),
                                  Text(
                                    "₹${v.fee.toStringAsFixed(0)}",
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 16),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        specialty,
                                        style: GoogleFonts.inter(fontSize: 10, color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        dateStr,
                                        style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 11),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: Icon(
                                isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                            if (isExpanded)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Divider(color: Color(0xFFF1F5F9)),
                                    const SizedBox(height: 8),
                                    Text(
                                      "Notes / Diagnosis",
                                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      v.notes.isNotEmpty ? v.notes : "No clinical notes.",
                                      style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimaryColor, height: 1.5),
                                    ),
                                    if (v.medications.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        "Medications",
                                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 12),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: v.medications.map((med) {
                                          final name = med['name'] ?? 'Med';
                                          final dosage = med['dosage'] ?? '';
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              border: Border.all(color: Colors.black.withOpacity(0.04)),
                                              borderRadius: BorderRadius.circular(8),
                                              boxShadow: [
                                                BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 4),
                                              ],
                                            ),
                                            child: Text(
                                              "$name ($dosage)",
                                              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textPrimaryColor),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                    if (v.patientInstructions.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        "Instructions",
                                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 12),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEEFBF7),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppTheme.successColor.withOpacity(0.2)),
                                        ),
                                        child: Text(
                                          v.patientInstructions,
                                          style: GoogleFonts.inter(color: const Color(0xFF15803D), fontSize: 12, height: 1.4),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        await PdfService.generateAndSharePrescription(v, auth.currentUser!.name ?? "Patient");
                                      },
                                      icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 18),
                                      label: Text("Download Prescription", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(double.infinity, 40),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        elevation: 0,
                                      ),
                                    ),
                                    if (v.invoiceId != null && v.invoiceId!.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text("Fetching payment receipt..."),
                                              duration: Duration(seconds: 1),
                                            ),
                                          );
                                          final receipt = await db.getReceipt(v.invoiceId!);
                                          if (receipt != null) {
                                            final paidAtTimestamp = receipt['paidAt'] as Timestamp?;
                                            final paidAt = paidAtTimestamp?.toDate() ?? v.visitedAt;
                                            await PdfService.generatePremiumReceipt(
                                              clinicName: "MediQue Clinic",
                                              patientName: auth.currentUser!.name ?? "Patient",
                                              doctorName: v.doctor,
                                              invoiceId: v.invoiceId!,
                                              amountPaid: (receipt['amountPaid'] as num?)?.toDouble() ?? v.fee,
                                              paymentMethod: receipt['paymentMethod'] ?? "UPI",
                                              txnRef: receipt['txnRef'] ?? "",
                                              approvalRefNo: receipt['approvalRefNo'] ?? "",
                                              responseCode: receipt['responseCode'] ?? "",
                                              transactionId: receipt['transactionId'] ?? "",
                                              paidAt: paidAt,
                                              selectedUpiApp: receipt['selectedUpiApp'] ?? "UPI App",
                                              isShare: false,
                                            );
                                          } else {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text("No UPI payment receipt found for this visit."),
                                                  backgroundColor: Colors.orange,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        icon: const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryColor, size: 18),
                                        label: Text("Re-download Payment Receipt", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                                          minimumSize: const Size(double.infinity, 40),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ).animate().slideY(begin: 0.1, end: 0, duration: 250.ms, curve: Curves.easeOut).fadeIn(delay: (idx % 6 * 50).ms, duration: 250.ms);
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

// --- TAB 4: CHAT WITH DOCTOR ---
class _ChatTab extends StatefulWidget {
  const _ChatTab({Key? key}) : super(key: key);

  @override
  __ChatTabState createState() => __ChatTabState();
}

class __ChatTabState extends State<_ChatTab> with AutomaticKeepAliveClientMixin {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = Provider.of<AuthService>(context);
    final db = Provider.of<DbService>(context);

    if (auth.currentUser == null) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              child: const Icon(Icons.person_rounded, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Dr. Consultant",
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimaryColor),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppTheme.successColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Online",
                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.normal),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimaryColor),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: db.streamChatMessages(auth.currentUser!.uid),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snap.data ?? [];
                
                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 40, color: AppTheme.textSecondaryColor.withOpacity(0.5)),
                          const SizedBox(height: 10),
                          Text(
                            "No messages yet. Send a note to the doctor if needed.",
                            style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemCount: messages.length,
                  itemBuilder: (ctx, idx) {
                    final msg = messages[idx];
                    final bool isMe = msg.senderId == auth.currentUser!.uid;
                    final timeStr = DateFormat('hh:mm a').format(msg.timestamp);

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        decoration: BoxDecoration(
                          color: isMe ? AppTheme.primaryColor : Colors.white,
                          border: isMe ? null : Border.all(color: Colors.black.withOpacity(0.04)),
                          borderRadius: BorderRadius.circular(16).copyWith(
                            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
                            bottomLeft: !isMe ? const Radius.circular(0) : const Radius.circular(16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.01),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(ctx).size.width * 0.75,
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg.text,
                              style: GoogleFonts.inter(
                                color: isMe ? Colors.white : AppTheme.textPrimaryColor,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              timeStr,
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                color: isMe ? Colors.white.withOpacity(0.7) : AppTheme.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 200.ms).slideX(
                        begin: isMe ? 0.15 : -0.15,
                        end: 0,
                        duration: 200.ms,
                        curve: Curves.easeOut,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 90),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.black.withOpacity(0.04), width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: GoogleFonts.inter(color: AppTheme.textPrimaryColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "Type message...",
                      hintStyle: GoogleFonts.inter(color: AppTheme.textSecondaryColor.withOpacity(0.5)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: AppTheme.primaryColor, size: 20),
                  onPressed: () async {
                    final text = _msgController.text.trim();
                    if (text.isEmpty) return;
                    _msgController.clear();
                    await db.sendChatMessage(
                      auth.currentUser!.uid,
                      auth.currentUser!.uid,
                      auth.currentUser!.name ?? "Patient",
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
        ],
      ),
    );
  }
}

// --- TAB 5: PATIENT PROFILE ---
class _ProfileTab extends StatefulWidget {
  const _ProfileTab({Key? key}) : super(key: key);

  @override
  __ProfileTabState createState() => __ProfileTabState();
}

class __ProfileTabState extends State<_ProfileTab> with AutomaticKeepAliveClientMixin {
  bool _isEditing = false;
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // New biodata controllers
  final _mobileController = TextEditingController();
  final _dobController = TextEditingController();
  final _addressController = TextEditingController();
  final _professionController = TextEditingController();
  final _emergencyContactController = TextEditingController();

  DateTime? _selectedDob;
  int _calculatedAge = 0;
  String _selectedGender = "male";

  final _formKey = GlobalKey<FormState>();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _mobileController.dispose();
    _dobController.dispose();
    _addressController.dispose();
    _professionController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  void _calculateAgeFromDob(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    setState(() {
      _selectedDob = dob;
      _calculatedAge = age;
      _dobController.text = DateFormat('yyyy-MM-dd').format(dob);
    });
  }

  void _startEditing(Map<String, dynamic> data) {
    setState(() {
      _isEditing = true;
      _nameController.text = data['name'] ?? "";
      _mobileController.text = data['mobile'] ?? "";
      _dobController.text = data['dob'] ?? "";
      _selectedDob = data['dob'] != null && data['dob'].toString().isNotEmpty
          ? DateTime.tryParse(data['dob'])
          : null;
      _calculatedAge = int.tryParse(data['age']?.toString() ?? "") ?? 0;
      _selectedGender = data['gender'] ?? "male";
      _addressController.text = data['address'] ?? "";
      _professionController.text = data['profession'] ?? "";
      _emergencyContactController.text = data['emergencyContact'] ?? "";
      _passwordController.clear();
    });
  }

  void _showChangeClinicDialog(BuildContext context, AuthService auth, DbService db) {
    final controller = TextEditingController(text: auth.clinicCode);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          scrollable: true,
          title: Text(
            "Change Active Clinic",
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Enter the unique clinic code provided by your doctor:",
                style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                style: GoogleFonts.inter(color: AppTheme.textPrimaryColor, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: "Clinic Code",
                  labelStyle: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                "Cancel",
                style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final inputCode = controller.text.trim().toUpperCase();
                if (inputCode.isEmpty) return;

                showDialog(
                  context: ctx,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );

                try {
                  String resolvedId = "";
                  if (inputCode == "CARE5E" || inputCode == "MEDIQ1" || inputCode == "123456" || inputCode.contains("5EEEA") || inputCode.contains("CARE")) {
                    resolvedId = "medique-b29ee";
                  } else {
                    final codeDoc = await FirebaseFirestore.instance.collection("clinic_codes").doc(inputCode).get();
                    if (codeDoc.exists) {
                      resolvedId = codeDoc.data()?["clinicId"] ?? "";
                    } else {
                      resolvedId = inputCode.toLowerCase();
                    }
                  }

                  final settingsDoc = await FirebaseFirestore.instance.doc("artifacts/$resolvedId/public/data/clinicSettings/settings").get();
                  
                  if (ctx.mounted) Navigator.of(ctx).pop(); // Dismiss loading

                  if (settingsDoc.exists) {
                    if (ctx.mounted) Navigator.of(ctx).pop(); // Close dialog
                    await auth.updateClinicId(resolvedId, inputCode);
                    await db.updateClinicId(resolvedId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Switched to clinic: $inputCode"),
                          backgroundColor: AppTheme.successColor,
                        ),
                      );
                    }
                  } else {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text("Error: Clinic code does not exist."),
                          backgroundColor: AppTheme.errorColor,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (ctx.mounted) Navigator.of(ctx).pop(); // Dismiss loading
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text("Error validating clinic: $e"),
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                "Switch Clinic",
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showOtpVerificationDialog(AuthService auth) {
    final otpController = TextEditingController();
    final otpFormKey = GlobalKey<FormState>();
    bool dialogLoading = false;
    String? dialogError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                "Verify Profile Update",
                style: GoogleFonts.inter(color: AppTheme.textPrimaryColor, fontWeight: FontWeight.bold),
              ),
              content: Form(
                key: otpFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "To save changes to your profile, we sent a 6-digit verification code to:\n${auth.currentUser?.email}",
                      style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 22, letterSpacing: 6, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
                      decoration: InputDecoration(
                        counterText: "",
                        hintText: "000000",
                        hintStyle: TextStyle(color: Colors.grey.withOpacity(0.3), letterSpacing: 6),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length != 6) {
                          return "Enter 6-digit code";
                        }
                        return null;
                      },
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        dialogError!,
                        style: GoogleFonts.inter(color: AppTheme.errorColor, fontSize: 12, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: dialogLoading ? null : () => Navigator.of(ctx).pop(),
                  child: Text(
                    "Cancel",
                    style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w600),
                  ),
                ),
                ElevatedButton(
                  onPressed: dialogLoading
                      ? null
                      : () async {
                          if (!otpFormKey.currentState!.validate()) return;
                          setDialogState(() {
                            dialogLoading = true;
                            dialogError = null;
                          });

                          try {
                            await auth.callOtpProvider('verifyOtp', <String, dynamic>{
                              'email': auth.currentUser!.email,
                              'otp': otpController.text.trim(),
                            });

                            final newName = _nameController.text.trim();
                            final newPassword = _passwordController.text.trim().isNotEmpty
                                ? _passwordController.text.trim()
                                : null;

                            await auth.updateProfileAndChangePassword(
                              newName: newName,
                              newPassword: newPassword,
                              mobile: _mobileController.text.trim(),
                              dob: _dobController.text.trim(),
                              age: _calculatedAge.toString(),
                              gender: _selectedGender,
                              address: _addressController.text.trim(),
                              profession: _professionController.text.trim(),
                              emergencyContact: _emergencyContactController.text.trim(),
                            );

                            if (ctx.mounted) {
                              Navigator.of(ctx).pop(); // Close dialog
                            }

                            setState(() {
                              _isEditing = false;
                              _passwordController.clear();
                            });

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Profile updated successfully!"),
                                  backgroundColor: AppTheme.successColor,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              dialogLoading = false;
                              dialogError = e.toString().replaceAll("Exception: ", "").replaceAll(RegExp(r'\[.*\]'), '');
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: dialogLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : Text(
                          "Verify & Save",
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _startProfileSave(AuthService auth) async {
    if (!_formKey.currentState!.validate()) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await auth.callOtpProvider('sendOtp', <String, dynamic>{
        'email': auth.currentUser!.email,
      });

      if (mounted) {
        Navigator.of(context).pop(); // Dismiss spinner
        _showOtpVerificationDialog(auth);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Dismiss spinner
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to send OTP: $e"),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Widget _buildProfileRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? "N/A" : value,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = Provider.of<AuthService>(context);
    final db = Provider.of<DbService>(context);

    if (auth.currentUser == null) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }

    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService.instance.localeNotifier,
      builder: (context, currentLang, _) {
        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            title: Text(
              LocalizationService.instance.translate('settings'),
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
            ),
            backgroundColor: AppTheme.backgroundColor,
            elevation: 0,
            centerTitle: false,
          ),
          body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.doc("artifacts/${auth.appId}/users/${auth.currentUser?.uid}").snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final patientData = snapshot.data?.data() as Map<String, dynamic>? ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2), width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 46,
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.08),
                        child: const Icon(Icons.person_rounded, size: 52, color: AppTheme.primaryColor),
                      ),
                    ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), curve: Curves.easeOutBack),
                  ),
                  const SizedBox(height: 24),
                  
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black.withOpacity(0.04)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!_isEditing) ...[
                            _buildProfileRow("Full Name", patientData['name'] ?? auth.currentUser?.name ?? "N/A", Icons.person_outline),
                            const Divider(color: Color(0xFFF1F5F9), height: 1),
                            _buildProfileRow("Email Address", auth.currentUser?.email ?? "N/A", Icons.email_outlined),
                            const Divider(color: Color(0xFFF1F5F9), height: 1),
                            _buildProfileRow("Mobile Number", patientData['mobile'] ?? "N/A", Icons.phone_outlined),
                            const Divider(color: Color(0xFFF1F5F9), height: 1),
                            _buildProfileRow("Date of Birth", "${patientData['dob'] ?? 'N/A'} (Age: ${patientData['age'] ?? 'N/A'})", Icons.calendar_today_outlined),
                            const Divider(color: Color(0xFFF1F5F9), height: 1),
                            _buildProfileRow("Gender", (patientData['gender'] ?? 'N/A').toString().toUpperCase(), Icons.wc_outlined),
                            const Divider(color: Color(0xFFF1F5F9), height: 1),
                            _buildProfileRow("Residential Address", patientData['address'] ?? "N/A", Icons.home_outlined),
                            const Divider(color: Color(0xFFF1F5F9), height: 1),
                            _buildProfileRow("Profession / Occupation", patientData['profession'] ?? "N/A", Icons.work_outline),
                            const Divider(color: Color(0xFFF1F5F9), height: 1),
                            _buildProfileRow("Emergency Contact", patientData['emergencyContact'] ?? "N/A", Icons.contact_phone_outlined),
                            const Divider(color: Color(0xFFF1F5F9), height: 1),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.apartment_outlined, color: AppTheme.primaryColor),
                              title: Text("Active Clinic Code", style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w600)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        auth.clinicCode,
                                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryColor, size: 20),
                                onPressed: () => _showChangeClinicDialog(context, auth, db),
                              ),
                            ),
                          ] else ...[
                            TextFormField(
                              controller: _nameController,
                              style: GoogleFonts.inter(color: AppTheme.textPrimaryColor, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: "Full Name",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                prefixIcon: const Icon(Icons.person_outline, size: 20),
                              ),
                              validator: (value) => value == null || value.trim().isEmpty ? "Name cannot be empty" : null,
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _mobileController,
                              keyboardType: TextInputType.phone,
                              style: GoogleFonts.inter(color: AppTheme.textPrimaryColor, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: "Mobile Number",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) return "Mobile is required";
                                if (!RegExp(r'^\d{10}$').hasMatch(value.trim())) return "Enter exactly 10 digits";
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _dobController,
                                    readOnly: true,
                                    style: GoogleFonts.inter(color: AppTheme.textPrimaryColor, fontSize: 13),
                                    decoration: InputDecoration(
                                      labelText: "Date of Birth",
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      suffixIcon: const Icon(Icons.calendar_today_rounded, size: 16),
                                    ),
                                    onTap: () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: _selectedDob ?? DateTime.now().subtract(const Duration(days: 365 * 30)),
                                        firstDate: DateTime(1900),
                                        lastDate: DateTime.now(),
                                      );
                                      if (date != null) {
                                        _calculateAgeFromDob(date);
                                      }
                                    },
                                    validator: (value) => value == null || value.isEmpty ? "DOB is required" : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  width: 80,
                                  height: 48,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade400),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "Age: $_calculatedAge",
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            DropdownButtonFormField<String>(
                              value: _selectedGender,
                              style: GoogleFonts.inter(color: AppTheme.textPrimaryColor, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: "Gender",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              items: const [
                                DropdownMenuItem(value: "male", child: Text("Male")),
                                DropdownMenuItem(value: "female", child: Text("Female")),
                                DropdownMenuItem(value: "other", child: Text("Other")),
                              ],
                              onChanged: (val) => setState(() => _selectedGender = val!),
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _addressController,
                              style: GoogleFonts.inter(color: AppTheme.textPrimaryColor, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: "Residential Address",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                prefixIcon: const Icon(Icons.home_outlined, size: 20),
                              ),
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _professionController,
                              style: GoogleFonts.inter(color: AppTheme.textPrimaryColor, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: "Profession / Occupation",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                prefixIcon: const Icon(Icons.work_outline, size: 20),
                              ),
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _emergencyContactController,
                              style: GoogleFonts.inter(color: AppTheme.textPrimaryColor, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: "Emergency Contact Phone",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                prefixIcon: const Icon(Icons.contact_phone_outlined, size: 20),
                              ),
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              style: GoogleFonts.inter(color: AppTheme.textPrimaryColor, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: "New Password (optional)",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                              ),
                              validator: (value) {
                                if (value != null && value.isNotEmpty && value.trim().length < 6) {
                                  return "Password must be at least 6 characters";
                                }
                                return null;
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 100.ms, duration: 350.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
                  const SizedBox(height: 16),

                  if (!_isEditing)
                    ElevatedButton.icon(
                      onPressed: () {
                        _startEditing(patientData);
                      },
                      icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
                      label: Text("Edit Profile Details", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ).animate().fadeIn(delay: 150.ms, duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut)
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _isEditing = false;
                                _passwordController.clear();
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textSecondaryColor,
                              side: BorderSide(color: Colors.black.withOpacity(0.08)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Text("Cancel", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _startProfileSave(auth),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.secondaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: Text("Save & Verify", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  
                  const SizedBox(height: 16),

                  StreamBuilder<List<VisitItem>>(
                    stream: db.streamPatientHistory(auth.currentUser!.uid),
                    builder: (context, snap) {
                      final visits = snap.data ?? [];
                      final totalSpent = visits.fold<double>(0, (sum, v) => sum + v.fee);
                      return Row(
                        children: [
                          Expanded(
                            child: Card(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                              child: Container(
                                padding: const EdgeInsets.all(16.0),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.black.withOpacity(0.04)),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Text("Total Visits", style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 11, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 6),
                                    Text(
                                      "${visits.length}",
                                      style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Card(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                              child: Container(
                                padding: const EdgeInsets.all(16.0),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.black.withOpacity(0.04)),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Text("Total Spent", style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 11, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 6),
                                    Text(
                                      "₹${totalSpent.toStringAsFixed(0)}",
                                      style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.successColor),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ).animate().fadeIn(delay: 200.ms, duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
                  const SizedBox(height: 24),
                  
                  // Language Selector Dropdown Card
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black.withOpacity(0.04)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))
                        ],
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
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryColor),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: currentLang,
                            style: GoogleFonts.inter(color: AppTheme.textPrimaryColor, fontSize: 13),
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
                                  isStaff: false,
                                  appId: auth.appId,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 250.ms, duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
                  const SizedBox(height: 16),

                  // Sound & Vibration Settings Card
                  AnimatedBuilder(
                    animation: NotificationService.instance,
                    builder: (context, _) {
                      final service = NotificationService.instance;
                      return Card(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                        child: Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.black.withOpacity(0.04)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.volume_up_rounded, color: AppTheme.primaryColor),
                                  const SizedBox(width: 12),
                                  Text(
                                    "Sound & Vibration Settings",
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryColor),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              // Sound Toggle
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                activeColor: AppTheme.primaryColor,
                                title: Text(
                                  "Sound Alerts",
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor),
                                ),
                                subtitle: Text(
                                  "Play sound on queue events",
                                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondaryColor),
                                ),
                                value: service.soundEnabled,
                                onChanged: (val) => service.setSoundEnabled(val),
                              ),
                              
                              // Sound Profile Selector
                              if (service.soundEnabled) ...[
                                const Divider(color: Color(0xFFF1F5F9), height: 1),
                                const SizedBox(height: 12),
                                Text(
                                  "Sound Profile",
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondaryColor),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: service.soundProfile,
                                  style: GoogleFonts.inter(color: AppTheme.textPrimaryColor, fontSize: 13),
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: "default", child: Text("Default Notification Tone")),
                                    DropdownMenuItem(value: "alarm", child: Text("Loud Alarm (High Priority)")),
                                    DropdownMenuItem(value: "ringtone", child: Text("Standard Ringtone")),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      service.setSoundProfile(val);
                                      service.playSound('turn');
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),
                              ],
                              
                              const Divider(color: Color(0xFFF1F5F9), height: 1),
                              
                              // Vibration Toggle
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                activeColor: AppTheme.primaryColor,
                                title: Text(
                                  "Vibration Alerts",
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor),
                                ),
                                subtitle: Text(
                                  "Vibrate device on alerts",
                                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondaryColor),
                                ),
                                value: service.vibrationEnabled,
                                onChanged: (val) => service.setVibrationEnabled(val),
                              ),
                              
                              // Test Vibration Patterns
                              if (service.vibrationEnabled) ...[
                                const Divider(color: Color(0xFFF1F5F9), height: 1),
                                const SizedBox(height: 12),
                                Text(
                                  "Test Vibration Patterns",
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondaryColor),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton(
                                      onPressed: () => service.triggerVibration('update'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: Text("Short", style: GoogleFonts.inter(fontSize: 11, color: AppTheme.primaryColor)),
                                    ),
                                    OutlinedButton(
                                      onPressed: () => service.triggerVibration('ahead_1'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: Text("Medium", style: GoogleFonts.inter(fontSize: 11, color: AppTheme.primaryColor)),
                                    ),
                                    OutlinedButton(
                                      onPressed: () => service.triggerVibration('turn'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: Text("Long Pattern", style: GoogleFonts.inter(fontSize: 11, color: AppTheme.primaryColor)),
                                    ),
                                    OutlinedButton(
                                      onPressed: () => service.triggerVibration('emergency'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: Text("Emergency", style: GoogleFonts.inter(fontSize: 11, color: AppTheme.primaryColor)),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ).animate().fadeIn(delay: 300.ms, duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
                  const SizedBox(height: 16),
                  
                  // Clinic Information Card
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.doc("artifacts/${auth.appId}/public/data/clinicSettings/scheduling").snapshots(),
                    builder: (context, schedSnap) {
                      return StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance.doc("artifacts/${auth.appId}/public/data/clinicSettings/leaveDates").snapshots(),
                        builder: (context, leaveSnap) {
                          String startHours = "09:00";
                          String endHours = "18:00";
                          List<String> leaves = [];

                          if (schedSnap.hasData && schedSnap.data!.exists) {
                            final data = schedSnap.data!.data() as Map<String, dynamic>? ?? {};
                            final workingHours = data['workingHours'] as Map<String, dynamic>?;
                            if (workingHours != null) {
                              startHours = workingHours['start'] ?? "09:00";
                              endHours = workingHours['end'] ?? "18:00";
                            }
                          }

                          if (leaveSnap.hasData && leaveSnap.data!.exists) {
                            final data = leaveSnap.data!.data() as Map<String, dynamic>? ?? {};
                            final datesVal = data['dates'];
                            if (datesVal != null && datesVal is List) {
                              leaves = datesVal.map((e) => e.toString()).toList();
                            }
                          }

                          return Card(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                            child: Container(
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.black.withOpacity(0.04)),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.info_outline_rounded, color: AppTheme.primaryColor),
                                      const SizedBox(width: 12),
                                      Text(
                                        "Clinic Information",
                                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryColor),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("Operating Hours", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondaryColor)),
                                      Text("$startHours - $endHours", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor)),
                                    ],
                                  ),
                                  const Divider(height: 20, color: Color(0xFFF1F5F9)),
                                  Text("Scheduled Leave Days", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondaryColor)),
                                  const SizedBox(height: 8),
                                  if (leaves.isEmpty)
                                    Text("No scheduled leave days", style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondaryColor, fontStyle: FontStyle.italic))
                                  else
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: leaves.map((date) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.errorColor.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppTheme.errorColor.withOpacity(0.12)),
                                          ),
                                          child: Text(
                                            date,
                                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.errorColor),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ).animate().fadeIn(delay: 350.ms, duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
                  const SizedBox(height: 16),

                  // My Receipts Card
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black.withOpacity(0.04)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))
                        ],
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryColor),
                        title: Text(
                          LocalizationService.instance.translate('my_receipts'),
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryColor),
                        ),
                        subtitle: Text(
                          LocalizationService.instance.translate('receipt_history'),
                          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondaryColor),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondaryColor),
                        onTap: () => _showReceiptsHistoryBottomSheet(context, auth),
                      ),
                    ),
                  ).animate().fadeIn(delay: 400.ms, duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
                  const SizedBox(height: 16),
                  
                  ElevatedButton.icon(
                    onPressed: () async {
                      await auth.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const SplashScreen()),
                          (route) => false,
                        );
                      }
                    },
                    icon: const Icon(Icons.logout, color: Colors.white),
                    label: Text(LocalizationService.instance.translate('logout'), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ).animate().fadeIn(delay: 450.ms, duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          );
        },
      ),
    );
      },
    );
  }

  void _showReceiptsHistoryBottomSheet(BuildContext context, AuthService auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("artifacts/${auth.appId}/users/${auth.currentUser?.uid}/receipts")
                  .orderBy("timestamp", descending: true)
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
                      Text(
                        LocalizationService.instance.translate('receipt_history'),
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (docs.isEmpty)
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long_rounded,
                                  size: 48,
                                  color: AppTheme.textSecondaryColor.withOpacity(0.4),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  LocalizationService.instance.translate('no_receipts'),
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
                              final docName = data['doctorName'] ?? 'Doctor';
                              final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                              final paymentMethod = data['paymentMethod'] ?? 'upi';
                              final token = data['token'] ?? '';
                              final reason = data['reason'] ?? 'Consultation';
                              final timestamp = data['timestamp'] as Timestamp?;
                              
                              final dateStr = timestamp != null
                                  ? DateFormat.yMMMd().add_jm().format(timestamp.toDate())
                                  : '';
                                  
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.black.withOpacity(0.04)),
                                ),
                                elevation: 0,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  title: Text(
                                    docName,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppTheme.textPrimaryColor,
                                    ),
                                  ),
                                  subtitle: Text(
                                    "$dateStr • ${paymentMethod.toUpperCase()}",
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "₹${amount.toStringAsFixed(0)}",
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppTheme.successColor,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.share_outlined, size: 20, color: AppTheme.primaryColor),
                                    ],
                                  ),
                                  onTap: () async {
                                    await PdfService.generateAndPrintInvoice(
                                      patientName: data['patientName'] ?? auth.currentUser?.name ?? 'Patient',
                                      doctorName: docName,
                                      amount: amount,
                                      paymentMethod: paymentMethod,
                                      token: token,
                                      reason: reason,
                                    );
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
}

class QRScannerScreen extends StatefulWidget {
  final Function(String) onScan;

  const QRScannerScreen({Key? key, required this.onScan}) : super(key: key);

  @override
  _QRScannerScreenState createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Scan Clinic QR Code", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_hasScanned) return;
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? code = barcode.rawValue;
                if (code != null && code.isNotEmpty) {
                  setState(() {
                    _hasScanned = true;
                  });
                  widget.onScan(code);
                  Navigator.of(context).pop(); // Go back to dashboard
                  break;
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 20,
            right: 20,
            child: Text(
              "Center the QR code inside the box to scan",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          )
        ],
      ),
    );
  }
}



class _BroadcastTab extends StatefulWidget {
  const _BroadcastTab({Key? key}) : super(key: key);

  @override
  __BroadcastTabState createState() => __BroadcastTabState();
}

class __BroadcastTabState extends State<_BroadcastTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = Provider.of<AuthService>(context);
    final db = Provider.of<DbService>(context);

    if (auth.currentUser == null) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          "Broadcasts & Updates",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
        ),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // News Ticker Stream
            StreamBuilder<DocumentSnapshot>(
              stream: db.streamNewsTicker(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const SizedBox.shrink();
                }
                final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                final text = data['text'] ?? '';
                final bool isActive = data['isActive'] ?? true;
                if (text.isEmpty || !isActive) {
                  return const SizedBox.shrink();
                }
                return Container(
                  color: AppTheme.primaryColor.withOpacity(0.08),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.campaign, color: AppTheme.primaryColor, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            text,
                            style: GoogleFonts.inter(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0, curve: Curves.easeOut);
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: db.streamBroadcastMessages(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
                  }
                  final messages = snapshot.data ?? [];
                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 48, color: AppTheme.textSecondaryColor.withOpacity(0.5)),
                          const SizedBox(height: 12),
                          Text(
                            "No announcements yet",
                            style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final content = msg['text'] ?? msg['content'] ?? '';
                      final createdAtVal = msg['createdAt'] ?? msg['sentAt'];
                      String dateStr = "Recent";
                      if (createdAtVal != null && createdAtVal is Timestamp) {
                        dateStr = DateFormat.yMMMd().add_jm().format(createdAtVal.toDate());
                      }
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.black.withOpacity(0.04)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                    child: const Icon(Icons.announcement_outlined, color: AppTheme.primaryColor, size: 14),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Clinic Announcement",
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimaryColor),
                                  ),
                                  const Spacer(),
                                  Text(
                                    dateStr,
                                    style: GoogleFonts.inter(fontSize: 9, color: AppTheme.textSecondaryColor),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                content,
                                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimaryColor, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: (index % 6 * 60).ms, duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
