import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gcs_attendence/main.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'home.dart';
import '../components/url.dart';
import '../components/alertDialog.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false; // Variable to toggle password visibility
  bool _isLoading = false; // New variable to track loading state

  Future<void> _login() async {
    setState(() {
      _isLoading = true; // Set loading to true when login starts
    });

    // Prepare the body
    final Map<String, String> requestBody = {
      "username": _usernameController.text,
      "password": _passwordController.text,
    };

    try {
      var response = await http.post(
        Uri.parse(loginTokenUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 307) {
        // Follow the redirect URL from the Location header
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          response = await http.post(
            Uri.parse(redirectUrl),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(requestBody),
          );
        }
      }

      if (response.statusCode == 200) {
        print("Logged in successfully");
        // Parse tokens from the response
        final Map<String, dynamic> data = json.decode(response.body);
        String accessToken = data['access'];
        String refreshToken = data['refresh'];

        // Decode the access token to get user_id (optional step)
        final decodedToken = _decodeToken(accessToken);
        print(decodedToken);
        final userId = decodedToken['id'];

        // Fetch user details using the access token
        print(userDetailsUrl + "$userId/");
        final userDetailsResponse = await http.get(
          Uri.parse(userDetailsUrl + "$userId/"),
          headers: {'Authorization': 'Bearer $accessToken'},
        );

        if (userDetailsResponse.statusCode == 200) {
          // Parse and store user details
          final userDetails = json.decode(userDetailsResponse.body);

          final prefs = await SharedPreferences.getInstance();
          // Save tokens
          prefs.setString('access_token', accessToken);
          prefs.setString('refresh_token', refreshToken);

          // Save user details
          prefs.setString('current_user', json.encode(userDetails));

          // Navigate to the home page
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainPage(),
            ),
          );

          // Show success message
          MessageSnackbar.show(
            context,
            type: MessageType.success,
            message: 'Login successful!',
          );
        } else if (userDetailsResponse.statusCode == 401) {
          // Unauthorized error
          MessageSnackbar.show(
            context,
            type: MessageType.error,
            message: 'Session expired. Please log in again.',
          );
        } else if (userDetailsResponse.statusCode == 404) {
          // User not found
          MessageSnackbar.show(
            context,
            type: MessageType.error,
            message: 'User details not found. Please contact support.',
          );
        } else {
          // Other errors
          MessageSnackbar.show(
            context,
            type: MessageType.error,
            message:
                'Error fetching user details! Status: ${userDetailsResponse.statusCode}',
          );
        }
      } else if (response.statusCode == 400) {
        // Bad Request
        MessageSnackbar.show(
          context,
          type: MessageType.error,
          message: 'Invalid request. Please check your input.',
        );
      } else if (response.statusCode == 401) {
        // Unauthorized
        MessageSnackbar.show(
          context,
          type: MessageType.error,
          message: 'Invalid credentials. Please try again.',
        );
      } else if (response.statusCode == 403) {
        // Forbidden
        MessageSnackbar.show(
          context,
          type: MessageType.error,
          message: 'You do not have permission to log in. Contact support.',
        );
      } else if (response.statusCode == 404) {
        // Not Found
        MessageSnackbar.show(
          context,
          type: MessageType.error,
          message: 'Server not found. Please try again later.',
        );
      } else if (response.statusCode == 500) {
        // Internal Server Error
        MessageSnackbar.show(
          context,
          type: MessageType.error,
          message: 'Server error. Please try again later.',
        );
      } else {
        // Handle unknown errors
        MessageSnackbar.show(
          context,
          type: MessageType.error,
          message: 'Login failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      // Handle exceptions
      MessageSnackbar.show(
        context,
        type: MessageType.error,
        message: 'An error occurred: $e',
      );
    } finally {
      setState(() {
        _isLoading =
            false; // Reset loading to false after the request completes
      });
    }
  }

  // Helper function to decode a JWT token
  Map<String, dynamic> _decodeToken(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw Exception('Invalid token');
    }

    final payload = parts[1];
    final normalizedPayload = base64Url.normalize(payload);
    final decodedBytes = base64Url.decode(normalizedPayload);
    final decodedString = utf8.decode(decodedBytes);

    return json.decode(decodedString);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          Image.asset(
            'assets/loginbg.jpg',
            fit: BoxFit.cover,
          ),
          // Content Overlay
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF000000).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/logo.png',
                      height: 100,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF92363E),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _usernameController,
                      style: const TextStyle(color: Color(0xFF92363E)),
                      decoration: InputDecoration(
                        labelText: 'Username',
                        labelStyle: const TextStyle(color: Color(0xFF92363E)),
                        border: const OutlineInputBorder(),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF92363E)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF92363E)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      style: const TextStyle(color: Color(0xFF92363E)),
                      obscureText: !_isPasswordVisible, // Toggle the visibility
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: const TextStyle(color: Color(0xFF92363E)),
                        border: const OutlineInputBorder(),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF92363E)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF92363E)),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: const Color(0xFF92363E),
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible =
                                  !_isPasswordVisible; // Toggle password visibility
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : _login, // Disable button while loading
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text('Login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF92363E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 15),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
