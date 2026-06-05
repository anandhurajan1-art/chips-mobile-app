import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'view_bill_summary_screen.dart';
import 'select_branch_screen.dart';

class SalesEntryScreen extends StatefulWidget {
  final Map<String, dynamic>? editBill;
  const SalesEntryScreen({super.key, this.editBill});

  @override
  State<SalesEntryScreen> createState() => _SalesEntryScreenState();
}

class _SalesEntryScreenState extends State<SalesEntryScreen> {
  final ApiService _apiService = ApiService();
  
  bool _isLoading = true;
  String? _selectedShopId;
  final List<Map<String, dynamic>> _items = [];
  
  List<dynamic> _shops = [];
  List<dynamic> _availableItems = [];

  @override
  void initState() {
    super.initState();
    if (widget.editBill != null) {
      _selectedShopId = widget.editBill!['shop']['id'].toString();
      final salesItems = widget.editBill!['salesItems'] as List;
      for (var item in salesItems) {
        _items.add({
          'itemListId': item['itemList']['id'].toString(),
          'unit': item['itemList']['unit']['unitName'],
          'price': item['itemList']['price'],
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
      print(e);
      setState(() => _isLoading = false);
      if (mounted) {
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
      _items[index]['price'] = selected['price'] ?? 0.0;
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

  double get _grandTotal {
    return _items.fold(0.0, (sum, item) => sum + (item['total'] as double));
  }

  Future<void> _saveBill() async {
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
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final payload = {
        "shop": { "id": int.parse(_selectedShopId!) },
        "saleDate": DateTime.now().toIso8601String().split('T')[0],
        "totalAmount": _grandTotal,
        "salesItems": _items.map((item) => {
          "itemList": { "id": int.parse(item['itemListId']) },
          "quantity": item['qty'],
          "amount": item['total']
        }).toList(),
      };

      late final response;
      if (widget.editBill != null) {
        response = await _apiService.put('/sales/${widget.editBill!['id']}', payload);
      } else {
        response = await _apiService.post('/sales', payload);
      }

      if (mounted) Navigator.pop(context); // close dialog

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.editBill != null ? 'Bill updated successfully!' : 'Bill saved successfully!'), backgroundColor: Colors.green),
          );
        }
        if (widget.editBill != null) {
          if (mounted) Navigator.pop(context, true);
        } else {
          setState(() {
            _selectedShopId = null;
            _items.clear();
          });
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      print('Save Bill Error: $e');
      if (mounted) {
        Navigator.pop(context); // close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving bill'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.editBill != null ? 'Edit Sales Entry' : 'New Sales Entry', style: const TextStyle(fontSize: 18)),
            Text(auth.selectedBranchName != null ? 'Branch: ${auth.selectedBranchName}' : 'No Branch Selected', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ViewBillSummaryScreen()),
              );
            },
            tooltip: 'View Bills',
          ),
          IconButton(
            icon: const Icon(Icons.sync_alt),
            onPressed: () {
              auth.selectBranch(-1, ''); // invalid, triggers routing to select screen if main checks it, or just use Navigator
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => SelectBranchScreen()),
              );
            },
            tooltip: 'Switch Branch',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.logout(),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Select Shop'),
              value: _selectedShopId,
              items: _shops.map((s) => DropdownMenuItem(
                value: s['id'].toString(), 
                child: Text('${s['name']} (${s['place']})')
              )).toList(),
              onChanged: (val) => setState(() => _selectedShopId = val),
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
                                    value: item['itemListId'],
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
                                      Text('₹${item['total'].toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
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
                  color: Colors.black.withOpacity(0.05),
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
                      const Text('Grand Total:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('₹${_grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber)),
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
                          onPressed: _saveBill,
                          icon: const Icon(Icons.save, color: Colors.white),
                          label: Text(widget.editBill != null ? 'Update Bill' : 'Save Bill', style: const TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
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
