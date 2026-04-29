import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../state/pricing_state.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _q = TextEditingController();
  final _store = TextEditingController();
  final _sku = TextEditingController();
  DateTime? _from;
  DateTime? _to;

  @override
  void dispose() {
    _q.dispose();
    _store.dispose();
    _sku.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PricingState>();
    final dateFmt = DateFormat('yyyy-MM-dd');

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(width: 240, child: TextField(controller: _q, decoration: const InputDecoration(labelText: 'Product name'))),
              SizedBox(width: 160, child: TextField(controller: _store, decoration: const InputDecoration(labelText: 'Store ID'))),
              SizedBox(width: 160, child: TextField(controller: _sku, decoration: const InputDecoration(labelText: 'SKU'))),
              OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    initialDate: _from ?? DateTime.now(),
                  );
                  if (picked != null) setState(() => _from = picked);
                },
                child: Text(_from == null ? 'From date' : 'From: ${dateFmt.format(_from!)}'),
              ),
              OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    initialDate: _to ?? DateTime.now(),
                  );
                  if (picked != null) setState(() => _to = picked);
                },
                child: Text(_to == null ? 'To date' : 'To: ${dateFmt.format(_to!)}'),
              ),
              FilledButton(
                onPressed: state.isLoading
                    ? null
                    : () => context.read<PricingState>().search(
                          q: _q.text.trim(),
                          storeId: _store.text.trim(),
                          sku: _sku.text.trim(),
                          dateFrom: _from,
                          dateTo: _to,
                          page: 1,
                        ),
                child: state.isLoading ? const Text('Searching...') : const Text('Search'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (state.error != null)
            Align(alignment: Alignment.centerLeft, child: Text(state.error!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: PaginatedDataTable(
                header: Text('Results (${state.total})'),
                rowsPerPage: state.perPage,
                availableRowsPerPage: const [10, 25, 50, 100],
                onRowsPerPageChanged: (v) {
                  if (v == null) return;
                  context.read<PricingState>().search(
                        q: _q.text.trim(),
                        storeId: _store.text.trim(),
                        sku: _sku.text.trim(),
                        dateFrom: _from,
                        dateTo: _to,
                        page: 1,
                        perPage: v,
                      );
                },
                onPageChanged: (start) {
                  final nextPage = (start ~/ state.perPage) + 1;
                  context.read<PricingState>().search(
                        q: _q.text.trim(),
                        storeId: _store.text.trim(),
                        sku: _sku.text.trim(),
                        dateFrom: _from,
                        dateTo: _to,
                        page: nextPage,
                      );
                },
                columns: const [
                  DataColumn(label: Text('Store')),
                  DataColumn(label: Text('SKU')),
                  DataColumn(label: Text('Product')),
                  DataColumn(label: Text('Price')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Edit')),
                ],
                source: _PricingDataSource(context, state, dateFmt),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PricingDataSource extends DataTableSource {
  final BuildContext context;
  final PricingState state;
  final DateFormat dateFmt;

  _PricingDataSource(this.context, this.state, this.dateFmt);

  @override
  DataRow? getRow(int index) {
    if (index >= state.items.length) return null;
    final r = state.items[index];
    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(Text(r.storeId)),
        DataCell(Text(r.sku)),
        DataCell(Text(r.productName)),
        DataCell(Text(r.price.toStringAsFixed(2))),
        DataCell(Text(dateFmt.format(r.date))),
        DataCell(
          IconButton(
            tooltip: 'Edit record',
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final storeCtrl = TextEditingController(text: r.storeId);
              final skuCtrl = TextEditingController(text: r.sku);
              final nameCtrl = TextEditingController(text: r.productName);
              final priceCtrl = TextEditingController(text: r.price.toStringAsFixed(2));
              DateTime pickedDate = r.date;
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => StatefulBuilder(
                  builder: (context, setState) => AlertDialog(
                    title: const Text('Update record'),
                    content: SizedBox(
                      width: 460,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(controller: storeCtrl, decoration: const InputDecoration(labelText: 'Store ID')),
                          const SizedBox(height: 8),
                          TextField(controller: skuCtrl, decoration: const InputDecoration(labelText: 'SKU')),
                          const SizedBox(height: 8),
                          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Product name')),
                          const SizedBox(height: 8),
                          TextField(
                            controller: priceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Price'),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton(
                              onPressed: () async {
                                final next = await showDatePicker(
                                  context: context,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                  initialDate: pickedDate,
                                );
                                if (next != null) setState(() => pickedDate = next);
                              },
                              child: Text('Date: ${dateFmt.format(pickedDate)}'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
                    ],
                  ),
                ),
              );
              if (ok != true) return;
              final parsedPrice = double.tryParse(priceCtrl.text.trim());
              if (parsedPrice == null || parsedPrice <= 0) return;
              final nextStore = storeCtrl.text.trim();
              final nextSku = skuCtrl.text.trim();
              final nextName = nameCtrl.text.trim();
              if (nextStore.isEmpty || nextSku.isEmpty || nextName.isEmpty) return;
              await state.updateRecord(
                r.id,
                storeId: nextStore,
                sku: nextSku,
                productName: nextName,
                price: parsedPrice,
                date: pickedDate,
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => state.items.length;

  @override
  int get selectedRowCount => 0;
}

