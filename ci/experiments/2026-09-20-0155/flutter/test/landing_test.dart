import 'package:flutter_test/flutter_test.dart';
import 'package:simple_chat_flutter/knowledge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every machine has a landing page address in the knowledge base', () async {
    final knowledge = await Knowledge.load();

    expect(knowledge.landingUrls.keys, containsAll(knowledge.modelIds));
    for (final url in knowledge.landingUrls.values) {
      // The addresses are what the app opens, so a missing path segment here
      // is a customer sent to a 404.
      expect(url, contains('/ci/domain/landing_pages/'));
    }
    expect(knowledge.corpus, contains('Just Shining Eco'));
  });
}
