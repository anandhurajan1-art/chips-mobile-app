import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'add_edit_shop_screen.dart';
import 'view_shop_screen.dart';

class ShopListScreen extends StatefulWidget {
  const ShopListScreen({super.key});

  @override
  State<ShopListScreen> createState() => _ShopListScreenState();
}

class _ShopListScreenState extends State<ShopListScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _shops = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchShops();
  }

  Future<void> _fetchShops() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.get('/shops');
      if (res.statusCode == 200) {
        setState(() {
          _shops = jsonDecode(res.body);
        });
      }
    } catch (e) {
      // print('Error fetching shops: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openMap(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open map')));
      }
    }
  }

  void _viewImage(String imageUrl) {
    String rootUrl = Constants.baseUrl.replaceAll('/api', '');
    String fullUrl = rootUrl + imageUrl;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Stack(
          children: [
            Image.network(fullUrl, fit: BoxFit.contain, errorBuilder: (context, error, stackTrace) => const Padding(
              padding: EdgeInsets.all(32.0),
              child: Text('Error loading image'),
            )),
            Positioned(
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.black, shadows: [Shadow(color: Colors.white, blurRadius: 10)]),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Shops')),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditShopScreen()));
          _fetchShops();
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _shops.isEmpty
              ? const Center(child: Text('No shops found.'))
              : ListView.builder(
                  itemCount: _shops.length,
                  itemBuilder: (context, index) {
                    final shop = _shops[index];
                    final hasLocation = shop['latitude'] != null && shop['longitude'] != null;
                    final hasImage = shop['shopImageUrl'] != null && shop['shopImageUrl'].toString().isNotEmpty;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(shop['name'] ?? 'Unknown Shop', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(shop['place'] ?? ''),
                            const SizedBox(height: 4),
                            Text(hasLocation ? 'Location Available' : 'Location Not Available', style: TextStyle(color: hasLocation ? Colors.green : Colors.red, fontSize: 12)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasImage)
                              IconButton(
                                icon: const Icon(Icons.image, color: Colors.blue),
                                onPressed: () => _viewImage(shop['shopImageUrl']),
                                tooltip: 'View Image',
                              ),
                            if (hasLocation)
                              IconButton(
                                icon: const Icon(Icons.map, color: Colors.green),
                                onPressed: () => _openMap(shop['latitude'], shop['longitude']),
                                tooltip: 'Open Map',
                              ),
                          ],
                        ),
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => ViewShopScreen(shop: shop)));
                          _fetchShops();
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
