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

