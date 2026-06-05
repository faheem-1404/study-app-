import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/models/redemption_request.dart';
import '../../core/models/study_session_summary.dart';
import '../../core/models/wallet_transaction.dart';
import '../../core/models/payout_method.dart';
import '../../core/services/app_storage_service.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../services/firebase_service.dart';

class FirestoreWalletRepository implements WalletRepository {
  FirestoreWalletRepository(this._storage);

  final AppStorageService _storage;

  String? get _userId {
    if (!FirebaseService.isInitialized) return null;
    return FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  Future<double> getCredits() async {
    final String? uid = _userId;
    if (uid != null) {
      try {
        final DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('wallet')
            .doc('balance')
            .get();
        if (doc.exists && doc.data() != null) {
          final double credits = (doc.get('credits') as num).toDouble();
          // Keep SharedPreferences updated
          final double local = _storage.readCredits();
          if (local != credits) {
            await _storage.subtractCredits(local);
            await _storage.addCredits(credits);
          }
          return credits;
        }
      } catch (e) {
        debugPrint('Error getting credits from Firestore: $e');
      }
    }
    return _storage.readCredits();
  }

  @override
  Future<int> getTodayStudySeconds() async {
    final String? uid = _userId;
    if (uid != null) {
      try {
        final DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('wallet')
            .doc('balance')
            .get();
        if (doc.exists && doc.data() != null) {
          // Check if it's the same day
          final String todayStr = _todayStamp();
          final String? dateStr = doc.get('todayDate')?.toString();
          if (dateStr == todayStr) {
            return doc.get('todayStudySeconds') as int;
          }
        }
      } catch (e) {
        debugPrint('Error getting today study seconds from Firestore: $e');
      }
    }
    return _storage.readTodayStudySeconds();
  }

  @override
  Future<List<RedemptionRequest>> getRedemptions() async {
    final String? uid = _userId;
    if (uid != null) {
      try {
        final QuerySnapshot query = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('redemptions')
            .orderBy('createdAt', descending: true)
            .get();
        
        final List<RedemptionRequest> list = query.docs
            .map((doc) => RedemptionRequest.fromMap(doc.data() as Map<String, dynamic>))
            .toList();
        
        if (list.isNotEmpty) {
          await _storage.saveRedemptions(list);
          return list;
        }
      } catch (e) {
        debugPrint('Error getting redemptions from Firestore: $e');
      }
    }
    return _storage.readRedemptions();
  }

  @override
  Future<List<WalletTransaction>> getTransactions() async {
    final String? uid = _userId;
    if (uid != null) {
      try {
        final QuerySnapshot query = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('transactions')
            .orderBy('date', descending: true)
            .get();
        
        final List<WalletTransaction> list = query.docs
            .map((doc) => WalletTransaction.fromMap(doc.data() as Map<String, dynamic>))
            .toList();
        
        if (list.isNotEmpty) {
          return list;
        }
      } catch (e) {
        debugPrint('Error getting transactions from Firestore: $e');
      }
    }

    // Local fallback: reconstruct transactions from local redemptions + local credits
    // Similar to WalletViewModel implementation
    final List<RedemptionRequest> redemptions = _storage.readRedemptions();
    final List<WalletTransaction> txs = <WalletTransaction>[];
    for (final RedemptionRequest r in redemptions) {
      txs.add(WalletTransaction(
        id: r.id,
        type: TransactionType.debit,
        amountInr: r.cashValue,
        credits: r.credits,
        date: r.createdAt,
        status: _mapStatus(r.status),
        description: 'Withdrawal via ${r.method.label}',
        transactionId: 'TXN${r.id.substring(r.id.length > 8 ? r.id.length - 8 : 0)}',
      ));
    }
    return txs;
  }

  @override
  Future<void> commitStudySummary(StudySessionSummary summary) async {
    if (summary.invalidated) return;

    final double newCredits = await _storage.addCredits(summary.earnedCredits);
    final int newSeconds = await _storage.addTodayStudySeconds(summary.focusedSeconds);

    final WalletTransaction tx = WalletTransaction(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: TransactionType.credit,
      amountInr: summary.earnedCredits * 0.10,
      credits: summary.earnedCredits,
      date: DateTime.now(),
      status: TransactionStatus.completed,
      description: 'Study session earnings',
      transactionId: 'SE${DateTime.now().millisecondsSinceEpoch}',
    );

    final String? uid = _userId;
    if (uid != null) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        
        // Update balance doc
        final balanceRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('wallet')
            .doc('balance');
        
        batch.set(balanceRef, {
          'credits': newCredits,
          'todayStudySeconds': newSeconds,
          'todayDate': _todayStamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Create transaction doc
        final txRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('transactions')
            .doc(tx.id);
        
        batch.set(txRef, tx.toMap());

        await batch.commit();
      } catch (e) {
        debugPrint('Error committing study summary to Firestore: $e');
      }
    }
  }

  @override
  Future<void> saveRedemption(RedemptionRequest redemption) async {
    final List<RedemptionRequest> current = _storage.readRedemptions();
    await _storage.saveRedemptions([redemption, ...current]);

    final String? uid = _userId;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('redemptions')
            .doc(redemption.id)
            .set(redemption.toMap());
      } catch (e) {
        debugPrint('Error saving redemption to Firestore: $e');
      }
    }
  }

  @override
  Future<void> updateRedemptionStatus(String id, RedemptionStatus status) async {
    final List<RedemptionRequest> current = _storage.readRedemptions();
    final int idx = current.indexWhere((r) => r.id == id);
    if (idx != -1) {
      final List<RedemptionRequest> updated = List<RedemptionRequest>.from(current);
      updated[idx] = current[idx].copyWith(status: status);
      await _storage.saveRedemptions(updated);
    }

    final String? uid = _userId;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('redemptions')
            .doc(id)
            .update({'status': status.name});
      } catch (e) {
        debugPrint('Error updating redemption status in Firestore: $e');
      }
    }
  }

  @override
  Future<void> deductCredits(double credits) async {
    final double newCredits = await _storage.subtractCredits(credits);

    final String? uid = _userId;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('wallet')
            .doc('balance')
            .update({
              'credits': newCredits,
              'updatedAt': FieldValue.serverTimestamp(),
            });
      } catch (e) {
        debugPrint('Error deducting credits in Firestore: $e');
      }
    }
  }

  @override
  Future<void> resetWallet() async {
    await _storage.resetWallet();

    final String? uid = _userId;
    if (uid != null) {
      try {
        // Reset in Firestore (just reset the balance doc, delete collections if needed, but resetting balance is enough)
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('wallet')
            .doc('balance')
            .set({
              'credits': 0.0,
              'todayStudySeconds': 0,
              'todayDate': _todayStamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
      } catch (e) {
        debugPrint('Error resetting wallet in Firestore: $e');
      }
    }
  }

  // Helper date stamp
  String _todayStamp() {
    final DateTime now = DateTime.now();
    final String month = now.month.toString().padLeft(2, '0');
    final String day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  TransactionStatus _mapStatus(RedemptionStatus s) {
    switch (s) {
      case RedemptionStatus.completed:
        return TransactionStatus.completed;
      case RedemptionStatus.pending:
        return TransactionStatus.pending;
      case RedemptionStatus.processing:
        return TransactionStatus.processing;
      case RedemptionStatus.rejected:
        return TransactionStatus.failed;
    }
  }
}
