import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/employee.dart';
import 'firestore_service.dart';

/// Repository for employee CRUD operations.
class EmployeeRepository {
  Stream<List<Employee>> watchEmployees() {
    if (!firestoreService.isAvailable) return Stream.value([]);
    // Sort locally to handle docs without sortOrder field
    return firestoreService.employeesCollection
        .snapshots()
        .map((s) {
          final employees = s.docs
              .map((d) => Employee.fromFirestore(d.id, d.data()))
              .toList();
          employees.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          return employees;
        })
        .handleError((e) {
      debugPrint('Failed to watch employees: $e');
      return <Employee>[];
    });
  }

  Future<int> _getNextSortOrder() async {
    try {
      final snapshot = await firestoreService.employeesCollection.get();
      if (snapshot.docs.isEmpty) return 0;
      int maxOrder = 0;
      for (final doc in snapshot.docs) {
        final order = doc.data()['sortOrder'] as int? ?? 0;
        if (order > maxOrder) maxOrder = order;
      }
      return maxOrder + 1;
    } catch (e) {
      return 0;
    }
  }

  Future<bool> addEmployee({
    required String name,
    String? email,
    EmployeeRole role = EmployeeRole.staff,
  }) async {
    if (!firestoreService.isAvailable) return false;
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final sortOrder = await _getNextSortOrder();
      final data = <String, dynamic>{
        'name': name,
        'role': role.firestoreValue,
        'sortOrder': sortOrder,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentUser?.email ?? currentUser?.uid ?? 'unknown',
      };
      if (email != null && email.isNotEmpty) {
        data['email'] = email;
      }
      await firestoreService.employeesCollection.add(data);
      return true;
    } catch (e) {
      debugPrint('Failed to add employee: $e');
      return false;
    }
  }

  Future<bool> updateEmployee({
    required String id,
    required String name,
    String? email,
    EmployeeRole? role,
  }) async {
    if (!firestoreService.isAvailable) return false;
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final data = <String, dynamic>{
        'name': name,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': currentUser?.email ?? currentUser?.uid ?? 'unknown',
      };
      if (email != null && email.isNotEmpty) {
        data['email'] = email;
      } else {
        data['email'] = FieldValue.delete();
      }
      if (role != null) {
        data['role'] = role.firestoreValue;
      }
      await firestoreService.employeesCollection.doc(id).update(data);
      return true;
    } catch (e) {
      debugPrint('Failed to update employee: $e');
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

  /// Reorder employees by updating their sortOrder values.
  Future<bool> reorderEmployees(List<Employee> employees) async {
    if (!firestoreService.isAvailable) return false;
    try {
      final batch = firestoreService.firestore.batch();
      for (var i = 0; i < employees.length; i++) {
        final ref = firestoreService.employeesCollection.doc(employees[i].id);
        batch.update(ref, {'sortOrder': i});
      }
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Failed to reorder employees: $e');
      return false;
    }
  }
}

final employeeRepository = EmployeeRepository();
