import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/employee.dart';
import 'firestore_service.dart';

/// Normalizes an email for use as an `employeeAccess` document ID: trims
/// whitespace and lowercases. Returns null for null/empty/whitespace-only
/// input, matching how `allowedUsers` doc IDs are already normalized in
/// `auth_service.dart`.
String? normalizeAccessEmail(String? email) {
  if (email == null) return null;
  final trimmed = email.trim();
  return trimmed.isEmpty ? null : trimmed.toLowerCase();
}

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
      final normalizedEmail = normalizeAccessEmail(email);
      final data = <String, dynamic>{
        'name': name,
        'role': role.firestoreValue,
        'sortOrder': sortOrder,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentUser?.email ?? currentUser?.uid ?? 'unknown',
      };
      if (normalizedEmail != null) {
        data['email'] = normalizedEmail;
      }

      final batch = firestoreService.firestore.batch();
      final employeeRef = firestoreService.employeesCollection.doc();
      batch.set(employeeRef, data);
      if (normalizedEmail != null) {
        batch.set(
          firestoreService.firestore
              .collection('employeeAccess')
              .doc(normalizedEmail),
          {
            'employeeId': employeeRef.id,
            'role': role.firestoreValue,
            'name': name,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      }
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Failed to add employee: $e');
      return false;
    }
  }

  Future<bool> updateEmployee({
    required Employee previous,
    required String name,
    String? email,
    EmployeeRole? role,
  }) async {
    if (!firestoreService.isAvailable) return false;
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final normalizedNewEmail = normalizeAccessEmail(email);
      final normalizedOldEmail = normalizeAccessEmail(previous.email);
      final resolvedRole = role ?? previous.role;

      final data = <String, dynamic>{
        'name': name,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': currentUser?.email ?? currentUser?.uid ?? 'unknown',
      };
      if (normalizedNewEmail != null) {
        data['email'] = normalizedNewEmail;
      } else {
        data['email'] = FieldValue.delete();
      }
      if (role != null) {
        data['role'] = role.firestoreValue;
      }

      final batch = firestoreService.firestore.batch();
      batch.update(
        firestoreService.employeesCollection.doc(previous.id),
        data,
      );

      final accessCollection =
          firestoreService.firestore.collection('employeeAccess');
      if (normalizedOldEmail != null &&
          normalizedOldEmail != normalizedNewEmail) {
        batch.delete(accessCollection.doc(normalizedOldEmail));
      }
      if (normalizedNewEmail != null) {
        batch.set(accessCollection.doc(normalizedNewEmail), {
          'employeeId': previous.id,
          'role': resolvedRole.firestoreValue,
          'name': name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Failed to update employee: $e');
      return false;
    }
  }

  Future<bool> deleteEmployee(Employee employee) async {
    if (!firestoreService.isAvailable) return false;
    try {
      final batch = firestoreService.firestore.batch();
      batch.delete(firestoreService.employeesCollection.doc(employee.id));
      final normalizedEmail = normalizeAccessEmail(employee.email);
      if (normalizedEmail != null) {
        batch.delete(
          firestoreService.firestore
              .collection('employeeAccess')
              .doc(normalizedEmail),
        );
      }
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Failed to delete employee: $e');
      return false;
    }
  }

  /// Rebuilds the `employeeAccess` mirror from the current `employees`
  /// roster: writes one mirror doc per roster entry that has an email, and
  /// deletes mirror docs with no matching roster entry. Idempotent - safe to
  /// run repeatedly (initial rollout, or as a repair action from the
  /// Employees screen).
  Future<int> rebuildEmployeeAccessIndex() async {
    if (!firestoreService.isAvailable) return 0;
    try {
      final employeesSnapshot = await firestoreService.employeesCollection.get();
      final employees = employeesSnapshot.docs
          .map((d) => Employee.fromFirestore(d.id, d.data()))
          .toList();

      final accessCollection =
          firestoreService.firestore.collection('employeeAccess');
      final existingMirrorDocs = await accessCollection.get();

      final expectedEmails = <String>{};
      final batch = firestoreService.firestore.batch();
      var written = 0;

      for (final employee in employees) {
        final normalizedEmail = normalizeAccessEmail(employee.email);
        if (normalizedEmail == null) continue;
        expectedEmails.add(normalizedEmail);
        batch.set(accessCollection.doc(normalizedEmail), {
          'employeeId': employee.id,
          'role': employee.role.firestoreValue,
          'name': employee.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        written++;
      }

      for (final doc in existingMirrorDocs.docs) {
        if (!expectedEmails.contains(doc.id)) {
          batch.delete(doc.reference);
        }
      }

      await batch.commit();
      return written;
    } catch (e) {
      debugPrint('Failed to rebuild employeeAccess index: $e');
      return 0;
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
