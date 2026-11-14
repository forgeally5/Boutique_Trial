import 'package:flutter/material.dart';
import 'qr_pdf_generator.dart';

/// Opens the label printer settings. Call it from a button, for example:
///   IconButton(icon: Icon(Icons.print), onPressed: () => showLabelSettingsDialog(context));
Future<void> showLabelSettingsDialog(BuildContext context) async {
  await QrPdfGenerator.loadConfig();
  final c = LabelRollConfig.fromJson(QrPdfGenerator.config.toJson());
  if (!context.mounted) return;

  double r1(double v) => (v * 10).round() / 10;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          Widget stepper(
            String label,
            double value,
            void Function(double) onSet, {
            double step = 0.5,
            double min = -20,
            double max = 200,
            String unit = 'mm',
          }) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: Text(label)),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => setState(
                      () => onSet(r1((value - step).clamp(min, max).toDouble())),
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text(
                      '${value.toStringAsFixed(1)} $unit',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setState(
                      () => onSet(r1((value + step).clamp(min, max).toDouble())),
                    ),
                  ),
                ],
              ),
            );
          }

          return AlertDialog(
            title: const Text('Label printer settings'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sticker size and roll layout',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    stepper('Sticker width', c.labelWidthMm,
                        (v) => c.labelWidthMm = v, min: 10),
                    stepper('Sticker height', c.labelHeightMm,
                        (v) => c.labelHeightMm = v, min: 10),
                    stepper('Stickers across', c.columns.toDouble(),
                        (v) => c.columns = v.round(),
                        step: 1, min: 1, max: 6, unit: ''),
                    stepper('Gap left-right', c.hGapMm,
                        (v) => c.hGapMm = v, min: 0, max: 10),
                    stepper('Gap top-bottom', c.vGapMm,
                        (v) => c.vGapMm = v, min: 0, max: 10),
                    stepper('Side margin', c.sideMarginMm,
                        (v) => c.sideMarginMm = v, min: 0, max: 10),
                    const Divider(),
                    const Text(
                      'Alignment fix',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        const Expanded(child: Text('Rotation')),
                        DropdownButton<int>(
                          value: (c.rotationQuarterTurns == 2) ? 2 : 0,
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('0° (Normal)')),
                            DropdownMenuItem(value: 2, child: Text('180° (Inverted)')),
                          ],
                          onChanged: (v) =>
                              setState(() => c.rotationQuarterTurns = v ?? 0),
                        ),
                      ],
                    ),
                    stepper('Move right / left (X)', c.offsetXmm,
                        (v) => c.offsetXmm = v, min: -10, max: 10),
                    stepper('Move down / up (Y)', c.offsetYmm,
                        (v) => c.offsetYmm = v, min: -10, max: 10),
                    const Divider(),
                    const Text(
                      'Printing mode',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        const Expanded(child: Text('Mode')),
                        DropdownButton<LabelPrintMode>(
                          value: c.mode,
                          items: const [
                            DropdownMenuItem(
                              value: LabelPrintMode.fillRow,
                              child: Text('Fill whole row'),
                            ),
                            DropdownMenuItem(
                              value: LabelPrintMode.singleColumn,
                              child: Text('One column only'),
                            ),
                          ],
                          onChanged: (v) => setState(
                            () => c.mode = v ?? LabelPrintMode.fillRow,
                          ),
                        ),
                      ],
                    ),
                    if (c.mode == LabelPrintMode.singleColumn)
                      Row(
                        children: [
                          const Expanded(child: Text('Print in column')),
                          DropdownButton<int>(
                            value: c.startColumn.clamp(1, c.columns),
                            items: [
                              for (int i = 1; i <= c.columns; i++)
                                DropdownMenuItem(value: i, child: Text('$i')),
                            ],
                            onChanged: (v) =>
                                setState(() => c.startColumn = v ?? 1),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    final d = LabelRollConfig();
                    c.labelWidthMm = d.labelWidthMm;
                    c.labelHeightMm = d.labelHeightMm;
                    c.columns = d.columns;
                    c.hGapMm = d.hGapMm;
                    c.vGapMm = d.vGapMm;
                    c.sideMarginMm = d.sideMarginMm;
                    c.rotationQuarterTurns = 0;
                    c.offsetXmm = 0;
                    c.offsetYmm = 0;
                    c.startColumn = 1;
                    c.mode = LabelPrintMode.fillRow;
                  });
                },
                child: const Text('Reset Defaults', style: TextStyle(color: Colors.red)),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  await QrPdfGenerator.saveConfig(c);
                  await QrPdfGenerator.printCalibrationTest();
                },
                child: const Text('Save + Test print'),
              ),
              FilledButton(
                onPressed: () async {
                  await QrPdfGenerator.saveConfig(c);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}