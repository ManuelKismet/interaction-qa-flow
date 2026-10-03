import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/core/platform/print_page.dart';

void main() {
  test('print helpers retain both legacy and dedicated report APIs', () {
    expect(() => printCurrentPage(), returnsNormally);
    expect(() => openPrintableReport('<!doctype html>'), returnsNormally);
  });
}
