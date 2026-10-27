import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../ui/tokens.dart';
import '../ui/widgets/buttons.dart';
import '../ui/widgets/floating_card.dart';
import '../ui/widgets/hero_card.dart';

const _brand = 'BlackLodge';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String? _errorKey;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorKey = null;
    });

    try {
      final result = await authService.signInWithGoogle();
      if (result != null && mounted) {
        // Check admin status after login
        await authService.checkIsAdmin();
        if (mounted) {
          context.go('/');
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorKey = _errorKeyFor(e.code);
      });
    } catch (e) {
      setState(() {
        _errorKey = 'login.error_failed';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInAsGuest() async {
    setState(() {
      _isLoading = true;
      _errorKey = null;
    });

    try {
      await authService.signInAnonymously();
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      setState(() {
        _errorKey = 'login.error_guest';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _errorKeyFor(String code) {
    switch (code) {
      case 'popup-closed-by-user':
        return 'login.error_cancelled';
      case 'account-exists-with-different-credential':
        return 'login.error_exists';
      case 'invalid-credential':
        return 'login.error_invalid';
      case 'operation-not-allowed':
        return 'login.error_not_enabled';
      case 'user-disabled':
        return 'login.error_disabled';
      default:
        return 'login.error_failed';
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSize.maxBarWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HeroCard(
                    kicker: 'start.kicker'.tr(),
                    title: _brand,
                    titleStyle: AppText.display,
                    meta: 'login.subtitle'.tr(),
                    // Logo placeholder until the brand asset exists.
                    trailing: const Icon(
                      Icons.local_bar,
                      size: AppSize.badgeIcon,
                      color: AppColors.goldOnBlack,
                    ),
                  ),
                  if (_errorKey != null) ...[
                    const SizedBox(height: AppSpace.s16),
                    FloatingCard(
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: AppSize.glassButtonIcon,
                            color: p.error,
                          ),
                          const SizedBox(width: AppSpace.s12),
                          Expanded(
                            child: Text(
                              _errorKey!.tr(),
                              style: AppText.body.copyWith(color: p.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpace.s24),
                  PrimaryButton(
                    label: 'login.google'.tr(),
                    loading: _isLoading,
                    onPressed: _isLoading ? null : _signInWithGoogle,
                  ),
                  const SizedBox(height: AppSpace.s8),
                  TextAction(
                    label: 'login.guest'.tr(),
                    onPressed: _isLoading ? null : _signInAsGuest,
                  ),
                  const SizedBox(height: AppSpace.s8),
                  Text(
                    'login.guest_hint'.tr(),
                    textAlign: TextAlign.center,
                    style: AppText.caption.copyWith(color: p.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
