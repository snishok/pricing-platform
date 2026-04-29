import 'package:core/core.dart';
import 'package:flutter/foundation.dart';

class PricingState extends ChangeNotifier {
  final ApiClient _api;
  bool _loading = false;
  String? _error;

  List<PricingRecord> _items = const [];
  int _page = 1;
  int _perPage = 25;
  int _total = 0;

  PricingState(this._api);

  bool get isLoading => _loading;
  String? get error => _error;
  List<PricingRecord> get items => _items;
  int get page => _page;
  int get perPage => _perPage;
  int get total => _total;

  Future<void> search({
    String? q,
    String? storeId,
    String? sku,
    DateTime? dateFrom,
    DateTime? dateTo,
    int? page,
    int? perPage,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.searchPricing(
        q: q,
        storeId: storeId,
        sku: sku,
        dateFrom: dateFrom,
        dateTo: dateTo,
        page: page ?? _page,
        perPage: perPage ?? _perPage,
      );
      _items = res.items;
      _page = res.page;
      _perPage = res.perPage;
      _total = res.total;
    } catch (e) {
      _error = 'Search failed';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> updatePrice(String id, double price) async {
    _error = null;
    notifyListeners();
    try {
      final updated = await _api.updatePricingRecord(id, price: price);
      _items = _items.map((e) => e.id == id ? updated : e).toList(growable: false);
      notifyListeners();
    } catch (e) {
      _error = 'Update failed';
      notifyListeners();
    }
  }

  Future<void> updateRecord(
    String id, {
    String? storeId,
    String? sku,
    String? productName,
    double? price,
    DateTime? date,
  }) async {
    _error = null;
    notifyListeners();
    try {
      final updated = await _api.updatePricingRecord(
        id,
        storeId: storeId,
        sku: sku,
        productName: productName,
        price: price,
        date: date,
      );
      _items = _items.map((e) => e.id == id ? updated : e).toList(growable: false);
      notifyListeners();
    } catch (e) {
      _error = 'Update failed';
      notifyListeners();
    }
  }
}

