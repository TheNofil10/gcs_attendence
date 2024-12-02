import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';
import 'loginPage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class HomePage extends StatefulWidget {
  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  Map<String, dynamic>? currentUser;
  bool isLoading = true;
  File? _imageFile; // To store the captured image file

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
    final cameras = await availableCameras();
    final firstCamera = cameras.first;

    final imagePath = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TakePictureScreen(camera: firstCamera),
      ),
    );

    if (imagePath != null) {
      setState(() {
        _imageFile = File(imagePath); // Store the captured image
      });

      try {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('http://10.0.2.2:8001/app_attendance'),
        );

        request.files.add(await http.MultipartFile.fromPath(
          'file', // This matches the backend's expected field name
          imagePath,
          contentType: MediaType('image', 'jpeg'), // Specify content type
        ));

        final response = await request.send();

        if (response.statusCode == 200) {
          final responseData = await response.stream.bytesToString();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Attendance marked: $responseData')),
          );
        } else {
          print('Failed to upload image: ${response.reasonPhrase}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to mark attendance')),
          );
        }
      } catch (e) {
        print('Error uploading image: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error marking attendance')),
        );
      }
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
              onPressed: _logout,
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

// Camera screen to take a picture
class TakePictureScreen extends StatefulWidget {
  const TakePictureScreen({
    super.key,
    required this.camera,
  });

  final CameraDescription camera;

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  List<CameraDescription> cameras = [];
  CameraDescription? selectedCamera;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // Retrieve all available cameras.
    cameras = await availableCameras();
    selectedCamera = widget.camera;

    _controller = CameraController(
      selectedCamera!,
      ResolutionPreset.medium,
    );

    _initializeControllerFuture = _controller.initialize();
    setState(() {});
  }

  Future<void> _switchCamera() async {
    // Find the next camera (toggle between front and back).
    final newCamera = cameras.firstWhere(
          (camera) => camera.lensDirection != selectedCamera?.lensDirection,
    );

    setState(() {
      selectedCamera = newCamera;
    });

    // Reinitialize the controller with the new camera.
    await _controller.dispose();

    _controller = CameraController(
      selectedCamera!,
      ResolutionPreset.medium,
    );

    _initializeControllerFuture = _controller.initialize();
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take a picture'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: _switchCamera,
            tooltip: 'Switch Camera',
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CameraPreview(_controller);
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            await _initializeControllerFuture;

            final image = await _controller.takePicture();

            if (!context.mounted) return;

            Navigator.pop(context, image.path);
          } catch (e) {
            print(e);
          }
        },
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}