import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/invoice_printer.dart';


class ViewBillSummaryScreen extends StatefulWidget {
  const ViewBillSummaryScreen({super.key});

  @override
  State<ViewBillSummaryScreen> createState() => _ViewBillSummaryScreenState();
}

class _ViewBillSummaryScreenState extends State<ViewBillSummaryScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _bills = [];
  Map<String, dynamic>? _settings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBills();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final response = await _apiService.get('/settings');
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _settings = jsonDecode(response.body);
          });
        }
      }
    } catch (e) {
      // handled below
    }
  }

  Future<void> _fetchBills() async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 30));
      
      final startStr = startDate.toIso8601String().split('T')[0];
      final endStr = endDate.toIso8601String().split('T')[0];

      final response = await _apiService.get('/sales/reports?startDate=$startStr&endDate=$endStr');

      if (response.statusCode == 200) {
        setState(() {
          _bills = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load bills');
      }
    } catch (e) {
      // handled below
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading bills from server')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Summary'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bills.isEmpty
              ? const Center(child: Text('No bills found for the last 30 days.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bills.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final bill = _bills[index];
                    final shopName = bill['shop']?['name'] ?? 'Unknown Shop';
                    final date = bill['saleDate'] ?? '';
                    final total = bill['totalAmount'] ?? 0.0;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Colors.amber.shade100,
                        child: const Icon(Icons.receipt, color: Colors.amber),
                      ),
                      title: Text(shopName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('INV-${bill['id']} • $date'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const Text('Paid', style: TextStyle(color: Colors.green, fontSize: 12)),
                            ],
                          ),

                          IconButton(
                            icon: const Icon(Icons.print, color: Colors.blueGrey),
                            onPressed: () {
                              InvoicePrinter.printInvoice(bill, _settings);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
