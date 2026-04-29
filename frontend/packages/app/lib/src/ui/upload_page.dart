import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/pricing_state.dart';
import 'package:core/core.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  bool _loading = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiClient>();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Upload CSV', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Required columns: store_id, sku, product_name, price, date'),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _loading
                    ? null
                    : () async {
                        final pricing = context.read<PricingState>();
                        setState(() {
                          _loading = true;
                          _message = null;
                        });
                        try {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: const ['csv'],
                            withData: true,
                          );
                          if (result == null || result.files.isEmpty) {
                            setState(() => _message = 'No file selected');
                            return;
                          }
                          final f = result.files.single;
                          if (f.bytes == null) throw Exception('Failed to read file bytes');
                          final inserted = await api.uploadCsv(filename: f.name, bytes: f.bytes!);
                          if (!mounted) return;
                          setState(() => _message = 'Inserted $inserted rows');
                          // optional: refresh search after upload
                          await pricing.search(page: 1);
                        } catch (e) {
                          setState(() => _message = 'Upload failed');
                        } finally {
                          setState(() => _loading = false);
                        }
                      },
                icon: const Icon(Icons.upload_file),
                label: Text(_loading ? 'Uploading...' : 'Choose CSV'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_message != null) Text(_message!),
        ],
      ),
    );
  }
}

