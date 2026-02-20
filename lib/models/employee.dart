/// Represents a staff member who can be assigned to orders.
class Employee {
  const Employee({
    required this.id,
    required this.name,
    this.email = '',
  });

  final String id;
  final String name;
  final String email;

  factory Employee.fromFirestore(String id, Map<String, dynamic> data) {
    return Employee(
      id: id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
      };
}
