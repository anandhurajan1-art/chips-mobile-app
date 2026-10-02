import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart';
import 'add_edit_shop_screen.dart';

class ViewShopScreen extends StatelessWidget {
  final Map<String, dynamic> shop;

  const ViewShopScreen({super.key, required this.shop});

  void _openMap(BuildContext context, double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open map')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = shop['latitude'] != null && shop['longitude'] != null;
    final hasImage = shop['shopImageUrl'] != null && shop['shopImageUrl'].toString().isNotEmpty;
    
    String? fullImageUrl;
    if (hasImage) {
      String rootUrl = Constants.baseUrl.replaceAll('/api', '');
      fullImageUrl = rootUrl + shop['shopImageUrl'];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(shop['name'] ?? 'View Shop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AddEditShopScreen(shop: shop)));
            },
            tooltip: 'Edit Shop',
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImage)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    fullImageUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      color: Colors.grey[200],
                      alignment: Alignment.center,
                      child: const Text('Error loading image'),
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const Text('No Image Available', style: TextStyle(color: Colors.grey)),
              ),
            const SizedBox(height: 24),
            _buildDetailRow('Shop Name', shop['name'] ?? 'N/A'),
            _buildDetailRow('Place', shop['place'] ?? 'N/A'),
            _buildDetailRow('Phone Number', shop['phoneNumber'] ?? 'N/A'),
            _buildDetailRow('GST Number', shop['gstNumber'] ?? 'N/A'),
            _buildDetailRow('GST Details', shop['gstDetails'] ?? 'N/A'),
            
            const SizedBox(height: 24),
            const Text('Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            if (hasLocation) ...[
              _buildDetailRow('Latitude', shop['latitude'].toString()),
              _buildDetailRow('Longitude', shop['longitude'].toString()),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.map),
                  label: const Text('Open in Google Maps'),
                  onPressed: () => _openMap(context, shop['latitude'], shop['longitude']),
                ),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('Location Not Available', style: TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value.isEmpty ? 'N/A' : value, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
