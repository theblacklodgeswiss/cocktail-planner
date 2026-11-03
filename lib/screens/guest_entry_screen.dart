import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../ui/widgets/states.dart';

/// `/login` has no form any more: a visitor without an account is signed in
/// as a guest and lands in the order form; signed-in users go to their
/// start. Staff sign in with Google from the user menu.
///
/// Only a loading state is shown, plus a retry if the guest sign-in fails.
/// [currentUser] and [signInAsGuest] are overridden in tests.
class GuestEntryScreen extends StatefulWidget {
  const GuestEntryScreen({super.key, this.currentUser, this.signInAsGuest});

  final User? Function()? currentUser;
  final Future<void> Function()? signInAsGuest;

  @override
  State<GuestEntryScreen> createState() => _GuestEntryScreenState();
}

class _GuestEntryScreenState extends State<GuestEntryScreen> {
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _enter();
  }

  Future<void> _enter() async {
    if (_failed) setState(() => _failed = false);
    final user = (widget.currentUser ?? () => authService.currentUser)();
    try {
      if (user == null) {
        await (widget.signInAsGuest ?? authService.signInAnonymously)();
      }
      if (!mounted) return;
      // Guests (new here or already signed in) start with the order form,
      // staff and Google users with their start page.
      final guest = user == null || user.isAnonymous;
      context.go(guest ? '/order-form' : '/');
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _failed
            ? ErrorState(message: 'login.error_guest'.tr(), onRetry: _enter)
            : const LoadingState(),
      ),
    );
  }
}
