import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../auth/repository/auth_repository.dart';
import '../models/cartok_forum_category.dart';
import '../models/cartok_forum_thread.dart';
import '../models/cartok_forum_post.dart';

class ForumPage<T> {
  const ForumPage({required this.items, this.nextCursor});
  final List<T> items;
  final String? nextCursor;
}

class ForumRepository {
  ForumRepository(this._client);

  final ApiClient _client;

  ApiException _mapError(DioException e) {
    final data = e.response?.data;
    final message = (data is Map && data['error'] != null)
        ? (data['error']['message'] as String? ?? 'Something went wrong')
        : 'Network error — please check your connection';
    return ApiException(message, statusCode: e.response?.statusCode);
  }

  Future<List<CartokForumCategory>> listCategories() async {
    try {
      final res = await _client.dio.get('/api/v1/forum/categories');
      return (res.data['data'] as List<dynamic>)
          .map((c) => CartokForumCategory.fromJson(c as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<ForumPage<CartokForumThread>> listThreads(
    String categoryId, {
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final res = await _client.dio.get(
        '/api/v1/forum/categories/$categoryId/threads',
        queryParameters: {'limit': limit, if (cursor != null) 'cursor': cursor},
      );
      final items = (res.data['data'] as List<dynamic>)
          .map((t) => CartokForumThread.fromJson(t as Map<String, dynamic>))
          .toList();
      return ForumPage(items: items, nextCursor: res.data['nextCursor'] as String?);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<CartokForumThreadDetail> getThread(String threadId) async {
    try {
      final res = await _client.dio.get('/api/v1/forum/threads/$threadId');
      return CartokForumThreadDetail.fromJson(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<CartokForumThread> createThread(String categoryId, {required String title, required String content}) async {
    try {
      final res = await _client.dio.post(
        '/api/v1/forum/categories/$categoryId/threads',
        data: {'title': title, 'content': content},
      );
      return CartokForumThread.fromJson(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<CartokForumPost> createPost(String threadId, {required String content, String? parentId}) async {
    try {
      final res = await _client.dio.post(
        '/api/v1/forum/threads/$threadId/posts',
        data: {'content': content, if (parentId != null) 'parentId': parentId},
      );
      return CartokForumPost.fromJson(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> vote(String threadId, String postId, int value) async {
    try {
      await _client.dio.post('/api/v1/forum/threads/$threadId/posts/$postId/vote', data: {'value': value});
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> removeVote(String threadId, String postId) async {
    try {
      await _client.dio.delete('/api/v1/forum/threads/$threadId/posts/$postId/vote');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> deletePost(String threadId, String postId) async {
    try {
      await _client.dio.delete('/api/v1/forum/threads/$threadId/posts/$postId');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> bookmarkThread(String threadId) async {
    try {
      await _client.dio.post('/api/v1/forum/threads/$threadId/bookmark');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> unbookmarkThread(String threadId) async {
    try {
      await _client.dio.delete('/api/v1/forum/threads/$threadId/bookmark');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<CartokForumThread>> listBookmarkedThreads() async {
    try {
      final res = await _client.dio.get('/api/v1/forum/threads/bookmarks');
      return (res.data['data'] as List<dynamic>)
          .map((t) => CartokForumThread.fromJson(t as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }
}
