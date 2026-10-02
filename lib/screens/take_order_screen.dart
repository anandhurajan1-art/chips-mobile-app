import 'dart:convert';
import 'package:flutter/material.dart';

import '../services/api_service.dart';

class TakeOrderScreen extends StatefulWidget {
  final Map<String, dynamic>? editOrder;
  const TakeOrderScreen({super.key, this.editOrder});

  @override
  State<TakeOrderScreen> createState() => _TakeOrderScreenState();
}

class _TakeOrderScreenState extends State<TakeOrderScreen> {
  final ApiService _apiService = ApiService();
  
  bool _isLoading = true;
  String? _selectedShopId;
  final List<Map<String, dynamic>> _items = [];
  
  List<dynamic> _shops = [];
  List<dynamic> _availableItems = [];

  List<dynamic> _mostOrdered = [];
  List<dynamic> _mostReturned = [];
  bool _isLoadingAnalytics = false;

  @override
  void initState() {
    super.initState();
    if (widget.editOrder != null) {
      _selectedShopId = widget.editOrder!['shopId'].toString();
      final orderItems = widget.editOrder!['items'] as List;
      for (var item in orderItems) {
        _items.add({
          'itemListId': item['itemListId'].toString(),
          'unit': item['unit'],
          'price': item['price'],
          'qty': item['quantity'],
          'total': item['amount'],
        });
      }
    }
    _fetchMasterData();
  }

  Future<void> _fetchMasterData() async {
    try {
      final shopsRes = await _apiService.get('/shops');
      final itemsRes = await _apiService.get('/item-list');

      if (shopsRes.statusCode == 200 && itemsRes.statusCode == 200) {
        setState(() {
          _shops = jsonDecode(shopsRes.body);
          _availableItems = jsonDecode(itemsRes.body);
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      // Error handled below
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading data from server')),
        );
      }
    }
  }

  void _addItem() {
    setState(() {
      _items.add({
        'itemListId': null,
        'unit': '',
        'price': 0.0,
        'qty': 1.0,
        'total': 0.0,
      });
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _updateItem(int index, String? itemListId) {
    if (itemListId == null) return;
    
    final selected = _availableItems.firstWhere((element) => element['id'].toString() == itemListId);
    setState(() {
      _items[index]['itemListId'] = itemListId;
      _items[index]['unit'] = selected['unit']?['unitName'] ?? '';
      _items[index]['price'] = selected['unitPrice'] ?? 0.0;
      _items[index]['total'] = (_items[index]['price'] as double) * (_items[index]['qty'] as double);
    });
  }

  void _updateQty(int index, String qtyStr) {
    final qty = double.tryParse(qtyStr) ?? 0.0;
    setState(() {
      _items[index]['qty'] = qty;
      _items[index]['total'] = (_items[index]['price'] as double) * qty;
    });
  }

  Future<void> _fetchShopAnalytics(String shopId) async {
    setState(() {
      _isLoadingAnalytics = true;
      _mostOrdered = [];
      _mostReturned = [];
    });
    try {
      final moRes = await _apiService.get('/shops/$shopId/most-ordered-items');
      final mrRes = await _apiService.get('/shops/$shopId/most-returned-items');
      
      if (moRes.statusCode == 200) {
        setState(() => _mostOrdered = jsonDecode(moRes.body));
      }
      if (mrRes.statusCode == 200) {
        setState(() => _mostReturned = jsonDecode(mrRes.body));
      }
    } catch (e) {
      // Silent fail
    } finally {
      if (mounted) setState(() => _isLoadingAnalytics = false);
    }
  }

  void _onShopChanged(String? shopId) {
    setState(() => _selectedShopId = shopId);
    if (shopId != null) {
      _fetchShopAnalytics(shopId);
    }
  }

  double get _grandTotal {
    return _items.fold(0.0, (sum, item) => sum + (item['total'] as double));
  }

  String _extractItemName(dynamic m) {
    if (m is Map) {
      if (m['itemName'] != null) return m['itemName'].toString();
      if (m['item'] is Map && m['item']['itemName'] != null) return m['item']['itemName'].toString();
      if (m['itemList'] is Map && m['itemList']['item'] is Map && m['itemList']['item']['itemName'] != null) return m['itemList']['item']['itemName'].toString();
      if (m['item'] != null) return m['item'].toString();
      if (m['name'] != null) return m['name'].toString();
      return "Unknown Item"; // Fallback for when all possible keys are null
    }
    return m.toString();
  }

  String _extractQty(dynamic m) {
    if (m is Map) {
      return (m['totalQuantity'] ?? m['quantity'] ?? m['totalSold'] ?? m['totalReturned'] ?? m['total'] ?? '').toString();
    }
    return '';
  }

  Future<void> _saveOrder() async {
    if (_selectedShopId == null || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a shop and add at least one item.')),
      );
      return;
    }

    final hasInvalidItems = _items.any((item) => item['itemListId'] == null || item['qty'] <= 0);
    if (hasInvalidItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please ensure all items are valid and quantity > 0')),
      );
      return;
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final payload = {
        "shopId": int.parse(_selectedShopId!),
        "orderDate": "${DateTime.now().toIso8601String().split('T')[0]}T00:00:00",
        "totalAmount": _grandTotal,
        "items": _items.map((item) => {
          "itemListId": int.parse(item['itemListId']),
          "quantity": item['qty'],
          "price": item['price'],
          "amount": item['total']
        }).toList(),
      };

      dynamic response;
      if (widget.editOrder != null) {
        response = await _apiService.put('/orders/${widget.editOrder!['id']}', payload);
      } else {
        response = await _apiService.post('/orders', payload);
      }

      if (mounted) Navigator.pop(context); // close dialog

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.editOrder != null ? 'Order updated successfully!' : 'Order saved successfully!'), backgroundColor: Colors.green),
          );
        }
        if (widget.editOrder != null) {
          if (mounted) Navigator.pop(context, true);
        } else {
          setState(() {
            _selectedShopId = null;
            _items.clear();
          });
        }
      } else {
        String errMsg = 'Server returned ${response.statusCode}';
        try {
          final errBody = jsonDecode(response.body);
          if (errBody['message'] != null) {
            errMsg = errBody['message'];
          }
        } catch (_) {}
        throw Exception(errMsg);
      }
    } catch (e) {
      // handled below
      if (mounted) {
        Navigator.pop(context); // close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editOrder != null ? 'Edit Order' : 'Take Order', style: const TextStyle(fontSize: 18)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Select Shop'),
                  initialValue: _selectedShopId,
                  items: _shops.map((s) => DropdownMenuItem(
                    value: s['id'].toString(), 
                    child: Text('${s['name']} (${s['place']})')
                  )).toList(),
                  onChanged: _onShopChanged,
                ),
                if (_selectedShopId != null) ...[
                  const SizedBox(height: 16),
                  if (_isLoadingAnalytics)
                    const Center(child: Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
                  else if (_mostOrdered.isNotEmpty || _mostReturned.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_mostOrdered.isNotEmpty)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Most Ordered', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                                  const SizedBox(height: 4),
                                  ..._mostOrdered.map((m) => Text('• ${_extractItemName(m)} (${_extractQty(m)})', style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis, maxLines: 2)),
                                ],
                              ),
                            ),
                          ),
                        if (_mostOrdered.isNotEmpty && _mostReturned.isNotEmpty)
                          const SizedBox(width: 8),
                        if (_mostReturned.isNotEmpty)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Most Returned', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                                  const SizedBox(height: 4),
                                  ..._mostReturned.map((m) => Text('• ${_extractItemName(m)} (${_extractQty(m)})', style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis, maxLines: 2)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                ]
              ],
            ),
          ),
          Expanded(
            child: _items.isEmpty 
              ? const Center(child: Text('No items added. Tap + to add items.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _items.length,
                  itemBuilder: (ctx, i) {
                    final item = _items[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<String>(
                                    decoration: const InputDecoration(
                                      labelText: 'Item',
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    initialValue: item['itemListId'],
                                    items: _availableItems.map((ai) => 
                                      DropdownMenuItem(
                                        value: ai['id'].toString(), 
                                        child: Text('${ai['item']?['itemName']}')
                                      )
                                    ).toList(),
                                    onChanged: (val) => _updateItem(i, val),
                                    isExpanded: true,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _removeItem(i),
                                )
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: item['qty'].toString(),
                                    decoration: const InputDecoration(
                                      labelText: 'Qty',
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    onChanged: (val) => _updateQty(i, val),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Price/${item['unit']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      Text('₹${item['price'].toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('Total', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                      Text('₹${item['total'].toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade700, fontSize: 16)),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                )
              ]
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Order:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('₹${_grandTotal.toStringAsFixed(2)}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber.shade700)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _addItem,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Item'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saveOrder,
                          icon: const Icon(Icons.save, color: Colors.white),
                          label: Text(widget.editOrder != null ? 'Update Order' : 'Save Order', style: const TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
