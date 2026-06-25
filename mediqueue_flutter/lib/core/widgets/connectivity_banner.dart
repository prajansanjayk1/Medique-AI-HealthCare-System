import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.doc(".info/connected").snapshots(),
      builder: (context, snapshot) {
        // If snapshot has error or hasn't loaded, default to connected: true
        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final connected = data?['connected'] as bool? ?? true;

        if (connected) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          color: const Color(0xFFFFF3CD), // Light amber warning
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.wifi_off_rounded, color: Color(0xFF856404), size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Offline Mode Active (Actions will synchronize automatically when connection is restored)",
                  style: TextStyle(
                    color: Color(0xFF856404),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
