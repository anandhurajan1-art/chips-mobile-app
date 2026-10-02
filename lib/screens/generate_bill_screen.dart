import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class GenerateBillScreen extends StatefulWidget {
  const GenerateBillScreen({super.key});

  @override
  State<GenerateBillScreen> createState() => _GenerateBillScreenState();
}

class _GenerateBillScreenState extends State<GenerateBillScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _pendingOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPendingOrders();
  }

  Future<void> _fetchPendingOrders() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.get('/orders');
      if (res.statusCode == 200) {
        final List<dynamic> allOrders = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _pendingOrders = allOrders.where((o) => o['status'] == 'PENDING').toList();
          });
        }
      }
    } catch (e) {
      // print('Fetch Orders Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error fetching pending orders')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateBill(int orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate Bill'),
        content: const Text('Are you sure you want to generate a bill for this order? This will deduct stock.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('GENERATE')),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final res = await _apiService.post('/invoices/generate/$orderId', {});
      if (mounted) Navigator.pop(context); // close dialog

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill generated successfully!'), backgroundColor: Colors.green));
        }
        _fetchPendingOrders(); // refresh list
      } else {
        throw Exception('Server returned ${res.statusCode} with body: ${res.body}');
      }
    } catch (e) {
      // print('Generate Bill Error: $e');
      if (mounted) {
        Navigator.pop(context); // close dialog
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to generate bill'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Bill (Pending Orders)'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchPendingOrders),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _pendingOrders.isEmpty
          ? const Center(child: Text('No pending orders found.'))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _pendingOrders.length,
              itemBuilder: (ctx, i) {
                final order = _pendingOrders[i];
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
                            Text('${order['orderNo']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('₹${order['totalAmount']?.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Shop: ${order['shopName']}'),
                        Text('Date: ${order['orderDate'] != null ? DateTime.parse(order['orderDate']).toLocal().toString().split(' ')[0] : '-'}'),
                        Text('Staff: ${order['staffName']}'),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _generateBill(order['id']),
                              icon: const Icon(Icons.receipt_long, color: Colors.white, size: 18),
                              label: const Text('Generate Bill', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                minimumSize: const Size(0, 36),
                              ),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
