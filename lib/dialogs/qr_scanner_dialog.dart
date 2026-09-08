import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/product.dart';

import 'qr_scanner_web_stub.dart'
    if (dart.library.html) 'qr_scanner_web.dart';

/// Opens the platform-compatible Google-Lens styled QR & Barcode Scanner.
/// Returns the extracted Tag ID string upon successful scan or manual fetch.
Future<String?> openQrScanner(BuildContext context) async {
  return await Navigator.of(context).push<String?>(
    MaterialPageRoute(
      builder: (context) => const GoogleLensScannerScreen(),
    ),
  );
}

/// Helper function to parse raw QR string into base Tag ID.
String parseScannedTagId(String? rawInput) {
  if (rawInput == null || rawInput.trim().isEmpty) return '';
  String text = rawInput.trim();
  if (text.startsWith('{') && text.contains('}')) {
    try {
      final map = jsonDecode(text.substring(text.indexOf('{'), text.lastIndexOf('}') + 1));
      if (map['tagId'] != null) return map['tagId'].toString().trim().toUpperCase();
      if (map['baseTag'] != null) return map['baseTag'].toString().trim().toUpperCase();
    } catch (_) {}
  } else if (text.contains('Tag:')) {
    final match = RegExp(r'Tag:\s*([^\r\n]+)').firstMatch(text);
    if (match != null) text = match.group(1)!;
  } else if (text.contains('\n')) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isNotEmpty) {
      String? found;
      for (final line in lines) {
        if (RegExp(r'^[A-Z0-9]+-[A-Z0-9]+').hasMatch(line.toUpperCase())) {
          found = line;
          break;
        }
      }
      text = found ?? lines.first;
    }
  }
  
  // Normalize spacing before brackets, e.g. "24B-1 [1]" -> "24B-1[1]"
  text = text.replaceAll(RegExp(r'\s+\['), '[');
  
  return text.split('-P')[0].split('-p')[0].split('/P')[0].trim().toUpperCase();
}

class GoogleLensScannerScreen extends StatefulWidget {
  const GoogleLensScannerScreen({super.key});

  @override
  State<GoogleLensScannerScreen> createState() => _GoogleLensScannerScreenState();
}

class _GoogleLensScannerScreenState extends State<GoogleLensScannerScreen>
    with SingleTickerProviderStateMixin {
  MobileScannerController? _mobileController;
  AnimationController? _animController;
  final TextEditingController _manualTagController = TextEditingController();

  bool _isProcessing = false;
  bool _isFrontCamera = true;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _mobileController = MobileScannerController(
        autoStart: true,
        facing: CameraFacing.front,
        detectionSpeed: DetectionSpeed.noDuplicates,
        returnImage: false,
      );
    }

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  Future<void> _toggleCameraFacing() async {
    if (!kIsWeb && _mobileController != null) {
      try {
        await _mobileController!.switchCamera();
        setState(() {
          _isFrontCamera = !_isFrontCamera;
        });
      } catch (e) {
        debugPrint('[SCANNER] Switch camera exception: $e');
      }
    }
  }

  @override
  void dispose() {
    _animController?.dispose();
    _manualTagController.dispose();
    _mobileController?.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(String rawValue) {
    if (_isProcessing) return;
    if (rawValue.trim().isNotEmpty) {
      _processTagId(rawValue, isManual: false);
    }
  }

  Future<void> _processTagId(String rawInput, {required bool isManual}) async {
    if (_isProcessing) return;
    final String cleanTag = parseScannedTagId(rawInput);

    if (cleanTag.isEmpty) {
      _showFeedback('Invalid Tag ID or QR Code format', isError: true);
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Searching product for "$cleanTag"...';
    });

    try {
      final doc = await _verifyAndFetchProductDoc(cleanTag);
      if (!mounted) return;

      if (doc != null && doc.exists) {
        _showFeedback('Product Found: $cleanTag', isError: false);
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          Navigator.of(context).pop(cleanTag);
        }
      } else {
        _showFeedback('Product not found for Tag ID "$cleanTag"', isError: true);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _statusMessage = null;
          });
        }
      }
    } catch (e) {
      debugPrint('[SCAN] Error fetching product: $e');
      if (mounted) {
        _showFeedback('Error querying inventory: $e', isError: true);
        setState(() {
          _isProcessing = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _verifyAndFetchProductDoc(String cleanTag) async {
    Future<DocumentSnapshot<Map<String, dynamic>>?> runQuery(String tag) async {
      // 1. Primary lookup by Firestore Document ID
      var doc = await FirebaseFirestore.instance
          .collection('jewelry_inventory')
          .doc(tag)
          .get();
      if (doc.exists && doc.data() != null) return doc;

      // 2. Lookup by tagId field
      final snapTag = await FirebaseFirestore.instance
          .collection('jewelry_inventory')
          .where('tagId', isEqualTo: tag)
          .limit(1)
          .get();
      if (snapTag.docs.isNotEmpty) return snapTag.docs.first;

      // 3. Lookup by barcode field
      final snapBarcode = await FirebaseFirestore.instance
          .collection('jewelry_inventory')
          .where('barcode', isEqualTo: tag)
          .limit(1)
          .get();
      if (snapBarcode.docs.isNotEmpty) return snapBarcode.docs.first;

      // 4. Fallback lowercase doc ID
      doc = await FirebaseFirestore.instance
          .collection('jewelry_inventory')
          .doc(tag.toLowerCase())
          .get();
      if (doc.exists && doc.data() != null) return doc;

      return null;
    }

    // Try with exact cleanTag
    final doc = await runQuery(cleanTag);
    if (doc != null) return doc;

    // Fallback: If it contains brackets, try with base Tag ID
    final baseTag = getBaseTagId(cleanTag);
    if (baseTag != cleanTag) {
      return await runQuery(baseTag);
    }

    return null;
  }

  void _showFeedback(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.deepOrange.shade700 : Colors.green.shade700,
        duration: Duration(seconds: isError ? 3 : 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryBrown = Color(0xFF3E2723);
    final size = MediaQuery.of(context).size;
    final scanBoxSize = (size.width < size.height ? size.width * 0.8 : size.height * 0.5).clamp(260.0, 360.0);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryBrown,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(null),
          tooltip: 'Close Scanner',
        ),
        title: const Text(
          'Scan Tag / Barcode',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.cameraswitch_outlined,
              color: _isFrontCamera ? Colors.amberAccent : Colors.white,
            ),
            onPressed: _toggleCameraFacing,
            tooltip: 'Switch Camera (Front / Back)',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top instruction / status bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              color: const Color(0xFFF5E6D3).withAlpha(153),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _isProcessing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: primaryBrown),
                        )
                      : const Icon(Icons.qr_code_scanner, color: primaryBrown, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _statusMessage ?? 'Align QR Code or Barcode within frame',
                    style: const TextStyle(color: primaryBrown, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            // Main Camera View Container with Google Scanner Overlay
            Expanded(
              child: Center(
                child: Container(
                  width: scanBoxSize,
                  height: scanBoxSize,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 8, spreadRadius: 2),
                    ],
                    border: Border.all(color: primaryBrown.withAlpha(76), width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Camera Stream: Web Native HTML5 camera for Web, MobileScanner for Mobile
                        kIsWeb
                            ? buildWebCameraWidget(
                                onScanned: _onBarcodeDetected,
                              )
                            : MobileScanner(
                                controller: _mobileController,
                                fit: BoxFit.cover,
                                onDetect: (capture) {
                                  for (final barcode in capture.barcodes) {
                                    if (barcode.rawValue != null) {
                                      _onBarcodeDetected(barcode.rawValue!);
                                      break;
                                    }
                                  }
                                },
                              ),

                        // Laser Scan Animated Overlay
                        AnimatedBuilder(
                          animation: _animController!,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: _GoogleScannerOverlayPainter(
                                scanBoxSize: scanBoxSize - 4,
                                animationValue: _animController!.value,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Manual Entry Card
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -2)),
                ],
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.keyboard_outlined, color: primaryBrown, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Manual Code / Tag Entry',
                        style: TextStyle(
                          color: primaryBrown,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          autofocus: true,
                          controller: _manualTagController,
                          style: const TextStyle(color: Colors.black87, fontSize: 14),
                          textCapitalization: TextCapitalization.characters,
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              _processTagId(val.trim(), isManual: true);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'Enter Tag ID or Barcode manually...',
                            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: primaryBrown, width: 1.5),
                            ),
                            suffixIcon: _manualTagController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                                    onPressed: () {
                                      _manualTagController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBrown,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                        ),
                        onPressed: _isProcessing || _manualTagController.text.trim().isEmpty
                            ? null
                            : () => _processTagId(_manualTagController.text.trim(), isManual: true),
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('Fetch', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
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

class _GoogleScannerOverlayPainter extends CustomPainter {
  final double scanBoxSize;
  final double animationValue;

  _GoogleScannerOverlayPainter({
    required this.scanBoxSize,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // 1. Google Lens Corner Reticles (glowing dark brown/gold brackets)
    final cornerPaint = Paint()
      ..color = const Color(0xFF3E2723)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const cornerLength = 24.0;

    // Top-Left
    canvas.drawLine(Offset(rect.left + 4, rect.top + 4), Offset(rect.left + 4, rect.top + 4 + cornerLength), cornerPaint);
    canvas.drawLine(Offset(rect.left + 4, rect.top + 4), Offset(rect.left + 4 + cornerLength, rect.top + 4), cornerPaint);

    // Top-Right
    canvas.drawLine(Offset(rect.right - 4, rect.top + 4), Offset(rect.right - 4, rect.top + 4 + cornerLength), cornerPaint);
    canvas.drawLine(Offset(rect.right - 4, rect.top + 4), Offset(rect.right - 4 - cornerLength, rect.top + 4), cornerPaint);

    // Bottom-Left
    canvas.drawLine(Offset(rect.left + 4, rect.bottom - 4), Offset(rect.left + 4, rect.bottom - 4 - cornerLength), cornerPaint);
    canvas.drawLine(Offset(rect.left + 4, rect.bottom - 4), Offset(rect.left + 4 + cornerLength, rect.bottom - 4), cornerPaint);

    // Bottom-Right
    canvas.drawLine(Offset(rect.right - 4, rect.bottom - 4), Offset(rect.right - 4, rect.bottom - 4 - cornerLength), cornerPaint);
    canvas.drawLine(Offset(rect.right - 4, rect.bottom - 4), Offset(rect.right - 4 - cornerLength, rect.bottom - 4), cornerPaint);

    // 2. Sweeping Laser Scan Line
    final laserY = rect.top + 10 + (animationValue * (rect.height - 20));
    final laserPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF3E2723).withAlpha(0),
          Colors.amber.shade700,
          const Color(0xFF3E2723).withAlpha(0),
        ],
      ).createShader(Rect.fromLTWH(rect.left + 10, laserY, rect.width - 20, 2))
      ..strokeWidth = 2.5;

    canvas.drawLine(
      Offset(rect.left + 10, laserY),
      Offset(rect.right - 10, laserY),
      laserPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleScannerOverlayPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.scanBoxSize != scanBoxSize;
  }
}
