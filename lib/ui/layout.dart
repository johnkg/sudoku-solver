import 'package:flutter/widgets.dart';

/// Screens at least this wide put the board and its panel side by side.
const wideLayoutMinWidth = 840.0;

/// A screen this much wider than it is tall (a phone held sideways) also
/// goes side by side.
const landscapeAspectRatio = 1.2;

/// Whether a screen of [constraints] should show the board beside its panel
/// rather than above it.
bool useSideBySide(BoxConstraints constraints) =>
    constraints.maxWidth >= wideLayoutMinWidth ||
    constraints.maxWidth > constraints.maxHeight * landscapeAspectRatio;

/// How the width is shared between the board and the panel beside it.
const boardFlex = 3;
const panelFlex = 2;

/// Widest a list of cards or text grows; wider screens centre it.
const contentMaxWidth = 640.0;

/// Widest a screen built around a board grows.
const boardScreenMaxWidth = 560.0;

/// Room kept above and below a board that fills the height beside a panel.
const boardVerticalMargin = 32.0;

/// Smallest height of a tappable key, from the Material touch-target size.
const minTapHeight = 48.0;

/// Height of the main buttons on a screen.
const largeButtonHeight = 52.0;

/// Digit size on the number keys.
const keypadFontSize = 20.0;

/// Corner rounding of cards and of keys.
const cardRadius = 16.0;
const keyRadius = 12.0;

/// Corner rounding of the filled buttons, a little rounder than the keys.
const buttonRadius = keyRadius + 2;

/// Opacity of controls and digits that cannot be used right now, from the
/// Material guidelines.
const disabledOpacity = 0.38;

/// Opacity of a digit on the number pad once all of it is placed.
const usedUpOpacity = 0.2;

/// The spacing scale used for padding and gaps between widgets.
abstract final class Space {
  static const double hair = 2;
  static const double xs = 4;
  static const double tight = 6;
  static const double sm = 8;
  static const double snug = 10;
  static const double md = 12;
  static const double lg = 16;
  static const double roomy = 20;
  static const double xl = 24;
  static const double wide = 28;
  static const double xxl = 32;
}

/// Icon and indicator sizes.
const iconSmall = 18.0;
const iconMedium = 28.0;
const iconHero = 64.0;
const avatarRadius = 18.0;
const progressRingSize = 48.0;
const progressRingStroke = 5.0;
const weekDotSize = 20.0;
const spinnerSize = 28.0;
const spinnerStroke = 3.0;

/// Small radii and widths for bars, badges and outlines.
const barRadius = 4.0;
const badgeRadius = 8.0;
const badgeFontSize = 9.0;
const todayRingWidth = 2.0;
const scoreColumnWidth = 56.0;
