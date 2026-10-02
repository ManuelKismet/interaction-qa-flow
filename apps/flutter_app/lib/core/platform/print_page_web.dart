import 'package:web/web.dart' as web;

void openPrintableReport(String documentHtml) {
  final reportWindow = web.window.open('', '_blank');
  if (reportWindow == null) {
    web.window.alert('Allow pop-ups to open the printable report preview.');
    return;
  }
  final document = reportWindow.document;
  document.open();
  document.write(documentHtml);
  document.close();
}