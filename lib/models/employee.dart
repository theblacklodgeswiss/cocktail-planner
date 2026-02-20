/// Employee role enumeration.
enum EmployeeRole {
  leadingSupervisor,
  supervisor,
  staff;

  String get firestoreValue {
    switch (this) {
      case EmployeeRole.leadingSupervisor:
        return 'leading_supervisor';
      case EmployeeRole.supervisor:
        return 'supervisor';
      case EmployeeRole.staff:
        return 'staff';
    }
  }

  static EmployeeRole fromFirestore(String? value) {
    switch (value) {
      case 'leading_supervisor':
        return EmployeeRole.leadingSupervisor;
      case 'supervisor':
        return EmployeeRole.supervisor;
      case 'staff':
      default:
        return EmployeeRole.staff;
    }
  }
}

/// Represents a staff member who can be assigned to orders.
class Employee {
  const Employee({
    required this.id,
    required this.name,
    this.email,
    this.role = EmployeeRole.staff,
    this.sortOrder = 0,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String name;
  final String? email;
  final EmployeeRole role;
  final int sortOrder;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory Employee.fromFirestore(String id, Map<String, dynamic> data) {
    return Employee(
      id: id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String?,
      role: EmployeeRole.fromFirestore(data['role'] as String?),
      sortOrder: data['sortOrder'] as int? ?? 0,
      createdAt: (data['createdAt'] as dynamic)?.toDate(),
      createdBy: data['createdBy'] as String?,
      updatedAt: (data['updatedAt'] as dynamic)?.toDate(),
      updatedBy: data['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        if (email != null && email!.isNotEmpty) 'email': email,
        'role': role.firestoreValue,
        'sortOrder': sortOrder,
      };
}
