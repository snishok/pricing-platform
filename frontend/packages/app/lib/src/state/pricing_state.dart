import 'package:core/core.dart';
import 'package:flutter/foundation.dart';

class PricingState extends ChangeNotifier {
  final ApiClient _api;
  bool _loading = false;
  String? _error;
  int _searchRequestId = 0;
  int _metaRequestId = 0;

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
    final requestId = ++_searchRequestId;
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
      if (requestId != _searchRequestId) return;
      _items = res.items;
      _page = res.page;
      _perPage = res.perPage;
      _total = res.total;

      final qTrim = (q ?? '').trim();
      if (qTrim.isNotEmpty) _rememberRecentSearch(qTrim);
    } catch (e) {
      if (requestId != _searchRequestId) return;
      _error = 'Search failed';
    } finally {
      if (requestId == _searchRequestId) {
        _loading = false;
        notifyListeners();
      }
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
    final requestId = ++_metaRequestId;
    try {
      final meta = await _api.searchPricingMeta(
        q: q,
        storeIds: storeIds,
        skus: skus,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
      if (requestId != _metaRequestId) return;
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
    if (_recentSearches.length > 8) {
      _recentSearches.removeRange(8, _recentSearches.length);
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
      _items = _items
          .map((e) => e.id == id ? updated : e)
          .toList(growable: false);
      notifyListeners();
    } catch (e) {
      _error = 'Update failed';
      notifyListeners();
    }
  }
}
