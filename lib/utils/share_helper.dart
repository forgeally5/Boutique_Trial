import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'pdf_invoice_api.dart';

Future<String?> uploadPdfToStorage(SalesInvoiceData invoiceData) async {
  try {
    final pdfBytes = await PdfInvoiceApi.generate(invoiceData).timeout(const Duration(seconds: 10));
    final storageRef = FirebaseStorage.instance.ref().child('invoices/${invoiceData.invoiceNo}.pdf');
    final uploadTask = storageRef.putData(pdfBytes, SettableMetadata(contentType: 'application/pdf'));
    final snapshot = await uploadTask.timeout(const Duration(seconds: 15));
    final downloadUrl = await snapshot.ref.getDownloadURL().timeout(const Duration(seconds: 10));
    return downloadUrl;
  } catch (e) {
    debugPrint("Error uploading PDF: $e");
    return null;
  }
}

Future<void> sendInvoiceEmailViaSmtp({
  required String customerName,
  required String recipientEmail,
  required String messageText,
  required String voucherNo,
  required SalesInvoiceData invoiceData,
}) async {
  final configDoc = await FirebaseFirestore.instance
      .collection('settings')
      .doc('email_config')
      .get();

  if (!configDoc.exists) {
    throw Exception("Email SMTP config not found. Please configure it in Settings.");
  }

  final data = configDoc.data()!;
  final username = data['username']?.toString() ?? '';
  final appPassword = data['appPassword']?.toString() ?? '';
  final senderName = data['senderName']?.toString() ?? 'Trilok';

  if (username.isEmpty || appPassword.isEmpty) {
    throw Exception("SMTP username or appPassword is empty in configurations.");
  }

  final pdfBytes = await PdfInvoiceApi.generate(invoiceData);
  final tempDir = Directory.systemTemp;
  final tempFile = File('${tempDir.path}/Invoice_${voucherNo.replaceAll('/', '_')}.pdf');
  await tempFile.writeAsBytes(pdfBytes);

  final smtpServer = gmail(username, appPassword);
  final message = Message()
    ..from = Address(username, senderName)
    ..recipients.add(recipientEmail.trim())
    ..subject = 'Tax Invoice $voucherNo - Trilok Jewellers'
    ..text = messageText
    ..attachments.add(FileAttachment(tempFile));

  await send(message, smtpServer);
}

Future<void> shareInvoiceHelper({
  required BuildContext context,
  required SalesInvoiceData invoiceData,
}) async {
  final String customerName = invoiceData.customerName;
  final String customerMobile = invoiceData.customerMobile;
  final String customerEmail = invoiceData.customerState.contains('@') ? invoiceData.customerState : '';

  final String voucherNo = invoiceData.invoiceNo;
  final double totalAmount = invoiceData.grossAmount;
  final String defaultMsg = "Dear $customerName, thank you for shopping with Trilok. Your invoice $voucherNo for Rs.${totalAmount.toStringAsFixed(2)} is ready. Date: ${invoiceData.date}. Thank you!";

  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: const Color(0xFFFCFAF5),
      title: const Text('Share Invoice', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3E2723), fontFamily: 'serif')),
      content: const Text('Select a medium to share the invoice:', style: TextStyle(color: Color(0xFF5D4037))),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
          label: const Text('WhatsApp', style: TextStyle(color: Color(0xFF3E2723), fontWeight: FontWeight.bold)),
          onPressed: () => Navigator.pop(ctx, 'whatsapp'),
        ),
        TextButton.icon(
          icon: const Icon(Icons.email, color: Color(0xFFD44638)),
          label: const Text('Email', style: TextStyle(color: Color(0xFF3E2723), fontWeight: FontWeight.bold)),
          onPressed: () => Navigator.pop(ctx, 'email'),
        ),
        TextButton(
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          onPressed: () => Navigator.pop(ctx, null),
        ),
      ],
    ),
  );

  if (choice == null) return;
  if (!context.mounted) return;

  if (choice == 'whatsapp') {
    String phone = customerMobile.replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) {
      final inputPhone = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final ctrl = TextEditingController();
          return AlertDialog(
            backgroundColor: const Color(0xFFFCFAF5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text('Enter Mobile Number', style: TextStyle(fontFamily: 'serif', color: Color(0xFF3E2723))),
            content: TextField(
              controller: ctrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: 'e.g. 9876543210',
                labelText: 'Customer Mobile',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      if (inputPhone == null || inputPhone.isEmpty) return;
      phone = inputPhone.replaceAll(RegExp(r'\D'), '');
    }

    if (!context.mounted) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    String finalMessage = defaultMsg;
    String? pdfUrl;
    try {
      pdfUrl = await uploadPdfToStorage(invoiceData);
    } catch (e) {
      debugPrint("Error in WhatsApp share: $e");
      pdfUrl = null;
    } finally {
      if (context.mounted) Navigator.pop(context);
    }

    if (pdfUrl != null) {
      finalMessage += '\n\nDownload Invoice PDF: $pdfUrl';
    }

    final text = Uri.encodeComponent(finalMessage);
    if (!phone.startsWith('91') && phone.length == 10) {
      phone = '91$phone';
    }
    final url = 'https://api.whatsapp.com/send?phone=$phone&text=$text';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch WhatsApp')),
        );
      }
    }
  } else if (choice == 'email') {
    String targetEmail = customerEmail.trim();
    if (targetEmail.isEmpty) {
      if (!context.mounted) return;
      final inputEmail = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final ctrl = TextEditingController();
          return AlertDialog(
            backgroundColor: const Color(0xFFFCFAF5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text('Enter Recipient Email', style: TextStyle(fontFamily: 'serif', color: Color(0xFF3E2723))),
            content: TextField(
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'e.g. customer@gmail.com',
                labelText: 'Customer Email',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: const Text('Send'),
              ),
            ],
          );
        },
      );
      if (inputEmail == null || inputEmail.isEmpty) return;
      targetEmail = inputEmail;
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await sendInvoiceEmailViaSmtp(
        customerName: customerName,
        recipientEmail: targetEmail,
        messageText: defaultMsg,
        voucherNo: voucherNo,
        invoiceData: invoiceData,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Invoice email sent successfully with PDF attachment!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Error sending invoice email: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed to send email: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (context.mounted) Navigator.pop(context);
    }
  }
}
