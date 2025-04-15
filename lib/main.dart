import 'package:flutter/material.dart';
import 'pages/loginPage.dart';
import 'pages/home.dart';
import 'pages/attendancePage.dart'; // Replace with your actual attendance page

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    HomePage(),
    AttendancePage(),
    LoginPage()
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF92363E), // Set the background color
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Colors.white, // Set the color for the selected item
        unselectedItemColor: Colors.white, // Set the color for unselected items
        selectedFontSize: 0.0,
        unselectedFontSize: 0.0,
        items: [
          BottomNavigationBarItem(
            icon: Icon(
              Icons.home,
              size: _currentIndex == 0 ? 30.0 : 24.0, // Increase size for selected item
            ),
            label: '', // Hide the label for the Home icon
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.event_note,
              size: _currentIndex == 1 ? 30.0 : 24.0, // Increase size for selected item
            ),
            label: '', // Hide the label for the Attendance icon
          ),
        ],
      ),
    );
  }
}
