import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
//import 'home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'just_audio.dart';

Future<void> signInUserAnon() async {
  await FirebaseAuth.instance.signInAnonymously();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await signInUserAnon();
  runApp(MediaVaultApp());
}

class MediaVaultApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Media Vault',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        hintColor: Colors.orangeAccent,
      ),
      home: MediaVaultHomePage(),
    );
  }
}
