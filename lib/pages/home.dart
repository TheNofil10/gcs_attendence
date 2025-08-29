import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';
import 'loginPage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../components/url.dart';
import '../components/helper.dart';
import 'cameraPage.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int DEBUG = 0;
  Map<String, dynamic>? currentUser;
  bool isLoading = true;
  bool isProcessing = false; // To indicate processing after taking a picture
  File? _imageFile;
  dynamic? attendanceData; // Holds the attendance data
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
    _fetchAttendanceData();
  }

  Future<void> _loadUserDetails() async {
    final prefs = await SharedPreferences.getInstance();

    String? userData = prefs.getString('current_user');

    if (userData != null) {
      setState(() {
        currentUser = json.decode(userData);
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
    await prefs.clear();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _fetchAttendanceData() async {
    Helper.debugPrint(1, "Fetching Attendance");

    if (!mounted) return; // Prevent operations if widget is disposed
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('access_token');
      String? refreshToken =
          prefs.getString('refresh_token'); // Get refresh token

      final response = await http.get(
        Uri.parse(attendanceTodayUrl + "?dateFilter=today"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        Helper.debugPrint(1, "Attendance fetched successfully");

        if (!mounted) return; // Check if the widget is still active

        // Parse the response body to JSON
        final rawData = json.decode(response.body);
        Helper.debugPrint(1, "Raw Attendance Data: $rawData");

        // Filter the record with matching employee_id
        Helper.debugPrint(1, currentUser!['username']);
        var matchingRecord = rawData.firstWhere(
          (record) => record['employee_id'] == currentUser!['id'],
          orElse: () => null, // Return null if no match is found
        );

        if (matchingRecord != null) {
          Helper.debugPrint(1, "Matching Record: $matchingRecord");
        } else {
          Helper.debugPrint(1,
              "No matching record found for username: ${currentUser!['username']}");
        }

        print(matchingRecord['time_in']);

        setState(() {
          attendanceData = matchingRecord ?? rawData;
          print("attendanceData");
          print(attendanceData);
          isLoading = false;
        });
      } else if (response.statusCode == 401) {
        // Access token expired, try refreshing the token
        Helper.debugPrint(DEBUG,
            "Access token expired, try refreshing the token: $refreshToken");
        if (refreshToken != null) {
          await _refreshAccessToken(refreshToken);
        } else {
          // No refresh token available, log out the user
          await _logout();
        }
      } else {
        errorMessage = "Failed to fetch attendance: ${response.reasonPhrase}";
        Helper.debugPrint(DEBUG, errorMessage!);
        if (!mounted) return; // Check if the widget is still active
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return; // Check if the widget is still active
      setState(() {
        errorMessage = "Error fetching attendance: $e";
        Helper.debugPrint(DEBUG, errorMessage!);
        isLoading = false;
      });
    }
  }

  Future<void> _refreshAccessToken(String refreshToken) async {
    try {
      Helper.debugPrint(DEBUG, "fetching access token");
      final response = await http.post(
        Uri.parse(refreshTokenUrl), // Provide your refresh token endpoint here
        headers: {
          "Content-Type": "application/json",
        },
        body: json.encode({
          "grant_type": "refresh_token",
          "refresh": refreshToken,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        Helper.debugPrint(DEBUG, "got access token");
        final responseData = json.decode(response.body);

        // Adjusted to match the field names in the response
        String? newAccessToken = responseData["access"];
        String? newRefreshToken = responseData["refresh"];

        if (newAccessToken == null || newRefreshToken == null) {
          throw Exception("Missing token in response: $responseData");
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', newAccessToken);
        await prefs.setString('refresh_token', newRefreshToken);

        // Retry fetching attendance with the new access token
        _fetchAttendanceData();
      } else {
        Helper.debugPrint(DEBUG, "did not get access token");
        Helper.debugPrint(DEBUG, "Response: ${response.body}");
        // If refresh token is invalid or expired, log out the user
        await _logout();
      }
    } catch (e) {
      Helper.debugPrint(DEBUG, "Error refreshing token: $e");
      await _logout();
    }
  }

  String formatTime(String? time) {
    if (time == null || time.isEmpty) {
      return '-';
    }

    try {
      // Parse the time string (assuming it's in "HH:mm:ss" format)
      DateTime parsedTime = DateFormat("HH:mm:ss").parse(time);

      // Format the time to "hh:mm a" (e.g., 02:30 PM)
      return DateFormat("hh:mm a").format(parsedTime);
    } catch (e) {
      // Return "-" in case of an error
      return '-';
    }
  }

  Future<void> _markAttendance(String logType) async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Location permission is required to mark attendance.')),
      );
      return;
    }

    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      print('Error getting location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error getting location.')),
      );
      return;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cameras available.')),
      );
      return;
    }

    final firstCamera = cameras.first;
    final imagePath = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TakePictureScreen(camera: firstCamera),
      ),
    );

    if (imagePath != null) {
      setState(() {
        _imageFile = File(imagePath);
        isProcessing = true;
      });

      try {
        // ✅ Load token from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        String? token = prefs.getString('access_token');

        if (token == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No access token found, please log in again.')),
          );
          await _logout();
          return;
        }

        final request = http.MultipartRequest(
          'POST',
          Uri.parse(facialCheckUrl),
        );

        // Attach the file
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          imagePath,
          contentType: MediaType('image', 'jpeg'),
        ));

        // Add fields
        request.fields['x'] = position.latitude.toString();
        request.fields['y'] = position.longitude.toString();
        request.fields['log_type'] = logType;
        request.fields['employeeid'] = currentUser!['id'].toString();

        // ✅ Add headers (fix 422 error)
        request.headers.addAll({
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        });

        print("Sending request with headers: ${request.headers}");
        print("Request fields: ${request.fields}");

        final response = await request.send();
        final respStr = await response.stream.bytesToString();
        print("Response body: $respStr");

        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Attendance marked: $respStr')),
          );
        } else {
          print('Failed to upload image. Status: ${response.statusCode}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: ${response.statusCode}, $respStr')),
          );
        }
      } catch (e) {
        print('Error uploading image: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error marking attendance')),
        );
      } finally {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    // Refresh the attendance data when pulling down
    await _loadUserDetails();
    await _fetchAttendanceData();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || isProcessing) {
      return Scaffold(
        appBar: AppBar(
          title: Text(isLoading ? 'Loading...' : 'Processing...'),
          backgroundColor: const Color(0xFF92363E),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
              tooltip: 'Logout',
              color: Colors.white,
            ),
          ],
        ),
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
        body: RefreshIndicator(
          onRefresh: _onRefresh,
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Top Group: Welcome and Attendance Info
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Welcome, ${currentUser!['first_name']}!',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF92363E),
                          ),
                        ),
                        if (currentUser!['is_superuser'] == false)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 10),
                              if (isLoading) ...[
                                // Show the loading circle when isLoading is true
                                const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF92363E)),
                                ),
                              ] else if (attendanceData != null &&
                                  attendanceData!.isNotEmpty) ...[
                                // Show attendance data if available
                                Text(
                                  'Time In: ${formatTime(attendanceData!['time_in'])}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Color(0xFF92363E),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Time Out: ${formatTime(attendanceData!['time_out'])}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Color(0xFF92363E),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ] else ...[
                                // Show the "No attendance data" message if there's no data
                                Text(
                                  'No attendance data available',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Color(0xFF92363E),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        if (_imageFile != null)
                          Center(
                            child: Image.file(
                              _imageFile!,
                              width: 300,
                              height: 400,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          const SizedBox(
                            width: 300,
                            height: 400, // Reserve space for the image
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        floatingActionButton: Stack(
          children: [
            Positioned(
              bottom: 90,
              left: 20,
              right: 20, // Full width with 20px margin on both sides
              child: ElevatedButton(
                onPressed: () => _markAttendance('in'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF92363E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30), // Rounded edges
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.login),
                    SizedBox(width: 8),
                    Text('Mark In'),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20, // Full width with 20px margin on both sides
              child: ElevatedButton(
                onPressed: () => _markAttendance('out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF92363E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30), // Rounded edges
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Mark Out'),
                  ],
                ),
              ),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      );
    } else {
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
        body: RefreshIndicator(
            onRefresh: _onRefresh,
            child: const Center(child: Text('No user details found.'))),
      );
    }
  }
}

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
  late Future<void> _initializeControllerFuture = Future.value();

  List<CameraDescription> cameras = [];
  CameraDescription? selectedCamera;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        selectedCamera!,
        ResolutionPreset.medium,
      );

      _initializeControllerFuture = _controller.initialize();
      setState(() {});
    } catch (e) {
      print('Error initializing camera: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initializing camera: $e')),
      );
    }
  }

  Future<void> _switchCamera() async {
    try {
      final newCamera = cameras.firstWhere(
        (camera) => camera.lensDirection != selectedCamera?.lensDirection,
      );

      setState(() {
        selectedCamera = newCamera;
      });

      await _controller.dispose();

      _controller = CameraController(
        selectedCamera!,
        ResolutionPreset.medium,
      );

      _initializeControllerFuture = _controller.initialize();
      setState(() {});
    } catch (e) {
      print('Error switching camera: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error switching camera: $e')),
      );
    }
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
        title: const Text('Take a Picture'),
      ),
      body: Column(
        children: [
          FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return CameraPreview(_controller);
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            },
          ),
          Spacer(),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                ),
                Spacer(),
                SizedBox(
                  width: 80,
                  height: 80,
                  child: FloatingActionButton(
                    heroTag: null,
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
                    child: const Icon(Icons.camera_alt, size: 32),
                  ),
                ),
                Spacer(),
                SizedBox(
                  width: 80,
                  height: 80,
                  child: FloatingActionButton(
                    heroTag: null,
                    onPressed: _switchCamera,
                    child: const Icon(Icons.flip_camera_ios, size: 32),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
