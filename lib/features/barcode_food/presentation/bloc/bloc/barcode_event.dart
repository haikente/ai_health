import 'package:equatable/equatable.dart';

abstract class BarcodeScanEvent extends Equatable {}

class BarcodeDetectedEvent extends BarcodeScanEvent {
  final String barcode;
  BarcodeDetectedEvent(this.barcode);
  @override List<Object> get props => [barcode];
}

class ResetScannerEvent extends BarcodeScanEvent {
  @override List<Object> get props => [];
}
