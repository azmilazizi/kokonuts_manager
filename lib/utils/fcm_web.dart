import 'dart:js_interop';
import 'package:web/web.dart' as web;

void listenForWebReceiptMessages(void Function(String) onReceipt) {
  web.window.addEventListener(
    'message',
    ((web.MessageEvent event) {
      try {
        final data = event.data.dartify();
        if (data is Map && data['type'] == 'open_receipt') {
          final receipt = data['receipt_number'] as String?;
          if (receipt != null && receipt.isNotEmpty) onReceipt(receipt);
        }
      } catch (_) {}
    }).toJS,
  );
}

String? getInitialReceiptFromUrl() {
  final receipt = Uri.base.queryParameters['open_receipt'];
  return (receipt != null && receipt.isNotEmpty) ? receipt : null;
}
