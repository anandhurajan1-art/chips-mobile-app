
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class InvoicePrinter {
  static Future<void> printInvoice(Map<String, dynamic> bill, [Map<String, dynamic>? settings]) async {
    final pdf = pw.Document();

    final shopName = bill['shop']?['name'] ?? 'Unknown Shop';
    final shopPlace = bill['shop']?['place'] ?? '';
    final invoiceNo = 'INV-${bill['id']}';
    final date = bill['saleDate'] ?? '';
    final totalAmount = bill['totalAmount'] ?? 0.0;
    final items = bill['salesItems'] as List<dynamic>? ?? [];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(settings?['companyName'] ?? 'CHIPSYS DISTRIBUTION', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    if (settings?['companyAddress'] != null && settings!['companyAddress'].toString().isNotEmpty)
                      pw.Text(settings['companyAddress'], style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700), textAlign: pw.TextAlign.center)
                    else ...[
                      pw.Text('123 Main Street, Cityville, State 12345', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                      pw.Text('Phone: (555) 123-4567 | Email: sales@chipsys.com', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    ]
                  ],
                ),
              ),
              pw.SizedBox(height: 30),
              pw.Divider(),
              pw.SizedBox(height: 10),

              // Billed To & Details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BILLED TO', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                      pw.SizedBox(height: 4),
                      pw.Text(shopName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      pw.Text(shopPlace, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text('Invoice No: ', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                          pw.Text(invoiceNo, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          pw.Text('Date: ', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                          pw.Text(date, style: pw.TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Items Table
              pw.TableHelper.fromTextArray(
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerRight,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                },
                headers: ['Description', 'Unit Price', 'Quantity', 'Amount'],
                data: items.map((item) {
                  final name = item['itemList']?['item']?['itemName'] ?? 'Item';
                  final unit = item['itemList']?['unit']?['unitName'] ?? 'Unit';
                  final amount = item['amount'] ?? 0.0;
                  final qty = item['quantity'] ?? 1.0;
                  final unitPrice = qty > 0 ? (amount / qty) : 0.0;
                  
                  return [
                    '$name\n($unit)',
                    'Rs. ${unitPrice.toStringAsFixed(2)}',
                    qty.toString(),
                    'Rs. ${amount.toStringAsFixed(2)}',
                  ];
                }).toList(),
              ),

              pw.SizedBox(height: 20),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 200,
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 12)),
                            pw.Text('Rs. ${totalAmount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 12)),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Tax (0%):', style: const pw.TextStyle(fontSize: 12)),
                            pw.Text('Rs. 0.00', style: const pw.TextStyle(fontSize: 12)),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Divider(),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Total:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                            pw.Text('Rs. ${totalAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),
              pw.Divider(),
              pw.Center(
                child: pw.Text('Thank you for your business!', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              )
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Invoice_$invoiceNo.pdf',
    );
  }
}
