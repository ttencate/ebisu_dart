Ebisu
=====

This is a Dart implementation of the [Ebisu](https://fasiha.github.io/ebisu/)
quiz scheduling algorithm, originally developed in Python by
[Ahmed Fasih](https://github.com/fasiha).

In a nutshell, Ebisu works by modelling the probability that a fact will be
remembered correctly at any arbitrary moment since the last time the fact was
last quizzed. For more information, refer to the excellent
[literate document](https://fasiha.github.io/ebisu/) describing the original
implementation.

This `ebisu_dart` package is unrelated to the similarly named
[`ebisu`](https://pub.dev/packages/ebisu) package.

Example
-------

    import 'package:ebisu_dart/ebisu.dart';

    // Assume an inital halflife of 10 units (interpreted as minutes here).
    const initialHalflife = 10.0;
    var model = EbisuModel(initialHalflife);

    // Predict recall after 30 minutes have elapsed.
    final predictedRecall = model.predictRecall(30.0);

    // Update model after a correct answer.
    model = model.updateRecall(1, 1, 30.0);

    // Calculate new halflife.
    print(model.modelToPercentileDecay());

Porting notes
-------------

This Dart implementation is a fairly literal port of
[the Java implementation](https://github.com/fasiha/ebisu-java), but converted
into idiomatic Dart: object oriented, no separation of interface/class, named
and optional method arguments, and so on. To keep the excellent documentation of
the original version relevant, method names have not been changed, even though
this results in slightly worse naming.

Documentation comments have been ported and updated from the Java version, but
for an in-depth explanation of the algorithm, refer to the
[original](https://fasiha.github.io/ebisu/).

Versioning
----------

The major version number follows that of the Python implementation while also
obeying semantic versioning; thus, API-breaking changes can only happen if a
new major version of the Python implementation is released.

Development
-----------

All unit tests of the original Python implementation have been ported. To run
them:

    pub test

To run the linter (configured with the rules from the `pedantic` package):

    dartanalyzer .

To publish a new version:

- Update the version number in `pubspec.yaml`.
- Update `CHANGELOG.md`.
- Commit the changes with a message of the form `vX.Y.Z: Brief summary`.
- Add a tag of the form `vX.Y.Z`.
- Run `git push && git push --tags` to push the code and tag to GitHub.
- Run `pub publish --dry-run` to check if everything is okay.
- Run `pub publish` to publish.

License
-------

Public domain (see the `LICENSE` file).
