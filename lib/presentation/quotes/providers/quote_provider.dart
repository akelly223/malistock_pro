import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers/repository_providers.dart';
import '../../../domain/entities/quote.dart';

final quoteByIdProvider =
    FutureProvider.autoDispose.family<QuoteEntity?, int>((ref, id) async {
  final repo = ref.watch(quoteRepositoryProvider);
  return repo.getQuoteById(id);
});
