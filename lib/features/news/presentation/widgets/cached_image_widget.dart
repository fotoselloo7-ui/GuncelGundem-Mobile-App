import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Güvenli, önbellekli ve hata korumalı görsel bileşeni
class CachedImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? fallbackWidget;

  const CachedImageWidget({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackWidget,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.zero;

    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildFallback(context, effectiveRadius);
    }

    return ClipRRect(
      borderRadius: effectiveRadius,
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          color: Colors.grey.withAlpha(25),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) =>
            _buildFallback(context, effectiveRadius),
      ),
    );
  }

  Widget _buildFallback(BuildContext context, BorderRadius radius) {
    if (fallbackWidget != null) {
      return ClipRRect(borderRadius: radius, child: fallbackWidget!);
    }

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: width,
        height: height,
        color: Colors.grey.withAlpha(40),
        child: const Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: Colors.grey,
            size: 28,
          ),
        ),
      ),
    );
  }
}
