import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../providers/auth_provider.dart';

class AddEditShopScreen extends StatefulWidget {
  final Map<String, dynamic>? shop;

  const AddEditShopScreen({super.key, this.shop});

  @override
  State<AddEditShopScreen> createState() => _AddEditShopScreenState();
}

class _AddEditShopScreenState extends State<AddEditShopScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _placeCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _gstNumCtrl;
  late TextEditingController _gstDetCtrl;
  late TextEditingController _latCtrl;
  late TextEditingController _lngCtrl;

  File? _imageFile;
  bool _isSaving = false;
  String? _existingImageUrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.shop?['name'] ?? '');
    _placeCtrl = TextEditingController(text: widget.shop?['place'] ?? '');
    _phoneCtrl = TextEditingController(text: widget.shop?['phoneNumber'] ?? '');
    _gstNumCtrl = TextEditingController(text: widget.shop?['gstNumber'] ?? '');
    _gstDetCtrl = TextEditingController(text: widget.shop?['gstDetails'] ?? '');
    
    _latCtrl = TextEditingController(text: widget.shop?['latitude']?.toString() ?? '');
    _lngCtrl = TextEditingController(text: widget.shop?['longitude']?.toString() ?? '');
    _existingImageUrl = widget.shop?['shopImageUrl'];
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return;
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location services are disabled.')));
      return;
    }

    permission = await Geolocator.checkPermission();
    if (!mounted) return;
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (!mounted) return;
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are denied')));
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are permanently denied, we cannot request permissions.')));
      return;
    } 

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 10),
      );
      if (!mounted) return;
      setState(() {
        _latCtrl.text = position.latitude.toString();
        _lngCtrl.text = position.longitude.toString();
      });
    } catch (e) {
      if (!mounted) return;
      try {
        // Fallback to last known position if current position times out or fails
        Position? lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          if (!mounted) return;
          setState(() {
            _latCtrl.text = lastPosition.latitude.toString();
            _lngCtrl.text = lastPosition.longitude.toString();
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Using last known location')));
          return;
        }
      } catch (_) {}
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to get location. Please ensure GPS is active and try again.')));
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: source, imageQuality: 70, maxWidth: 1024, maxHeight: 1024);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to pick image')));
    }
  }

  Future<bool> _uploadImage(String shopId) async {
    if (_imageFile == null) return true;
    
    try {
      var request = http.MultipartRequest('POST', Uri.parse('${Constants.baseUrl}/shops/$shopId/image'));
      request.files.add(await http.MultipartFile.fromPath('image', _imageFile!.path));
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      
      var res = await request.send();
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> _saveShop() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final branchId = auth.selectedBranchId;
      if (branchId == null || branchId == -1) {
        throw Exception("Please select a branch first from home screen");
      }

      final data = {
        'name': _nameCtrl.text,
        'place': _placeCtrl.text,
        'phoneNumber': _phoneCtrl.text,
        'gstNumber': _gstNumCtrl.text,
        'gstDetails': _gstDetCtrl.text,
        'branch': {'id': branchId},
        'latitude': _latCtrl.text.isNotEmpty ? double.parse(_latCtrl.text) : null,
        'longitude': _lngCtrl.text.isNotEmpty ? double.parse(_lngCtrl.text) : null,
        'shopImageUrl': _existingImageUrl,
      };

      http.Response res;
      if (widget.shop == null) {
        res = await _apiService.post('/shops', data);
      } else {
        res = await _apiService.put('/shops/${widget.shop!['id']}', data);
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        final savedShop = jsonDecode(res.body);
        final shopId = savedShop['id'].toString();
        
        if (_imageFile != null) {
          bool uploaded = await _uploadImage(shopId);
          if (!uploaded && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shop saved, but image upload failed')));
          }
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shop saved successfully')));
          Navigator.pop(context);
        }
      } else {
        throw Exception('Failed to save shop');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String? fullImageUrl;
    if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
      String rootUrl = Constants.baseUrl.replaceAll('/api', '');
      fullImageUrl = rootUrl + _existingImageUrl!;
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.shop == null ? 'Add Shop' : 'Edit Shop')),
      body: _isSaving 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Shop Name'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: _placeCtrl,
                    decoration: const InputDecoration(labelText: 'Place'),
                  ),
                  TextFormField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Phone Number'),
                    keyboardType: TextInputType.phone,
                  ),
                  TextFormField(
                    controller: _gstNumCtrl,
                    decoration: const InputDecoration(labelText: 'GST Number'),
                  ),
                  TextFormField(
                    controller: _gstDetCtrl,
                    decoration: const InputDecoration(labelText: 'GST Details'),
                  ),
                  const SizedBox(height: 24),
                  const Text('Location Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _latCtrl,
                          decoration: const InputDecoration(labelText: 'Latitude'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          validator: (v) {
                            if (v != null && v.isNotEmpty) {
                              final lat = double.tryParse(v);
                              if (lat == null || lat < -90 || lat > 90) return 'Invalid Latitude (-90 to 90)';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _lngCtrl,
                          decoration: const InputDecoration(labelText: 'Longitude'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          validator: (v) {
                            if (v != null && v.isNotEmpty) {
                              final lng = double.tryParse(v);
                              if (lng == null || lng < -180 || lng > 180) return 'Invalid Longitude (-180 to 180)';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.my_location),
                    label: const Text('Get Current Location'),
                    onPressed: _getCurrentLocation,
                  ),
                  const SizedBox(height: 24),
                  const Text('Shop Image', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_imageFile != null)
                    Image.file(_imageFile!, height: 150, width: double.infinity, fit: BoxFit.cover)
                  else if (fullImageUrl != null)
                    Image.network(fullImageUrl, height: 150, width: double.infinity, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Text('Error loading image'))
                  else
                    Container(
                      height: 150,
                      width: double.infinity,
                      color: Colors.grey[200],
                      alignment: Alignment.center,
                      child: const Text('No Image Selected'),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Take Photo'),
                        onPressed: () => _pickImage(ImageSource.camera),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Gallery'),
                        onPressed: () => _pickImage(ImageSource.gallery),
                      ),
                    ],
                  ),
                  if (_imageFile != null)
                    Center(
                      child: TextButton(
                        child: const Text('Remove Image', style: TextStyle(color: Colors.red)),
                        onPressed: () => setState(() => _imageFile = null),
                      ),
                    ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveShop,
                      child: const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Save Shop', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
