import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SymptomsService {
  SymptomsService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> saveSymptoms({
    required String symptomsText,
    required List<String> symptoms,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Please sign in to save your symptoms.');
    }

    await _firestore.collection('symptom_entries').add({
      'symptomsText': symptomsText,
      'symptoms': symptoms,
      'createdAt': FieldValue.serverTimestamp(),
      'userId': user.uid,
      'email': user.email,
    });
  }
}