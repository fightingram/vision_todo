import 'package:flutter/material.dart';

/// Minimal design tokens based on design-system.md (v1)
class DT {
  // Colors
  static const brandPrimary = Color(0xFF2B6BE4);
  static const brandPrimaryHover = Color(0xFF255CC5);
  static const brandPrimaryPressed = Color(0xFF1F4EA5);

  static const bgBase = Color(0xFFF2EBDD);
  static const bgSurface = Color(0xFFFFFFFF);
  static const bgTint = Color(0xFFF8F5EE);

  static const textPrimary = Color(0xFF15171A);
  static const textSecondary = Color(0xFF5E6672);
  static const textInverse = Color(0xFFFFFFFF);
  static const textLink = brandPrimary;

  static const borderSubtle = Color(0xFFE6E2D8);
  static const borderStrong = Color(0xFFC9C2B3);
  static const borderFocus = brandPrimary;

  static const stateSuccess = Color(0xFF3CB371);
  static const stateWarning = Color(0xFFE8A13A);
  static const stateDanger = Color(0xFFE25555);

  // Goal gradients
  static const goalTeal = [Color(0xFF5AC2B9), Color(0xFF3E9E95)];
  static const goalIndigo = [Color(0xFF6C6BD7), Color(0xFF4C49B8)];
  static const goalAmber = [Color(0xFFF4C76A), Color(0xFFE6A94C)];
  static const goalSalmon = [Color(0xFFF19A86), Color(0xFFE3766A)];

  // Radius
  static const radiusM = 12.0;
  static const radiusL = 16.0;
  static const radiusXL = 20.0;

  // Spacing (4pt base)
  static const spaceXS = 4.0;
  static const spaceS = 8.0;
  static const spaceM = 12.0;
  static const spaceMD = 16.0;
  static const spaceLG = 20.0;
  static const spaceXL = 24.0;
  static const spaceXXL = 32.0;
}
