# TeleTable Robot Control - Backend Diary API Documentation

This document describes the backend API endpoints for managing the robot diary/journal system. The diary is stored on a server and provides CRUD operations for journal entries.

## Base URL
```
https://api.teletable.com/v1
```

## Authentication
All API requests require authentication via Bearer token:
```
Authorization: Bearer <your_token_here>
```

## Data Models

### DiaryEntry
```json
{
  "id": "string",
  "title": "string",
  "content": "string",
  "createdAt": "2023-12-01T10:30:00Z",
  "updatedAt": "2023-12-01T10:30:00Z",
  "tags": ["string", "string"],
  "userId": "string"
}
```

## API Endpoints

### 1. Get All Diary Entries
**GET** `/diary/entries`

Retrieves all diary entries for the authenticated user.

**Query Parameters:**
- `page` (optional): Page number for pagination (default: 1)
- `limit` (optional): Number of entries per page (default: 20)
- `tags` (optional): Filter by tags (comma-separated)
- `search` (optional): Search in title and content

**Response:**
```json
{
  "success": true,
  "data": {
    "entries": [
      {
        "id": "entry_001",
        "title": "Robot Setup Day 1",
        "content": "Today we started setting up the robot...",
        "createdAt": "2023-12-01T10:30:00Z",
        "updatedAt": "2023-12-01T10:30:00Z",
        "tags": ["setup", "hardware"],
        "userId": "user_123"
      }
    ],
    "pagination": {
      "currentPage": 1,
      "totalPages": 5,
      "totalEntries": 87,
      "hasNext": true,
      "hasPrevious": false
    }
  }
}
```

### 2. Get Single Diary Entry
**GET** `/diary/entries/{id}`

Retrieves a specific diary entry by ID.

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "entry_001",
    "title": "Robot Setup Day 1",
    "content": "Today we started setting up the robot...",
    "createdAt": "2023-12-01T10:30:00Z",
    "updatedAt": "2023-12-01T10:30:00Z",
    "tags": ["setup", "hardware"],
    "userId": "user_123"
  }
}
```

### 3. Create New Diary Entry
**POST** `/diary/entries`

Creates a new diary entry.

**Request Body:**
```json
{
  "title": "New Entry Title",
  "content": "Entry content goes here...",
  "tags": ["tag1", "tag2"]
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "entry_002",
    "title": "New Entry Title",
    "content": "Entry content goes here...",
    "createdAt": "2023-12-01T11:00:00Z",
    "updatedAt": "2023-12-01T11:00:00Z",
    "tags": ["tag1", "tag2"],
    "userId": "user_123"
  },
  "message": "Diary entry created successfully"
}
```

### 4. Update Diary Entry
**PUT** `/diary/entries/{id}`

Updates an existing diary entry.

**Request Body:**
```json
{
  "title": "Updated Title",
  "content": "Updated content...",
  "tags": ["updated", "tags"]
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "entry_001",
    "title": "Updated Title",
    "content": "Updated content...",
    "createdAt": "2023-12-01T10:30:00Z",
    "updatedAt": "2023-12-01T11:30:00Z",
    "tags": ["updated", "tags"],
    "userId": "user_123"
  },
  "message": "Diary entry updated successfully"
}
```

### 5. Delete Diary Entry
**DELETE** `/diary/entries/{id}`

Deletes a diary entry.

**Response:**
```json
{
  "success": true,
  "message": "Diary entry deleted successfully"
}
```

### 6. Get Diary Statistics
**GET** `/diary/stats`

Retrieves diary statistics for the authenticated user.

**Response:**
```json
{
  "success": true,
  "data": {
    "totalEntries": 87,
    "entriesThisMonth": 12,
    "entriesThisWeek": 3,
    "mostUsedTags": [
      {"tag": "setup", "count": 15},
      {"tag": "testing", "count": 12},
      {"tag": "hardware", "count": 8}
    ],
    "averageEntriesPerWeek": 2.5
  }
}
```

## Error Handling

All errors follow a consistent format:

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid request data",
    "details": {
      "title": "Title is required",
      "content": "Content cannot be empty"
    }
  }
}
```

### Error Codes
- `VALIDATION_ERROR`: Request validation failed
- `UNAUTHORIZED`: Invalid or missing authentication token
- `FORBIDDEN`: User doesn't have permission
- `NOT_FOUND`: Requested resource not found
- `CONFLICT`: Resource conflict (e.g., duplicate entry)
- `RATE_LIMIT_EXCEEDED`: Too many requests
- `INTERNAL_SERVER_ERROR`: Server error

## HTTP Status Codes
- `200`: Success
- `201`: Created
- `400`: Bad Request
- `401`: Unauthorized
- `403`: Forbidden
- `404`: Not Found
- `409`: Conflict
- `422`: Unprocessable Entity
- `429`: Too Many Requests
- `500`: Internal Server Error

## Implementation Notes

### App Integration
The Flutter app should implement the following functionality:

1. **Authentication**: Store and refresh JWT tokens
2. **Offline Support**: Cache entries locally for offline viewing
3. **Sync Strategy**: Implement background sync when connection is available
4. **Conflict Resolution**: Handle conflicts when local and server data differ

### Security Considerations
- Use HTTPS for all requests
- Implement proper token refresh mechanism
- Validate all user inputs
- Sanitize content to prevent XSS attacks
- Implement rate limiting on client side

### Performance Optimization
- Implement pagination for large datasets
- Use compression for large text content
- Cache frequently accessed entries
- Implement incremental sync for updates

### Backend Requirements
- Database: PostgreSQL or MongoDB
- Authentication: JWT tokens
- File Storage: For future attachment support
- Search: Full-text search capabilities
- Backup: Regular automated backups

## Example Flutter Integration

```dart
class DiaryApiService {
  final String baseUrl = 'https://api.teletable.com/v1';
  final Dio _dio = Dio();

  Future<List<DiaryEntry>> getEntries({
    int page = 1,
    int limit = 20,
    List<String>? tags,
    String? search,
  }) async {
    final response = await _dio.get(
      '$baseUrl/diary/entries',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (tags != null) 'tags': tags.join(','),
        if (search != null) 'search': search,
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    
    return (response.data['data']['entries'] as List)
        .map((json) => DiaryEntry.fromJson(json))
        .toList();
  }

  Future<DiaryEntry> createEntry(DiaryEntry entry) async {
    final response = await _dio.post(
      '$baseUrl/diary/entries',
      data: entry.toJson(),
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    
    return DiaryEntry.fromJson(response.data['data']);
  }
}
```

## Testing

### Unit Tests
Test all API endpoints with various scenarios:
- Valid requests
- Invalid authentication
- Missing required fields
- Edge cases (empty content, long text, special characters)

### Integration Tests
- End-to-end workflow testing
- Performance testing with large datasets
- Concurrent user testing

---

**Note**: This API is designed to be RESTful and follows standard HTTP conventions. All timestamps are in ISO 8601 format (UTC). The backend should implement proper logging, monitoring, and error tracking for production use.