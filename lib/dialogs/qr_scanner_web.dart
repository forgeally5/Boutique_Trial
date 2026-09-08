// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use, undefined_function, undefined_method, unused_import
import 'dart:convert';
import 'dart:js' as js;
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;
import 'package:flutter/material.dart';

Widget buildWebCameraWidget({required Function(String) onScanned}) {
  return WebCameraScannerWidget(onScanned: onScanned);
}

class WebCameraScannerWidget extends StatefulWidget {
  final Function(String) onScanned;
  const WebCameraScannerWidget({super.key, required this.onScanned});

  @override
  State<WebCameraScannerWidget> createState() => _WebCameraScannerWidgetState();
}

class _WebCameraScannerWidgetState extends State<WebCameraScannerWidget> {
  final String _viewId = 'web-camera-view-${DateTime.now().millisecondsSinceEpoch}';
  html.VideoElement? _videoElement;
  html.MediaStream? _mediaStream;
  js.JsObject? _scannerHandle;
  bool _hasError = false;
  String _errorMessage = '';



  @override
  void initState() {
    super.initState();
    _initWebCamera();
  }

  Future<void> _initWebCamera() async {
    try {
      // Inject JS helper to handle camera and QR/barcode scanning loop natively
      final scriptElement = html.ScriptElement()
        ..text = '''
        window.initQrScanner = function(videoEl, onResultCallback, onDiagnosticCallback) {
          if (window.currentQrScanner) {
            try {
              window.currentQrScanner.stop();
            } catch (e) {
              console.log("[QR] Error stopping previous scanner:", e);
            }
          }
          let active = true;
          let framesProcessed = 0;
          let detector = null;
          let zxingReader = null;
          let lastResult = "";
          let canvas = null;
          let ctx = null;
          let fatalScannerError = false;
          
          function getAllMethods(obj) {
            let props = new Set();
            let currentObj = obj;
            while (currentObj && currentObj !== Object.prototype) {
              Object.getOwnPropertyNames(currentObj).forEach(item => {
                if (typeof obj[item] === 'function') {
                  props.add(item);
                }
              });
              currentObj = Object.getPrototypeOf(currentObj);
            }
            return Array.from(props);
          }
          
          console.log("[QR] initQrScanner called");
          
          // Try native BarcodeDetector API first (hardware-accelerated, modern browsers)
          if (typeof window.BarcodeDetector !== 'undefined') {
            try {
              detector = new window.BarcodeDetector({ formats: ['qr_code'] });
              console.log("[QR] Native BarcodeDetector initialized");
            } catch (e) {
              console.log("[QR] Native BarcodeDetector init failed:", e);
            }
          }
          
          // Try ZXing as fallback
          if (typeof window.ZXing !== 'undefined') {
            try {
              zxingReader = new window.ZXing.BrowserMultiFormatReader();
              console.log("[QR] ZXing Fallback Reader initialized");
              console.log("[QR] ZXing BrowserMultiFormatReader available methods:", getAllMethods(zxingReader));
            } catch (e) {
              console.log("[QR] ZXing initialization failed:", e);
            }
          }
          
          function updateDiagnostic(statusMessage, errorDetail) {
            if (onDiagnosticCallback) {
              onDiagnosticCallback(JSON.stringify({
                camera: (videoEl.srcObject && videoEl.srcObject.active) ? "ACTIVE" : "INACTIVE",
                videoReady: (videoEl.readyState >= 2 && videoEl.videoWidth > 0) ? "YES" : "NO",
                resolution: videoEl.videoWidth + " x " + videoEl.videoHeight,
                frames: framesProcessed,
                barcodeDetectorAvailable: (typeof window.BarcodeDetector !== 'undefined') ? "YES" : "NO",
                decoder: detector ? "BarcodeDetector" : (zxingReader ? "ZXing Fallback" : "None"),
                canvasCreated: canvas ? "YES" : "NO",
                canvasContext: ctx ? "YES" : "NO",
                lastError: errorDetail || "None",
                lastResult: lastResult,
                status: statusMessage || "Analyzing..."
              }));
            }
          }

          function scanFrame() {
            if (!active || fatalScannerError) return;
            
            if (videoEl.readyState >= 2 && videoEl.videoWidth > 0 && videoEl.videoHeight > 0) {
              framesProcessed++;
              
              if (detector) {
                // STEP 3 - Direct detection on HTMLVideoElement when BarcodeDetector is available
                detector.detect(videoEl)
                  .then(barcodes => {
                    if (barcodes.length > 0) {
                      const text = barcodes[0].rawValue || barcodes[0].displayValue;
                      if (text) {
                        lastResult = text;
                        onResultCallback(text);
                        updateDiagnostic("QR DETECTED!");
                      }
                    } else {
                      updateDiagnostic("Scanning...");
                    }
                    requestAnimationFrame(scanFrame);
                  })
                  .catch(err => {
                    console.error("[QR SCANNER] BarcodeDetector Error:", err);
                    updateDiagnostic("Scanning...", err.toString());
                    requestAnimationFrame(scanFrame);
                  });
              } else if (zxingReader) {
                // STEP 2 - Canvas Frame Capture
                try {
                  if (!canvas) {
                    canvas = document.createElement('canvas');
                  }
                  canvas.width = videoEl.videoWidth;
                  canvas.height = videoEl.videoHeight;
                  ctx = canvas.getContext('2d');
                  if (!ctx) {
                    throw new Error("Failed to get 2D context from canvas");
                  }
                  ctx.drawImage(videoEl, 0, 0, canvas.width, canvas.height);
                } catch (canvasErr) {
                  console.error("[QR SCANNER] Canvas Capture Error:", canvasErr);
                  updateDiagnostic("Canvas Error", canvasErr.toString());
                  setTimeout(scanFrame, 200);
                  return;
                }

                  // STEP 4 - ZXing Fallback execution
                  try {
                    let zxingNamespace = (typeof window.ZXing !== 'undefined') ? window.ZXing : (typeof ZXing !== 'undefined' ? ZXing : null);
                    let resultPromise = null;
                    
                    if (typeof zxingReader.decode === 'function') {
                      try {
                        // Strategy A: Direct decode on videoEl (natively supported by BrowserCodeReader)
                        const res = zxingReader.decode(videoEl);
                        resultPromise = Promise.resolve(res);
                      } catch (decodeErr) {
                        const errStr = decodeErr ? (decodeErr.toString() || "") : "";
                        const isNotFound = errStr.includes("NotFoundException") || decodeErr.name === "NotFoundException" || (decodeErr.constructor && decodeErr.constructor.name === "NotFoundException");
                        
                        if (isNotFound) {
                          resultPromise = Promise.reject(decodeErr);
                        } else {
                          // Strategy B: Fallback to canvas creation binarizers if direct decode fails with TypeError
                          if (typeof zxingReader.decodeFromCanvas === 'function') {
                            resultPromise = zxingReader.decodeFromCanvas(canvas);
                          } else if (typeof zxingReader.createBinaryBitmapFromCanvas === 'function') {
                            try {
                              const bitmap = zxingReader.createBinaryBitmapFromCanvas(canvas);
                              const res = zxingReader.decodeBitmap(bitmap);
                              resultPromise = Promise.resolve(res);
                            } catch (bitmapErr) {
                              resultPromise = Promise.reject(bitmapErr);
                            }
                          } else if (typeof zxingReader.decodeBitmap === 'function' && zxingNamespace !== null) {
                            try {
                              let luminanceSource;
                              if (typeof zxingNamespace.HTMLCanvasElementLuminanceSource !== 'undefined') {
                                luminanceSource = new zxingNamespace.HTMLCanvasElementLuminanceSource(canvas);
                              } else if (typeof zxingNamespace.RGBLuminanceSource !== 'undefined') {
                                const imgData = ctx.getImageData(0, 0, canvas.width, canvas.height);
                                luminanceSource = new zxingNamespace.RGBLuminanceSource(imgData.data, canvas.width, canvas.height);
                              } else {
                                throw new Error("No LuminanceSource class found in ZXing namespace");
                              }
                              const binarizer = new zxingNamespace.HybridBinarizer(luminanceSource);
                              const bitmap = new zxingNamespace.BinaryBitmap(binarizer);
                              const res = zxingReader.decodeBitmap(bitmap);
                              resultPromise = Promise.resolve(res);
                            } catch (bitmapErr) {
                              resultPromise = Promise.reject(bitmapErr);
                            }
                          } else {
                            resultPromise = Promise.reject(decodeErr);
                          }
                        }
                      }
                    } else if (typeof zxingReader.decodeFromCanvas === 'function') {
                      resultPromise = zxingReader.decodeFromCanvas(canvas);
                    } else if (typeof zxingReader.createBinaryBitmapFromCanvas === 'function') {
                      try {
                        const bitmap = zxingReader.createBinaryBitmapFromCanvas(canvas);
                        const res = zxingReader.decodeBitmap(bitmap);
                        resultPromise = Promise.resolve(res);
                      } catch (bitmapErr) {
                        resultPromise = Promise.reject(bitmapErr);
                      }
                    } else {
                      let allMethods = getAllMethods(zxingReader);
                      throw new Error("No decode method found. Available methods on instance: " + allMethods.join(", "));
                    }
 
                    resultPromise
                      .then(result => {
                        if (result) {
                          const text = typeof result.getText === 'function' ? result.getText() : (result.text || "");
                          if (text) {
                            lastResult = text;
                            onResultCallback(text);
                            updateDiagnostic("QR DETECTED!");
                          }
                        } else {
                          updateDiagnostic("Scanning...");
                        }
                        setTimeout(scanFrame, 100);
                      })
                      .catch(err => {
                        // STEP 5 - Prevent normal NotFoundException from becoming a Canvas Error
                        const errStr = err.toString() || "";
                        const isRealError = (err instanceof TypeError) || (err instanceof ReferenceError) || (err instanceof RangeError) || errStr.includes("TypeError") || errStr.includes("ReferenceError") || errStr.includes("LuminanceSource");
                        if (isRealError) {
                          console.error('[QR SCANNER] ZXing Decode Error: ' + (err.stack || err.message || errStr));
                        }
                        updateDiagnostic("Scanning...");
                        setTimeout(scanFrame, 100);
                      });
                  } catch (decodeErr) {
                    if (!fatalScannerError) {
                      fatalScannerError = true;
                      const errMsg = decodeErr ? (decodeErr.stack || decodeErr.message || decodeErr.toString()) : "Unknown Invocation Error";
                      console.error('[QR SCANNER] ZXing Invocation Error: ' + errMsg);
                      if (decodeErr) {
                        console.error('[QR SCANNER] Error name:', decodeErr.name);
                        console.error('[QR SCANNER] Error message:', decodeErr.message);
                        console.error('[QR SCANNER] Error stack:', decodeErr.stack);
                      }
                    }
                    updateDiagnostic("Canvas Error", decodeErr ? decodeErr.toString() : "Unknown Invocation Error");
                    return;
                  }
              } else {
                updateDiagnostic("Scanning...", "No decoder library loaded");
                requestAnimationFrame(scanFrame);
              }
            } else {
              updateDiagnostic("Waiting for camera...");
              requestAnimationFrame(scanFrame);
            }
          }

          requestAnimationFrame(scanFrame);
          
          window.currentQrScanner = {
            stop: function() {
              active = false;
              console.log("[QR] initQrScanner stopped");
            }
          };
          return window.currentQrScanner;
        };
        ''';
      html.document.head!.append(scriptElement);

      // Create video element
      _videoElement = html.VideoElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true');

      // Register platform view for HTML5 video element
      ui_web.platformViewRegistry.registerViewFactory(
        _viewId,
        (int viewId) => _videoElement!,
      );

      // Request webcam media stream directly
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        throw Exception('Navigator.mediaDevices is blocked or unsupported');
      }

      final constraints = {
        'audio': false,
        'video': {
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
          'facingMode': 'environment'
        }
      };

      _mediaStream = await mediaDevices.getUserMedia(constraints);
      _videoElement!.srcObject = _mediaStream;
      await _videoElement!.play();
      debugPrint('[QR] Camera stream started and playing');

      // Bind scanner loop once mounted
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startScannerLoop();
      });

    } catch (e) {
      debugPrint('[WEB SCANNER] Setup error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _startScannerLoop() {
    try {
      if (js.context.hasProperty('initQrScanner')) {
        final resultCallback = js.allowInterop((String rawText) {
          if (rawText.trim().isNotEmpty) {
            widget.onScanned(rawText);
          }
        });

        final diagnosticCallback = js.allowInterop((String jsonStr) {
          // Send diagnostics only to console logs, keeping UI completely clean
          debugPrint('[QR DIAGNOSTIC] $jsonStr');
        });

        _scannerHandle = js.JsObject(js.context['initQrScanner'] as js.JsFunction, [
          js.JsObject.fromBrowserObject(_videoElement!),
          resultCallback,
          diagnosticCallback
        ]);
        debugPrint('[QR] initQrScanner helper loop registered');
      } else {
        debugPrint('[QR] initQrScanner JS helper not ready. Retrying in 100ms...');
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _startScannerLoop();
          }
        });
      }
    } catch (e) {
      debugPrint('[QR] Scanner loop initialization error: $e');
    }
  }

  @override
  void dispose() {
    try {
      if (_scannerHandle != null) {
        _scannerHandle!.callMethod('stop');
      }
      if (_mediaStream != null) {
        for (final track in _mediaStream!.getTracks()) {
          track.stop();
        }
      }
      if (_videoElement != null) {
        _videoElement!.srcObject = null;
      }
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.white,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_outlined, color: Color(0xFF3E2723), size: 48),
            const SizedBox(height: 12),
            const Text(
              'Camera Access Blocked or Unavailable',
              style: TextStyle(color: Color(0xFF3E2723), fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Please allow camera permissions in browser or enter Tag ID manually below.\n($_errorMessage)',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black87, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return HtmlElementView(viewType: _viewId);
  }
}
