import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'sales_entry_screen.dart';
import 'select_branch_screen.dart';
import 'take_order_screen.dart';
import 'returns_screen.dart';
import 'generate_bill_screen.dart';
import 'view_bill_summary_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    final List<Map<String, dynamic>> modules = [
      {
        'title': 'Sales Entry',
        'icon': Icons.shopping_cart,
        'privilege': 'SALES',
        'color': Colors.blue,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesEntryScreen())),
      },
      {
        'title': 'Take Order',
        'icon': Icons.assignment,
        'privilege': 'TAKE_ORDER',
        'color': Colors.amber.shade700,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TakeOrderScreen())),
      },
      {
        'title': 'Generate Bill',
        'icon': Icons.receipt,
        'privilege': 'VIEW_ORDERS',
        'color': Colors.purple,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GenerateBillScreen())),
      },
      {
        'title': 'Invoices (Bills)',
        'icon': Icons.receipt_long,
        'privilege': 'VIEW_BILL',
        'color': Colors.green,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ViewBillSummaryScreen())),
      },
      {
        'title': 'Returns',
        'icon': Icons.assignment_return,
        'privilege': 'RETURN_ENTRY',
        'color': Colors.red,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReturnsScreen())),
      },
    ];

    final availableModules = modules.where((m) => auth.hasPrivilege(m['privilege'])).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard', style: TextStyle(fontSize: 18)),
            Text(auth.selectedBranchName != null ? 'Branch: ${auth.selectedBranchName}' : 'No Branch Selected', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_alt),
            onPressed: () {
              auth.selectBranch(-1, '');
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => SelectBranchScreen()),
              );
            },
            tooltip: 'Switch Branch',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.logout(),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: availableModules.isEmpty
          ? const Center(child: Text('No modules available for your role.'))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              itemCount: availableModules.length,
              itemBuilder: (context, index) {
                final mod = availableModules[index];
                return InkWell(
                  onTap: mod['onTap'],
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: (mod['color'] as Color).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            mod['icon'],
                            size: 36,
                            color: mod['color'],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          mod['title'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
