import 'dart:io';

final String crmBaseUrl = Platform.isIOS
    // ? 'http://192.168.10.60:8000/'  // For iOS physical
    ? 'http://localhost:8000/'  // For iOS simulator

    : 'http://10.0.2.2:8000/';  // For Android emulator

final String facialBaseUrl = Platform.isIOS
    // ? 'http://localhost:8001/'  // For iOS physical
    ? 'http://192.168.10.60:8001/'  // For iOS simulator

    : 'http://10.0.2.2:8001/';  // For Android emulator

String loginTokenUrl = crmBaseUrl + "api/token/";
String userDetailsUrl = crmBaseUrl + "api/employees/";

String facialCheckUrl = facialBaseUrl + "app_attendance";