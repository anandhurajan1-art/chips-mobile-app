import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});

  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _invoiceSearchCtrl = TextEditingController();
  
  bool _isSearching = false;
  Map<String, dynamic>? _invoiceDetails;
  List<dynamic> _foundInvoices = [];
  List<Map<String, dynamic>> _returnItems = [];
  bool _isSaving = false;

  List<dynamic> _shops = [];
  String? _selectedShopId;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _fetchShops();
  }

  Future<void> _fetchShops() async {
    try {
      final res = await _apiService.get('/shops');
      if (res.statusCode == 200) {
        setState(() => _shops = jsonDecode(res.body));
      }
    } catch (e) {
      // error handled below
    }
  }

  Future<void> _searchInvoice() async {
    final query = _invoiceSearchCtrl.text.trim();
    if (query.isEmpty && _selectedShopId == null && _selectedDate == null) return;

    setState(() {
      _isSearching = true;
      _foundInvoices = [];
      _invoiceDetails = null;
      _returnItems = [];
    });
    
    try {
      String url = '/invoices';
      final params = <String>[];
      if (_selectedShopId != null) params.add('shopId=$_selectedShopId');
      if (_selectedDate != null) params.add('date=${_selectedDate!.toIso8601String().split('T')[0]}');
      if (params.isNotEmpty) url += '?${params.join('&')}';

      final res = await _apiService.get(url);
      if (res.statusCode == 200) {
        List<dynamic> invoices = jsonDecode(res.body);
        
        if (query.isNotEmpty) {
          invoices = invoices.where((inv) => 
            inv['invoiceNo'] == query || 'INV-${inv['id']}' == query || inv['id'].toString() == query
          ).toList();
        }

        if (invoices.isEmpty) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No invoices found matching criteria')));
        } else if (invoices.length == 1) {
          _selectInvoice(invoices[0]);
        } else {
          setState(() {
            _foundInvoices = invoices;
          });
        }
      }
    } catch (e) {
      // error handled below
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error searching invoice')));
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectInvoice(Map<String, dynamic> found) {
    setState(() {
      _foundInvoices = [];
      _invoiceDetails = found;
      _returnItems = (found['items'] as List).map((item) => {
        'invoiceItemId': item['id'],
        'itemName': item['itemName'],
        'unit': item['unit'],
        'price': item['price'],
        'maxQty': item['quantity'],
        'returnedQuantity': 0.0,
        'reason': '',
        'amount': 0.0,
      }).toList();
    });
  }

  void _updateReturnQty(int index, String qtyStr) {
    double qty = double.tryParse(qtyStr) ?? 0.0;
    final maxQty = _returnItems[index]['maxQty'];
    
    if (qty > maxQty) qty = maxQty;
    if (qty < 0) qty = 0;

    setState(() {
      _returnItems[index]['returnedQuantity'] = qty;
      _returnItems[index]['amount'] = qty * _returnItems[index]['price'];
    });
  }

  void _updateReason(int index, String reason) {
    setState(() {
      _returnItems[index]['reason'] = reason;
    });
  }

  double get _totalReturnAmount {
    return _returnItems.fold(0.0, (sum, item) => sum + (item['amount'] as double));
  }

  Future<void> _submitReturn() async {
    final validItems = _returnItems.where((item) => item['returnedQuantity'] > 0).toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter return quantity for at least one item.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final payload = {
        "invoiceId": _invoiceDetails!['id'],
        "returnDate": "${DateTime.now().toIso8601String().split('T')[0]}T00:00:00",
        "items": validItems.map((item) => {
          "invoiceItemId": item['invoiceItemId'],
          "returnedQuantity": item['returnedQuantity'],
          "reason": item['reason'],
          "amount": item['amount']
        }).toList(),
      };

      final response = await _apiService.post('/returns', payload);

      if (mounted) Navigator.pop(context); // close dialog

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Return submitted successfully!'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      // error handled below
      if (mounted) {
        Navigator.pop(context); // close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error submitting return'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Return Entry', style: TextStyle(fontSize: 18)),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Shop', isDense: true),
                        initialValue: _selectedShopId,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Shops')),
                          ..._shops.map((s) => DropdownMenuItem(
                            value: s['id'].toString(), 
                            child: Text(s['name'], overflow: TextOverflow.ellipsis)
                          ))
                        ],
                        onChanged: (val) => setState(() => _selectedShopId = val),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (date != null) {
                            setState(() => _selectedDate = date);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Date', isDense: true),
                          child: Text(_selectedDate != null ? _selectedDate!.toIso8601String().split('T')[0] : 'All Dates'),
                        ),
                      ),
                    ),
                    if (_selectedDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => setState(() => _selectedDate = null),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _invoiceSearchCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Search Invoice No. (Opt)',
                          hintText: 'e.g. INV-1',
                          isDense: true,
                        ),
                        onSubmitted: (_) => _searchInvoice(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSearching ? null : _searchInvoice,
                      child: _isSearching 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.search),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          if (_foundInvoices.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _foundInvoices.length,
                itemBuilder: (ctx, i) {
                  final inv = _foundInvoices[i];
                  return ListTile(
                    title: Text('${inv['invoiceNo'] ?? 'INV-${inv['id']}'}'),
                    subtitle: Text('${inv['shopName']} - ${inv['invoiceDate'].toString().split('T')[0]}'),
                    trailing: Text('₹${inv['totalAmount']}'),
                    onTap: () => _selectInvoice(inv),
                  );
                },
              ),
            ),
          
          if (_invoiceDetails != null)
            Expanded(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: Colors.grey.shade100,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Invoice: ${_invoiceDetails!['invoiceNo']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Shop: ${_invoiceDetails!['shopName']}'),
                        Text('Date: ${DateTime.parse(_invoiceDetails!['invoiceDate']).toLocal().toString().split(' ')[0]}'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _returnItems.length,
                      itemBuilder: (ctx, i) {
                        final item = _returnItems[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${item['itemName']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text('₹${item['price'].toStringAsFixed(2)} / ${item['unit']}', style: const TextStyle(color: Colors.grey)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('Billed Qty: ${item['maxQty']}', style: const TextStyle(fontSize: 12)),
                                const Divider(),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        decoration: const InputDecoration(
                                          labelText: 'Return Qty',
                                          isDense: true,
                                        ),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        onChanged: (val) => _updateReturnQty(i, val),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 3,
                                      child: TextFormField(
                                        decoration: const InputDecoration(
                                          labelText: 'Reason (Opt)',
                                          isDense: true,
                                        ),
                                        onChanged: (val) => _updateReason(i, val),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text('Return Amt: ₹${item['amount'].toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
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
                        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))
                      ]
                    ),
                    child: SafeArea(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Refund:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Text('₹${_totalReturnAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: (_totalReturnAmount > 0 && !_isSaving) ? _submitReturn : null,
                              icon: const Icon(Icons.assignment_return, color: Colors.white),
                              label: const Text('Submit Return', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            ),
                          )
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
        ],
      ),
    );
  }
}
