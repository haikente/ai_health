abstract class BarcodeFailure {
  final String message;
  const BarcodeFailure(this.message);
}

class NetworkFailure extends BarcodeFailure {
  const NetworkFailure() : super('Không có kết nối mạng');
}

class ProductNotFoundFailure extends BarcodeFailure {
  const ProductNotFoundFailure() : super('Không tìm thấy sản phẩm');
}

class ServerFailure extends BarcodeFailure {
  const ServerFailure() : super('Lỗi máy chủ, thử lại sau');
}
