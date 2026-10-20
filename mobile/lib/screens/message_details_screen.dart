import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../logic/messages/message_details_cubit.dart';
import '../repositories/message_repository.dart';

class MessageDetailsScreen extends StatelessWidget {
  const MessageDetailsScreen({super.key, required this.messageId});

  final String messageId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MessageDetailsCubit(
        messageRepository: context.read<MessageRepository>(),
      )..load(messageId),
      child: Scaffold(
        appBar: AppBar(title: const Text('פרטי הודעה')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: BlocBuilder<MessageDetailsCubit, MessageDetailsState>(
            builder: (context, state) {
              if (state.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              final message = state.message;
              if (message == null) {
                return Center(
                    child: Text(state.errorMessage ?? 'ההודעה לא נמצאה'));
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message.title,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(message.text),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
