import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import 'package:core/core.dart';
import '../state/auth_state.dart';
import '../state/pricing_state.dart';

enum _SortOption {
  relevance,
  priceLowHigh,
  priceHighLow,
  dateNew,
  dateOld,
  productAZ,
  productZA,
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');
  final _q = TextEditingController();
  DateTime? _from;
  DateTime? _to;
  _SortOption _sort = _SortOption.relevance;
  final Set<String> _selectedStoreIds = <String>{};
  final Set<String> _selectedSkus = <String>{};
  Timer? _debounce;
  List<PricingRecord>? _lastSortedSource;
  _SortOption? _lastSortedOption;
  List<_PricingRowVm> _sortedCache = const [];

  @override
  void dispose() {
    _q.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Initial load (facets + initial results) after first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PricingState>().refreshMeta(
        q: _q.text.trim(),
        storeIds: _selectedStoreIds.toList(growable: false),
        skus: _selectedSkus.toList(growable: false),
        dateFrom: _from,
        dateTo: _to,
      );
      _runSearch(page: 1);
    });
  }

  Future<void> _pickFromDate(DateTime initial) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: _from ?? initial,
    );
    if (picked == null) return;
    setState(() {
      _from = picked;
      if (_to != null && picked.isAfter(_to!)) {
        _to = picked;
      }
    });
  }

  Future<void> _pickToDate(DateTime initial) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: _to ?? initial,
    );
    if (picked == null) return;
    setState(() {
      _to = picked;
      if (_from != null && picked.isBefore(_from!)) {
        _from = picked;
      }
    });
  }

  void _runSearch({int? page, int? perPage}) {
    context.read<PricingState>().search(
      q: _q.text.trim(),
      storeIds: _selectedStoreIds.toList(growable: false),
      skus: _selectedSkus.toList(growable: false),
      dateFrom: _from,
      dateTo: _to,
      page: page ?? 1,
      perPage: perPage,
    );
  }

  void _refreshMeta() {
    context.read<PricingState>().refreshMeta(
      q: _q.text.trim(),
      storeIds: _selectedStoreIds.toList(growable: false),
      skus: _selectedSkus.toList(growable: false),
      dateFrom: _from,
      dateTo: _to,
    );
  }

  void _toggleStoreId(String value, bool checked) {
    setState(() {
      if (checked) {
        _selectedStoreIds.add(value);
      } else {
        _selectedStoreIds.remove(value);
      }
    });
    _refreshMeta();
    _runSearch(page: 1);
  }

  void _toggleSku(String value, bool checked) {
    setState(() {
      if (checked) {
        _selectedSkus.add(value);
      } else {
        _selectedSkus.remove(value);
      }
    });
    _refreshMeta();
    _runSearch(page: 1);
  }

  void _clearDates() {
    setState(() {
      _from = null;
      _to = null;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _q.clear();
      _from = null;
      _to = null;
      _selectedStoreIds.clear();
      _selectedSkus.clear();
    });
    _refreshMeta();
    _runSearch(page: 1);
  }

  void _debouncedMetaOnly() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      context.read<PricingState>().refreshMeta(
        q: _q.text.trim(),
        storeIds: _selectedStoreIds.toList(growable: false),
        skus: _selectedSkus.toList(growable: false),
        dateFrom: _from,
        dateTo: _to,
        updateFacets: false,
      );
    });
  }

  List<_PricingRowVm> _buildSortedItems(PricingState state) {
    if (identical(_lastSortedSource, state.items) &&
        _lastSortedOption == _sort) {
      return _sortedCache;
    }
    final items = state.items
        .map(_PricingRowVm.fromRecord)
        .toList(growable: false);
    int byProduct(_PricingRowVm a, _PricingRowVm b) =>
        a.productName.toLowerCase().compareTo(b.productName.toLowerCase());

    final sorted = switch (_sort) {
      _SortOption.relevance => items,
      _SortOption.priceLowHigh =>
        (items..sort((a, b) => a.price.compareTo(b.price))),
      _SortOption.priceHighLow =>
        (items..sort((a, b) => b.price.compareTo(a.price))),
      _SortOption.dateNew => (items..sort((a, b) => b.date.compareTo(a.date))),
      _SortOption.dateOld => (items..sort((a, b) => a.date.compareTo(b.date))),
      _SortOption.productAZ => (items..sort(byProduct)),
      _SortOption.productZA => (items..sort((a, b) => -byProduct(a, b))),
    };
    _lastSortedSource = state.items;
    _lastSortedOption = _sort;
    _sortedCache = sorted;
    return sorted;
  }

  Future<void> _openFiltersSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: _FiltersPanel(
                from: _from,
                to: _to,
                storeIdFacets: context.watch<PricingState>().storeIdFacets,
                skuFacets: context.watch<PricingState>().skuFacets,
                selectedStoreIds: _selectedStoreIds,
                selectedSkus: _selectedSkus,
                onToggleStoreId: _toggleStoreId,
                onToggleSku: _toggleSku,
                onPickFrom: () => _pickFromDate(DateTime.now()),
                onPickTo: () => _pickToDate(DateTime.now()),
                onClearDates: _clearDates,
                onSearch: () {
                  Navigator.pop(context);
                  _runSearch(page: 1);
                },
                onClearAll: _clearAllFilters,
                isLoading: context.watch<PricingState>().isLoading,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PricingState>();
    final canEdit = context.watch<AuthState>().canEdit;
    final dateFmt = _dateFmt;
    final items = _buildSortedItems(state);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1040;
        final pad = EdgeInsets.symmetric(
          horizontal: wide ? 16 : 12,
          vertical: wide ? 14 : 10,
        );

        final filtersPanel = _FiltersPanel(
          from: _from,
          to: _to,
          storeIdFacets: state.storeIdFacets,
          skuFacets: state.skuFacets,
          selectedStoreIds: _selectedStoreIds,
          selectedSkus: _selectedSkus,
          onToggleStoreId: _toggleStoreId,
          onToggleSku: _toggleSku,
          onPickFrom: () => _pickFromDate(DateTime.now()),
          onPickTo: () => _pickToDate(DateTime.now()),
          onClearDates: _clearDates,
          onSearch: () => _runSearch(page: 1),
          onClearAll: _clearAllFilters,
          isLoading: state.isLoading,
        );

        return Padding(
          padding: pad,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (wide) ...[
                SizedBox(width: 332, child: _SurfaceCard(child: filtersPanel)),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  children: [
                    _TopBar(
                      total: state.total,
                      isLoading: state.isLoading,
                      wide: wide,
                      sort: _sort,
                      onSortChanged: (next) => setState(() => _sort = next),
                      onOpenFilters: wide ? null : _openFiltersSheet,
                    ),
                    if (state.isLoading)
                      const LinearProgressIndicator(minHeight: 2),
                    if (state.error != null) ...[
                      const SizedBox(height: 10),
                      _ErrorBanner(message: state.error!),
                    ],
                    const SizedBox(height: 10),
                    _SurfaceCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: _SearchBox(
                        controller: _q,
                        isLoading: state.isLoading,
                        recent: state.recentSearches,
                        suggestions: state.suggestions,
                        onChanged: (_) => _debouncedMetaOnly(),
                        onSubmit: (v) {
                          _q.text = v;
                          _q.selection = TextSelection.collapsed(
                            offset: _q.text.length,
                          );
                          _refreshMeta();
                          _runSearch(page: 1);
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _SurfaceCard(
                        padding: EdgeInsets.zero,
                        child: items.isEmpty
                            ? _EmptyState(
                                hasSearched:
                                    !state.isLoading &&
                                    (state.total > 0 ||
                                        state.items.isNotEmpty ||
                                        state.error != null),
                                onSearch: () => _runSearch(page: 1),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                itemCount: items.length,
                                separatorBuilder: (_, i) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, i) => _ResultRow(
                                  vm: items[i],
                                  dateFmt: dateFmt,
                                  onEdit: canEdit
                                      ? () => _editRecord(
                                          context,
                                          state,
                                          items[i],
                                          dateFmt,
                                        )
                                      : null,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _BottomPager(
                      page: state.page,
                      perPage: state.perPage,
                      total: state.total,
                      onPrev: state.page <= 1 || state.isLoading
                          ? null
                          : () => _runSearch(page: state.page - 1),
                      onNext: _canGoNext(state) && !state.isLoading
                          ? () => _runSearch(page: state.page + 1)
                          : null,
                      onPerPageChanged: state.isLoading
                          ? null
                          : (v) {
                              _runSearch(page: 1, perPage: v);
                            },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

bool _canGoNext(PricingState state) {
  if (state.total <= 0) return false;
  final maxPage = (state.total / state.perPage).ceil();
  return state.page < maxPage;
}

Future<void> _editRecord(
  BuildContext context,
  PricingState state,
  _PricingRowVm r,
  DateFormat dateFmt,
) async {
  final storeCtrl = TextEditingController(text: r.storeId);
  final skuCtrl = TextEditingController(text: r.sku);
  final nameCtrl = TextEditingController(text: r.productName);
  final priceCtrl = TextEditingController(text: r.price.toStringAsFixed(2));
  try {
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
                TextField(
                  controller: storeCtrl,
                  decoration: const InputDecoration(labelText: 'Store ID'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: skuCtrl,
                  decoration: const InputDecoration(labelText: 'SKU'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Product name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
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
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
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
  } finally {
    storeCtrl.dispose();
    skuCtrl.dispose();
    nameCtrl.dispose();
    priceCtrl.dispose();
  }
}

class _PricingRowVm {
  final String id;
  final String storeId;
  final String sku;
  final String productName;
  final double price;
  final DateTime date;

  const _PricingRowVm({
    required this.id,
    required this.storeId,
    required this.sku,
    required this.productName,
    required this.price,
    required this.date,
  });

  static _PricingRowVm fromRecord(PricingRecord r) => _PricingRowVm(
    id: r.id,
    storeId: r.storeId,
    sku: r.sku,
    productName: r.productName,
    price: r.price,
    date: r.date,
  );
}

class _SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _TopBar extends StatelessWidget {
  final int total;
  final bool isLoading;
  final bool wide;
  final _SortOption sort;
  final ValueChanged<_SortOption> onSortChanged;
  final VoidCallback? onOpenFilters;

  const _TopBar({
    required this.total,
    required this.isLoading,
    required this.wide,
    required this.sort,
    required this.onSortChanged,
    required this.onOpenFilters,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return _SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  'Results',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$total',
                    style: t.labelLarge?.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
                if (!wide) ...[
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: onOpenFilters,
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('Filters'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _SortDropdown(
            value: sort,
            onChanged: isLoading ? null : onSortChanged,
          ),
        ],
      ),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  final _SortOption value;
  final ValueChanged<_SortOption>? onChanged;

  const _SortDropdown({required this.value, required this.onChanged});

  String _label(_SortOption v) {
    return switch (v) {
      _SortOption.relevance => 'Relevance',
      _SortOption.priceLowHigh => 'Price (page): Low → High',
      _SortOption.priceHighLow => 'Price (page): High → Low',
      _SortOption.dateNew => 'Date (page): Newest',
      _SortOption.dateOld => 'Date (page): Oldest',
      _SortOption.productAZ => 'Product (page): A → Z',
      _SortOption.productZA => 'Product (page): Z → A',
    };
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<_SortOption>(
        value: value,
        onChanged: onChanged == null
            ? null
            : (v) => v == null ? null : onChanged!(v),
        items: _SortOption.values
            .map((v) => DropdownMenuItem(value: v, child: Text(_label(v))))
            .toList(growable: false),
      ),
    );
  }
}

class _FiltersPanel extends StatelessWidget {
  static final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');
  final DateTime? from;
  final DateTime? to;
  final List<FacetValue> storeIdFacets;
  final List<FacetValue> skuFacets;
  final Set<String> selectedStoreIds;
  final Set<String> selectedSkus;
  final void Function(String value, bool checked) onToggleStoreId;
  final void Function(String value, bool checked) onToggleSku;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onClearDates;
  final VoidCallback onSearch;
  final VoidCallback onClearAll;
  final bool isLoading;

  const _FiltersPanel({
    required this.from,
    required this.to,
    required this.storeIdFacets,
    required this.skuFacets,
    required this.selectedStoreIds,
    required this.selectedSkus,
    required this.onToggleStoreId,
    required this.onToggleSku,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onClearDates,
    required this.onSearch,
    required this.onClearAll,
    required this.isLoading,
  });

  Widget _facetList({
    required BuildContext context,
    required List<FacetValue> facets,
    required Set<String> selected,
    required void Function(String value, bool checked) onToggle,
    required String emptyLabel,
  }) {
    if (facets.isEmpty) {
      return Text(emptyLabel, style: Theme.of(context).textTheme.bodySmall);
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 180),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: facets.length,
        itemBuilder: (context, i) {
          final f = facets[i];
          final checked = selected.contains(f.value);
          return CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            visualDensity: VisualDensity.compact,
            value: checked,
            onChanged: isLoading ? null : (v) => onToggle(f.value, v == true),
            title: Text(f.value, maxLines: 1, overflow: TextOverflow.ellipsis),
            secondary: Text('${f.count}'),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dateFmt = _dateFmt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Filters',
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            TextButton(
              onPressed: isLoading ? null : onClearAll,
              child: const Text('Clear'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _FilterSection(
          title: 'Store ID',
          child: _facetList(
            context: context,
            facets: storeIdFacets,
            selected: selectedStoreIds,
            onToggle: onToggleStoreId,
            emptyLabel: 'No store IDs available',
          ),
        ),
        const SizedBox(height: 12),
        _FilterSection(
          title: 'SKU',
          child: _facetList(
            context: context,
            facets: skuFacets,
            selected: selectedSkus,
            onToggle: onToggleSku,
            emptyLabel: 'No SKUs available',
          ),
        ),
        const SizedBox(height: 12),
        _FilterSection(
          title: 'Date range',
          trailing: TextButton(
            onPressed: isLoading ? null : onClearDates,
            child: const Text('Reset'),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isLoading ? null : onPickFrom,
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          from == null ? 'From date' : dateFmt.format(from!),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isLoading ? null : onPickTo,
                      icon: const Icon(Icons.event, size: 18),
                      label: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          to == null ? 'To date' : dateFmt.format(to!),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isLoading ? null : onSearch,
                  child: Text(isLoading ? 'Searching…' : 'Apply & Search'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final List<String> recent;
  final List<String> suggestions;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmit;

  const _SearchBox({
    required this.controller,
    required this.isLoading,
    required this.recent,
    required this.suggestions,
    required this.onChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) {
          // Nothing typed: show recent first (no relevance signal).
          return recent.take(8);
        }

        // User is typing: keep Typesense ordering (already relevance-ranked + typo tolerant),
        // then add matching recents after.
        final out = <String>[];
        final seen = <String>{};

        for (final s in suggestions) {
          final t = s.trim();
          if (t.isEmpty) continue;
          final k = t.toLowerCase();
          if (seen.add(k)) out.add(t);
          if (out.length >= 8) return out;
        }

        for (final s in recent) {
          final t = s.trim();
          if (t.isEmpty) continue;
          final k = t.toLowerCase();
          if (!t.toLowerCase().contains(q)) continue;
          if (seen.add(k)) out.add(t);
          if (out.length >= 8) break;
        }

        return out;
      },
      onSelected: onSubmit,
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        // Keep external controller in sync so existing search plumbing works.
        if (textController.text != controller.text) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (textController.text != controller.text) {
              textController.value = controller.value;
            }
          });
        }
        void sync(String v) {
          controller.value = textController.value;
          onChanged(v);
        }

        return TextField(
          controller: textController,
          focusNode: focusNode,
          enabled: !isLoading,
          onChanged: sync,
          onSubmitted: (v) => onSubmit(v.trim()),
          decoration: InputDecoration(
            labelText: 'Search / Product name',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (textController.text.trim().isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            textController.clear();
                            controller.clear();
                            onChanged('');
                          },
                          icon: const Icon(Icons.close),
                        )),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, opts) {
        final options = opts.toList(growable: false);
        if (options.isEmpty) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320, maxWidth: 720),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final s = options[i];
                  final isRecent = recent.any(
                    (r) => r.toLowerCase() == s.toLowerCase(),
                  );
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      isRecent ? Icons.history : Icons.search,
                      size: 18,
                    ),
                    title: Text(
                      s,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => onSelected(s),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FilterSection extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _FilterSection({
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: t.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                trailing ?? const SizedBox.shrink(),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final _PricingRowVm vm;
  final DateFormat dateFmt;
  final VoidCallback? onEdit;

  const _ResultRow({
    required this.vm,
    required this.dateFmt,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vm.productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ChipPair(label: 'Store', value: vm.storeId),
                      _ChipPair(label: 'SKU', value: vm.sku),
                      _ChipPair(label: 'Date', value: dateFmt.format(vm.date)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  vm.price.toStringAsFixed(2),
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Price',
                  style: t.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                IconButton(
                  tooltip: 'Edit record',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipPair extends StatelessWidget {
  final String label;
  final String value;

  const _ChipPair({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: RichText(
        text: TextSpan(
          style: t.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
          children: [
            TextSpan(
              text: '$label  ',
              style: t.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: value,
              style: t.labelMedium?.copyWith(color: scheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomPager extends StatelessWidget {
  final int page;
  final int perPage;
  final int total;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final ValueChanged<int>? onPerPageChanged;

  const _BottomPager({
    required this.page,
    required this.perPage,
    required this.total,
    required this.onPrev,
    required this.onNext,
    required this.onPerPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final maxPage = total <= 0 ? 1 : (total / perPage).ceil();

    return _SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Text(
            'Page $page of $maxPage',
            style: t.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Text(
            'Rows',
            style: t.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: perPage,
              onChanged: onPerPageChanged == null
                  ? null
                  : (v) => v == null ? null : onPerPageChanged!(v),
              items: const [10, 25, 50, 100]
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                  .toList(growable: false),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Previous page',
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasSearched;
  final VoidCallback onSearch;

  const _EmptyState({required this.hasSearched, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final title = hasSearched ? 'No results' : 'Search pricing records';
    final body = hasSearched
        ? 'Try adjusting filters, or clear them and search again.'
        : 'Use filters to find records, then sort and edit quickly.';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.search, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                textAlign: TextAlign.center,
                style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onSearch,
                icon: const Icon(Icons.search),
                label: const Text('Search'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
