import 'package:flutter/material.dart';

/// Public, signed-out-accessible screen that resolves a `/s/:code` share
/// link. Filled in by Task 7.
class SharedDocumentScreen extends StatelessWidget {
  const SharedDocumentScreen({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('code: $code')));
  }
}
