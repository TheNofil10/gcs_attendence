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

// final String crmBaseUrl = 'http://192.168.62.25:8000/'; //port 8000
// final String facialBaseUrl = 'http://192.168.62.25:8001/'; //port 8001

final String crmBaseUrl = 'http://110.39.151.34:8002/'; //port 8000
final String facialBaseUrl = 'http://110.39.151.34:8002/'; //port 8001

String facialCheckUrl = facialBaseUrl + "proxy_attendance/";

String loginTokenUrl = crmBaseUrl + "proxy_token/";
String refreshTokenUrl = crmBaseUrl + "proxy_token_refresh/";

String userDetailsUrl = crmBaseUrl + "proxy_employees/";
String attendanceTodayUrl = crmBaseUrl + "proxy_attendance_home/";
String attendanceHistoryUrl = crmBaseUrl + "proxy_attendance_history/";
