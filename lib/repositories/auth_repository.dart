import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AuthRepository{
  final FirebaseAuth firebaseAuth;
  final FirebaseStorage firebaseStorage;
  final FirebaseFirestore firebaseFirestore;

  const AuthRepository({
    required this.firebaseAuth,
    required this.firebaseStorage,
    required this.firebaseFirestore,
  });

  Future<void> signUp({
    required String email,
    required String name,
    required String password,
    }) async{
    UserCredential userCredential = await firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
    );

    print(userCredential.user);
  }
}