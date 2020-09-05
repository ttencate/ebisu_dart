/// Unit tests for `ebisu.dart`.
///
/// Ported from the Java implementation:
/// https://github.com/fasiha/ebisu-java/blob/master/src/test/java/me/aldebrn/ebisu/EbisuTest.java

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';
import 'package:ebisu_dart/ebisu.dart';
import 'package:ebisu_dart/src/math.dart';

import 'ulp.dart';

void main() {
  final eps = 2.0 * ulp(1.0);

  // The ulp function is only used in tests, but we better make sure that it
  // works.
  test('ulp', () {
    final ulp1 = ulp(1.0);
    expect(ulp1, greaterThan(0.0));
    expect(1.0 + ulp1, greaterThan(1.0));
    expect(1.0 + ulp1 / 2.0, 1.0);
  });

  group('compare against test.json from reference implementation', () {
    const maxTol = 5e-3;
    // test.json was taken verbatim from the Python implementation:
    // https://github.com/fasiha/ebisu/blob/gh-pages/test.json
    final testJson = File('test/test.json').readAsStringSync();
    final json = jsonDecode(testJson) as List<dynamic>;
    for (final i in json) {
      final testCase = i as List<dynamic>;
      final description = jsonEncode(testCase.sublist(0, 3));
      final model = parseModel(testCase[1]);
      switch (testCase[0] as String) {
        case 'update':
          test(description, () {
            final successes = (testCase[2] as List<dynamic>)[0] as int;
            final total = (testCase[2] as List<dynamic>)[1] as int;
            final tNow = (testCase[2] as List<dynamic>)[2] as double;
            final expected = parseModel((testCase[3] as Map<String, dynamic>)['post']);

            final actual = model.updateRecall(successes, total, tNow);

            expect(actual.alpha, closeTo(expected.alpha, maxTol));
            expect(actual.beta, closeTo(expected.beta, maxTol));
            expect(actual.time, closeTo(expected.time, maxTol));
          });
          break;

        case 'predict':
          test(description, () {
            final tNow = (testCase[2] as List<dynamic>)[0] as double;
            final expected = (testCase[3] as Map<String, dynamic>)['mean'] as double;

            final actual = model.predictRecall(tNow, exact: true);

            expect(actual, closeTo(expected, maxTol));
          });
          break;

        default:
          assert(false);
      }
    }
  });

  test('verify halflife', () {
    final hl = 20.0;
    final m = EbisuModel(time: hl, alpha: 2.0, beta: 2.0);
    expect((m.modelToPercentileDecay(percentile: 0.5, coarse: true) - hl).abs(), greaterThan(1e-2));
    expect(relerr(m.modelToPercentileDecay(percentile: 0.5, tolerance: 1e-6), hl), lessThan(1e-3));
    expect(() => m.modelToPercentileDecay(percentile: 0.5, tolerance: 1e-150), throwsA(isA<AssertionError>()));
  });

  test('Ebisu predict at exactly half-life', () {
    final m = EbisuModel(time: 2.0, alpha: 2.0, beta: 2.0);
    final p = m.predictRecall(2, exact: true);
    expect(p, closeTo(0.5, eps));
  });

  test('Ebisu update at exactly half-life', () {
    final m = EbisuModel(time: 2.0, alpha: 2.0, beta: 2.0);
    final success = m.updateRecall(1, 1, 2.0);
    final failure = m.updateRecall(0, 1, 2.0);

    expect(success.alpha, closeTo(3.0, 500 * eps));
    expect(success.beta, closeTo(2.0, 500 * eps));

    expect(failure.alpha, closeTo(2.0, 500 * eps));
    expect(failure.beta, closeTo(3.0, 500 * eps));
  });

  test('Check logSumExp', () {
    final expected = exp(3.3) + exp(4.4) - exp(5.5);
    final actual = logSumExp([3.3, 4.4, 5.5], [1, 1, -1]);

    final epsilon = ulp(actual);
    expect(actual, closeTo(log(expected.abs()), epsilon));
    // expect(actual[1], signum(expected));
  });
}

EbisuModel parseModel(dynamic params) {
  final doubles = params as List<dynamic>;
  assert(doubles.length == 3);
  return EbisuModel(alpha: params[0] as double, beta: params[1] as double, time: params[2] as double);
}

double relerr(double dirt, double gold) {
  return (dirt == gold) ? 0 : (dirt - gold).abs() / gold.abs();
}