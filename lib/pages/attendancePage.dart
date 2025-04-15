import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../components/url.dart';
import 'package:intl/intl.dart';
import '../components/helper.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  _AttendancePageState createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  Map<String, dynamic>? currentUser;
  bool isLoading = true;
  bool isProcessing = false; // To indicate processing after taking a picture
  List<dynamic>? attendanceData; // Holds the attendance data
  String? errorMessage;
  String _selectedFilter = 'This Week';
  List<String> _filters = [
    'This Week',
    'This Month',
    'Custom'
  ]; // Dropdown filter options
  DateTimeRange? _customDateRange;
  TextEditingController _searchController =
      TextEditingController(); // Controller for text box
  List<dynamic>? filteredAttendanceData;

  // Fetch attendance data from the backend
  Future<void> _fetchAttendanceData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('access_token');

      // Build URL with dynamic filter
      String dateFilter = _selectedFilter == 'Custom'
          ? 'custom'
          : _selectedFilter.toLowerCase().replaceAll(' ', '_');

      // Construct the base URL
      String url = attendanceHistoryUrl + "?dateFilter=$dateFilter";

      if (_selectedFilter == 'Custom' && _customDateRange != null) {
        // Format start and end date to "YYYY-MM-DD"
        String startDate = _customDateRange!.start
            .toIso8601String()
            .split('T')[0]; // Get the date part only
        String endDate = _customDateRange!.end
            .toIso8601String()
            .split('T')[0]; // Get the date part only

        url += "&start_date=$startDate&end_date=$endDate";
      }

      final response = await http.get(
        Uri.parse(url), // Use the dynamic URL with query parameters

        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          attendanceData =
              List.from(json.decode(response.body)).reversed.toList();

          attendanceData?.sort((a, b) {
            String dateA = a['date'] ?? '';
            String dateB = b['date'] ?? '';

            int dateComparison = dateA.compareTo(dateB);
            if (dateComparison != 0) {
              return -dateComparison; // Descending order
            }

            String timeInA = a['time_in'] ?? '';
            String timeInB = b['time_in'] ?? '';

            return timeInB.compareTo(timeInA); // Ascending order
          });

          filteredAttendanceData =
              List.from(attendanceData!); // Initialize filtered data
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = "Failed to fetch attendance: ${response.reasonPhrase}";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Error fetching attendance: $e";
        isLoading = false;
      });
    }
  }

  Future<void> _loadUserDetails() async {
    final prefs = await SharedPreferences.getInstance();

    String? userData = prefs.getString('current_user');

    if (userData != null) {
      setState(() {
        currentUser = json.decode(userData);
        print("currentUser");
        print(currentUser);
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
      print('No user data found in SharedPreferences');
    }
  }

  void _filterData() {
    if (_searchController.text.isEmpty) {
      setState(() {
        filteredAttendanceData = List.from(attendanceData!);
      });
    } else {
      setState(() {
        filteredAttendanceData = attendanceData?.where((record) {
          String employeeName = record['employee_name']?.toLowerCase() ?? '';
          return employeeName.contains(_searchController.text.toLowerCase());
        }).toList();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
    _searchController.addListener(_filterData);
    _fetchAttendanceData();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Colors.green.withOpacity(0.2); // Pastel green
      case 'late':
        return Colors.yellow.withOpacity(0.3); // Pastel yellow
      case 'absent':
        return Colors.red.withOpacity(0.3); // Pastel red
      default:
        return Colors.transparent; // No color if status is unknown
    }
  }

  // Show a date range picker for custom dates
  Future<void> _selectCustomDateRange() async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime(2101),
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedFilter = 'Custom';
      });
      _fetchAttendanceData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF92363E),
        title: const Text(
          'Attendance',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dropdown filter selector
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search by Employee Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: DropdownButton<String>(
                    value: _selectedFilter,
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedFilter = newValue!;
                        if (_selectedFilter != 'Custom') {
                          _fetchAttendanceData(); // Fetch data for the selected filter
                        } else {
                          _selectCustomDateRange(); // Show custom date range picker
                        }
                      });
                    },
                    items:
                        _filters.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: TextStyle(color: Colors.black),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            // Data display section
            isLoading
                ? const Center(
                    child: CircularProgressIndicator()) // Show loading spinner
                : errorMessage != null
                    ? Center(
                        child: Text(errorMessage!)) // Display error message
                    : Expanded(
                        child: ListView.builder(
                          itemCount: filteredAttendanceData?.length ?? 0,
                          itemBuilder: (context, index) {
                            final attendance = filteredAttendanceData![index];
                            final String status = attendance['status'];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                  horizontal: 8.0), // Add spacing between items
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                      status), // Set background color based on status
                                  borderRadius: BorderRadius.circular(
                                      12.0), // Rounded edges
                                ),
                                child: currentUser?['is_manager'] ||
                                        currentUser?['is_hr_manager'] ||
                                        currentUser?['is_superuser']
                                    ? ListTile(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                              12.0), // Match the rounding
                                        ),
                                        title: Text(
                                          attendance['employee_name'],
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Text(
                                          Helper.formatDate(attendance['date']),
                                          style:
                                              const TextStyle(fontSize: 14.0),
                                        ),
                                        trailing: Column(
                                          children: [
                                            Text(
                                              Helper.getDayOfWeek(
                                                  Helper.formatDate(
                                                      attendance['date'])),
                                              style: const TextStyle(
                                                  fontSize: 12.0,
                                                  fontWeight: FontWeight.w800),
                                            ),
                                            Text(
                                              'IN: ${Helper.formatTime(attendance['time_in'])}',
                                              style: const TextStyle(
                                                  fontSize: 12.0),
                                            ),
                                            Text(
                                              'OUT: ${Helper.formatTime(attendance['time_out'])}',
                                              style: const TextStyle(
                                                  fontSize: 12.0),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListTile(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                              12.0), // Match the rounding
                                        ),
                                        title: Text(
                                          Helper.formatDate(attendance['date']),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Text(
                                          status,
                                          style:
                                              const TextStyle(fontSize: 14.0),
                                        ),
                                        trailing: Column(
                                          children: [
                                            Text(
                                              Helper.getDayOfWeek(
                                                  Helper.formatDate(
                                                      attendance['date'])),
                                              style: const TextStyle(
                                                  fontSize: 12.0,
                                                  fontWeight: FontWeight.w800),
                                            ),
                                            Text(
                                              'IN: ${Helper.formatTime(attendance['time_in'])}',
                                              style: const TextStyle(
                                                  fontSize: 12.0),
                                            ),
                                            Text(
                                              'OUT: ${Helper.formatTime(attendance['time_out'])}',
                                              style: const TextStyle(
                                                  fontSize: 12.0),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                      ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose(); // Dispose the controller
    super.dispose();
  }
}
