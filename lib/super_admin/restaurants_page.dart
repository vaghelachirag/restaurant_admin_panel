import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RestaurantListPage extends StatelessWidget {
  const RestaurantListPage({super.key});
  void addRestaurant(BuildContext context) {

    // Restaurant fields
    TextEditingController nameController = TextEditingController();
    TextEditingController addressController = TextEditingController();
    TextEditingController phoneController = TextEditingController();

    // Theme controllers
    TextEditingController bgColorController =
    TextEditingController(text: "#FAF5EF");
    TextEditingController textColorController =
    TextEditingController(text: "#000000");
    TextEditingController cardColorController =
    TextEditingController(text: "#FFFFFF");
    TextEditingController categoryBgController =
    TextEditingController(text: "#6D4C41");
    TextEditingController categoryTextController =
    TextEditingController(text: "#FFFFFF");
    TextEditingController cardInfoController =
    TextEditingController(text: "#757575");

    // Admin fields
    TextEditingController adminEmailController = TextEditingController();
    TextEditingController adminPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Restaurant"),
          content: SingleChildScrollView(
            child: Column(
              children: [

                const Text("Restaurant Info",
                    style: TextStyle(fontWeight: FontWeight.bold)),

                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Name"),
                ),

                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: "Address"),
                ),

                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: "Phone"),
                ),

                const SizedBox(height: 15),

                const Text("Theme Colors",
                    style: TextStyle(fontWeight: FontWeight.bold)),

                TextField(
                  controller: bgColorController,
                  decoration:
                  const InputDecoration(labelText: "Background Color"),
                ),

                TextField(
                  controller: textColorController,
                  decoration: const InputDecoration(labelText: "Text Color"),
                ),

                TextField(
                  controller: cardColorController,
                  decoration: const InputDecoration(labelText: "Card Color"),
                ),

                TextField(
                  controller: categoryBgController,
                  decoration:
                  const InputDecoration(labelText: "Category Background"),
                ),

                TextField(
                  controller: categoryTextController,
                  decoration:
                  const InputDecoration(labelText: "Category Text Color"),
                ),

                TextField(
                  controller: cardInfoController,
                  decoration:
                  const InputDecoration(labelText: "Card Info Color"),
                ),

                const SizedBox(height: 20),

                const Text("Admin Login Info",
                    style: TextStyle(fontWeight: FontWeight.bold)),

                TextField(
                  controller: adminEmailController,
                  decoration: const InputDecoration(labelText: "Admin Email"),
                ),

                TextField(
                  controller: adminPasswordController,
                  obscureText: true,
                  decoration:
                  const InputDecoration(labelText: "Admin Password"),
                ),
              ],
            ),
          ),
          actions: [

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),

            ElevatedButton(
              onPressed: () async {

                DocumentReference restaurantRef =
                await FirebaseFirestore.instance
                    .collection('restaurants')
                    .add({

                  "name": nameController.text,
                  "address": addressController.text,
                  "phone": phoneController.text,
                  "logo": "",
                  "isActive": true,
                  "createdAt": FieldValue.serverTimestamp(),

                  "theme": {
                    "backgroundColor": bgColorController.text,
                    "textColor": textColorController.text,
                    "cardColor": cardColorController.text,
                    "categoryBackgroundColor": categoryBgController.text,
                    "categoryTextColor": categoryTextController.text,
                    "cardInfoColor": cardInfoController.text,
                  }
                });

                String restaurantId = restaurantRef.id;

                UserCredential credential =
                await FirebaseAuth.instance
                    .createUserWithEmailAndPassword(
                  email: adminEmailController.text.trim(),
                  password: adminPasswordController.text.trim(),
                );

                String uid = credential.user!.uid;

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .set({
                  "email": adminEmailController.text.trim(),
                  "role": "admin",
                  "restaurantId": restaurantId,
                  "createdAt": FieldValue.serverTimestamp(),
                });

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Restaurant & Admin Created")),
                );
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restaurants')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('restaurants').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No Restaurants Found"));
          }

          final restaurants = snapshot.data!.docs;

          return ListView.builder(
            itemCount: restaurants.length,
            itemBuilder: (context, index) {
              var data = restaurants[index];

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text(data['name']),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['address']),
                      Text("📞 ${data['phone']}"),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Edit button (can be implemented later)
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {},
                      ),
                      // Delete restaurant
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          FirebaseFirestore.instance
                              .collection('restaurants')
                              .doc(data.id)
                              .delete();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () => addRestaurant(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}