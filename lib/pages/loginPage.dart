import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'home.dart';
import 'url.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _login() async {

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
        // Parse tokens from the response
        final Map<String, dynamic> data = json.decode(response.body);
        String accessToken = data['access'];
        String refreshToken = data['refresh'];

        // Decode the access token to get user_id (optional step)
        final decodedToken = _decodeToken(accessToken);
        final userId = decodedToken['user_id'];

        // Fetch user details using the access token
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login successful!')),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomePage(),
            ),
          );
        } else {
          // Handle error fetching user details
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching user details: ${userDetailsResponse.statusCode}')),
          );
        }
      } else {
        // Handle login failure
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${response.statusCode}')),
        );
      }
    } catch (e) {
      // Handle exceptions
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
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
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _login,
                      child: const Text('Login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF92363E),
                        foregroundColor: Colors.white,
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
