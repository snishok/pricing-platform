import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiClient {
  final Uri baseUri;
  final http.Client _http;
  String? _accessToken;

  ApiClient({required this.baseUri, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  void setAccessToken(String? token) => _accessToken = token;

  Map<String, String> _headers({bool json = true}) {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    if (_accessToken != null) headers['Authorization'] = 'Bearer $_accessToken';
    return headers;
  }

  Future<String> login({
    required String email,
    required String password,
  }) async {
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

  Future<MeResponse> me() async {
    final res = await _http.get(
      baseUri.resolve('auth/me'),
      headers: _headers(json: false),
    );
    if (res.statusCode != 200) throw Exception('Me failed');
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return MeResponse.fromJson(json);
  }

  Future<int> uploadCsv({
    required String filename,
    required Uint8List bytes,
  }) async {
    final req = http.MultipartRequest('POST', baseUri.resolve('upload-csv'));
    if (_accessToken != null)
      req.headers['Authorization'] = 'Bearer $_accessToken';
    req.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );
    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) throw Exception('Upload failed');
    final data = jsonDecode(body) as Map<String, dynamic>;
    return (data['inserted'] as num).toInt();
  }

  Future<Paginated<PricingRecord>> searchPricing({
    String? q,
    List<String>? storeIds,
    List<String>? skus,
    DateTime? dateFrom,
    DateTime? dateTo,
    int page = 1,
    int perPage = 25,
  }) async {
    final qp = <String>[];
    qp.add('page=$page');
    qp.add('per_page=$perPage');
    if (q != null && q.isNotEmpty) qp.add('q=${Uri.encodeQueryComponent(q)}');
    for (final v in (storeIds ?? const <String>[])) {
      final t = v.trim();
      if (t.isNotEmpty) qp.add('store_id=${Uri.encodeQueryComponent(t)}');
    }
    for (final v in (skus ?? const <String>[])) {
      final t = v.trim();
      if (t.isNotEmpty) qp.add('sku=${Uri.encodeQueryComponent(t)}');
    }
    if (dateFrom != null)
      qp.add('date_from=${dateFrom.toIso8601String().split('T').first}');
    if (dateTo != null)
      qp.add('date_to=${dateTo.toIso8601String().split('T').first}');

    final uri = baseUri.resolve('pricing/search?${qp.join('&')}');
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

  Future<PricingSearchMeta> searchPricingMeta({
    String? q,
    List<String>? storeIds,
    List<String>? skus,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final qp = <String>[];
    if (q != null && q.isNotEmpty) qp.add('q=${Uri.encodeQueryComponent(q)}');
    for (final v in (storeIds ?? const <String>[])) {
      final t = v.trim();
      if (t.isNotEmpty) qp.add('store_id=${Uri.encodeQueryComponent(t)}');
    }
    for (final v in (skus ?? const <String>[])) {
      final t = v.trim();
      if (t.isNotEmpty) qp.add('sku=${Uri.encodeQueryComponent(t)}');
    }
    if (dateFrom != null)
      qp.add('date_from=${dateFrom.toIso8601String().split('T').first}');
    if (dateTo != null)
      qp.add('date_to=${dateTo.toIso8601String().split('T').first}');

    final uri = baseUri.resolve(
      'pricing/search/meta${qp.isEmpty ? '' : '?${qp.join('&')}'}',
    );
    final res = await _http.get(uri, headers: _headers(json: false));
    if (res.statusCode != 200) throw Exception('Search meta failed');
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return PricingSearchMeta.fromJson(json);
  }

  Future<PricingRecord> getPricing(String id) async {
    final res = await _http.get(
      baseUri.resolve('pricing/$id'),
      headers: _headers(json: false),
    );
    if (res.statusCode != 200) throw Exception('Get failed');
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
