import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Where the traffic comes out while connected: the country's flag as a soft
/// background, the country and city, and the IP — masked ("203.0.*.*")
/// until tapped. Hidden when not connected or turned off in the settings.
class ExitCard extends StatelessWidget {
  const ExitCard(this.st, {super.key, this.big = false});

  final AppState st;

  /// Larger text for the simple home screen.
  final bool big;

  static bool visible(AppState st) => st.status == LinkStatus.connected && st.settings.showExitInfo;

  @override
  Widget build(BuildContext context) {
    if (!visible(st)) return const SizedBox.shrink();
    final s = S.of(context);
    final p = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final info = st.exit;
    final code = info?.countryCode;
    final hasFlag = code != null && FlagCode.fromCountryCode(code) != null;

    final Widget body;
    if (info == null) {
      body = Row(children: [
        if (st.exitLoading)
          const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
        else
          Icon(Icons.public_off_outlined, size: 18, color: p.muted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(st.exitLoading ? s.exitLocating : s.exitUnknown, style: TextStyle(fontSize: 14, color: p.muted)),
        ),
        if (!st.exitLoading) _refresh(s),
      ]);
    } else {
      final place = info.place;
      body = Row(children: [
        if (hasFlag)
          CountryFlag.fromCountryCode(
            code,
            theme: ImageTheme(width: big ? 40 : 30, height: big ? 30 : 22, shape: const RoundedRectangle(4)),
          )
        else
          Icon(Icons.public, size: big ? 30 : 22),
        SizedBox(width: big ? 14 : 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(
              place.isEmpty ? s.exitUnknownPlace : place,
              style: TextStyle(fontSize: big ? 18 : 15, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: st.toggleExitReveal,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    st.exitRevealed ? info.ip : info.masked,
                    style: TextStyle(fontSize: big ? 14 : 13, fontFamily: 'monospace', color: p.muted),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: st.exitRevealed ? s.hideIp : s.showIp,
                    child: Icon(st.exitRevealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 16, color: p.muted),
                  ),
                ]),
              ),
            ),
          ]),
        ),
        if (st.exitLoading)
          const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          _refresh(s),
      ]);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(children: [
        Positioned.fill(child: ColoredBox(color: p.panel)),
        // The whole flag on the right, fading into the card towards the text.
        if (hasFlag)
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: Opacity(
              opacity: dark ? 0.40 : 0.50,
              child: ShaderMask(
                // Transparent on the left edge, full on the right: no hard edge next to the text.
                blendMode: BlendMode.dstIn,
                shaderCallback: (r) => const LinearGradient(
                  colors: [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
                  stops: [0.0, 0.7],
                ).createShader(r),
                child: AspectRatio(
                  aspectRatio: 2.4,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: CountryFlag.fromCountryCode(code, theme: const ImageTheme(width: 300, height: 200)),
                  ),
                ),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(big ? 16 : 12, big ? 14 : 10, 4, big ? 14 : 10),
          child: body,
        ),
      ]),
    );
  }

  Widget _refresh(S s) => IconButton(
        tooltip: s.refresh,
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.refresh, size: 18),
        onPressed: st.refreshExit,
      );
}
