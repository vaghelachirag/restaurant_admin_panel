import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/models/restaurant_model.dart';

class RestaurantService {

  Future<void> addRestaurant(
      String name,
      String address,
      String phone,
      String adminEmail,
      String adminPassword,
      ) async {

    /// 1️⃣ Create restaurant
    DocumentReference restaurantRef =
    await FirebaseFirestore.instance.collection('restaurants').add({
      "name": name,
      "address": address,
      "phone": phone,
      "createdAt": FieldValue.serverTimestamp(),
    });

    String restaurantId = restaurantRef.id;

    /// 2️⃣ Create admin user
    UserCredential credential =
    await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: adminEmail,
      password: adminPassword,
    );

    String uid = credential.user!.uid;

    /// 3️⃣ Save user with restaurantId
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      "email": adminEmail,
      "role": "admin",
      "restaurantId": restaurantId,
    });
  }

  Future<RestaurantModel?> fetchRestaurant(String restaurantId) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurantId)
          .get();
      
      if (doc.exists) {
        return RestaurantModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      print('Error fetching restaurant: $e');
      return null;
    }
  }
}