import 'package:ai_health/features/barcode_food/domain/entities/barcode_food.dart';
import 'package:ai_health/features/barcode_food/domain/failures/barcode_failure.dart';
import 'package:equatable/equatable.dart';

abstract class BarcodeScanState extends Equatable {}

class BarcodeScanInitial extends BarcodeScanState {
  @override List<Object> get props => [];
}

class BarcodeScanLoading extends BarcodeScanState {
  final String barcode;
  BarcodeScanLoading(this.barcode);
  @override List<Object> get props => [barcode];
}

class BarcodeScanSuccess extends BarcodeScanState {
  final BarcodeFood food;
  BarcodeScanSuccess(this.food);
  @override List<Object> get props => [food];
}

class BarcodeScanFailure extends BarcodeScanState {
  final BarcodeFailure failure;
  BarcodeScanFailure(this.failure);
  @override List<Object> get props => [failure];
}
