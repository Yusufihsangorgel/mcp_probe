/// A deliberately broken fixture that reads stdin and never responds to
/// anything, not even initialize. Used to test the handshake timeout.
library;

import 'dart:io';

void main() {
  stdin.listen((_) {});
}
