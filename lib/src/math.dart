/// Implementation of some mathematical functions needed by the Ebisu
/// algorithm but missing from Dart's standard library, most notably an
/// approximation of the Gamma function.
///
/// Port of https://github.com/fasiha/gamma-java/blob/5288b5890968f047aed9c9c9b96f8d5016e4ac1b/src/main/java/me/aldebrn/gamma/Gamma.java

import 'dart:math';

const _gLn = 607.0 / 128.0;
const _pLn = [
  0.99999999999999709182, 57.156235665862923517, -59.597960355475491248,
  14.136097974741747174, -0.49191381609762019978, 0.33994649984811888699e-4,
  0.46523628927048575665e-4, -0.98374475304879564677e-4, 0.15808870322491248884e-3,
  -0.21026444172410488319e-3, 0.21743961811521264320e-3, -0.16431810653676389022e-3,
  0.84418223983852743293e-4, -0.26190838401581408670e-4, 0.36899182659531622704e-5,
];

final _log2pi = log(2 * pi);

/// Spouge approximation of `log(Gamma(z))`.
double logGamma(double z) {
  if (z < 0) {
    return double.nan;
  }
  var x = _pLn[0];
  for (var i = _pLn.length - 1; i > 0; --i) {
    x += _pLn[i] / (z + i);
  }
  final t = z + _gLn + 0.5;
  return .5 * _log2pi + (z + .5) * log(t) - t + log(x) - log(z);
}

/// Returns the sign of `x`.
double signum(double x) {
  return x == 0.0 ? 0.0 : x > 0.0 ? 1.0 : -1.0;
}

/// Evaluates `log(Beta(a, b))`.
double logBeta(double a, double b) {
  return logGamma(a) + logGamma(b) - logGamma(a + b);
}

/// Evaluates `log(Beta(a1, b) / Beta(a, b))`.
double logBetaRatio(double a1, double a, double b) {
  return logGamma(a1) - logGamma(a1 + b) + logGamma(a + b) - logGamma(a);
}

/// Evaluates `log(binom(n, k))` entirely in the log domain.
double logBinom(int n, int k) {
  return -logBeta(1.0 + n - k, 1.0 + k) - log(n + 1.0);
}

/// Stably evaluates the log of the sum of the exponentials of inputs:
/// `log(sum(b .* exp(a)))`. Returns the absolute value of the result.
///
/// If `b` is shorter than `a`, it is implicitly padded with ones.
///
/// In the Java implementation of Ebisu, this also returned the sign of the
/// result, but it was unused.
double logSumExp(List<double> a, List<double> b) {
  if (a.isEmpty) {
    return double.negativeInfinity;
  }
  final amax = a.reduce(max);
  var sum = 0.0;
  for (var i = 0; i < a.length; i++) {
    sum += exp(a[i] - amax) * (i < b.length ? b[i] : 1.0);
  }
  return log(sum.abs()) + amax;
  // final sign = signum(sum);
  // sum *= sign;
  // final abs = log(sum) + amax;
  // return [abs, sign];
}