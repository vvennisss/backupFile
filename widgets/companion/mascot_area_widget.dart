import 'package:flutter/material.dart';
import '../../controllers/trip_controller.dart';

class MascotAreaWidget extends StatefulWidget {
  final MascotState mascotState;
  final String? birdMode;
  final IconData? birdModeIcon;
  final Color? birdModeColor;
  final VoidCallback? onTap;

  const MascotAreaWidget({
    super.key,
    required this.mascotState,
    this.birdMode,
    this.birdModeIcon,
    this.birdModeColor,
    this.onTap,
  });

  @override
  State<MascotAreaWidget> createState() => _MascotAreaWidgetState();
}

class _MascotAreaWidgetState extends State<MascotAreaWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -4, end: 4).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.mascotState;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Floating Bird GIF Area - Framed Portrait Card
            AnimatedBuilder(
              animation: _floatAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _floatAnimation.value),
                  child: child,
                );
              },
              child: Center(
                child: Container(
                  width: 160,
                  height: 160,
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: const Color(0xFFF1F5F9),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: state.moodColor.withValues(alpha: 0.12),
                        blurRadius: 24,
                        spreadRadius: 2,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(
                          scale: CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutBack,
                          ),
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: SizedBox.expand(
                        key: ValueKey<String>(state.assetPath),
                        child: Image.asset(
                          state.assetPath,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              'assets/images/${state.assetPath.split('/').last}',
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              errorBuilder: (context, error2, stackTrace2) {
                                return Container(
                                  decoration: BoxDecoration(
                                    color: state.moodColor.withValues(alpha: 0.15),
                                  ),
                                  child: Icon(
                                    Icons.cruelty_free,
                                    size: 54,
                                    color: state.moodColor,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.birdMode != null && widget.birdMode!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: (widget.birdModeColor ?? const Color(0xFF304FFE)).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (widget.birdModeColor ?? const Color(0xFF304FFE)).withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.birdModeIcon ?? Icons.explore_rounded,
                      size: 14,
                      color: widget.birdModeColor ?? const Color(0xFF304FFE),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      widget.birdMode!,
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: widget.birdModeColor ?? const Color(0xFF304FFE),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

