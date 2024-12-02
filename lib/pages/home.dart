import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gcs_attendence/pages/test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart'; // For camera functionality
import 'package:http/http.dart' as http;
import 'loginPage.dart';

import 'dart:io';

import 'package:camera/camera.dart';

class HomePage extends StatefulWidget {
  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  Map<String, dynamic>? currentUser;
  bool isLoading = true;
  File? _imageFile; // To store the captured image

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    final prefs = await SharedPreferences.getInstance();

    String? userData = prefs.getString('current_user');

    if (userData != null) {
      setState(() {
        currentUser =
            json.decode(userData); // Decode the JSON string into a map
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
      print('No user data found in SharedPreferences');
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear all saved preferences

    // Navigate back to LoginPage
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
    );
  }

  Future<void> _markAttendance() async {

    WidgetsFlutterBinding.ensureInitialized();

    final cameras = await availableCameras();

    print(cameras);

    // Get a specific camera from the list of available cameras.
    final firstCamera = cameras.first;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => TakePictureScreen(camera: firstCamera,),
      ),
    );


    try {
      // Open camera to capture the image
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.camera);

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });

        // Send the captured image to the backend
        final prefs = await SharedPreferences.getInstance();
        String? accessToken = prefs.getString('access_token');

        if (accessToken != null) {
          final request = http.MultipartRequest(
            'POST',
            Uri.parse('http://10.0.2.2:8000/api/mark-attendance/'), // Backend API endpoint
          );

          request.headers['Authorization'] = 'Bearer $accessToken';
          request.files.add(await http.MultipartFile.fromPath(
            'image', // Field name expected by the backend
            _imageFile!.path,
          ));

          final response = await request.send();

          if (response.statusCode == 200) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Attendance marked successfully!')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to mark attendance.')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No access token found.')),
          );
        }
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    } else if (currentUser != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF92363E),
          title: const Text(
            'Home',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout, // Call the logout function
              tooltip: 'Logout',
              color: Colors.white,
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Greeting Message
                Text(
                  'Welcome, ${currentUser!['username']}!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF92363E),
                  ),
                ),
                const SizedBox(height: 16),

                // Mark Attendance Button
                ElevatedButton(
                  onPressed: _markAttendance,
                  child: const Text('Mark Attendance'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF92363E),
                    foregroundColor: Colors.white,
                  ),
                ),

                // Display Captured Image (Optional)
                if (_imageFile != null) ...[
                  const SizedBox(height: 16),
                  Image.file(
                    _imageFile!,
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('No user details found.')),
      );
    }
  }
}
