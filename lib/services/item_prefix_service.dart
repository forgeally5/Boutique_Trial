import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/item_prefix.dart';

class ItemPrefixService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'item_prefixes';

  Future<void> addItemPrefix(ItemPrefix prefix) async {
    try {
      await _firestore.collection(_collectionName).add(prefix.toMap());
    } catch (e) {
      debugPrint('Error saving item prefix: $e');
      rethrow;
    }
  }

  Future<List<ItemPrefix>> getAllItemPrefixes() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).orderBy('createdAt', descending: true).get();
      return snapshot.docs.map((doc) => ItemPrefix.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error fetching item prefixes: $e');
      return [];
    }
  }

  Future<void> updateItemPrefix(String id, ItemPrefix prefix) async {
    try {
      final map = prefix.toMap();
      map.remove('createdAt'); // preserve original createdAt
      await _firestore.collection(_collectionName).doc(id).update(map);
    } catch (e) {
      debugPrint('Error updating item prefix: $e');
      rethrow;
    }
  }

  Future<void> deleteItemPrefix(String id) async {
    try {
      await _firestore.collection(_collectionName).doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting item prefix: $e');
      rethrow;
    }
  }
}
