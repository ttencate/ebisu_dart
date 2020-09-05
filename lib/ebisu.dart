/// Implementation of the Ebisu quiz scheduling algorithm:
/// https://fasiha.github.io/ebisu/
///
/// This Dart port is largely based on the Java implementation of Ebisu:
/// https://github.com/fasiha/ebisu-java

import 'dart:math';

import 'package:meta/meta.dart';
import 'src/math.dart';
import 'src/mingolden.dart';

/// Wrapper class to store three numbers representing an Ebisu model.
///
/// The model is encoded by a Beta distribution, parameterized by `alpha` and
/// `beta`, which defines the probability of recall after a certain amount of
/// elapsed `time` (units are left to the user).
///
/// Instances of this class are immutable. The `updateRecall` method returns a
/// new instance with the updated parameters.
///
/// N.B. In the Python and JavaScript implementations of Ebisu, this class
/// doesn't exist: those versions just store the three numeric parameters in a
/// 3-tuple or array. This Dart implementation is more object oriented.
@immutable
class EbisuModel {
  /// The time since last review (in unspecified units) for which the Beta
  /// distribution models the recall probability.
  final double time;
  /// The `alpha` parameter of the Beta distribution.
  final double alpha;
  /// The `beta` parameter of the Beta distribution.
  final double beta;

  EbisuModel({@required this.time, this.alpha = 4.0, double beta}) :
      beta = beta ?? alpha
  {
    assert(time > 0.0);
    assert(alpha > 0.0);
    assert(this.beta > 0.0);
  }

  /// Expected recall probability now, given a prior distribution on it.
  ///
  /// `tNow` is the *actual* time elapsed since this fact's most recent review.
  ///
  /// Optional keyword parameter `exact` makes the return value a probability,
  /// specifically, the expected recall probability `tNow` after the last review: a
  /// number between 0 and 1. If `exact` is false (the default), some calculations
  /// are skipped and the return value won't be a probability, but can still be
  /// compared against other values returned by this function. That is, if for an
  /// `EbishuModel m`
  ///
  /// ```
  /// m.predictRecall(tNow1, exact = true) < m.predictRecall(tNow2, exact = true)
  /// ```
  ///
  /// then it is guaranteed that
  ///
  /// ```
  /// m.predictRecall(tNow1, exact = false) < m.predictRecall(tNow2, exact = false)
  /// ```
  ///
  /// The default is set to `false` for computational efficiency.
  double predictRecall(double tNow, {bool exact = false}) {
    assert(tNow >= 0.0);
    if (tNow == 0.0) {
      return exact ? 1.0 : 0.0;
    }
    final dt = tNow / time;
    final ret = logBetaRatio(alpha + dt, alpha, beta);
    return exact ? exp(ret) : ret;
  }

  /// Update a prior on recall probability with a quiz result and time.
  ///
  /// `successes` is the number of times the user *successfully* exercised this
  /// memory during this review session, out of `n` attempts. Therefore, `0 <=
  /// successes <= total` and `1 <= total`.
  ///
  /// If the user was shown this flashcard only once during this review session,
  /// then `total=1`. If the quiz was a success, then `successes=1`, else
  /// `successes=0`.
  ///
  /// If the user was shown this flashcard *multiple* times during the review
  /// session (e.g., Duolingo-style), then `total` can be greater than 1.
  ///
  /// `tNow` is the time elapsed between this fact's last review and the review
  /// being used to update.
  ///
  /// Returns a new object describing the posterior distribution of recall
  /// probability at `tNow`.
  ///
  /// N.B. This function is tested for numerical stability for small `total < 5`. It
  /// may be unstable for much larger `total`.
  ///
  /// N.B.2. This function may throw `RangeError` upon numerical instability.
  /// This can happen if the algorithm is *extremely* surprised by a result; for
  /// example, if `successes=0` and `total=5` (complete failure) when `tNow` is very
  /// small compared to the halflife encoded in `prior`. Calling functions are asked
  /// to call this inside a try-except block and to handle any possible
  /// `RangeError`s in a manner consistent with user expectations, for example,
  /// by faking a more reasonable `tNow`.
  EbisuModel updateRecall(int successes, int total, double tNow) {
    assert(0 <= successes);
    assert(successes <= total);
    assert (1 <= total);
    assert(tNow > 0.0);
    final proposed = _updateRecall(successes, total, tNow, time);
    return _rebalance(successes, total, tNow, proposed);
  }

  /// Implementation of `updateRecall` that leaves it to the caller to rebalance
  /// the result if needed.
  EbisuModel _updateRecall(int successes, int total, double tNow, double tBack) {
    final dt = tNow / time;
    final et = tBack / tNow;

    final binomlns = [
      for (var i = 0; i <= total - successes; i++) logBinom(total - successes, i),
    ];
    final logs = [
      for (final m in [0, 1, 2]) logSumExp(
        [for (var i = 0; i <= total - successes; i++) binomlns[i] + logBeta(beta, alpha + dt * (successes + i) + m * dt * et)],
        [for (var i = 0; i <= total - successes; i++) pow(-1.0, i).toDouble()],
      ),
    ];

    final logDenominator = logs[0];
    final logMeanNum = logs[1];
    final logM2Num = logs[2];

    final mean = exp(logMeanNum - logDenominator);
    final m2 = exp(logM2Num - logDenominator);
    final meanSq = exp(2 * (logMeanNum - logDenominator));
    final sig2 = m2 - meanSq;

    if (mean <= 0) {
      throw RangeError('Invalid mean ${mean} found');
    }
    if (m2 <= 0) {
      throw RangeError('Invalid second moment ${m2} found');
    }
    if (sig2 <= 0) {
      throw RangeError('Invalid variance ${sig2} found: '
          'a=$alpha, b=$beta, t=$time, k=$successes, n=$total, tnow=$tNow, mean=$mean, m2=$m2, sig2=$sig2');
    }

    // Convert the mean and variance of a Beta distribution to its parameters. See:
    // https://en.wikipedia.org/w/index.php?title=Beta_distribution&oldid=774237683#Two_unknown_parameters
    final tmp = mean * (1.0 - mean) / sig2 - 1.0;
    final newAlpha = mean * tmp;
    final newBeta = (1.0 - mean) * tmp;

    return EbisuModel(time: tBack, alpha: newAlpha, beta: newBeta);
  }

  /// Computes this model's half-life (or other `percentile` in the range [0, 1]).
  /// Returns the time at which `predictRecall` would return `percentile`.
  ///
  /// If `coarse` is `true` (the default is `false`), returns an approximate solution
  /// (within an order of magnitude).
  ///
  /// `tolerance` indicates the accuracy of the search; ignored if `coarse`.
  double modelToPercentileDecay({double percentile = 0.5, bool coarse = false, double tolerance = 1e-4}) {
    assert(0.0 <= percentile);
    assert(percentile <= 1.0);

    final logBab = logBeta(alpha, beta);
    final logPercentile = log(percentile);
    final f = (double lndelta) => (logBeta(alpha + exp(lndelta), beta) - logBab) - logPercentile;

    final bracketWidth = coarse ? 1.0 : 6.0;
    var blow = -bracketWidth / 2.0;
    var bhigh = bracketWidth / 2.0;
    var flow = f(blow);
    var fhigh = f(bhigh);
    while (flow > 0 && fhigh > 0) {
      // Move the bracket up.
      blow = bhigh;
      flow = fhigh;
      bhigh += bracketWidth;
      fhigh = f(bhigh);
    }
    while (flow < 0 && fhigh < 0) {
      // Move the bracket down.
      bhigh = blow;
      fhigh = flow;
      blow -= bracketWidth;
      flow = f(blow);
    }

    if (!(flow > 0 && fhigh < 0)) {
      throw RangeError('Failed to bracket: flow=$flow, fhigh=$fhigh');
    }
    if (coarse) {
      return (exp(blow) + exp(bhigh)) / 2 * time;
    }
    final status = minimize((y) => f(y).abs(), blow, bhigh, tolerance, 10000);
    assert(status.converged);
    final sol = status.argmin;
    return exp(sol) * time;
  }

  EbisuModel _rebalance(int successes, int total, double tNow, EbisuModel proposed) {
    if (proposed.alpha > 2 * proposed.beta || proposed.beta > 2 * proposed.alpha) {
      final roughHalflife = proposed.modelToPercentileDecay(percentile: 0.5, coarse: true);
      return _updateRecall(successes, total, tNow, roughHalflife);
    } else {
      return proposed;
    }
  }

  static bool _approxEqual(double a, double b) {
    return a == b || a.isNaN == b.isNaN || max(a, b) - min(a, b) < 1e-6 * max(a, b);
  }

  @override
  bool operator ==(dynamic other) => other is EbisuModel &&
      _approxEqual(time, other.time) &&
      _approxEqual(alpha, other.alpha) &&
      _approxEqual(beta, other.beta);

  // XXX This is not fully consistent with operator == because it's not approximate!
  @override
  int get hashCode => time.hashCode ^ alpha.hashCode ^ beta.hashCode;

  @override
  String toString() => 'EbisuModel(time: $time, alpha: $alpha, beta: $beta)';
}
