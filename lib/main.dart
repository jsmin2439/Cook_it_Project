import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_state_notifier/flutter_state_notifier.dart';
import 'package:provider/provider.dart';
import 'package:son_1/firebase_options.dart';
import 'package:son_1/providers/auth_state.dart';
import 'package:son_1/repositories/auth_repository.dart';
import 'package:son_1/screens/signup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
  return MultiProvider(
    providers: [
      Provider<AuthRepository>(
          create: (context) => AuthRepository(
              firebaseAuth: FirebaseAuth.instance,
              firebaseStorage: FirebaseStorage.instance,
              firebaseFirestore: FirebaseFirestore.instance,
          ),
      ),

    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: MainScreen(),
    ),
  );
  }
}

class MainScreen extends StatelessWidget{
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context){
    return SignupScreen();
  }
}