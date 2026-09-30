import 'package:flutter/material.dart';
import '../utils/boutique_theme.dart';

class ReportExportDialog {
  static Future<void> show({
    required BuildContext context,
    required String title,
    required Future<void> Function() onDownloadPdf,
    required Future<void> Function() onDownloadExcel,
  }) async {
    showDialog(
      context: context,
      builder: (ctx) {
        bool isDownloading = false;
        String? downloadingFormat;

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: Colors.white,
              child: Container(
                width: 440,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: BoutiqueColors.accentSoft,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.download_rounded,
                                color: BoutiqueColors.accent,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Download Report',
                                  style: TextStyle(
                                    fontFamily: 'serif',
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: BoutiqueColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: BoutiqueColors.textSecondary,
                          ),
                          onPressed: isDownloading
                              ? null
                              : () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(color: BoutiqueColors.borderLight),
                    const SizedBox(height: 12),
                    const Text(
                      'Select Download Format:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: BoutiqueColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Option 1: Excel
                    InkWell(
                      onTap: isDownloading
                          ? null
                          : () async {
                              setDialogState(() {
                                isDownloading = true;
                                downloadingFormat = 'Excel';
                              });
                              try {
                                Navigator.pop(ctx);
                                await onDownloadExcel();
                              } catch (e) {
                                if (context.mounted) {
                                  BoutiqueToast.showError(
                                    context,
                                    'Failed to generate Excel: $e',
                                  );
                                }
                              }
                            },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF15803D),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.table_chart_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Microsoft Excel',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Color(0xFF15803D),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        '.XLSX',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: Color(0xFF166534),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Download spreadsheet data for Excel / Sheets analysis',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF166534),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: Color(0xFF15803D),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Option 2: PDF
                    InkWell(
                      onTap: isDownloading
                          ? null
                          : () async {
                              setDialogState(() {
                                isDownloading = true;
                                downloadingFormat = 'PDF';
                              });
                              try {
                                Navigator.pop(ctx);
                                await onDownloadPdf();
                              } catch (e) {
                                if (context.mounted) {
                                  BoutiqueToast.showError(
                                    context,
                                    'Failed to generate PDF: $e',
                                  );
                                }
                              }
                            },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFB91C1C),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.picture_as_pdf_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'PDF Document',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Color(0xFFB91C1C),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        '.PDF',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: Color(0xFF991B1B),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Download clean, printable document layout',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF991B1B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: Color(0xFFB91C1C),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (isDownloading)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: BoutiqueColors.accent,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Generating $downloadingFormat report...',
                              style: const TextStyle(
                                fontSize: 12,
                                color: BoutiqueColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
