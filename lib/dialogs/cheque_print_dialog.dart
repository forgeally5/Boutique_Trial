// cheque_print_dialog.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../utils/pdf_invoice_api.dart';

class ChequePrintDialog extends StatefulWidget {
  final String payee;
  final double amount;
  final String date;

  const ChequePrintDialog({
    super.key,
    required this.payee,
    required this.amount,
    required this.date,
  });

  static Future<void> show(
    BuildContext context, {
    required String payee,
    required double amount,
    required String date,
  }) {
    return showDialog(
      context: context,
      builder: (_) => ChequePrintDialog(payee: payee, amount: amount, date: date),
    );
  }

  @override
  State<ChequePrintDialog> createState() => _ChequePrintDialogState();
}

class _ChequePrintDialogState extends State<ChequePrintDialog> {
  late TextEditingController _payeeCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _dateCtrl;
  bool _showPreview = false;

  @override
  void initState() {
    super.initState();
    _payeeCtrl = TextEditingController(text: widget.payee);
    _amountCtrl = TextEditingController(text: widget.amount.toStringAsFixed(2));
    _dateCtrl = TextEditingController(text: widget.date);
  }

  @override
  void dispose() {
    _payeeCtrl.dispose();
    _amountCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<Uint8List> _generateChequePdf() async {
    final pdf = pw.Document();
    final String payeeName = _payeeCtrl.text.trim();
    final double amt = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    final String amtWords = PdfInvoiceApi.numberToWords(amt);
    final String dateStr = _dateCtrl.text.trim();

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(576, 216, marginAll: 18),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 1),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Top Row: Bank name placeholder and Date
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('CHEQUE PRINT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.grey700)),
                    pw.Row(
                      children: [
                        pw.Text('Date: ', style: const pw.TextStyle(fontSize: 10)),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)),
                          child: pw.Text(dateStr, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, letterSpacing: 2)),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                
                // Payee Row
                pw.Row(
                  children: [
                    pw.Text('Pay  ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.only(bottom: 2),
                        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1))),
                        child: pw.Text(' $payeeName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      ),
                    ),
                    pw.Text('  Or Bearer', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                pw.SizedBox(height: 12),

                // Rupees in Words Row
                pw.Row(
                  children: [
                    pw.Text('Rupees  ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.only(bottom: 2),
                        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1))),
                        child: pw.Text(' $amtWords', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),

                // Bottom Row: Amount Box and Signature Placeholder
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    // Amount in numbers box
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.black, width: 1.5),
                        color: PdfColors.grey100,
                      ),
                      child: pw.Text('Rs. ${amt.toStringAsFixed(2)} /-', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    ),
                    // Signature line
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Authorised Signatory', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                        pw.SizedBox(height: 16),
                        pw.Container(width: 140, height: 1, color: PdfColors.black),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    const brown = Color(0xFF3E2723);
    const border = Color(0xFFE5DDD0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: _showPreview ? 700 : 400,
        height: 500,
        child: Column(
          children: [
            // Header
            Container(
              color: brown,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Cheque Print Setup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: _showPreview
                  ? PdfPreview(
                      build: (format) => _generateChequePdf(),
                      canChangePageFormat: false,
                      canChangeOrientation: false,
                      canDebug: false,
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Payee Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: brown)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _payeeCtrl,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: border)),
                            ),
                          ),
                          const SizedBox(height: 18),
                          
                          const Text('Cheque Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: brown)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _dateCtrl,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: border)),
                              suffixIcon: const Icon(Icons.calendar_today, size: 16),
                            ),
                          ),
                          const SizedBox(height: 18),

                          const Text('Amount (Rs.)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: brown)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: border)),
                            ),
                          ),
                          const SizedBox(height: 30),

                          SizedBox(
                            width: double.infinity,
                            height: 40,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: brown,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: () {
                                setState(() {
                                  _showPreview = true;
                                });
                              },
                              child: const Text('Generate Cheque Preview'),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            
            // Footer Action buttons in preview mode
            if (_showPreview)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFFAFAFA),
                  border: Border(top: BorderSide(color: border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showPreview = false;
                        });
                      },
                      child: const Text('Back to Setup', style: TextStyle(color: brown)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brown,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
