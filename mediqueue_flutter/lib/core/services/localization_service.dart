import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocalizationService {
  static final LocalizationService instance = LocalizationService._internal();
  LocalizationService._internal();

  final ValueNotifier<String> localeNotifier = ValueNotifier<String>('en');

  String get currentLanguage => localeNotifier.value;

  final Map<String, Map<String, String>> _translations = {
    'en': {
      'welcome_back': 'Welcome Back',
      'clinic_status': 'Clinic Status',
      'clinic_open': 'Open',
      'clinic_closed': 'Closed',
      'patients_waiting': 'patients waiting',
      'your_position': 'Your Position',
      'estimated_wait': 'Estimated Wait',
      'join_queue': 'Join Queue',
      'scan_qr': 'Scan QR',
      'book_appointment': 'Book Appointment',
      'language': 'Language',
      'save': 'Save',
      'logout': 'Logout',
      'confirm': 'Confirm',
      'cancel': 'Cancel',
      'submit': 'Submit',
      'rupees': '₹',
      'billing_receipt': 'Receipt',
      'billing_total_amount': 'Total Amount',
      'billing_invoice_number': 'Invoice Number',
      'feedback_submit': 'Submit Feedback',
      'settings': 'Settings',
      'home': 'Home',
      'queue': 'Queue',
      'bookings': 'Bookings',
      'chats': 'Chats',
      'profile': 'Profile',
      'receipt_history': 'Receipt History',
      'no_receipts': 'No receipts found',
      'my_receipts': 'My Receipts',
      'download': 'Download',
      'share': 'Share',
      'smart_analytics': 'Smart Operations Console',
      'peak_doctor': 'Peak Doctor',
      'busiest_hour': 'Busiest Hour',
      'noshow_rate': 'No-Show Rate',
      'satisfaction': 'Avg Satisfaction',
      'whatsapp_queue': 'WhatsApp Delivery Queue',
      'audit_panel': 'Analytics Audit Info',
      'feedback_insights': 'Feedback Insights',
      'offline_banner': 'Offline Mode Active (Actions will synchronize automatically)',
      'doctor_status': 'Consultant Status',
      'available': 'Available',
      'consulting': 'In Consultation',
      'break': 'On Break',
      'offline': 'Offline',
    },
    'ta': {
      'welcome_back': 'மீண்டும் வருக',
      'clinic_status': 'கிளினிக் நிலை',
      'clinic_open': 'திறந்துள்ளது',
      'clinic_closed': 'மூடப்பட்டது',
      'patients_waiting': 'நோயாளிகள் காத்திருக்கின்றனர்',
      'your_position': 'உங்கள் நிலை',
      'estimated_wait': 'மதிப்பிடப்பட்ட காத்திருப்பு',
      'join_queue': 'வரிசையில் சேர',
      'scan_qr': 'QR ஸ்கேன்',
      'book_appointment': 'சந்திப்பு முன்பதிவு',
      'language': 'மொழி',
      'save': 'சேமி',
      'logout': 'வெளியேறு',
      'confirm': 'உறுதிப்படுத்து',
      'cancel': 'ரத்து செய்',
      'submit': 'சமர்ப்பி',
      'rupees': '₹',
      'billing_receipt': 'ரசீது',
      'billing_total_amount': 'மொத்த தொகை',
      'billing_invoice_number': 'இன்வாய்ஸ் எண்',
      'feedback_submit': 'மதிப்பீட்டை சமர்ப்பி',
      'settings': 'அமைப்புகள்',
      'home': 'முகப்பு',
      'queue': 'வரிசை',
      'bookings': 'முன்பதிவுகள்',
      'chats': 'அரட்டைகள்',
      'profile': 'சுயவிவரம்',
      'receipt_history': 'ரசீது வரலாறு',
      'no_receipts': 'ரசீதுகள் எதுவும் இல்லை',
      'my_receipts': 'எனது ரசீதுகள்',
      'download': 'பதிவிறக்கு',
      'share': 'பகிர்',
      'smart_analytics': 'ஸ்மார்ட் செயல்பாட்டு கன்சோல்',
      'peak_doctor': 'அதிக நோயாளி பார்த்த மருத்துவர்',
      'busiest_hour': 'பரபரப்பான நேரம்',
      'noshow_rate': 'வராதோர் விகிதம்',
      'satisfaction': 'சராசரி திருப்தி',
      'whatsapp_queue': 'வாட்ஸ்அப் விநியோக வரிசை',
      'audit_panel': 'பகுப்பாய்வு தணிக்கை தகவல்',
      'feedback_insights': 'கருத்து நுண்ணறிவு',
      'offline_banner': 'ஆஃப்லைன் பயன்முறை செயலில் உள்ளது (இணைப்பு மீண்டும் வந்ததும் ஒத்திசைக்கப்படும்)',
      'doctor_status': 'மருத்துவர் நிலை',
      'available': 'கிடைக்கும்',
      'consulting': 'ஆலோசனையில்',
      'break': 'இடைவெளியில்',
      'offline': 'ஆஃப்லைன்',
    },
    'te': {
      'welcome_back': 'మరలి స్వాగతం',
      'clinic_status': 'క్లినిక్ ಸ್ಥಿತಿ',
      'clinic_open': 'తెరిచి ఉంది',
      'clinic_closed': 'మూసివేయబడింది',
      'patients_waiting': 'రోగులు వేచి ఉన్నారు',
      'your_position': 'మీ స్థానం',
      'estimated_wait': 'అంచనా వేచి సమయం',
      'join_queue': 'సరతి లో చేరండి',
      'scan_qr': 'QR స్కాన్',
      'book_appointment': 'నివాస బుక్ చేయండి',
      'language': 'భాష',
      'save': 'భద్రపరచు',
      'logout': 'లాగ్అవుట్',
      'confirm': 'ధృవీకరించు',
      'cancel': 'రద్దు చేయి',
      'submit': 'సమర్పించు',
      'rupees': '₹',
      'billing_receipt': 'రసీదు',
      'billing_total_amount': 'మొత్తం రుసుము',
      'billing_invoice_number': 'ఇన్వాయిస్ సంఖ్య',
      'feedback_submit': 'అభిప్రायాన్ని సమర్పించండి',
      'settings': 'అమరికలు',
      'home': 'హోమ్',
      'queue': 'క్యూ',
      'bookings': 'బుకింగ్స్',
      'chats': 'చాట్స్',
      'profile': 'ప్రొఫైల్',
      'receipt_history': 'రసీదు చరిత్ర',
      'no_receipts': 'రసీదులు కనుగొనబడలేదు',
      'my_receipts': 'నా రసీదులు',
      'download': 'డౌన్‌లోడ్',
      'share': 'షేర్',
      'smart_analytics': 'స్మార్ట్ ఆపరేషన్స్ కన్సోల్',
      'peak_doctor': 'పీక్ డాక్టర్',
      'busiest_hour': 'బిజీ అవర్',
      'noshow_rate': 'నో-షో రేట్',
      'satisfaction': 'సగటు సంతృప్తి',
      'whatsapp_queue': 'వాట్సాప్ డెలివరీ క్యూ',
      'audit_panel': 'విశ్లేషణల ఆడిట్ సమాచారం',
      'feedback_insights': 'అభిప్రాయాల అంతర్దృష్టులు',
      'offline_banner': 'ఆఫ్‌లైన్ మోడ్ యాక్టివ్ (కనెక్షన్ పునరుద్ధరించబడినప్పుడు ఆటోమేటిక్‌గా సమకాలీకరించబడుతుంది)',
      'doctor_status': 'డాక్టర్ స్థితి',
      'available': 'అందుబాటులో ఉంది',
      'consulting': 'సంప్రదింపులలో',
      'break': 'విరామంలో',
      'offline': 'ఆఫ్‌లైన్',
    },
    'hi': {
      'welcome_back': 'स्वागत है',
      'clinic_status': 'क्लीनिक की स्थिति',
      'clinic_open': 'खुला है',
      'clinic_closed': 'बंद है',
      'patients_waiting': 'मरीज प्रतीक्षा कर रहे हैं',
      'your_position': 'आपकी स्थिति',
      'estimated_wait': 'अनुमानित प्रतीक्षा समय',
      'join_queue': 'कतार में शामिल हों',
      'scan_qr': 'QR स्कैन करें',
      'book_appointment': 'अपॉइंटमेंट बुक करें',
      'language': 'भाषा',
      'save': 'सहेजें',
      'logout': 'लॉगआउट',
      'confirm': 'पुष्टि करें',
      'cancel': 'रद्द करें',
      'submit': 'जमा करें',
      'rupees': '₹',
      'billing_receipt': 'रसीद',
      'billing_total_amount': 'कुल राशि',
      'billing_invoice_number': 'चालान संख्या',
      'feedback_submit': 'प्रतिक्रिया सबमिट करें',
      'settings': 'सेटिंग्स',
      'home': 'होम',
      'queue': 'कतार',
      'bookings': 'बुकिंग्स',
      'chats': 'चैट',
      'profile': 'प्रोफ़ाइल',
      'receipt_history': 'रसीद इतिहास',
      'no_receipts': 'कोई रसीद नहीं मिली',
      'my_receipts': 'मेरी रसीदें',
      'download': 'डाउनलोड',
      'share': 'शेयर',
      'smart_analytics': 'स्मार्ट ऑपरेशंस कंसोल',
      'peak_doctor': 'पीक डॉक्टर',
      'busiest_hour': 'व्यस्ततम समय',
      'noshow_rate': 'अनुपस्थिति दर',
      'satisfaction': 'औसत संतुष्टि',
      'whatsapp_queue': 'व्हाट्सएप डिलीवरी कतार',
      'audit_panel': 'एनालिटिक्स ऑडिट जानकारी',
      'feedback_insights': 'प्रतिक्रिया अंतर्दृष्टि',
      'offline_banner': 'ऑफ़लाइन मोड सक्रिय (कनेक्शन बहाल होने पर स्वचालित रूप से सिंक हो जाएगा)',
      'doctor_status': 'डॉक्टर की स्थिति',
      'available': 'उपलब्ध',
      'consulting': 'परामर्श में',
      'break': 'ब्रेक पर',
      'offline': 'ऑफ़लाइन',
    },
    'kn': {
      'welcome_back': 'ಮರಳಿ ಸ್ವಾಗತ',
      'clinic_status': 'ಕ್ಲಿನಿಕ್ ಸ್ಥಿತಿ',
      'clinic_open': 'ತೆರೆದಿದೆ',
      'clinic_closed': 'ಮುಚ್ಚಲಾಗಿದೆ',
      'patients_waiting': 'ರೋಗಿಗಳು ಕಾಯುತ್ತಿದ್ದಾರೆ',
      'your_position': 'ನಿಮ್ಮ ಸ್ಥಾನ',
      'estimated_wait': 'ಅಂದಾಜು ಕಾಯುವಿಕೆ',
      'join_queue': 'ಸರತಿ ಸಾಲಿಗೆ ಸೇರಿ',
      'scan_qr': 'QR ಸ್ಕ್ಯಾನ್',
      'book_appointment': 'ನೇಮಕಾತಿ ಕಾಯ್ದಿರಿಸಿ',
      'language': 'ಭಾಷೆ',
      'save': 'ಉಳಿಸು',
      'logout': 'ಲಾಗ್ ಔಟ್',
      'confirm': 'ದೃಢೀಕರಿಸಿ',
      'cancel': 'ರದ್ದುಮಾಡು',
      'submit': 'ಸಲ್ಲಿಸು',
      'rupees': '₹',
      'billing_receipt': 'ರಸೀದಿ',
      'billing_total_amount': 'ಒಟ್ಟು ಮೊತ್ತ',
      'billing_invoice_number': 'ಇನ್‌ವಾಯ್ಸ್ ಸಂಖ್ಯೆ',
      'feedback_submit': 'ಪ್ರತಿಕ್ರಿಯೆ ಸಲ್ಲಿಸಿ',
      'settings': 'ಸಂಯೋಜನೆಗಳು',
      'receipt_history': 'ರಸೀದಿ ಇತಿಹಾಸ',
      'no_receipts': 'ಯಾವುದೇ ರಸೀದಿಗಳು ಕಂಡುಬಂದಿಲ್ಲ',
      'my_receipts': 'ನನ್ನ ರಸೀದಿಗಳು',
    }
  };

  String translate(String key) {
    return _translations[currentLanguage]?[key] ?? _translations['en']?[key] ?? key;
  }

  // Load selected language from Firestore
  Future<void> loadUserLanguage(String uid, {required bool isStaff, required String appId}) async {
    try {
      DocumentSnapshot doc;
      if (isStaff) {
        doc = await FirebaseFirestore.instance.doc("artifacts/$appId/public/data/staff/$uid").get();
      } else {
        doc = await FirebaseFirestore.instance.doc("artifacts/$appId/users/$uid/profile/details").get();
      }
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null && data['language'] != null) {
          localeNotifier.value = data['language'].toString();
        }
      }
    } catch (e) {
      print("Error loading language preference: $e");
    }
  }

  // Save selected language to Firestore
  Future<void> saveUserLanguage(String uid, String lang, {required bool isStaff, required String appId}) async {
    try {
      localeNotifier.value = lang;
      if (isStaff) {
        await FirebaseFirestore.instance.doc("artifacts/$appId/public/data/staff/$uid").set(
          {'language': lang},
          SetOptions(merge: true),
        );
      } else {
        await FirebaseFirestore.instance.doc("artifacts/$appId/users/$uid/profile/details").set(
          {'language': lang},
          SetOptions(merge: true),
        );
      }
    } catch (e) {
      print("Error saving language preference: $e");
    }
  }
}
