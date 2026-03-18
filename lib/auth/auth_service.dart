import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {

  Future<Map<String, dynamic>?> login(String email, String password) async {

    try {

      UserCredential credential =
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      String uid = credential.user!.uid;

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        return null;
      }

      return {
        "role": userDoc['role'],
        "restaurantId": userDoc.data().toString().contains("restaurantId")
            ? userDoc['restaurantId']
            : null
      };

    } catch (e) {
      print(e);
      return null;
    }
  }
}