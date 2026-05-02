import '../../config/constants/app_strings.dart';

sealed class AppError {
  const AppError();
  String get userMessage;
}

final class NetworkError extends AppError {
  const NetworkError();
  @override
  String get userMessage => AppStrings.noInternet;
}

final class AuthError extends AppError {
  const AuthError([this._message]);
  final String? _message;
  @override
  String get userMessage => _message ?? AppStrings.invalidCredentials;
}

final class PermissionError extends AppError {
  const PermissionError();
  @override
  String get userMessage => AppStrings.permissionDeniedMessage;
}

final class UnknownError extends AppError {
  const UnknownError();
  @override
  String get userMessage => AppStrings.somethingWentWrong;
}
