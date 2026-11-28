import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_brand.dart';
import 'folio_assembly_mark.dart';

/// Vector Folio mark, optionally presented as the rounded app tile.
class KiloClaimBrandMark extends StatelessWidget {
  final double size;
  final bool tile;

  const KiloClaimBrandMark({super.key, this.size = 44, this.tile = false});

  @override
  Widget build(BuildContext context) {
    final mark = SvgPicture.asset(
      tile ? AppBrand.iconAsset : AppBrand.markAsset,
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
    return Semantics(
      label: 'KiloClaim',
      image: true,
      child: tile
          ? ClipRRect(
              borderRadius: BorderRadius.circular(size * 0.24), child: mark)
          : mark,
    );
  }
}

/// Shared wordmark for welcome, account entry and product navigation.
class KiloClaimBrandLockup extends StatelessWidget {
  final bool compact;
  final Animation<double>? markProgress;

  const KiloClaimBrandLockup({
    super.key,
    this.compact = false,
    this.markProgress,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'KiloClaim',
        image: true,
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (markProgress case final progress?)
                FolioAssemblyMark(
                  progress: progress,
                  size: compact ? 32 : 44,
                )
              else
                KiloClaimBrandMark(size: compact ? 32 : 44),
              SizedBox(width: compact ? 8 : 12),
              Flexible(
                child: Text(
                  'KiloClaim',
                  style: compact ? AppBrand.wordmarkCompact : AppBrand.wordmark,
                ),
              ),
            ],
          ),
        ),
      );
}
