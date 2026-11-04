import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../repositories/candidate_repository.dart';
import '../state/election_state.dart';
import 'election_home.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        // Signed in: one brain for this user.
        return ChangeNotifierProvider<ElectionState>(
          create: (_) => ElectionState(CandidateRepository(user.uid)),
          child: const ElectionHome(),
        );
      },
    );
  }
}