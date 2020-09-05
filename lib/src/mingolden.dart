/// Golden section minimization algorithm.
///
/// Port of https://github.com/fasiha/minimize-golden-section-java

import 'dart:math';

import 'package:meta/meta.dart';

@immutable
class MinimizationStatus {
  final int iterations;
  final double argmin;
  final double minimum;
  final bool converged;

  MinimizationStatus(this.iterations, this.argmin, this.minimum, this.converged);
}

final _phiRatio = 2 / (1 + sqrt(5));

MinimizationStatus minimize(double Function(double) f, double xL, double xU, double tol, int maxIterations) {
  double xF;
  double fF;
  var iteration = 0;
  var x1 = xU - _phiRatio * (xU - xL);
  var x2 = xL + _phiRatio * (xU - xL);
  // Initial bounds:
  var f1 = f(x1);
  var f2 = f(x2);

  // Store these values so that we can return these if they're better.
  // This happens when the minimization falls *approaches* but never
  // actually reaches one of the bounds
  final f10 = f(xL);
  final f20 = f(xU);
  final xL0 = xL;
  final xU0 = xU;

  // Simple, robust golden section minimization:
  while (++iteration < maxIterations && (xU - xL).abs() > tol) {
    if (f2 > f1) {
      xU = x2;
      x2 = x1;
      f2 = f1;
      x1 = xU - _phiRatio * (xU - xL);
      f1 = f(x1);
    } else {
      xL = x1;
      x1 = x2;
      f1 = f2;
      x2 = xL + _phiRatio * (xU - xL);
      f2 = f(x2);
    }
  }

  xF = 0.5 * (xU + xL);
  fF = 0.5 * (f1 + f2);

  final converged = !f2.isNaN && !f1.isNaN && iteration < maxIterations;
  final argmin =
      f10 < fF ? xL0 :
      f20 < fF ? xU0 :
      xF;
  return MinimizationStatus(iteration, argmin, fF, converged);
}