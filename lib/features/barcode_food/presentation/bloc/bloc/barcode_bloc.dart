import 'package:ai_health/features/barcode_food/domain/repositories/food_barcode_repository.dart';
import 'package:ai_health/features/barcode_food/presentation/bloc/bloc/barcode_event.dart';
import 'package:ai_health/features/barcode_food/presentation/bloc/bloc/barcode_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BarcodeScanBloc extends Bloc<BarcodeScanEvent, BarcodeScanState> {
  final FoodBarcodeRepository _repository;
  String? _lastScanned; // tránh scan lặp cùng 1 barcode

  BarcodeScanBloc(this._repository) : super(BarcodeScanInitial()) {
    on<BarcodeDetectedEvent>(_onBarcodeDetected);
    on<ResetScannerEvent>((_, emit) {
      _lastScanned = null;
      emit(BarcodeScanInitial());
    });
  }

  Future<void> _onBarcodeDetected(
    BarcodeDetectedEvent event,
    Emitter<BarcodeScanState> emit,
  ) async {
    if (event.barcode == _lastScanned) return; 
    _lastScanned = event.barcode;

    emit(BarcodeScanLoading(event.barcode));

    final result = await _repository.lookupBarcode(event.barcode);

    result.fold(
      (failure) => emit(BarcodeScanFailure(failure)),
      (food)    => emit(BarcodeScanSuccess(food)),
    );
  }
}
