<!--
SPDX-FileCopyrightText: 2020 Zach Daniel

SPDX-License-Identifier: MIT
-->

# Paginated Relationships

AshJsonApi supports pagination for included relationships, allowing you to limit the number of related resources returned when using the `include` query parameter.

## Overview

By default, when you include relationships in a JSON:API request, all related resources are returned. For relationships with many records (e.g., a post with hundreds of comments), this can result in large response payloads and performance issues.

Paginated relationships allow clients to request a specific page of related resources using the `included_page` query parameter, similar to how top-level resources can be paginated with the `page` parameter.

## Configuration

To enable pagination for specific relationships, add them to the `paginated_includes` list in your resource's `json_api` block:

```elixir
defmodule MyApp.Post do
  use Ash.Resource,
    extensions: [AshJsonApi.Resource]

  json_api do
    type "post"

    # Allow comments to be included
    includes [:comments, :author]

    # Configure which relationships can be paginated
    paginated_includes [:comments]
  end

  relationships do
    has_many :comments, MyApp.Comment
    belongs_to :author, MyApp.Author
  end
end
```

### Nested Relationship Paths

You can also configure pagination for nested relationship paths:

```elixir
defmodule MyApp.Author do
  use Ash.Resource,
    extensions: [AshJsonApi.Resource]

  json_api do
    type "author"

    includes posts: [:comments]

    # Allow pagination for both posts and nested comments
    paginated_includes [
      :posts,
      [:posts, :comments]
    ]
  end
end
```

## Query Parameters

### Basic Pagination

Use the `included_page` query parameter to paginate included relationships:

```
GET /posts/1?include=comments&included_page[comments][limit]=10
```

This will include only the first 10 comments.

### Offset Pagination

Offset pagination uses `limit` and `offset` parameters:

```
GET /posts/1?include=comments&included_page[comments][limit]=10&included_page[comments][offset]=20
```

This returns 10 comments starting from the 21st comment.

### Keyset Pagination

Keyset (cursor-based) pagination uses `limit`, `after`, and `before` parameters:

```
GET /posts/1?include=comments&included_page[comments][limit]=10&included_page[comments][after]=<cursor>
```

### Count Parameter

To include the total count of related resources:

```
GET /posts/1?include=comments&included_page[comments][limit]=10&included_page[comments][count]=true
```

### Nested Relationships

For nested relationship paths, use dot notation:

```
GET /authors/1?include=posts.comments&included_page[posts.comments][limit]=5
```

This paginates the comments included for each post.

## Response Format

When a relationship is paginated, the response includes pagination metadata in the relationship's `meta` object:

```json
{
  "data": {
    "id": "1",
    "type": "post",
    "attributes": {
      "title": "My Post"
    },
    "relationships": {
      "comments": {
        "data": [
          {"id": "1", "type": "comment"},
          {"id": "2", "type": "comment"}
        ],
        "links": {
          "self": "/posts/1/relationships/comments",
          "related": "/posts/1/comments"
        },
        "meta": {
          "limit": 10,
          "offset": 0,
          "count": 50
        }
      }
    }
  },
  "included": [
    {
      "id": "1",
      "type": "comment",
      "attributes": {
        "body": "First comment"
      }
    },
    {
      "id": "2",
      "type": "comment",
      "attributes": {
        "body": "Second comment"
      }
    }
  ]
}
```

### Metadata Fields

For **offset pagination**:
- `limit`: The number of resources requested
- `offset`: The starting position
- `count`: The total count (if requested)

For **keyset pagination**:
- `limit`: The number of resources requested
- `more?`: Whether there are more resources available
- `count`: The total count (if requested)

## Error Handling

If you attempt to paginate a relationship that is not configured in `paginated_includes`, you will receive a 400 Bad Request error:

```json
{
  "errors": [
    {
      "status": "400",
      "code": "invalid_pagination",
      "title": "InvalidPagination",
      "detail": "Invalid pagination: Relationship path author is not configured for pagination. Add it to paginated_includes in the resource.",
      "source": {
        "parameter": "page"
      }
    }
  ]
}
```

## Best Practices

1. **Performance**: Consider adding default limits at the action level for relationships that are commonly included:

   ```elixir
   read :read do
     primary? true
     pagination offset?: true, default_limit: 20
   end
   ```

2. **Client Implementation**: Clients should check the `meta` object on relationships to determine if pagination is active and what the current page parameters are.

3. **Nested Pagination**: Be cautious with nested pagination - paginating both `posts` and `posts.comments` can result in complex queries. Consider whether you really need both levels paginated.

4. **Backwards Compatibility**: Non-paginated includes continue to work as before, so adding `paginated_includes` configuration is backwards compatible. Clients that don't use `included_page` parameters will receive all related resources as usual.

## Example: Complete Flow

### 1. Configure the resource

```elixir
defmodule MyApp.Post do
  use Ash.Resource,
    extensions: [AshJsonApi.Resource]

  json_api do
    type "post"
    includes [:comments, :author]
    paginated_includes [:comments]

    routes do
      base "/posts"
      get :read
      index :read
    end
  end

  actions do
    defaults [:read]
  end

  relationships do
    has_many :comments, MyApp.Comment
    belongs_to :author, MyApp.Author
  end
end
```

### 2. Make the API request

```bash
curl "http://localhost:4000/posts/1?include=comments&included_page[comments][limit]=5&included_page[comments][count]=true"
```

### 3. Process the response

The response will include:
- The post data in `data`
- Up to 5 comments in `included`
- Pagination metadata in `data.relationships.comments.meta`
- The linkage (comment IDs) in `data.relationships.comments.data`

### 4. Navigate to the next page

```bash
curl "http://localhost:4000/posts/1?include=comments&included_page[comments][limit]=5&included_page[comments][offset]=5"
```

## Combining with Other Features

Paginated relationships can be combined with:

- **Sparse fieldsets**: `fields[comment]=body,created_at`
- **Filtering included**: `filter_included[comments][status]=published`
- **Sorting included**: `sort_included[comments]=-created_at`
- **Field inputs**: `field_inputs[comment][calculated_field][arg]=value`

Example combining multiple features:

```
GET /posts/1?
  include=comments&
  included_page[comments][limit]=10&
  filter_included[comments][status]=published&
  sort_included[comments]=-created_at&
  fields[comment]=body,author_name
```
