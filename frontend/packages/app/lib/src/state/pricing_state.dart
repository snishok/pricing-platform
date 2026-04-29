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

  List<FacetValue> _storeIdFacets = const [];
  List<FacetValue> _skuFacets = const [];
  List<String> _suggestions = const [];

  final List<String> _recentSearches = [];

  PricingState(this._api);

  bool get isLoading => _loading;
  String? get error => _error;
  List<PricingRecord> get items => _items;
  int get page => _page;
  int get perPage => _perPage;
  int get total => _total;
  List<FacetValue> get storeIdFacets => _storeIdFacets;
  List<FacetValue> get skuFacets => _skuFacets;
  List<String> get suggestions => _suggestions;
  List<String> get recentSearches => List.unmodifiable(_recentSearches);

  Future<void> search({
    String? q,
    List<String>? storeIds,
    List<String>? skus,
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
        storeIds: storeIds,
        skus: skus,
        dateFrom: dateFrom,
        dateTo: dateTo,
        page: page ?? _page,
        perPage: perPage ?? _perPage,
      );
      _items = res.items;
      _page = res.page;
      _perPage = res.perPage;
      _total = res.total;

      final qTrim = (q ?? '').trim();
      if (qTrim.isNotEmpty) _rememberRecentSearch(qTrim);
    } catch (e) {
      _error = 'Search failed';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshMeta({
    String? q,
    List<String>? storeIds,
    List<String>? skus,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool updateFacets = true,
  }) async {
    try {
      final meta = await _api.searchPricingMeta(
        q: q,
        storeIds: storeIds,
        skus: skus,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
      _suggestions = meta.suggestions;
      if (updateFacets) {
        _storeIdFacets = meta.storeIdFacets;
        _skuFacets = meta.skuFacets;
      }
      notifyListeners();
    } catch (_) {
      // Keep previous meta; search itself will still work.
    }
  }

  void clearMeta() {
    _storeIdFacets = const [];
    _skuFacets = const [];
    _suggestions = const [];
    notifyListeners();
  }

  void clearRecentSearches() {
    _recentSearches.clear();
    notifyListeners();
  }

  void _rememberRecentSearch(String q) {
    // Keep most-recent-first, unique.
    _recentSearches.removeWhere((e) => e.toLowerCase() == q.toLowerCase());
    _recentSearches.insert(0, q);
    if (_recentSearches.length > 8) _recentSearches.removeRange(8, _recentSearches.length);
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

