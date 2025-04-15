import 'dart:convert';
import 'package:intl/intl.dart'; // For date formatting
import 'package:http/http.dart' as http; // For network requests
import 'package:shared_preferences/shared_preferences.dart'; // For shared preferences

class Helper {

  // IN: YYYY-MM-DD
  // OUT: DD-MM-YYYY
  static String formatDate(String date) {
    // Parse the string into a DateTime object
    DateTime parsedDate = DateTime.parse(date);

    // Format the DateTime object into the desired format
    String formattedDate = DateFormat('dd-MM-yyyy').format(parsedDate);

    return formattedDate;
  }

  // IN: HH:MM:SS
  // OUT: HH:MM AM/PM
  static String formatTime(String? time) {
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

  // IN: DD-MM-YYYY
  // OUT: Day of the week, e.g. 'Monday'
  static String getDayOfWeek(String date) {
    // Parse the date string (dd-mm-yyyy) into a DateTime object
    DateFormat inputFormat = DateFormat('dd-MM-yyyy');
    DateTime parsedDate = inputFormat.parse(date);

    // Format the DateTime object to get the day name
    DateFormat outputFormat = DateFormat('EEEE');
    return outputFormat.format(parsedDate); // Returns the day, e.g., "Monday"
  }

  // Function to check if the string is a valid email
  static bool isValidEmail(String email) {
    final RegExp emailRegExp = RegExp(
        r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
    return emailRegExp.hasMatch(email);
  }

  // Function to check if the string is a valid phone number
  static bool isValidPhoneNumber(String phone) {
    final RegExp phoneRegExp = RegExp(r"^[0-9]{10}$");
    return phoneRegExp.hasMatch(phone);
  }

  //Pring statements if debugging is needed
  static void debugPrint(int debug, String message) {
    if (debug == 1) {
      print(message);
    }
  }
}

