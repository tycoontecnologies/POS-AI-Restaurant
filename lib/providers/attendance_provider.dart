import 'package:flutter/foundation.dart';
import 'package:pos/models/attendance.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/services/attendance_service.dart';

class AttendanceProvider with ChangeNotifier {
  final AuthProvider authProvider;
  List<Attendance> _todayAttendance = [];
  bool _isLoading = false;

  AttendanceProvider(this.authProvider);

  List<Attendance> get todayAttendance => _todayAttendance;
  bool get isLoading => _isLoading;

  String get _vendorId => authProvider.currentUser?.id ?? '';

  Stream<List<Attendance>> getAttendanceByDate(DateTime date) {
    return FirebaseAttendanceService.getAttendanceByDate(_vendorId, date);
  }

  Future<Attendance?> getAttendanceByStaffAndDate(
    String staffId,
    DateTime date,
  ) async {
    return await FirebaseAttendanceService.getAttendanceByStaffAndDate(
      _vendorId,
      staffId,
      date,
    );
  }

  Future<void> markAttendance(Attendance attendance) async {
    _setLoading(true);
    try {
      if (attendance.id.isEmpty) {
        await FirebaseAttendanceService.addAttendance(_vendorId, attendance);
      } else {
        await FirebaseAttendanceService.updateAttendance(_vendorId, attendance);
      }
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> markBulkAttendance(List<Attendance> attendanceList) async {
    _setLoading(true);
    try {
      await FirebaseAttendanceService.markBulkAttendance(
        _vendorId,
        attendanceList,
      );
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> checkInStaff(String staffId) async {
    _setLoading(true);
    try {
      await FirebaseAttendanceService.checkInStaff(_vendorId, staffId);
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> checkOutStaff(String staffId) async {
    _setLoading(true);
    try {
      await FirebaseAttendanceService.checkOutStaff(_vendorId, staffId);
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void updateAttendanceList(List<Attendance> attendance) {
    _todayAttendance = attendance;
    notifyListeners();
  }
  // Add these methods to AttendanceProvider in attendance_provider.dart

  Stream<List<Attendance>> getAttendanceByMonth(DateTime month) {
    return FirebaseAttendanceService.getAttendanceByMonth(_vendorId, month);
  }

  Stream<List<Attendance>> getStaffAttendanceByMonth(
    String staffId,
    DateTime month,
  ) {
    return FirebaseAttendanceService.getStaffAttendanceByMonth(
      _vendorId,
      staffId,
      month,
    );
  }
}
