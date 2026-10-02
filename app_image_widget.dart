import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme.dart';


/// AppImageWidget
/// A robust, universally compatible image rendering widget for Kia Kia Penang.
/// Seamlessly renders:
/// 1. Base64 Data URI strings (e.g. `data:image/jpeg;base64,...`)
/// 2. Raw Base64 encoded strings
/// 3. Google imgres redirect links (extracts real image target)
/// 4. Direct HTTP / HTTPS URLs
/// 5. Local Flutter asset paths (e.g. `assets/...`)
/// 6. Graceful, elegant placeholders when images fail or are empty.
class AppImageWidget extends StatefulWidget {
  final String? imagePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Color? placeholderBg;
  final IconData? placeholderIcon;
  final double? iconSize;

  const AppImageWidget({
    Key? key,
    required this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.placeholderBg,
    this.placeholderIcon,
    this.iconSize,
  }) : super(key: key);

  /// Helper to extract real image URL from Google imgres links if present
  static String extractRealUrl(String raw) {
    if (raw.contains('google.com/imgres')) {
      try {
        final uri = Uri.parse(raw);
        final real = uri.queryParameters['imgurl'];
        if (real != null && real.isNotEmpty) {
          return real;
        }
      } catch (_) {}
    }
    return raw;
  }

  /// Helper to check if a string is a base64 image
  static bool isBase64(String? str) {
    if (str == null || str.isEmpty) return false;
    final trimmed = str.trim();
    if (trimmed.startsWith('data:image/') || trimmed.startsWith('data:application/')) {
      return true;
    }
    // High probability of raw base64 string
    if (trimmed.length > 200 && !trimmed.startsWith('http') && !trimmed.startsWith('/') && !trimmed.startsWith('assets/')) {
      return true;
    }
    return false;
  }

  @override
  State<AppImageWidget> createState() => _AppImageWidgetState();
}

class _AppImageWidgetState extends State<AppImageWidget> {
  // In-memory static cache for decoded base64 Uint8Lists to avoid repeated CPU decodes
  static final Map<int, Uint8List> _base64Cache = {};

  Uint8List? _decodedBytes;
  bool _isBase64 = false;
  String _effectiveUrl = '';

  @override
  void initState() {
    super.initState();
    _processInput();
  }

  @override
  void didUpdateWidget(covariant AppImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _processInput();
    }
  }

  void _processInput() {
    final raw = widget.imagePath?.trim() ?? '';
    _isBase64 = false;
    _decodedBytes = null;
    _effectiveUrl = '';

    if (raw.isEmpty || raw == 'no_image_found') {
      return;
    }

    if (AppImageWidget.isBase64(raw)) {
      _isBase64 = true;
      final cacheKey = raw.hashCode;
      if (_base64Cache.containsKey(cacheKey)) {
        _decodedBytes = _base64Cache[cacheKey];
        return;
      }

      try {
        String clean = raw;
        if (clean.contains('base64,')) {
          clean = clean.split('base64,').last;
        } else if (clean.startsWith('data:') && clean.contains(',')) {
          clean = clean.split(',').last;
        }
        // Remove possible newlines/whitespace
        clean = clean.replaceAll(RegExp(r'\s+'), '');
        final bytes = base64Decode(clean);
        _decodedBytes = bytes;
        if (_base64Cache.length < 200) {
          _base64Cache[cacheKey] = bytes;
        }
      } catch (e) {
        _decodedBytes = null;
      }
    } else {
      _effectiveUrl = AppImageWidget.extractRealUrl(raw);
    }
  }

  Widget _buildPlaceholder() {
    if (widget.placeholder != null) return widget.placeholder!;
    return Container(
      width: widget.width,
      height: widget.height,
      color: widget.placeholderBg ?? AppColors.accentMintTeal.withOpacity(0.35),
      child: Center(
        child: Icon(
          widget.placeholderIcon ?? Icons.image,
          size: widget.iconSize ?? 36,
          color: AppColors.grey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_isBase64) {
      if (_decodedBytes != null) {
        content = Image.memory(
          _decodedBytes!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) =>
              widget.errorWidget ?? _buildPlaceholder(),
        );
      } else {
        content = widget.errorWidget ?? _buildPlaceholder();
      }
    } else if (_effectiveUrl.startsWith('http://') || _effectiveUrl.startsWith('https://')) {
      content = Image.network(
        _effectiveUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholder();
        },
        errorBuilder: (context, error, stackTrace) =>
            widget.errorWidget ?? _buildPlaceholder(),
      );
    } else if (_effectiveUrl.startsWith('assets/')) {
      content = Image.asset(
        _effectiveUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) =>
            widget.errorWidget ?? _buildPlaceholder(),
      );
    } else {
      content = _buildPlaceholder();
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: content,
      );
    }

    return content;
  }
}
