/// Computation of ulp (unit in last position).
///
/// Ported from https://stackoverflow.com/a/24129944/14637

import 'dart:typed_data';

const _MAX_ULP = 1.9958403095347198E292;

/// Returns the size of an ulp of the argument. An ulp of a double value is the
/// positive distance between this / floating-point value and the double value
/// next larger in magnitude. Note that for non-NaN x, `ulp(-x) == ulp(x)`.
///
/// Special Cases:
///
/// - If the argument is `double.nan`, then the result is `double.nan`.
/// - If the argument is positive or negative infinity, then the result is positive infinity.
/// - If the argument is positive or negative zero, then the result is `double.minPositive`.
/// - If the argument is ±double.maxFinite, then the result is equal to 2^971.
double ulp(double d) {
  if (d.isNaN) {
    // If the argument is NaN, then the result is NaN.
    return double.nan;
  }

  if (d.isInfinite) {
    // If the argument is positive or negative infinity, then the
    // result is positive infinity.
    return double.infinity;
  }

  if (d == 0.0) {
    // If the argument is positive or negative zero, then the result is Double.MIN_VALUE.
    return double.minPositive;
  }

  d = d.abs();
  if (d == double.maxFinite) {
    // If the argument is Double.MAX_VALUE, then the result is equal to 2^971.
    return _MAX_ULP;
  }

  return nextAfter(d, double.maxFinite) - d;
}

double copySign(double x, double y) {
  return bitsToDouble((doubleToBits(x) & 0x7fffffffffffffff) | (doubleToBits(y) & 0x8000000000000000));
}

bool isSameSign(double x, double y) {
  return copySign(x, y) == x;
}

double nextAfter(double start, double direction) {
  if (start.isNaN || direction.isNaN) {
    // If either argument is a NaN, then NaN is returned.
    return double.nan;
  }

  if (start == direction) {
    // If both arguments compare as equal the second argument is returned.
    return direction;
  }

  final absStart = start.abs();
  final absDir = direction.abs();
  final toZero = !isSameSign(start, direction) || absDir < absStart;

  if (toZero) {
    // we are reducing the magnitude, going toward zero.
    if (absStart == double.minPositive) {
      return copySign(0.0, start);
    }
    if (absStart.isInfinite) {
      return copySign(double.maxFinite, start);
    }
    return copySign(bitsToDouble(doubleToBits(absStart) - 1), start);
  } else {
    // we are increasing the magnitude, toward +-Infinity
    if (start == 0.0) {
      return copySign(double.minPositive, direction);
    }
    if (absStart == double.maxFinite) {
      return copySign(double.infinity, start);
    }
    return copySign(bitsToDouble(doubleToBits(absStart) + 1), start);
  }
}

/// Equivalent of Java's `Double.doubleToRawLongBits(x)`.
int doubleToBits(double x) {
  return Float64List.fromList([x]).buffer.asInt64List()[0];
}

/// Equivalent of Java's `Double.longBitsToDouble(bits)`.
double bitsToDouble(int bits) {
  return Int64List.fromList([bits]).buffer.asFloat64List()[0];
}