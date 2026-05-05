import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiClient {
  static const String baseUrl = 'https://portal.gcsewithrosi.co.uk';
  
  // Timeout duration for requests
  static const Duration timeoutDuration = Duration(seconds: 30);

  /// Makes a POST request to the specified endpoint (form-urlencoded body).
  static Future<Map<String, dynamic>> post({
    required String endpoint,
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final defaultHeaders = {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
        if (headers != null) ...headers,
      };
      final encodedBody = body.entries
          .where((e) => e.value != null)
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');
      final response = await http
          .post(uri, headers: defaultHeaders, body: encodedBody)
          .timeout(timeoutDuration);
      return _handleResponse(response);
    } on http.ClientException catch (e) {
      throw ApiException('Network error: ${e.message}');
    } on Exception catch (e) {
      throw ApiException('Unexpected error: ${e.toString()}');
    }
  }

  /// Makes a POST request with JSON body (for APIs that read php://input with json_decode).
  static Future<Map<String, dynamic>> postJson({
    required String endpoint,
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final defaultHeaders = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (headers != null) ...headers,
      };
      final encodedBody = json.encode(body);
      final response = await http
          .post(uri, headers: defaultHeaders, body: encodedBody)
          .timeout(timeoutDuration);
      return _handleResponse(response);
    } on http.ClientException catch (e) {
      throw ApiException('Network error: ${e.message}');
    } on Exception catch (e) {
      throw ApiException('Unexpected error: ${e.toString()}');
    }
  }

  /// Makes a GET request to the specified endpoint
  /// 
  /// [endpoint] - The API endpoint
  /// [queryParameters] - Optional query parameters
  /// [headers] - Optional custom headers
  /// 
  /// Returns a Future with the response data as Map<String, dynamic>
  static Future<Map<String, dynamic>> get({
    required String endpoint,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) async {
    try {
      var uri = Uri.parse('$baseUrl$endpoint');
      
      if (queryParameters != null && queryParameters.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParameters);
      }

      final defaultHeaders = {
        'Accept': 'application/json',
        if (headers != null) ...headers,
      };

      final response = await http
          .get(uri, headers: defaultHeaders)
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } on http.ClientException catch (e) {
      throw ApiException('Network error: ${e.message}');
    } on Exception catch (e) {
      throw ApiException('Unexpected error: ${e.toString()}');
    }
  }

  /// Handles the HTTP response and converts it to a Map
  static Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        // Try to parse as JSON
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return jsonData;
      } catch (e) {
        // If JSON parsing fails, return the raw body as a map
        return {'raw': response.body, 'statusCode': response.statusCode};
      }
    } else {
      throw ApiException(
        'Request failed with status: ${response.statusCode}\n${response.body}',
      );
    }
  }

  /// Multipart upload for file + fields.
  ///
  /// [fileFieldName] defaults to 'media_file' to match our PHP endpoints.
  static Future<Map<String, dynamic>> postMultipart({
    required String endpoint,
    required Map<String, dynamic> fields,
    String? filePath,
    String fileFieldName = 'media_file',
    String? filename,
    Map<String, String>? headers,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final req = http.MultipartRequest('POST', uri);
      req.headers.addAll({
        'Accept': 'application/json',
        if (headers != null) ...headers,
      });
      for (final e in fields.entries) {
        if (e.value == null) continue;
        req.fields[e.key] = e.value.toString();
      }

      if (filePath != null && filePath.isNotEmpty) {
        final f = File(filePath);
        if (await f.exists()) {
          req.files.add(
            await http.MultipartFile.fromPath(
              fileFieldName,
              filePath,
              filename: filename,
            ),
          );
        }
      }

      final streamed = await req.send().timeout(timeoutDuration);
      final response = await http.Response.fromStream(streamed);
      return _handleResponse(response);
    } on http.ClientException catch (e) {
      throw ApiException('Network error: ${e.message}');
    } on Exception catch (e) {
      throw ApiException('Unexpected error: ${e.toString()}');
    }
  }
}

/// Custom exception class for API errors
class ApiException implements Exception {
  final String message;
  
  ApiException(this.message);
  
  @override
  String toString() => 'ApiException: $message';
}
