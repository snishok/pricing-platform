import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiClient {
  final Uri baseUri;
  final http.Client _http;
  String? _accessToken;

  ApiClient({required this.baseUri, http.Client? httpClient}) : _http = httpClient ?? http.Client();

  void setAccessToken(String? token) => _accessToken = token;

  Map<String, String> _headers({bool json = true}) {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    if (_accessToken != null) headers['Authorization'] = 'Bearer $_accessToken';
    return headers;
  }

  Future<String> login({required String email, required String password}) async {
    final res = await _http.post(
      baseUri.resolve('auth/login'),
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode != 200) throw Exception('Login failed');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final token = data['access_token'] as String;
    setAccessToken(token);
    return token;
  }

  Future<int> uploadCsv({required String filename, required Uint8List bytes}) async {
    final req = http.MultipartRequest('POST', baseUri.resolve('upload-csv'));
    if (_accessToken != null) req.headers['Authorization'] = 'Bearer $_accessToken';
    req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) throw Exception('Upload failed');
    final data = jsonDecode(body) as Map<String, dynamic>;
    return (data['inserted'] as num).toInt();
  }

  Future<Paginated<PricingRecord>> searchPricing({
    String? q,
    String? storeId,
    String? sku,
    DateTime? dateFrom,
    DateTime? dateTo,
    int page = 1,
    int perPage = 25,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
    };
    if (q != null && q.isNotEmpty) params['q'] = q;
    if (storeId != null && storeId.isNotEmpty) params['store_id'] = storeId;
    if (sku != null && sku.isNotEmpty) params['sku'] = sku;
    if (dateFrom != null) params['date_from'] = dateFrom.toIso8601String().split('T').first;
    if (dateTo != null) params['date_to'] = dateTo.toIso8601String().split('T').first;

    final uri = baseUri.resolve('pricing/search').replace(queryParameters: params);
    final res = await _http.get(uri, headers: _headers(json: false));
    if (res.statusCode != 200) throw Exception('Search failed');
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (json['data'] as List<dynamic>)
        .map((e) => PricingRecord.fromJson(e as Map<String, dynamic>))
        .toList();
    final p = json['pagination'] as Map<String, dynamic>;
    return Paginated(
      items: items,
      page: (p['page'] as num).toInt(),
      perPage: (p['per_page'] as num).toInt(),
      total: (p['total'] as num).toInt(),
    );
  }

  Future<PricingRecord> getPricing(String id) async {
    final res = await _http.get(baseUri.resolve('pricing/$id'), headers: _headers(json: false));
    if (res.statusCode != 200) throw Exception('Get failed');
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return PricingRecord.fromJson(json);
  }

  Future<PricingRecord> updatePrice(String id, double price) async {
    final res = await _http.put(
      baseUri.resolve('pricing/$id'),
      headers: _headers(),
      body: jsonEncode({'price': price}),
    );
    if (res.statusCode != 200) throw Exception('Update failed');
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return PricingRecord.fromJson(json);
  }

  Future<PricingRecord> updatePricingRecord(
    String id, {
    String? storeId,
    String? sku,
    String? productName,
    double? price,
    DateTime? date,
  }) async {
    final body = <String, dynamic>{};
    if (storeId != null) body['store_id'] = storeId;
    if (sku != null) body['sku'] = sku;
    if (productName != null) body['product_name'] = productName;
    if (price != null) body['price'] = price;
    if (date != null) body['date'] = date.toIso8601String().split('T').first;

    final res = await _http.put(
      baseUri.resolve('pricing/$id'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) throw Exception('Update failed');
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return PricingRecord.fromJson(json);
  }
}

