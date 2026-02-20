import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/order.dart';
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

  /// Update an existing order with shopping list data.
  /// Used for linking form submissions to shopping lists.
  Future<bool> updateOrderShoppingList({
    required String orderId,
    required List<Map<String, dynamic>> items,
    required double total,
    required String currency,
    int personCount = 0,
    String drinkerType = 'normal',
    List<String> cocktails = const [],
    List<String> shots = const [],
    int distanceKm = 0,
    double thekeCost = 0,
  }) async {
    if (!firestoreService.isAvailable) return false;

    try {
      await firestoreService.ordersCollection.doc(orderId).update({
        'items': items,
        'total': total,
        'currency': currency,
        'personCount': personCount,
        'drinkerType': drinkerType,
        'cocktails': cocktails,
        'shots': shots,
        'distanceKm': distanceKm,
        'thekeCost': thekeCost,
        'hasShoppingList': true,
        'shoppingListCreatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Failed to update order shopping list: $e');
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
  /// Excludes pending orders (total == 0) unless [includePending] is true.
  Stream<List<SavedOrder>> watchOrders({int? year, bool includePending = false}) {
    if (!firestoreService.isAvailable) {
      return Stream.value([]);
    }

    return firestoreService.ordersCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      var orders = snapshot.docs
          .map((doc) => SavedOrder.fromFirestore(doc.id, doc.data()))
          .toList();
      
      // Filter out pending orders (total == 0) unless explicitly included
      if (!includePending) {
        orders = orders.where((o) => o.total > 0).toList();
      }
      
      if (year != null) {
        return orders.where((o) => o.year == year).toList();
      }
      return orders;
    }).handleError((e) {
      debugPrint('Failed to watch orders: $e');
      return <SavedOrder>[];
    });
  }

  /// Watch pending orders (total == 0) across all years.
  Stream<List<SavedOrder>> watchPendingOrders() {
    if (!firestoreService.isAvailable) {
      return Stream.value([]);
    }

    return firestoreService.ordersCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SavedOrder.fromFirestore(doc.id, doc.data()))
          .where((o) => o.total == 0)
          .toList();
    }).handleError((e) {
      debugPrint('Failed to watch pending orders: $e');
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

  /// Get all existing form submission IDs with their document IDs.
  Future<Map<String, String>> getExistingFormSubmissions() async {
    if (!firestoreService.isAvailable) return {};

    try {
      final snapshot = await firestoreService.ordersCollection
          .where('source', isEqualTo: OrderSource.form.value)
          .get();
      final result = <String, String>{};
      for (final doc in snapshot.docs) {
        final formId = doc.data()['formSubmissionId'] as String?;
        if (formId != null && formId.isNotEmpty) {
          result[formId] = doc.id;
        }
      }
      return result;
    } catch (e) {
      debugPrint('Failed to get form submissions: $e');
      return {};
    }
  }

  /// Delete all form submissions (for clean re-import).
  Future<int> deleteAllFormSubmissions() async {
    if (!firestoreService.isAvailable) return 0;

    try {
      final snapshot = await firestoreService.ordersCollection
          .where('source', isEqualTo: OrderSource.form.value)
          .get();

      int count = 0;
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
        count++;
      }
      debugPrint('Deleted $count form submissions');
      return count;
    } catch (e) {
      debugPrint('Failed to delete form submissions: $e');
      return 0;
    }
  }

  /// Save or update a form submission as an order.
  Future<String?> saveOrUpdateFormSubmission({
    required String formSubmissionId,
    required String name,
    required DateTime date,
    required String phone,
    required String location,
    required String guestCountRange,
    required bool mobileBar,
    required String eventType,
    required String serviceType,
    String eventTime = '',
    DateTime? formCreatedAt,
    String? existingDocId,
  }) async {
    if (!firestoreService.isAvailable) {
      debugPrint('Firebase not available, form submission not saved');
      return null;
    }

    try {
      // Parse person count from range (e.g. "100-200" -> 150)
      int personCount = 0;
      if (guestCountRange.contains('-')) {
        final parts = guestCountRange.split('-');
        if (parts.length == 2) {
          final min = int.tryParse(parts[0].trim()) ?? 0;
          final max = int.tryParse(parts[1].trim()) ?? 0;
          personCount = ((min + max) / 2).round();
        }
      } else {
        // Handle single values like "600+" or just "600"
        final cleaned = guestCountRange.replaceAll(RegExp(r'[^0-9]'), '');
        personCount = int.tryParse(cleaned) ?? 0;
      }

      final data = {
        'name': name,
        'date': date.toIso8601String(),
        'personCount': personCount,
        'updatedAt': FieldValue.serverTimestamp(),
        // Form sync fields
        'source': OrderSource.form.value,
        'formSubmissionId': formSubmissionId,
        'formCreatedAt': formCreatedAt?.toIso8601String(),
        'phone': phone,
        'location': location,
        'guestCountRange': guestCountRange,
        'mobileBar': mobileBar,
        'eventType': eventType,
        'serviceType': serviceType,
        // Offer fields from form
        'offerClientName': name,
        'offerClientContact': phone,
        'offerEventTime': eventTime,
        'offerEventTypes': [eventType],
      };

      if (existingDocId != null) {
        // Update existing document
        await firestoreService.ordersCollection.doc(existingDocId).update(data);
        debugPrint('Updated form submission: $name');
        return existingDocId;
      } else {
        // Create new document - use formCreatedAt as createdAt if available
        final docRef = await firestoreService.ordersCollection.add({
          ...data,
          'items': <Map<String, dynamic>>[],
          'total': 0.0,
          'currency': 'CHF',
          'drinkerType': 'normal',
          'status': OrderStatus.quote.value,
          'hasShoppingList': false,
          'createdAt': formCreatedAt?.toIso8601String() ?? FieldValue.serverTimestamp(),
          'createdBy': authService.email ?? authService.currentUser?.uid,
        });
        debugPrint('Created form submission: $name');
        return docRef.id;
      }
    } catch (e) {
      debugPrint('Failed to save/update form submission: $e');
      return null;
    }
  }

  /// Update an order to mark it as having a shopping list.
  Future<bool> markHasShoppingList(String orderId, bool hasShoppingList) async {
    if (!firestoreService.isAvailable) return false;

    try {
      await firestoreService.ordersCollection.doc(orderId).update({
        'hasShoppingList': hasShoppingList,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Failed to update hasShoppingList: $e');
      return false;
    }
  }

  /// Sync form submissions from Excel rows.
  /// [rows] should be a list of rows from Excel.
  /// Excel has columns A-N, but A-D may contain form metadata.
  /// Visible data columns:
  /// E: Name, F: Phone1, G: Phone2, H: Date, I: Time,
  /// J: Location, K: GuestCount, L: MobileBar, M: EventType, N: ServiceType
  /// Returns the number of synced submissions (new + updated).
  Future<int> syncFormSubmissions({
    required List<List<String>> rows,
  }) async {
    if (!firestoreService.isAvailable) {
      debugPrint('Firebase not available');
      return -1;
    }

    if (rows.isEmpty) {
      debugPrint('No data to sync');
      return 0;
    }

    try {
      // Debug: Print first row to understand structure
      if (rows.isNotEmpty) {
        debugPrint('First row has ${rows.first.length} columns');
        for (int i = 0; i < rows.first.length && i < 15; i++) {
          debugPrint('  [$i]: "${rows.first[i]}"');
        }
      }

      // Get existing form submissions with their doc IDs
      final existingSubmissions = await getExistingFormSubmissions();
      debugPrint('Found ${existingSubmissions.length} existing form submissions');

      int syncedCount = 0;

      for (final row in rows) {
        // Excel column mapping (fixed indices):
        // [0]: ID
        // [1]: ignore
        // [2]: createdAt
        // [3]: ignore
        // [4]: ignore
        // [5]: Name
        // [6]: Kontakt (Telephone)
        // [7]: EventDatum
        // [8]: Starttime
        // [9]: Ort (Location)
        // [10]: Gäste
        // [11]: Theke Ja/Nein
        // [12]: EventTyp
        // [13-14]: ignore
        
        if (row.length < 13) {
          debugPrint('Skipping row with ${row.length} columns (need at least 13)');
          continue;
        }

        final createdAtStr = row[2].trim();
        final name = row[5].trim();
        final phone = row[6].trim();
        final dateStr = row[7].trim();
        final timeStr = row[8].trim();
        final location = row[9].trim();
        final guestCount = row[10].trim();
        final mobileBarStr = row[11].trim();
        final eventType = row[12].trim();

        // Parse createdAt (Excel serial number)
        DateTime? formCreatedAt;
        final createdAtSerial = double.tryParse(createdAtStr);
        if (createdAtSerial != null && createdAtSerial > 40000) {
          // Excel serial includes fractional days for time
          final days = createdAtSerial.floor();
          final timeFraction = createdAtSerial - days;
          final baseDate = DateTime(1899, 12, 30).add(Duration(days: days));
          final timeMs = (timeFraction * 24 * 60 * 60 * 1000).round();
          formCreatedAt = baseDate.add(Duration(milliseconds: timeMs));
        }

        if (name.isEmpty) {
          debugPrint('Skipping row with empty name');
          continue;
        }
        
        debugPrint('Processing: $name, $phone, $dateStr');

        // Create unique ID from name + phone (stable identifier across syncs)
        final formSubmissionId = '${name}_$phone'.hashCode.toString();

        // Check if this submission already exists
        final existingDocId = existingSubmissions[formSubmissionId];
        if (existingDocId != null) {
          debugPrint('  -> Will update existing doc: $existingDocId');
        } else {
          debugPrint('  -> Will create new doc');
        }

        // Parse date - can be Excel serial number (e.g., "46144") or DD.MM.YYYY
        DateTime eventDate;
        try {
          final serialNum = int.tryParse(dateStr);
          if (serialNum != null && serialNum > 40000) {
            // Excel serial date: days since 1899-12-30 (Excel's epoch with its leap year bug)
            eventDate = DateTime(1899, 12, 30).add(Duration(days: serialNum));
          } else if (dateStr.contains('.')) {
            final parts = dateStr.split('.');
            if (parts.length >= 3) {
              eventDate = DateTime(
                int.parse(parts[2].split(' ')[0]), // Year
                int.parse(parts[1]), // Month
                int.parse(parts[0]), // Day
              );
            } else {
              eventDate = DateTime.now();
            }
          } else {
            eventDate = DateTime.tryParse(dateStr) ?? DateTime.now();
          }
        } catch (_) {
          eventDate = DateTime.now();
        }

        // Parse mobile bar (Ja/Nein/Vielleicht)
        final mobileBar = mobileBarStr.toLowerCase() == 'ja';

        // Save or update in Firestore
        final orderId = await saveOrUpdateFormSubmission(
          formSubmissionId: formSubmissionId,
          name: name,
          date: eventDate,
          phone: phone,
          location: location,
          guestCountRange: guestCount,
          mobileBar: mobileBar,
          eventType: eventType,
          serviceType: '', // Not used
          eventTime: timeStr,
          formCreatedAt: formCreatedAt,
          existingDocId: existingDocId,
        );

        if (orderId != null) {
          syncedCount++;
          existingSubmissions[formSubmissionId] = orderId;
        }
      }

      debugPrint('Synced $syncedCount form submissions');
      return syncedCount;
    } catch (e) {
      debugPrint('Form sync error: $e');
      return -1;
    }
  }
}

final orderRepository = OrderRepository();
