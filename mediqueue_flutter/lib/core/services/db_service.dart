import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import '../utils.dart';

class QueueItem {
  final String id;
  final String name;
  final String mobile;
  final String issue;
  final String patientId;
  final String status;
  final String? token;
  final String? doctorId;
  final String? doctorName;
  final String? specialty;
  final DateTime? joinedAt;
  final DateTime? completedAt;
  final double? fee;
  final String? paymentMethod;
  final String? paymentRequestStatus;
  final String? priority;

  // Billing & Pacing fields
  final String? invoiceNumber;
  final double? consultationFee;
  final double? serviceCharges;
  final double? labTests;
  final double? medicationCharges;
  final double? totalAmount;
  final String? paymentStatus;
  final double? amountPaid;
  final int? predictedWait;

  QueueItem({
    required this.id,
    required this.name,
    required this.mobile,
    required this.issue,
    required this.patientId,
    required this.status,
    this.token,
    this.doctorId,
    this.doctorName,
    this.specialty,
    this.joinedAt,
    this.completedAt,
    this.fee,
    this.paymentMethod,
    this.paymentRequestStatus,
    this.priority,
    this.invoiceNumber,
    this.consultationFee,
    this.serviceCharges,
    this.labTests,
    this.medicationCharges,
    this.totalAmount,
    this.paymentStatus,
    this.amountPaid,
    this.predictedWait,
  });

  factory QueueItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final Timestamp? t = data['joinedAt'];
    final Timestamp? comp = data['completedAt'];
    return QueueItem(
      id: doc.id,
      name: data['name'] ?? "",
      mobile: data['mobile'] ?? "",
      issue: data['issue'] ?? "",
      patientId: data['patientId'] ?? "",
      status: data['status'] ?? "",
      token: data['token']?.toString(),
      doctorId: data['doctorId'],
      doctorName: data['doctorName'],
      specialty: data['specialty'],
      joinedAt: t?.toDate(),
      completedAt: comp?.toDate(),
      fee: (data['fee'] as num?)?.toDouble(),
      paymentMethod: data['paymentMethod'],
      paymentRequestStatus: data['paymentRequestStatus'],
      priority: data['priority']?.toString(),
      invoiceNumber: data['invoiceNumber']?.toString(),
      consultationFee: (data['consultationFee'] as num?)?.toDouble(),
      serviceCharges: (data['serviceCharges'] as num?)?.toDouble(),
      labTests: (data['labTests'] as num?)?.toDouble(),
      medicationCharges: (data['medicationCharges'] as num?)?.toDouble(),
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? (data['fee'] as num?)?.toDouble(),
      paymentStatus: data['paymentStatus']?.toString(),
      amountPaid: (data['amountPaid'] as num?)?.toDouble(),
      predictedWait: (data['predictedWait'] as num?)?.toInt(),
    );
  }
}

class VisitItem {
  final String id;
  final DateTime visitedAt;
  final String notes;
  final String patientInstructions;
  final double fee;
  final String doctor;
  final List<dynamic> medications;
  final String? invoiceId;

  VisitItem({
    required this.id,
    required this.visitedAt,
    required this.notes,
    required this.patientInstructions,
    required this.fee,
    required this.doctor,
    required this.medications,
    this.invoiceId,
  });

  factory VisitItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final Timestamp t = data['visitedAt'] ?? Timestamp.now();
    return VisitItem(
      id: doc.id,
      visitedAt: t.toDate(),
      notes: data['notes'] ?? "",
      patientInstructions: data['patientInstructions'] ?? "",
      fee: (data['fee'] as num?)?.toDouble() ?? 0.0,
      doctor: data['doctor'] ?? "Doctor",
      medications: data['medications'] ?? [],
      invoiceId: data['invoiceId']?.toString(),
    );
  }
}

class ClinicSettings {
  final String doctorName;
  final String upiId;
  final double latitude;
  final double longitude;
  final String? bharatPeQrUrl;

  ClinicSettings({
    required this.doctorName,
    required this.upiId,
    required this.latitude,
    required this.longitude,
    this.bharatPeQrUrl,
  });

  factory ClinicSettings.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ClinicSettings(
      doctorName: data['doctorName'] ?? "Clinic Doctor",
      upiId: data['upiId'] ?? "prajansanjayko@okaxis",
      latitude: double.tryParse(data['latitude']?.toString() ?? "") ?? 13.0,
      longitude: double.tryParse(data['longitude']?.toString() ?? "") ?? 80.0,
      bharatPeQrUrl: data['bharatPeQrUrl'] as String?,
    );
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final String senderName;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.senderName,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final Timestamp t = data['timestamp'] ?? data['createdAt'] ?? Timestamp.now();
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? "",
      text: data['text'] ?? "",
      timestamp: t.toDate(),
      senderName: data['senderName'] ?? "",
    );
  }
}

class ChatRoomItem {
  final String patientId;
  final String patientName;
  final String lastMessageText;
  final DateTime lastMessageTime;
  final String lastMessageBy;
  final bool doctorRead;
  final bool patientRead;

  ChatRoomItem({
    required this.patientId,
    required this.patientName,
    required this.lastMessageText,
    required this.lastMessageTime,
    required this.lastMessageBy,
    required this.doctorRead,
    required this.patientRead,
  });

  factory ChatRoomItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final Timestamp t = data['lastMessageTime'] ?? data['lastMessageAt'] ?? Timestamp.now();
    return ChatRoomItem(
      patientId: data['patientId'] ?? doc.id,
      patientName: data['patientName'] ?? "Patient",
      lastMessageText: data['lastMessageText'] ?? "No messages yet",
      lastMessageTime: t.toDate(),
      lastMessageBy: data['lastMessageBy'] ?? "",
      doctorRead: data['doctorRead'] ?? true,
      patientRead: data['patientRead'] ?? true,
    );
  }
}

class AppointmentItem {
  final String id;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final String specialty;
  final DateTime appointmentAt;
  final String status;
  final String reason;

  AppointmentItem({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.specialty,
    required this.appointmentAt,
    required this.status,
    required this.reason,
  });

  factory AppointmentItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final Timestamp t = data['appointmentAt'] ?? Timestamp.now();
    return AppointmentItem(
      id: doc.id,
      patientId: data['patientId'] ?? "",
      patientName: data['patientName'] ?? "",
      doctorId: data['doctorId'] ?? "",
      doctorName: data['doctorName'] ?? "",
      specialty: data['specialty'] ?? "",
      appointmentAt: t.toDate(),
      status: data['status'] ?? "pending",
      reason: data['reason'] ?? "",
    );
  }
}

class DbService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  String _appId = "medique-b29ee";
  String get appId => _appId;

  DbService(String initialId) {
    _appId = initialId;
    try {
      _db.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      debugPrint("Firestore settings error (persistence already enabled): $e");
    }
  }

  Future<void> updateClinicId(String newId) async {
    _appId = newId;
    notifyListeners();
  }

  // Stream of patient's active queue document
  Stream<List<QueueItem>> streamPatientActiveQueue(String patientId) {
    return _db
        .collection("artifacts/$appId/public/data/queue")
        .where("patientId", isEqualTo: patientId)
        .where("status", whereIn: ["waiting", "pre_registered", "calling", "pending_payment"])
        .snapshots()
        .map((snap) => snap.docs.map((doc) => QueueItem.fromFirestore(doc)).toList());
  }

  int _getPriorityScore(QueueItem item) {
    final priority = (item.priority ?? 'normal').toLowerCase();
    switch (priority) {
      case 'emergency':
        return 50;
      case 'senior_citizen':
        return 40;
      case 'pregnant':
        return 30;
      case 'disabled':
        return 20;
      case 'normal':
      default:
        return 10;
    }
  }

  // Stream of doctor's queue (only waiting, calling, pending_payment)
  Stream<List<QueueItem>> streamDoctorQueue(String doctorId) {
    return _db
        .collection("artifacts/$appId/public/data/queue")
        .where("doctorId", isEqualTo: doctorId)
        .where("status", whereIn: ["waiting", "calling", "pending_payment"])
        .snapshots()
        .map((snap) {
          final items = snap.docs.map((doc) => QueueItem.fromFirestore(doc)).toList();
          // Sort by calling state, then priority, then joinedAt
          items.sort((a, b) {
            if (a.status == 'calling' && b.status != 'calling') return -1;
            if (b.status == 'calling' && a.status != 'calling') return 1;
            
            if (a.status == 'pending_payment' && b.status != 'pending_payment') return 1;
            if (b.status == 'pending_payment' && a.status != 'pending_payment') return -1;

            final scoreA = _getPriorityScore(a);
            final scoreB = _getPriorityScore(b);
            if (scoreA != scoreB) {
              return scoreB.compareTo(scoreA);
            }

            if (a.joinedAt == null) return 1;
            if (b.joinedAt == null) return -1;
            return a.joinedAt!.compareTo(b.joinedAt!);
          });
          return items;
        });
  }

  // Stream of receptionist's complete queue for today
  Stream<List<QueueItem>> streamReceptionistQueue() {
    return _db
        .collection("artifacts/$appId/public/data/queue")
        .snapshots()
        .map((snap) {
          final items = snap.docs.map((doc) => QueueItem.fromFirestore(doc)).toList();
          final now = DateTime.now();
          final startOfToday = DateTime(now.year, now.month, now.day);
          
          final filtered = items.where((item) {
            // Include active status items (including pending timestamps)
            if (item.status == 'waiting' || 
                item.status == 'calling' || 
                item.status == 'pending_payment' || 
                item.status == 'pre_registered') {
              return true;
            }
            // Include seen/completed items if they occurred today
            if (item.status == 'seen' || item.status == 'completed') {
              if (item.joinedAt != null && item.joinedAt!.isAfter(startOfToday)) {
                return true;
              }
              // If timestamp is null (locally pending save), include it
              if (item.joinedAt == null) {
                return true;
              }
            }
            return false;
          }).toList();

          // Sort by calling state, priority, then joinedAt
          filtered.sort((a, b) {
            if (a.status == 'calling' && b.status != 'calling') return -1;
            if (b.status == 'calling' && a.status != 'calling') return 1;
            
            if (a.status == 'pending_payment' && b.status != 'pending_payment') return 1;
            if (b.status == 'pending_payment' && a.status != 'pending_payment') return -1;

            final scoreA = _getPriorityScore(a);
            final scoreB = _getPriorityScore(b);
            if (scoreA != scoreB) {
              return scoreB.compareTo(scoreA);
            }

            if (a.joinedAt == null) return 1;
            if (b.joinedAt == null) return -1;
            return a.joinedAt!.compareTo(b.joinedAt!);
          });
          return filtered;
        });
  }

  // Stream of clinic settings
  Stream<ClinicSettings> streamSettings() {
    return _db
        .doc("artifacts/$appId/public/data/clinicSettings/settings")
        .snapshots()
        .map((snap) => ClinicSettings.fromFirestore(snap));
  }

  // Stream of dynamic average consultation time (in minutes) from completed visits today
  Stream<double> streamAverageConsultationTime() {
    return _db
        .collection("artifacts/$appId/public/data/queue")
        .snapshots()
        .map((snap) {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);

      final completedDocs = snap.docs.where((doc) {
        final data = doc.data();
        final Timestamp? joinedAt = data['joinedAt'];
        
        // Match today's seen or calling docs
        final bool isToday = (joinedAt != null && joinedAt.toDate().isAfter(startOfToday)) || joinedAt == null;
        if (!isToday) return false;

        return (data['status'] == 'seen' || data['status'] == 'pending_payment' || data['status'] == 'completed') &&
            data['calledAt'] != null &&
            (data['consultationCompletedAt'] != null || data['completedAt'] != null);
      }).toList();

      if (completedDocs.isEmpty) {
        return 15.0; // fallback default matching web settings
      }

      double totalMinutes = 0;
      int count = 0;
      for (var doc in completedDocs) {
        final data = doc.data();
        final Timestamp? calledAt = data['calledAt'];
        final Timestamp? completedAt = data['consultationCompletedAt'] ?? data['completedAt'];
        if (calledAt != null && completedAt != null) {
          final diff = completedAt.toDate().difference(calledAt.toDate()).inMinutes;
          if (diff >= 0) {
            totalMinutes += diff;
            count++;
          }
        }
      }

      if (count == 0) return 15.0;
      return totalMinutes / count;
    });
  }

  // Stream of dynamic doctor-specific average consultation time (in minutes) from today's wacdSnapshots
  Stream<double> streamDoctorAverageConsultationTime(String doctorId) {
    final String today = DateTime.now().toIso8601String().split('T')[0];
    return _db
        .collection("artifacts/$appId/public/data/wacdSnapshots")
        .doc(today)
        .snapshots()
        .map((snap) {
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>?;
        if (data != null) {
          if (data['doctorWACDs'] != null && data['doctorWACDs'][doctorId] != null) {
            return (data['doctorWACDs'][doctorId] as num).toDouble();
          } else if (data['globalWACD'] != null) {
            return (data['globalWACD'] as num).toDouble();
          }
        }
      }
      return 12.0; // fallback standard WACD
    });
  }

  // Stream of chat messages
  Stream<List<ChatMessage>> streamChatMessages(String patientId) {
    return _db
        .collection("artifacts/$appId/public/data/chatRooms/$patientId/messages")
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList());
  }

  // Send message
  Future<void> sendChatMessage(String patientId, String senderId, String senderName, String text) async {
    final bool isPatient = senderId == patientId;
    
    // 1. Add message document
    await _db.collection("artifacts/$appId/public/data/chatRooms/$patientId/messages").add({
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'type': 'text',
      'createdAt': FieldValue.serverTimestamp(),
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });

    // 2. Update chat room summary document
    final String lastMessageBy = isPatient ? 'patient' : 'doctor';
    await _db.collection("artifacts/$appId/public/data/chatRooms").doc(patientId).set({
      'patientId': patientId,
      'patientName': isPatient ? senderName : FieldValue.increment(0),
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageText': text.length > 50 ? "${text.substring(0, 47)}..." : text,
      'lastMessageBy': lastMessageBy,
      'doctorRead': !isPatient,
      'patientRead': isPatient,
    }, SetOptions(merge: true));
  }

  // Mark chat as read
  Future<void> markChatAsRead(String patientId, String role) async {
    final Map<String, dynamic> update = {};
    if (role == 'doctor') {
      update['doctorRead'] = true;
    } else {
      update['patientRead'] = true;
    }
    await _db.collection("artifacts/$appId/public/data/chatRooms").doc(patientId).set(update, SetOptions(merge: true));
  }

  // Stream of patient's appointments
  Stream<List<AppointmentItem>> streamPatientAppointments(String patientId) {
    return _db
        .collection("artifacts/$appId/public/data/appointments")
        .where("patientId", isEqualTo: patientId)
        .snapshots()
        .map((snap) {
          final items = snap.docs.map((doc) => AppointmentItem.fromFirestore(doc)).toList();
          items.sort((a, b) => a.appointmentAt.compareTo(b.appointmentAt));
          return items;
        });
  }

  // Book an appointment slot
  Future<void> bookAppointment({
    required String patientId,
    required String patientName,
    required String doctorId,
    required String doctorName,
    required String specialty,
    required DateTime appointmentAt,
    required String reason,
  }) async {
    // Check if slot is already booked (double-booking protection)
    final startOfDay = DateTime(appointmentAt.year, appointmentAt.month, appointmentAt.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    final snap = await _db
        .collection("artifacts/$appId/public/data/appointments")
        .where("appointmentAt", isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where("appointmentAt", isLessThan: Timestamp.fromDate(endOfDay))
        .where("status", whereIn: ["pending", "confirmed"])
        .get();

    for (var doc in snap.docs) {
      final apptTime = (doc.data()['appointmentAt'] as Timestamp).toDate();
      if (apptTime.isAtSameMomentAs(appointmentAt) && doc.data()['doctorId'] == doctorId) {
        throw Exception("This slot is already booked. Please select another slot.");
      }
    }

    await _db.collection("artifacts/$appId/public/data/appointments").add({
      'patientId': patientId,
      'patientName': patientName,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'specialty': specialty,
      'appointmentAt': Timestamp.fromDate(appointmentAt),
      'status': 'pending',
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
      'source': 'mobile_app',
    });
  }

  // Stream all clinic appointments (for doctor or receptionist)
  Stream<List<AppointmentItem>> streamClinicAppointments() {
    return _db
        .collection("artifacts/$appId/public/data/appointments")
        .snapshots()
        .map((snap) {
          final items = snap.docs.map((doc) => AppointmentItem.fromFirestore(doc)).toList();
          items.sort((a, b) => b.appointmentAt.compareTo(a.appointmentAt)); // Show latest first
          return items;
        });
  }

  // Update appointment status
  Future<void> updateAppointmentStatus(String apptId, String status) async {
    await _db
        .collection("artifacts/$appId/public/data/appointments")
        .doc(apptId)
        .update({
          'status': status,
        });
  }

  // Check in patient from an appointment
  Future<void> checkInAppointment({
    required String apptId,
    required String patientId,
    required String patientName,
    required String doctorId,
    required String doctorName,
    required String specialty,
    required String reason,
  }) async {
    // Get current queue count for token assignment
    final queueSnap = await _db.collection("artifacts/$appId/public/data/queue").get();
    final token = 'T-${queueSnap.size + 1}';

    // 1. Create queue document
    await _db.collection("artifacts/$appId/public/data/queue").add({
      'name': patientName,
      'mobile': '', 
      'issue': reason,
      'patientId': patientId,
      'status': 'waiting',
      'joinedAt': FieldValue.serverTimestamp(),
      'doctorId': doctorId,
      'doctorName': doctorName,
      'specialty': specialty,
      'source': 'mobile_app',
      'token': token,
    });

    // 2. Mark appointment as checked_in
    await _db.collection("artifacts/$appId/public/data/appointments").doc(apptId).update({
      'status': 'checked_in',
    });
  }

  // Get active doctors list for auto-assignment / receptionist dropdowns
  Future<List<Map<String, dynamic>>> getActiveDoctors() async {
    final snap = await _db
        .collection("artifacts/$appId/public/data/staff")
        .where("role", isEqualTo: "doctor")
        .where("isActive", isEqualTo: true)
        .get();
    return snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  // Auto-assign doctor based on issue/shortest queue
  Future<Map<String, dynamic>> autoAssignDoctor(String issue) async {
    final doctors = await getActiveDoctors();
    if (doctors.isEmpty) {
      return {'doctorId': null, 'doctorName': "General Physician", 'specialty': "General"};
    }

    // Sort by active queue length
    final queueSnap = await _db
        .collection("artifacts/$appId/public/data/queue")
        .where("status", whereIn: ["waiting", "calling", "pending_payment"])
        .get();
    
    final Map<String, int> doctorQueueCounts = {};
    for (var d in doctors) {
      doctorQueueCounts[d['id']] = 0;
    }
    for (var qDoc in queueSnap.docs) {
      final docId = qDoc.data()['doctorId'];
      if (doctorQueueCounts.containsKey(docId)) {
        doctorQueueCounts[docId] = doctorQueueCounts[docId]! + 1;
      }
    }

    doctors.sort((a, b) {
      final countA = doctorQueueCounts[a['id']] ?? 0;
      final countB = doctorQueueCounts[b['id']] ?? 0;
      return countA.compareTo(countB);
    });

    final selected = doctors.first;
    return {
      'doctorId': selected['id'],
      'doctorName': selected['name'] ?? "Doctor",
      'specialty': selected['specialization'] ?? "General",
    };
  }

  // Join Live Queue (Verify Geofencing distance)
  Future<String> joinQueue(String name, String phone, String issue, String patientId, bool isPreRegistered) async {
    // 1. Get Clinic Coordinates from settings
    final settingsDoc = await _db.doc("artifacts/$appId/public/data/clinicSettings/settings").get();
    final ClinicSettings settings = ClinicSettings.fromFirestore(settingsDoc);
    
    // 2. Compute patient's current distance to clinic
    final Position pos = await AppUtils.determinePosition();
    final double dist = AppUtils.calculateDistance(pos.latitude, pos.longitude, settings.latitude, settings.longitude);

    if (dist > 150 && !isPreRegistered) {
      throw Exception("Too far from clinic. You must be within 150m of the clinic to check-in.");
    }

    // 3. Auto-assign doctor
    final assignment = await autoAssignDoctor(issue);

    // Get current queue count for token assignment
    final queueSnap = await _db.collection("artifacts/$appId/public/data/queue").get();
    final token = 'T-${queueSnap.size + 1}';

    // 4. Create queue document
    final docRef = await _db.collection("artifacts/$appId/public/data/queue").add({
      'name': name,
      'mobile': phone,
      'issue': issue,
      'patientId': patientId,
      'status': isPreRegistered ? 'pre_registered' : 'waiting',
      'joinedAt': FieldValue.serverTimestamp(),
      'doctorId': assignment['doctorId'],
      'doctorName': assignment['doctorName'],
      'specialty': assignment['specialty'],
      'source': 'mobile_app',
      'token': token,
    });

    return docRef.id;
  }

  // Check in a walk-in patient from receptionist dashboard
  Future<void> checkInWalkInPatient({
    required String name,
    required String mobile,
    required String issue,
    required String doctorId,
    required String doctorName,
    required String specialty,
    required bool isEmergency,
  }) async {
    // 1. Double check-in protection: query active queue for mobile number
    final activeSnap = await _db.collection("artifacts/$appId/public/data/queue")
        .where("mobile", isEqualTo: mobile)
        .where("status", whereIn: ["waiting", "calling", "pending_payment"])
        .get();
        
    if (activeSnap.docs.isNotEmpty) {
      throw Exception("Patient with this mobile number is already in the active queue.");
    }

    // 2. Determine token index (sequential T-1, T-2, etc.)
    final queueSnap = await _db.collection("artifacts/$appId/public/data/queue").get();
    final token = 'T-${queueSnap.size + 1}';

    // 3. Create queue document
    await _db.collection("artifacts/$appId/public/data/queue").add({
      'name': name,
      'mobile': mobile,
      'issue': issue + (isEmergency ? " (EMERGENCY)" : ""),
      'patientId': 'walkin_${DateTime.now().millisecondsSinceEpoch}',
      'status': 'waiting',
      'joinedAt': FieldValue.serverTimestamp(),
      'doctorId': doctorId,
      'doctorName': doctorName,
      'specialty': specialty,
      'source': 'receptionist_walkin',
      'token': token,
      'priority': isEmergency ? 1 : 0,
    });
  }

  // Assign token explicitly
  Future<void> assignToken(String queueDocId, String token) async {
    await _db.doc("artifacts/$appId/public/data/queue/$queueDocId").update({
      'token': token,
    });
  }

  // Update payment status (patient checkout confirmation)
  Future<void> confirmUpiPayment(String queueId) async {
    await _db.doc("artifacts/$appId/public/data/queue/$queueId").update({
      'status': 'seen',
      'paymentRequestStatus': 'paid',
      'paymentMethod': 'upi',
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  // Submit patient rating & feedback
  Future<void> submitPatientFeedback({
    required String doctorId,
    required String doctorName,
    required String patientId,
    required Map<String, int> ratings,
    required String comments,
  }) async {
    await _db.collection("artifacts/$appId/public/data/feedback").add({
      'ratings': ratings,
      'comments': comments,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'patientId': patientId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Receptionist payment trigger
  Future<void> requestUpiPayment(String queueId, double fee) async {
    await _db.doc("artifacts/$appId/public/data/queue/$queueId").update({
      'paymentMethod': 'upi',
      'paymentRequestStatus': 'requested',
      'fee': fee,
    });
  }

  // Receptionist Cash/Card completion
  Future<void> confirmManualPayment(String queueId, double fee, String method) async {
    await _db.doc("artifacts/$appId/public/data/queue/$queueId").update({
      'status': 'seen',
      'paymentMethod': method,
      'paymentRequestStatus': 'paid',
      'fee': fee,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  // Doctor: Call patient
  Future<void> callPatient(String queueId) async {
    await _db.doc("artifacts/$appId/public/data/queue/$queueId").update({
      'status': 'calling',
      'calledAt': FieldValue.serverTimestamp(),
    });
  }

  // Doctor: Submit treatment notes and visit
  Future<void> submitConsultation(
    String queueId,
    String patientId,
    String notes,
    double fee,
    String instructions,
    String doctorName,
    List<Map<String, dynamic>> medications,
  ) async {
    // 1. Add visit record
    await _db.collection("artifacts/$appId/users/$patientId/visits").add({
      'visitedAt': FieldValue.serverTimestamp(),
      'notes': notes,
      'patientInstructions': instructions,
      'fee': fee,
      'doctor': doctorName,
      'medications': medications,
      'invoiceId': queueId,
    });

    // 2. Put queue in pending_payment status
    await _db.doc("artifacts/$appId/public/data/queue/$queueId").update({
      'status': 'pending_payment',
      'fee': fee,
      'notes': notes,
      'patientInstructions': instructions,
      'medications': medications,
      'consultationCompletedAt': FieldValue.serverTimestamp(),
    });
  }

  // Fetch visits history for a patient as Future
  Future<List<VisitItem>> getPatientHistory(String patientId) async {
    final snap = await _db
        .collection("artifacts/$appId/users/$patientId/visits")
        .orderBy("visitedAt", descending: true)
        .get();
    return snap.docs.map((doc) => VisitItem.fromFirestore(doc)).toList();
  }

  // Stream patient history
  Stream<List<VisitItem>> streamPatientHistory(String patientId) {
    return _db
        .collection("artifacts/$appId/users/$patientId/visits")
        .orderBy("visitedAt", descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => VisitItem.fromFirestore(doc)).toList());
  }

  // Stream all chat rooms for Doctor Chat list
  Stream<List<ChatRoomItem>> streamChatRooms() {
    return _db
        .collection("artifacts/$appId/public/data/chatRooms")
        .orderBy("lastMessageTime", descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => ChatRoomItem.fromFirestore(doc)).toList());
  }

  // Handle doctor presence update & queue reassignment on logout
  Future<void> handleDoctorLogout(String doctorId) async {
    // 1. Mark doctor presence as offline
    await _db.collection("artifacts/$appId/public/data/staff").doc(doctorId).update({
      'sessionActive': false,
      'isActive': false,
      'doctorStatus': 'offline',
    });

    // 2. Query waiting / active patients of this doctor
    final waitingSnap = await _db
        .collection("artifacts/$appId/public/data/queue")
        .where("doctorId", isEqualTo: doctorId)
        .where("status", whereIn: ["waiting", "calling", "pending_payment"])
        .get();

    if (waitingSnap.docs.isNotEmpty) {
      // 3. Query other active doctors
      final otherDocsSnap = await _db
          .collection("artifacts/$appId/public/data/staff")
          .where("role", isEqualTo: "doctor")
          .where("isActive", isEqualTo: true)
          .get();

      final List<Map<String, dynamic>> otherDoctors = [];
      for (var doc in otherDocsSnap.docs) {
        if (doc.id != doctorId) {
          otherDoctors.add({'id': doc.id, ...doc.data()});
        }
      }

      if (otherDoctors.isNotEmpty) {
        // Shortest queue distribution logic
        final activeQueueSnap = await _db
            .collection("artifacts/$appId/public/data/queue")
            .where("status", whereIn: ["waiting", "calling", "pending_payment"])
            .get();

        final Map<String, int> queueCounts = {};
        for (var d in otherDoctors) {
          queueCounts[d['id']] = 0;
        }

        for (var qDoc in activeQueueSnap.docs) {
          final docId = qDoc.data()['doctorId'];
          if (queueCounts.containsKey(docId)) {
            queueCounts[docId] = queueCounts[docId]! + 1;
          }
        }

        for (var patientDoc in waitingSnap.docs) {
          // Sort remaining active doctors by shortest queue size
          otherDoctors.sort((a, b) {
            final countA = queueCounts[a['id']] ?? 0;
            final countB = queueCounts[b['id']] ?? 0;
            return countA.compareTo(countB);
          });

          final bestDoctor = otherDoctors.first;
          final bestDocName = bestDoctor['name'] ?? "Doctor";
          await patientDoc.reference.update({
            'doctorId': bestDoctor['id'],
            'doctorName': bestDocName,
            'specialty': bestDoctor['specialization'] ?? "General",
          });

          // Send reassignment notification & WhatsApp log
          try {
            final pData = patientDoc.data();
            final pId = pData['patientId'] ?? '';
            final pName = pData['name'] ?? '';
            final pMobile = pData['mobile'] ?? '';

            if (pId.isNotEmpty) {
              await _db.collection("artifacts/$appId/users/$pId/notifications").add({
                'title': 'Doctor Reassigned',
                'body': 'Your doctor has been changed to $bestDocName due to unavailability. Your wait time is being recalculated.',
                'category': 'reassignment',
                'status': 'unread',
                'createdAt': FieldValue.serverTimestamp(),
              });
            }

            await _db.collection("artifacts/$appId/public/data/whatsappLogs").add({
              'patientId': pId,
              'patientName': pName,
              'phone': pMobile,
              'message': 'Hi $pName, your doctor has been updated to $bestDocName. We have recalculated your ETA.',
              'sentAt': FieldValue.serverTimestamp(),
              'status': 'sent',
            });
          } catch (e) {
            debugPrint("Failed to write reassignment notifications/logs: $e");
          }

          // Update local queue count
          final bestDocId = bestDoctor['id'];
          queueCounts[bestDocId] = (queueCounts[bestDocId] ?? 0) + 1;
        }
      } else {
        // Fallback to General Physician
        for (var patientDoc in waitingSnap.docs) {
          await patientDoc.reference.update({
            'doctorId': null,
            'doctorName': "General Physician",
            'specialty': "General",
          });

          // Send reassignment notification & WhatsApp log
          try {
            final pData = patientDoc.data();
            final pId = pData['patientId'] ?? '';
            final pName = pData['name'] ?? '';
            final pMobile = pData['mobile'] ?? '';

            if (pId.isNotEmpty) {
              await _db.collection("artifacts/$appId/users/$pId/notifications").add({
                'title': 'Doctor Reassigned',
                'body': 'Your doctor has been changed to General Physician due to unavailability. Your wait time is being recalculated.',
                'category': 'reassignment',
                'status': 'unread',
                'createdAt': FieldValue.serverTimestamp(),
              });
            }

            await _db.collection("artifacts/$appId/public/data/whatsappLogs").add({
              'patientId': pId,
              'patientName': pName,
              'phone': pMobile,
              'message': 'Hi $pName, your doctor has been updated to General Physician. We have recalculated your ETA.',
              'sentAt': FieldValue.serverTimestamp(),
              'status': 'sent',
            });
          } catch (e) {
            debugPrint("Failed to write reassignment fallback notifications/logs: $e");
          }
        }
      }
    }
  }

  // Save the patient's push notification token
  Future<void> updateUserPushToken(String userId, String token) async {
    await _db.collection("artifacts/$appId/users").doc(userId).set({
      'pushToken': token,
    }, SetOptions(merge: true));
  }

  // Get yesterday's completed queue items
  Future<List<QueueItem>> getYesterdayQueue() async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfYesterday = startOfToday.subtract(const Duration(days: 1));

    final snap = await _db
        .collection("artifacts/$appId/public/data/queue")
        .where("status", isEqualTo: "seen")
        .where("joinedAt", isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYesterday))
        .where("joinedAt", isLessThan: Timestamp.fromDate(startOfToday))
        .get();

    return snap.docs.map((doc) => QueueItem.fromFirestore(doc)).toList();
  }

  // Stream of completed patient count today for a doctor
  Stream<int> streamDoctorCompletedTodayCount(String doctorId) {
    return _db
        .collection("artifacts/$appId/public/data/queue")
        .where("doctorId", isEqualTo: doctorId)
        .snapshots()
        .map((snap) {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      return snap.docs.where((doc) {
        final data = doc.data();
        final bool isSeen = data['status'] == 'seen' || data['status'] == 'pending_payment' || data['status'] == 'completed';
        final Timestamp? completedAt = data['completedAt'] ?? data['consultationCompletedAt'];
        return isSeen && completedAt != null && completedAt.toDate().isAfter(startOfToday);
      }).length;
    });
  }

  // Stream of lifetime completed patient count for a doctor
  Stream<int> streamDoctorLifetimeCompletedCount(String doctorId) {
    return _db
        .collection("artifacts/$appId/public/data/queue")
        .where("doctorId", isEqualTo: doctorId)
        .snapshots()
        .map((snap) {
      return snap.docs.where((doc) {
        final data = doc.data();
        return data['status'] == 'seen' || data['status'] == 'pending_payment' || data['status'] == 'completed';
      }).length;
    });
  }

  // Stream of lifetime average consultation time for a doctor
  Stream<double> streamDoctorLifetimeAverageConsultationTime(String doctorId) {
    return _db
        .collection("artifacts/$appId/public/data/queue")
        .where("doctorId", isEqualTo: doctorId)
        .snapshots()
        .map((snap) {
      final completedDocs = snap.docs.where((doc) {
        final data = doc.data();
        return (data['status'] == 'seen' || data['status'] == 'pending_payment' || data['status'] == 'completed') &&
            data['calledAt'] != null &&
            (data['consultationCompletedAt'] != null || data['completedAt'] != null);
      }).toList();

      if (completedDocs.isEmpty) {
        return 12.0;
      }

      double totalMinutes = 0;
      int count = 0;
      for (var doc in completedDocs) {
        final data = doc.data();
        final Timestamp? calledAt = data['calledAt'];
        final Timestamp? completedAt = data['consultationCompletedAt'] ?? data['completedAt'];
        if (calledAt != null && completedAt != null) {
          final diff = completedAt.toDate().difference(calledAt.toDate()).inMinutes;
          if (diff >= 0 && diff < 120) {
            totalMinutes += diff;
            count++;
          }
        }
      }

      if (count == 0) return 12.0;
      return totalMinutes / count;
    });
  }

  // Initiate a pending payment session in Firestore before launching UPI Intent
  Future<void> initiatePaymentSession({
    required String invoiceId,
    required String patientId,
    required double amount,
  }) async {
    await _db.doc("artifacts/$appId/public/data/payment_sessions/$invoiceId").set({
      'invoiceId': invoiceId,
      'patientId': patientId,
      'amount': amount,
      'createdAt': FieldValue.serverTimestamp(),
      'paymentStatus': 'INITIATED',
    }, SetOptions(merge: true));
  }

  // Check for any active payment session for the current patient
  Future<Map<String, dynamic>?> getActivePaymentSession(String patientId) async {
    try {
      final snap = await _db
          .collection("artifacts/$appId/public/data/payment_sessions")
          .where("patientId", isEqualTo: patientId)
          .where("paymentStatus", isEqualTo: "INITIATED")
          .get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.first.data();
      }
    } catch (e) {
      debugPrint("Error fetching active payment session: $e");
    }
    return null;
  }

  // Cancel/fail a payment session
  Future<void> cancelPaymentSession(String invoiceId) async {
    await _db.doc("artifacts/$appId/public/data/payment_sessions/$invoiceId").set({
      'paymentStatus': 'FAILED',
      'paymentCompletedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Update UPI Payment status with full audit logging and receipt storage
  Future<void> updateUpiPaymentStatus({
    required String queueId,
    required String paymentStatus,
    required double amountPaid,
    String? billingStatus,
    String? consultationStatus,
    String? visitStatus,
    String? paymentMethod,
    String? selectedUpiApp,
    String? txnRef,
    String? approvalRefNo,
    String? responseCode,
    String? transactionId,
    DateTime? paidAt,
  }) async {
    final Map<String, dynamic> queueUpdates = {
      'paymentStatus': paymentStatus,
    };
    if (billingStatus != null) queueUpdates['billingStatus'] = billingStatus;
    if (consultationStatus != null) queueUpdates['consultationStatus'] = consultationStatus;
    if (visitStatus != null) queueUpdates['visitStatus'] = visitStatus;
    if (paymentMethod != null) queueUpdates['paymentMethod'] = paymentMethod;

    final upiMetadata = {
      'amountPaid': amountPaid,
      'invoiceId': queueId,
      'selectedUpiApp': selectedUpiApp ?? 'Unknown',
      'txnRef': txnRef ?? '',
      'approvalRefNo': approvalRefNo ?? '',
      'responseCode': responseCode ?? '',
      'transactionId': transactionId ?? '',
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt) : FieldValue.serverTimestamp(),
    };
    
    queueUpdates['upiMetadata'] = upiMetadata;

    if (paymentStatus == 'SUCCESS') {
      queueUpdates['status'] = 'completed';
      queueUpdates['paymentRequestStatus'] = 'paid';
      queueUpdates['completedAt'] = FieldValue.serverTimestamp();
      queueUpdates['amountPaid'] = amountPaid;
      queueUpdates['paidAt'] = FieldValue.serverTimestamp();
      
      // Fetch queue document to get patient info
      final queueDoc = await _db.doc("artifacts/$appId/public/data/queue/$queueId").get();
      final queueData = queueDoc.data() ?? {};
      final patientId = queueData['patientId'] as String?;

      // 1. Update queue status and details
      await _db.doc("artifacts/$appId/public/data/queue/$queueId").update(queueUpdates);

      // 2. Update payment session in Firestore
      await _db.doc("artifacts/$appId/public/data/payment_sessions/$queueId").set({
        'paymentStatus': 'SUCCESS',
        'paymentCompletedAt': FieldValue.serverTimestamp(),
        'amountPaid': amountPaid,
        'metadata': upiMetadata,
      }, SetOptions(merge: true));

      // 3. Save receipt data permanently for reprint/download history
      final receiptData = {
        'invoiceId': queueId,
        'invoiceNumber': "INV-${queueId.substring(0, 8)}",
        'patientName': queueData['name'] ?? 'Patient',
        'doctorName': queueData['doctorName'] ?? queueData['doctor'] ?? 'Doctor',
        'amount': amountPaid,
        'amountPaid': amountPaid,
        'paymentMethod': paymentMethod ?? 'UPI',
        'token': queueData['token'] ?? '',
        'reason': queueData['issue'] ?? queueData['notes'] ?? 'Consultation',
        'txnRef': txnRef ?? '',
        'approvalRefNo': approvalRefNo ?? '',
        'responseCode': responseCode ?? '',
        'transactionId': transactionId ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'paidAt': paidAt != null ? Timestamp.fromDate(paidAt) : FieldValue.serverTimestamp(),
        'selectedUpiApp': selectedUpiApp ?? 'Unknown',
      };

      await _db.doc("artifacts/$appId/public/data/receipts/$queueId").set(receiptData, SetOptions(merge: true));

      if (patientId != null && patientId.isNotEmpty) {
        await _db.collection("artifacts/$appId/users/$patientId/receipts").add(receiptData);
      }

    } else if (paymentStatus == 'FAILED') {
      queueUpdates['paymentRequestStatus'] = 'failed';
      await _db.doc("artifacts/$appId/public/data/queue/$queueId").update(queueUpdates);

      await _db.doc("artifacts/$appId/public/data/payment_sessions/$queueId").set({
        'paymentStatus': 'FAILED',
        'paymentCompletedAt': FieldValue.serverTimestamp(),
        'metadata': upiMetadata,
      }, SetOptions(merge: true));
    } else {
      // PENDING or SUBMITTED
      queueUpdates['paymentRequestStatus'] = 'pending';
      await _db.doc("artifacts/$appId/public/data/queue/$queueId").update(queueUpdates);

      await _db.doc("artifacts/$appId/public/data/payment_sessions/$queueId").set({
        'paymentStatus': 'PENDING',
        'metadata': upiMetadata,
      }, SetOptions(merge: true));
    }
  }

  // Retrieve a permanently stored receipt
  Future<Map<String, dynamic>?> getReceipt(String invoiceId) async {
    try {
      final doc = await _db.doc("artifacts/$appId/public/data/receipts/$invoiceId").get();
      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      debugPrint("Error fetching receipt: $e");
    }
    return null;
  }

  // Stream news ticker document
  Stream<DocumentSnapshot> streamNewsTicker() {
    return _db.doc("artifacts/$appId/public/data/broadcast/news").snapshots();
  }

  // Stream broadcast messages collection
  Stream<List<Map<String, dynamic>>> streamBroadcastMessages() {
    return _db
        .collection("artifacts/$appId/public/data/broadcast_messages")
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final d = doc.data();
              d['id'] = doc.id;
              return d;
            }).toList());
  }

  // Auto-assign unassigned patients to doctor with shortest wait time
  Future<void> autoAssignUnassignedPatients() async {
    try {
      final queueSnap = await _db
          .collection("artifacts/$appId/public/data/queue")
          .where("status", whereIn: ["waiting", "pre_registered"])
          .get();

      final unassignedItems = queueSnap.docs.where((doc) {
        final d = doc.data();
        final docId = d['doctorId'];
        return docId == null || docId.toString().isEmpty || docId == 'unassigned' || docId == 'unasigned';
      }).toList();

      if (unassignedItems.isEmpty) return;

      final doctors = await getActiveDoctors();
      final onlineDoctors = doctors.where((doc) {
        final status = doc['doctorStatus'] ?? 'offline';
        final isActive = doc['isActive'] ?? true;
        return isActive && (status == 'available' || status == 'consulting');
      }).toList();

      if (onlineDoctors.isEmpty) return;

      final Map<String, int> doctorWaitTimes = {};
      final Map<String, String> doctorNames = {};
      final Map<String, String> doctorSpecialties = {};

      for (var doc in onlineDoctors) {
        final docId = doc['id'];
        doctorNames[docId] = doc['name'] ?? "Doctor";
        doctorSpecialties[docId] = doc['specialization'] ?? "General";

        final avgTimeSnap = await _db
            .collection("artifacts/$appId/public/data/queue")
            .where("doctorId", isEqualTo: docId)
            .get();
        final completedDocs = avgTimeSnap.docs.where((d) {
          final data = d.data();
          return (data['status'] == 'seen' || data['status'] == 'completed') && data['calledAt'] != null;
        }).toList();
        
        double avgTime = 12.0;
        if (completedDocs.isNotEmpty) {
          double totalMin = 0;
          int count = 0;
          for (var d in completedDocs) {
            final data = d.data();
            final Timestamp? called = data['calledAt'];
            final Timestamp? completed = data['consultationCompletedAt'] ?? data['completedAt'];
            if (called != null && completed != null) {
              final diff = completed.toDate().difference(called.toDate()).inMinutes;
              if (diff >= 0 && diff < 120) {
                totalMin += diff;
                count++;
              }
            }
          }
          if (count > 0) avgTime = totalMin / count;
        }

        final currentQueueSnap = await _db
            .collection("artifacts/$appId/public/data/queue")
            .where("doctorId", isEqualTo: docId)
            .where("status", whereIn: ["waiting", "calling"])
            .get();

        final waitCount = currentQueueSnap.docs.length;
        doctorWaitTimes[docId] = (waitCount * avgTime).round();
      }

      for (var item in unassignedItems) {
        String? bestDoctorId;
        int minWait = 999999;
        doctorWaitTimes.forEach((docId, wait) {
          if (wait < minWait) {
            minWait = wait;
            bestDoctorId = docId;
          }
        });

        if (bestDoctorId != null) {
          final docId = bestDoctorId!;
          await _db.collection("artifacts/$appId/public/data/queue").doc(item.id).update({
            'doctorId': docId,
            'doctorName': doctorNames[docId],
            'specialty': doctorSpecialties[docId],
          });

          final avgTimeSnap = await _db
              .collection("artifacts/$appId/public/data/queue")
              .where("doctorId", isEqualTo: docId)
              .get();
          final completedDocs = avgTimeSnap.docs.where((d) {
            final data = d.data();
            return (data['status'] == 'seen' || data['status'] == 'completed') && data['calledAt'] != null;
          }).toList();
          double avgTime = 12.0;
          if (completedDocs.isNotEmpty) {
            double totalMin = 0;
            int count = 0;
            for (var d in completedDocs) {
              final data = d.data();
              final Timestamp? called = data['calledAt'];
              final Timestamp? completed = data['consultationCompletedAt'] ?? data['completedAt'];
              if (called != null && completed != null) {
                final diff = completed.toDate().difference(called.toDate()).inMinutes;
                if (diff >= 0 && diff < 120) {
                  totalMin += diff;
                  count++;
                }
              }
            }
            if (count > 0) avgTime = totalMin / count;
          }
          doctorWaitTimes[docId] = doctorWaitTimes[docId]! + avgTime.round();
        }
      }
    } catch (e) {
      debugPrint("Error auto-assigning patients: $e");
    }
  }

  // --- Clinic Expenses Operations ---
  Stream<List<Map<String, dynamic>>> streamExpenses() {
    return _db
        .collection("artifacts/$appId/public/data/expenses")
        .orderBy("date", descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  Future<void> addExpense(String category, double amount, String description, DateTime date, String addedBy) async {
    await _db.collection("artifacts/$appId/public/data/expenses").add({
      'category': category,
      'amount': amount,
      'description': description,
      'date': Timestamp.fromDate(date),
      'addedBy': addedBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteExpense(String docId) async {
    await _db.collection("artifacts/$appId/public/data/expenses").doc(docId).delete();
  }

  // --- Broadcast & Global News Operations ---
  Stream<DocumentSnapshot> streamBroadcastNews() {
    return _db.doc("artifacts/$appId/public/data/broadcast/news").snapshots();
  }

  Future<void> updateBroadcastNews(String text, String title, String subtitle, bool active, String userId) async {
    await _db.doc("artifacts/$appId/public/data/broadcast/news").set({
      'text': text,
      'pageTitle': title,
      'pageSubtitle': subtitle,
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userId,
    }, SetOptions(merge: true));
  }

  Stream<List<Map<String, dynamic>>> streamBroadcastHistory() {
    return _db
        .collection("artifacts/$appId/public/data/broadcast_messages")
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  Future<void> sendBroadcastMessage(String text, String userId) async {
    await _db.collection("artifacts/$appId/public/data/broadcast_messages").add({
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'senderId': userId,
    });
  }
}

