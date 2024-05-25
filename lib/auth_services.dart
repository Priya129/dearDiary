import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService{

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? gUser =
      await GoogleSignIn().signIn();
      if (gUser != null) {
        final GoogleSignInAuthentication gAuth =
        await gUser!.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: gAuth.accessToken,
          idToken: gAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
    }
    catch (e) {
      print("Error siging in with google $e");
    }

  }
}