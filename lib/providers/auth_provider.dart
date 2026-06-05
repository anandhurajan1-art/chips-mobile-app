import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;
  String? _username;
  String? _role;
  List<String> _privileges = [];
  int? _selectedBranchId;
  String? _selectedBranchName;

  bool get isAuthenticated => _isAuthenticated;
  String? get username => _username;
  String? get role => _role;
  List<String> get privileges => _privileges;
  int? get selectedBranchId => _selectedBranchId;
  String? get selectedBranchName => _selectedBranchName;

  bool hasPrivilege(String privilege) {
    if (_role == 'ADMIN') return true;
    return _privileges.contains(privilege);
  }

  Future<void> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token != null) {
      _isAuthenticated = true;
      _username = prefs.getString('username');
      _role = prefs.getString('role');
      _privileges = prefs.getStringList('privileges') ?? [];
      _selectedBranchId = prefs.getInt('selectedBranchId');
      _selectedBranchName = prefs.getString('selectedBranchName');
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        final role = data['role'];
        final List<String> privileges = List<String>.from(data['privileges'] ?? []);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);
        await prefs.setString('username', data['username']);
        if (role != null) await prefs.setString('role', role);
        await prefs.setStringList('privileges', privileges);
        
        _isAuthenticated = true;
        _username = data['username'];
        _role = role;
        _privileges = privileges;
        notifyListeners();
        return true;
      }
    } catch (e) {
      print('Login Error: $e');
    }
    return false;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('username');
    await prefs.remove('role');
    await prefs.remove('privileges');
    await prefs.remove('selectedBranchId');
    await prefs.remove('selectedBranchName');
    
    _isAuthenticated = false;
    _username = null;
    _role = null;
    _privileges = [];
    _selectedBranchId = null;
    _selectedBranchName = null;
    notifyListeners();
  }

  Future<void> selectBranch(int id, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedBranchId', id);
    await prefs.setString('selectedBranchName', name);
    
    _selectedBranchId = id;
    _selectedBranchName = name;
    notifyListeners();
  }
}
