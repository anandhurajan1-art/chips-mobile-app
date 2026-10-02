import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class SelectBranchScreen extends StatefulWidget {
  const SelectBranchScreen({super.key});
  @override
  State<SelectBranchScreen> createState() => _SelectBranchScreenState();
}

class _SelectBranchScreenState extends State<SelectBranchScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _branches = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchBranches();
  }

  Future<void> _fetchBranches() async {
    try {
      final response = await _apiService.get('/branches');
      if (response.statusCode == 200) {
        setState(() {
          _branches = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load branches';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error connecting to server. Ensure backend is running.';
        _isLoading = false;
      });
    }
  }

  void _selectBranch(int id, String name) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.selectBranch(id, name);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  void _logout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    // Navigator logic handled by main.dart listening to auth state changes
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Select Branch'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _logout,
          )
        ],
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator())
        : _error != null 
          ? Center(child: Text(_error!, style: TextStyle(color: Colors.red)))
          : _branches.isEmpty 
            ? Center(child: Text('No branches available. Please configure in Web Admin.'))
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome, ${authProvider.username}!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('Please select a branch to continue:'),
                    SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _branches.length,
                        itemBuilder: (context, index) {
                          final branch = _branches[index];
                          return Card(
                            margin: EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: Icon(Icons.store, color: Colors.blue),
                              title: Text(branch['name'], style: TextStyle(fontWeight: FontWeight.w500)),
                              trailing: Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () => _selectBranch(branch['id'], branch['name']),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
