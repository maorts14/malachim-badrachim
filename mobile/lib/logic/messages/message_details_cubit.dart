import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rescue_app/models/message.dart';
import '../../repositories/message_repository.dart';

class MessageDetailsState {
  const MessageDetailsState({
    this.message,
    this.isLoading = false,
    this.errorMessage,
  });

  final Message? message;
  final bool isLoading;
  final String? errorMessage;

  MessageDetailsState copyWith({
    Message? message,
    bool? isLoading,
    String? errorMessage,
  }) =>
      MessageDetailsState(
        message: message ?? this.message,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
      );
}

class MessageDetailsCubit extends Cubit<MessageDetailsState> {
  MessageDetailsCubit({required MessageRepository messageRepository})
      : _messageRepository = messageRepository,
        super(const MessageDetailsState());

  final MessageRepository _messageRepository;

  Future<void> load(String messageId) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final message = await _messageRepository.getMessageDetails(messageId);
      emit(state.copyWith(message: message, isLoading: false));
    } catch (error) {
      emit(state.copyWith(isLoading: false, errorMessage: error.toString()));
    }
  }
}
