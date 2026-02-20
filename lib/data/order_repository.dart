import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/order.dart' show SavedOrder;
import '../services/auth_service.dart';
import 'firestore_service.dart';

/// Repository for order operations.
class OrderRepository {
  /// Save an order to Firestore.
  /// Returns the order ID if successful, null if Firebase unavailable.
  Future<String?> saveOrder({
    required String name,
    required DateTime date,
    required List<Map<String, dynamic>> items,
    required double total,
    required String currency,
    int personCount = 0,
    String drinkerType = 'normal',
    String status = 'quote',
    List<String> cocktails = const [],
    List<String> shots = const [],
    String bar = '',
    int distanceKm = 0,
    double thekeCost = 0,
  }) async {
    if (!firestoreService.isAvailable) {
      debugPrint('Firebase not available, order not saved to cloud');
      return null;
    }

    try {
      final docRef = await firestoreService.ordersCollection.add({
        'name': name,
        'date': date.toIso8601String(),
        'items': items,
        'total': total,
        'currency': currency,
        'personCount': personCount,
        'drinkerType': drinkerType,
        'status': status,
        'cocktails': cocktails,
        'shots': shots,
        'bar': bar,
        'distanceKm': distanceKm,
        'thekeCost': thekeCost,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': authService.email ?? authService.currentUser?.uid,
      });
      return docRef.id;
    } catch (e) {
      debugPrint('Failed to save order: $e');
      return null;
    }
  }

  /// Update order status in Firestore.
  Future<bool> updateStatus(String orderId, String status) async {
    if (!firestoreService.isAvailable) return false;

    try {
      await firestoreService.ordersCollection.doc(orderId).update({
        'status': status,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Failed to update order status: $e');
      return false;
    }
  }

  /// Update order with offer-related data.
  Future<bool> updateOfferData({
    required String orderId,
    required String clientName,
    required String clientContact,
    required String eventTime,
    required List<String> eventTypes,
    required double discount,
    required String language,
    required DateTime eventDate,
    List<Map<String, dynamic>> extraPositions = const [],
  }) async {
    if (!firestoreService.isAvailable) return false;

    try {
      await firestoreService.ordersCollection.doc(orderId).update({
        'offerClientName': clientName,
        'offerClientContact': clientContact,
        'offerEventTime': eventTime,
        'offerEventTypes': eventTypes,
        'offerDiscount': discount,
        'offerLanguage': language,
        'offerExtraPositions': extraPositions,
        'offerUpdatedAt': FieldValue.serverTimestamp(),
        'date': eventDate.toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Failed to update order offer data: $e');
      return false;
    }
  }

  /// Fetch saved orders, optionally filtered by year.
  Future<List<SavedOrder>> getOrders({int? year}) async {
    if (!firestoreService.isAvailable) return [];

    try {
      final snapshot = await firestoreService.ordersCollection
          .orderBy('createdAt', descending: true)
          .get();
      final orders = snapshot.docs
          .map((doc) => SavedOrder.fromFirestore(doc.id, doc.data()))
          .toList();
      if (year != null) {
        return orders.where((o) => o.year == year).toList();
      }
      return orders;
    } catch (e) {
      debugPrint('Failed to fetch orders: $e');
      return [];
    }
  }

  /// Watch orders as a real-time stream.
  Stream<List<SavedOrder>> watchOrders({int? year}) {
    if (!firestoreService.isAvailable) {
      return Stream.value([]);
    }

    return firestoreService.ordersCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final orders = snapshot.docs
          .map((doc) => SavedOrder.fromFirestore(doc.id, doc.data()))
          .toList();
      if (year != null) {
        return orders.where((o) => o.year == year).toList();
      }
      return orders;
    }).handleError((e) {
      debugPrint('Failed to watch orders: $e');
      return <SavedOrder>[];
    });
  }

  /// Update the assigned employees for an order.
  Future<bool> updateAssignedEmployees(
      String orderId, List<String> employees) async {
    if (!firestoreService.isAvailable) return false;
    try {
      await firestoreService.ordersCollection.doc(orderId).update({
        'assignedEmployees': employees,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Failed to update assigned employees: $e');
      return false;
    }
  }

  /// Delete an order (super admin only).
  Future<bool> deleteOrder(String orderId) async {
    if (!firestoreService.isAvailable) return false;

    if (!authService.isSuperAdmin) {
      debugPrint('Delete order denied: not super admin');
      return false;
    }

    try {
      await firestoreService.ordersCollection.doc(orderId).delete();
      return true;
    } catch (e) {
      debugPrint('Failed to delete order: $e');
      return false;
    }
  }

  /// Fetch a single order by ID.
  Future<SavedOrder?> getOrderById(String orderId) async {
    if (!firestoreService.isAvailable) return null;

    try {
      final doc = await firestoreService.ordersCollection.doc(orderId).get();
      if (!doc.exists || doc.data() == null) return null;
      return SavedOrder.fromFirestore(doc.id, doc.data()!);
    } catch (e) {
      debugPrint('Failed to fetch order: $e');
      return null;
    }
  }
}

final orderRepository = OrderRepository();
