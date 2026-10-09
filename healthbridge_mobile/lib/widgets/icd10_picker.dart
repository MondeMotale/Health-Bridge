import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A searchable ICD-10 code picker.
///
/// Loads ~150 common codes from assets/icd10_common.json.
/// Emits the selected code + name via [onChanged].
class Icd10Picker extends StatefulWidget {
  final String? initialCode;
  final void Function(String? code, String? name)? onChanged;

  const Icd10Picker({
    super.key,
    this.initialCode,
    this.onChanged,
  });

  @override
  State<Icd10Picker> createState() => _Icd10PickerState();
}

class _Icd10PickerState extends State<Icd10Picker> {
  List<Map<String, dynamic>> _allCodes = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  Map<String, dynamic>? _selected;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCodes();
  }

  Future<void> _loadCodes() async {
    try {
      final raw = await rootBundle.loadString('assets/icd10_common.json');
      final data = json.decode(raw);
      final codes = List<Map<String, dynamic>>.from(data['codes']);

      // Find the initial code if provided
      Map<String, dynamic>? initial;
      if (widget.initialCode != null) {
        initial = codes.firstWhere(
          (c) => c['code'] == widget.initialCode,
          orElse: () => <String, dynamic>{},
        );
        if (initial.isEmpty) initial = null;
      }

      setState(() {
        _allCodes = codes;
        _filtered = codes;
        _selected = initial;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _filter(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filtered = _allCodes);
      return;
    }

    setState(() {
      _filtered = _allCodes.where((c) {
        final code = (c['code'] ?? '').toString().toLowerCase();
        final name = (c['name'] ?? '').toString().toLowerCase();
        final category = (c['category'] ?? '').toString().toLowerCase();
        return code.contains(q) || name.contains(q) || category.contains(q);
      }).toList();
    });
  }

  void _openPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) {
          return StatefulBuilder(
            builder: (ctx, setModalState) {
              return Column(
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Title
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      'Select ICD-10 Code',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ),

                  // Search
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search by code, name, or category...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onChanged: (q) {
                        _filter(q);
                        setModalState(() {});
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Result count
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Text(
                          '${_filtered.length} results',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // List
                  Expanded(
                    child: _filtered.isEmpty
                        ? const Center(
                            child: Text('No codes match your search'),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final item = _filtered[i];
                              final isSelected =
                                  _selected?['code'] == item['code'];
                              return ListTile(
                                onTap: () {
                                  setState(() {
                                    _selected = item;
                                    _searchController.clear();
                                    _filter('');
                                  });
                                  widget.onChanged?.call(
                                    item['code'] as String?,
                                    item['name'] as String?,
                                  );
                                  Navigator.pop(ctx);
                                },
                                leading: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF1E3A8A)
                                        : const Color(0xFF1E3A8A)
                                            .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item['code'] ?? '',
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF1E3A8A),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  item['name'] ?? '',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                subtitle: Text(
                                  item['category'] ?? '',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle,
                                        color: Color(0xFF1E3A8A))
                                    : null,
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return InkWell(
      onTap: _openPicker,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.medical_information,
                color: Color(0xFF6B7280), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: _selected == null
                  ? const Text(
                      'Tap to select a condition',
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_selected!['code']} — ${_selected!['name']}',
                          style: const TextStyle(
                            color: Color(0xFF1A1A2E),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selected!['category'] ?? '',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
            ),
            const Icon(Icons.arrow_drop_down, color: Color(0xFF6B7280)),
          ],
        ),
      ),
    );
  }
}