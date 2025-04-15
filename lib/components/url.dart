import 'dart:io';

// final String crmBaseUrl = Platform.isIOS
//     ? 'http://192.168.62.34:8000/'  // For iOS physical
//     // ? 'http://localhost:8000/'  // For iOS simulator
//
//     : 'http://10.0.2.2:8000/';  // For Android emulator
//
// final String facialBaseUrl = Platform.isIOS
//     ? 'http://192.168.62.34:8001/'  // For iOS physical
//     // ? 'http://localhost:8001/'  // For iOS simulator
//
//     : 'http://10.0.2.2:8001/';  // For Android emulator

final String crmBaseUrl = 'http://10.10.10.39:8000/'; //port 8000

final String facialBaseUrl = 'http://10.10.10.39:8001/'; //port 8001

String loginTokenUrl = crmBaseUrl + "api/token/";
String userDetailsUrl = crmBaseUrl + "api/employees/";
String attendanceDetailsUrl = crmBaseUrl + "api/attendance/";

String facialCheckUrl = facialBaseUrl + "app_attendance/";