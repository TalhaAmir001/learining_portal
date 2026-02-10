import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Shared Firebase Firestore instance for the entire app
final FirebaseFirestore firestore = FirebaseFirestore.instance;

/// Shared Firebase Auth instance for the entire app
final FirebaseAuth firebaseAuth = FirebaseAuth.instance;

/// Virtual Support user ID (staff_id = 0 in backend). Students and teachers chat only with Support; any admin can reply.
const String supportUserId = '0';
