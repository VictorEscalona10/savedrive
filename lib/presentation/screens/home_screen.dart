import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Home Screen')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Home Screen'),
            Text('Welcome to the Home Screen'),
            ElevatedButton(
              onPressed: () {
                GoogleSignIn.instance.signOut();

                Supabase.instance.client.auth.signOut();
              },
              child: Text('Go to Files'),
            ),
          ],
        ),
      ),
    );
  }
}
