import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AppErrorMessage {
  const AppErrorMessage._();

  static String from(
    Object error, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    if (error is FirebaseAuthException) {
      return _authMessage(error.code);
    }
    if (error is FirebaseException) {
      return _firebaseMessage(error.code);
    }
    final normalizedError = error.toString().toLowerCase();
    if (error is TimeoutException ||
        normalizedError.contains('socketexception') ||
        normalizedError.contains('handshakeexception')) {
      return 'Unable to connect to the server. Check your internet connection and try again.';
    }

    final code = _extractCode(error);
    if (code != null) {
      return _firebaseMessage(code);
    }
    return fallback;
  }

  static String _authMessage(String code) {
    switch (_normalize(code)) {
      case 'network-request-failed':
      case 'network-error':
        return 'Unable to connect to the server. Check your internet connection and try again.';
      case 'user-disabled':
        return 'This account is currently unavailable. Contact support for help.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a while and try again.';
      case 'invalid-email':
        return 'Enter a valid email address and try again.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'The email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Choose a stronger password and try again.';
      case 'operation-not-allowed':
        return 'This sign-in option is currently unavailable. Please try again later.';
      default:
        return 'Unable to complete sign-in. Please try again.';
    }
  }

  static String _firebaseMessage(String code) {
    switch (_normalize(code)) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'Access denied. Please sign in again or contact support.';
      case 'unavailable':
      case 'deadline-exceeded':
      case 'aborted':
        return 'Service is temporarily unavailable. Please try again.';
      case 'network-request-failed':
      case 'network-error':
        return 'Unable to connect to the server. Check your internet connection and try again.';
      case 'failed-precondition':
        return 'This request cannot be completed right now. Please try again later.';
      case 'already-exists':
        return 'This information already exists.';
      case 'not-found':
        return 'The requested information could not be found.';
      case 'resource-exhausted':
        return 'The service is busy. Please wait a while and try again.';
      case 'cancelled':
        return 'The request was cancelled. Please try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  static String? _extractCode(Object error) {
    final text = error.toString().toLowerCase();
    final knownCodes = [
      'network-request-failed',
      'permission-denied',
      'unauthenticated',
      'unavailable',
      'deadline-exceeded',
      'failed-precondition',
      'already-exists',
      'not-found',
      'resource-exhausted',
      'cancelled',
    ];
    for (final code in knownCodes) {
      if (text.contains(code)) return code;
    }
    return null;
  }

  static String _normalize(String code) {
    final normalized = code.toLowerCase().split('/').last;
    return normalized.replaceAll('_', '-');
  }

  static void log(
    Object error,
    StackTrace stackTrace, {
    required String context,
  }) {
    final code = error is FirebaseException
        ? error.code
        : error is FirebaseAuthException
        ? error.code
        : null;
    debugPrint(
      '$context failed (${error.runtimeType}${code == null ? '' : ', code: $code'}).',
    );
    debugPrint('$context stack trace: $stackTrace');
  }
}
