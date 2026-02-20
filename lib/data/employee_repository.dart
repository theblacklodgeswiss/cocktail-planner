import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/employee.dart';
import 'firestore_service.dart';

/// Repository for employee CRUD operations.
class EmployeeRepository {
  Stream<List<Employee>> watchEmployees() {
    if (!firestoreService.isAvailable) return Stream.value([]);
    return firestoreService.employeesCollection
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs
            .map((d) => Employee.fromFirestore(d.id, d.data()))
            .toList())
        .handleError((e) {
      debugPrint('Failed to watch employees: $e');
      return <Employee>[];
    });
  }

  Future<bool> addEmployee({
    required String name,
    required String email,
  }) async {
    if (!firestoreService.isAvailable) return false;
    try {
      await firestoreService.employeesCollection.add({
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Failed to add employee: $e');
      return false;
    }
  }

  Future<bool> deleteEmployee(String id) async {
    if (!firestoreService.isAvailable) return false;
    try {
      await firestoreService.employeesCollection.doc(id).delete();
      return true;
    } catch (e) {
      debugPrint('Failed to delete employee: $e');
      return false;
    }
  }
}

final employeeRepository = EmployeeRepository();
