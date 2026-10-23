import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ui/shared_ui.dart';

void main() {
  test('adds the space a resumed turn leaves out', () {
    expect(joinContinuation('dedicated', 'water'), 'dedicated water');
    expect(joinContinuation('question:', 'where'), 'question: where');
    expect(joinContinuation('Ну', 'да'), 'Ну да');
  });

  test('keeps the space a resumed turn brings', () {
    expect(joinContinuation('dedicated', ' water'), 'dedicated water');
    expect(joinContinuation('dedicated', '\n\nwater'), 'dedicated\n\nwater');
  });

  test('adds no space before punctuation or after a space', () {
    expect(joinContinuation('dedicated', ', water'), 'dedicated, water');
    expect(joinContinuation('dedicated ', 'water'), 'dedicated water');
    expect(joinContinuation('(', 'like'), '(like');
    expect(joinContinuation('**', 'Slim**'), '**Slim**');
  });
}
