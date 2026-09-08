import sys

file_path = r"c:\Users\nila0\Desktop\FA\trial\lib\views\home_view.dart"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

target = """                                  _isEditing = !_isEditing;
        onTap: widget.isEditing ? null : widget.onTap,"""

replacement = """                                  _isEditing = !_isEditing;
                                });
                              },
                              icon: Icon(
                                _isEditing ? Icons.check_rounded : Icons.edit_note_rounded,
                                size: 22,
                                color: _isEditing ? const Color(0xFF2E7D32) : const Color(0xFF8D6E63),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Windows-like Grid layout
                      Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        children: [
                          ..._shortcuts.map((s) => _ShortcutCard(
                                shortcut: s,
                                isEditing: _isEditing,
                                onTap: () => _launchShortcut(s),
                                onDelete: () => _deleteShortcut(s),
                              )),
                          
                          // Dotted Add Shortcut placeholder card (only visible in edit mode)
                          if (_isEditing)
                            InkWell(
                              onTap: _showAddShortcutDialog,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: 110,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
                                ),
                                child: const Center(
                                  child: Icon(Icons.add, size: 32),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ShortcutCard extends StatefulWidget {
  final ShortcutItem shortcut;
  final bool isEditing;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ShortcutCard({
    super.key,
    required this.shortcut,
    required this.isEditing,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_ShortcutCard> createState() => _ShortcutCardState();
}

class _ShortcutCardState extends State<_ShortcutCard> {
  bool _isHovered = false;
  final Color _border = const Color(0xFFE0E0E0); // Added to avoid missing variables

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onDoubleTap: widget.isEditing ? null : widget.onTap,
        onTap: widget.isEditing ? null : widget.onTap,"""

if target in content:
    content = content.replace(target, replacement)
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)
    print("Fixed successfully")
else:
    print("Target not found. Current target area:")
    idx = content.find("_isEditing = !_isEditing;")
    if idx != -1:
        print(content[idx-50:idx+200])
