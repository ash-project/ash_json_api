<!--
SPDX-FileCopyrightText: 2020 Zach Daniel

SPDX-License-Identifier: MIT
-->

# Composite Primary Keys

When working with resources that have composite primary keys (multiple fields that together form the unique identifier), AshJsonApi provides special support for encoding and decoding these keys in URLs.

## Defining Composite Primary Keys

First, define your composite primary key in the JSON API configuration:

```elixir
defmodule MyApp.Bio do
  use Ash.Resource,
    extensions: [AshJsonApi.Resource]

  attributes do
    attribute :author_id, :uuid, primary_key?: true, public?: true
    attribute :category, :string, primary_key?: true, public?: true
    attribute :content, :string, public?: true
  end

  json_api do
    type "bio"
    
    primary_key do
      keys [:author_id, :category]
      delimiter "|"  # Use a delimiter that won't conflict with your data
    end
  end
end
```

### Important Considerations for Delimiters

When choosing a delimiter, ensure it won't appear in your actual data:

- **UUIDs contain dashes (`-`)** - Don't use `-` as a delimiter if any of your composite key fields are UUIDs
- **Safe alternatives**: `|`, `~`, `::`, or other characters unlikely to appear in your data
- **Default delimiter**: If not specified, AshJsonApi uses `-` as the default delimiter

## Enabling Composite Key Parsing in Routes

To enable automatic parsing of composite primary keys in URL paths, you must opt-in by specifying the `path_param_is_composite_key` option on your routes:

```elixir
json_api do
  type "bio"
  
  primary_key do
    keys [:author_id, :category]
    delimiter "|"
  end
  
  routes do
    base "/bios"
    
    # Enable composite key parsing for the :id parameter
    get :read, path_param_is_composite_key: :id
    patch :update, path_param_is_composite_key: :id
    delete :destroy, path_param_is_composite_key: :id
    
    # Other routes that don't need composite key parsing
    index :read
    post :create
  end
end
```

## How It Works

With the above configuration:

1. **URL Format**: `/bios/550e8400-e29b-41d4-a716-446655440000|sports`
2. **Parsing**: The `:id` parameter `550e8400-e29b-41d4-a716-446655440000|sports` gets split by the `|` delimiter
3. **Mapping**: The parts are mapped to the primary key fields in order:
   - `author_id` = `550e8400-e29b-41d4-a716-446655440000`
   - `category` = `sports`
4. **Filtering**: The query is filtered to find the record with both `author_id` and `category` matching

## Example Usage

```elixir
# Creating a bio
POST /bios
{
  "data": {
    "type": "bio",
    "attributes": {
      "author_id": "550e8400-e29b-41d4-a716-446655440000",
      "category": "sports",
      "content": "Author bio for sports category"
    }
  }
}

# Retrieving the bio using composite key
GET /bios/550e8400-e29b-41d4-a716-446655440000|sports

# Updating the bio
PATCH /bios/550e8400-e29b-41d4-a716-446655440000|sports
{
  "data": {
    "type": "bio", 
    "attributes": {
      "content": "Updated bio content"
    }
  }
}

# Deleting the bio
DELETE /bios/550e8400-e29b-41d4-a716-446655440000|sports
```

## Without Opt-In Parsing

If you don't specify `path_param_is_composite_key` on a route, the path parameter will be treated as a regular single value, even if your resource has composite primary keys defined. This ensures backward compatibility and prevents unexpected behavior.

## Error Handling

If the composite key format is invalid (wrong number of parts after splitting), AshJsonApi will return a 404 Not Found error with appropriate JSON:API error formatting.