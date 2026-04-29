class PricingRecord {
  final String id;
  final String storeId;
  final String sku;
  final String productName;
  final double price;
  final DateTime date;

  PricingRecord({
    required this.id,
    required this.storeId,
    required this.sku,
    required this.productName,
    required this.price,
    required this.date,
  });

  factory PricingRecord.fromJson(Map<String, dynamic> json) {
    return PricingRecord(
      id: json['id'] as String,
      storeId: json['store_id'] as String,
      sku: json['sku'] as String,
      productName: json['product_name'] as String,
      price: (json['price'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
    );
  }
}

class MeResponse {
  final String id;
  final String email;
  final String role;

  MeResponse({required this.id, required this.email, required this.role});

  factory MeResponse.fromJson(Map<String, dynamic> json) {
    return MeResponse(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
    );
  }
}

class Paginated<T> {
  final List<T> items;
  final int page;
  final int perPage;
  final int total;

  Paginated({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
  });
}

class FacetValue {
  final String value;
  final int count;

  FacetValue({required this.value, required this.count});

  factory FacetValue.fromJson(Map<String, dynamic> json) {
    return FacetValue(
      value: json['value'] as String,
      count: (json['count'] as num).toInt(),
    );
  }
}

class PricingSearchMeta {
  final int found;
  final List<FacetValue> storeIdFacets;
  final List<FacetValue> skuFacets;
  final List<String> suggestions;

  PricingSearchMeta({
    required this.found,
    required this.storeIdFacets,
    required this.skuFacets,
    required this.suggestions,
  });

  static List<FacetValue> _facetValuesFor(List<dynamic> facetCounts, String fieldName) {
    final fc = facetCounts.cast<Map<String, dynamic>>().where((e) => e['field_name'] == fieldName).toList();
    if (fc.isEmpty) return const [];
    final counts = (fc.first['counts'] as List<dynamic>).cast<Map<String, dynamic>>();
    return counts.map(FacetValue.fromJson).toList(growable: false);
  }

  factory PricingSearchMeta.fromJson(Map<String, dynamic> json) {
    final facetCounts = (json['facet_counts'] as List<dynamic>? ?? const <dynamic>[]);
    return PricingSearchMeta(
      found: (json['found'] as num? ?? 0).toInt(),
      storeIdFacets: _facetValuesFor(facetCounts, 'store_id'),
      skuFacets: _facetValuesFor(facetCounts, 'sku'),
      suggestions: (json['suggestions'] as List<dynamic>? ?? const <dynamic>[]).map((e) => e.toString()).toList(growable: false),
    );
  }
}

