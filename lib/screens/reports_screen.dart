import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  bool _isLoading = false;
  List<dynamic> _shops = [];
  String? _selectedShopId;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  List<dynamic> _itemCounts = [];
  List<dynamic> _profits = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _fetchShops();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      _fetchData();
    }
  }

  Future<void> _fetchShops() async {
    try {
      final res = await _apiService.get('/shops');
      if (res.statusCode == 200) {
        setState(() => _shops = jsonDecode(res.body));
        _fetchData();
      }
    } catch (e) {
      // error handled below
    }
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      String params = '?startDate=${_startDate.toIso8601String().split('T')[0]}&endDate=${_endDate.toIso8601String().split('T')[0]}';
      if (_selectedShopId != null) params += '&shopId=$_selectedShopId';

      if (_tabController.index == 0) {
        final res = await _apiService.get('/reports/item-count$params');
        if (res.statusCode == 200) {
          setState(() => _itemCounts = jsonDecode(res.body));
        }
      } else {
        final res = await _apiService.get('/reports/profit$params');
        if (res.statusCode == 200) {
          setState(() => _profits = jsonDecode(res.body));
        }
      }
    } catch (e) {
      // error handled below
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error loading reports')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() {
        if (isStart) {
          _startDate = date;
        } else {
          _endDate = date;
        }
      });
      _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports', style: TextStyle(fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Item Count'),
            Tab(text: 'Profit'),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Shop', isDense: true),
                  initialValue: _selectedShopId,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Shops')),
                    ..._shops.map((s) => DropdownMenuItem(
                      value: s['id'].toString(), 
                      child: Text(s['name'], overflow: TextOverflow.ellipsis)
                    ))
                  ],
                  onChanged: (val) {
                    setState(() => _selectedShopId = val);
                    _fetchData();
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context, true),
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Start Date', isDense: true),
                          child: Text(_startDate.toIso8601String().split('T')[0]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context, false),
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'End Date', isDense: true),
                          child: Text(_endDate.toIso8601String().split('T')[0]),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildItemCountTab(),
                  _buildProfitTab(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemCountTab() {
    if (_itemCounts.isEmpty) return const Center(child: Text('No data found'));
    
    return ListView.builder(
      itemCount: _itemCounts.length,
      itemBuilder: (ctx, i) {
        final item = _itemCounts[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            title: Text('${item['itemName']}'),
            subtitle: Text('${item['shopName']}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Sold: ${item['totalSold']}', style: const TextStyle(color: Colors.green, fontSize: 12)),
                Text('Ret: ${item['totalReturned']}', style: const TextStyle(color: Colors.red, fontSize: 12)),
                Text('Net: ${item['netCount']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfitTab() {
    if (_profits.isEmpty) return const Center(child: Text('No data found'));

    return ListView.builder(
      itemCount: _profits.length,
      itemBuilder: (ctx, i) {
        final item = _profits[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            title: Text('${item['itemName']}'),
            subtitle: Text('${item['shopName']} | Qty: ${item['soldQuantity']}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Cost: ₹${item['costPrice']?.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
                Text('Price: ₹${item['unitPrice']?.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
                Text('Profit: ₹${item['profit']?.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
          ),
        );
      },
    );
  }
}
