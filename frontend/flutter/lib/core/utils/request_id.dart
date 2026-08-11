import 'dart:math';

/// Creates a client idempotency key for one create attempt.
///
/// The caller must retain this value after a network failure and reuse it for
/// the retry. A successful request or a different payload starts a new attempt.
String newClientRequestId() {
  final Random rng = Random.secure();
  final StringBuffer buffer = StringBuffer('req-');
  for (int i = 0; i < 16; i++) {
    buffer.write(rng.nextInt(16).toRadixString(16));
  }
  return buffer.toString();
}
