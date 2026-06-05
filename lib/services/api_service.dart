import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class ApiService {
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> get(String endpoint) async {
    final headers = await _getHeaders();
    String finalEndpoint = endpoint;
    final prefs = await SharedPreferences.getInstance();
    final branchId = prefs.getInt('selectedBranchId');
    
    if (branchId != null && _isBranchRequired(endpoint)) {
      final delimiter = endpoint.contains('?') ? '&' : '?';
      finalEndpoint = '$endpoint${delimiter}branchId=$branchId';
    }
    
    return http.get(Uri.parse('${Constants.baseUrl}$finalEndpoint'), headers: headers);
  }

  Future<http.Response> post(String endpoint, dynamic body) async {
    final headers = await _getHeaders();
    final prefs = await SharedPreferences.getInstance();
    final branchId = prefs.getInt('selectedBranchId');
    
    if (branchId != null && _isBranchRequired(endpoint)) {
      if (body is Map) {
        body['branch'] = {'id': branchId};
      }
    }
    
    return http.post(
      Uri.parse('${Constants.baseUrl}$endpoint'), 
      headers: headers,
      body: jsonEncode(body),
    );
  }

  Future<http.Response> put(String endpoint, dynamic body) async {
    final headers = await _getHeaders();
    final prefs = await SharedPreferences.getInstance();
    final branchId = prefs.getInt('selectedBranchId');
    
    if (branchId != null && _isBranchRequired(endpoint)) {
      if (body is Map) {
        body['branch'] = {'id': branchId};
      }
    }
    
    return http.put(
      Uri.parse('${Constants.baseUrl}$endpoint'), 
      headers: headers,
      body: jsonEncode(body),
    );
  }

  Future<http.Response> delete(String endpoint) async {
    final headers = await _getHeaders();
    return http.delete(Uri.parse('${Constants.baseUrl}$endpoint'), headers: headers);
  }

  bool _isBranchRequired(String endpoint) {
    return endpoint.startsWith('/items') || 
           endpoint.startsWith('/item-list') || 
           endpoint.startsWith('/shops') || 
           endpoint.startsWith('/sales');
  }
}
