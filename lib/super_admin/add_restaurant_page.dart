import 'package:flutter/material.dart';
import '../service/restaurant_service.dart';

class AddRestaurantPage extends StatefulWidget {
  const AddRestaurantPage({super.key});

  @override
  State<AddRestaurantPage> createState() => _AddRestaurantPageState();
}

class _AddRestaurantPageState extends State<AddRestaurantPage> {

  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final phoneController = TextEditingController();

  /// admin login fields
  final adminEmailController = TextEditingController();
  final adminPasswordController = TextEditingController();

  final restaurantService = RestaurantService();

  void addRestaurant() async {

    await restaurantService.addRestaurant(
      nameController.text,
      addressController.text,
      phoneController.text,
      adminEmailController.text,
      adminPasswordController.text,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Restaurant & Admin Created")),
    );

    nameController.clear();
    addressController.clear();
    phoneController.clear();
    adminEmailController.clear();
    adminPasswordController.clear();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text("Add Restaurant")),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [

            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Restaurant Name",
              ),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: "Address",
              ),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: "Phone",
              ),
            ),

            const SizedBox(height: 20),

            const Divider(),

            const Text(
              "Restaurant Admin Login",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: adminEmailController,
              decoration: const InputDecoration(
                labelText: "Admin Email",
              ),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: adminPasswordController,
              decoration: const InputDecoration(
                labelText: "Admin Password",
              ),
            ),

            const SizedBox(height: 25),

            ElevatedButton(
              onPressed: addRestaurant,
              child: const Text("Add Restaurant"),
            ),
          ],
        ),
      ),
    );
  }
}