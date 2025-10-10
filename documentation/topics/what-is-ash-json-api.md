<!--
SPDX-FileCopyrightText: 2020 Zach Daniel

SPDX-License-Identifier: MIT
-->

# What is AshJsonApi

AshJsonApi allows you to expose your resource actions over a [JSON:API](https://jsonapi.org]). This API supports all of the features of JSON:API and Ash, like sorting, filtering, pagination, and side loading.

The kinds of thing this extension handles:

1. Route Creation: AshJsonApi defines routes and actions in your app based on resource configurations
2. Deserialization: When an incoming HTTP request hits a AshJsonApi defined route/action, AshJsonApi will parse it from `/api/users?filter[admin]=true` into a call to ash
3. Query Execution: AshJsonApi then executes the parsed Ash Action (this is the integration point between AshJsonApi and Ash Core, where Ash Actions are defined)
4. Serialization: AshJsonApi then serializes the result of the Ash Action into JSON API objects.
5. Response: AshJsonApi then sends this JSON back to the client
6. Schema Generation: AshJsonApi generates a machine-readable JSON Schema of your entire API and a route/action that can serve it
7. OpenAPI generation: AshJsonApi generates an OpenAPI spec for your API, which provides _human_ readable documentation effortlessly.

> ### Ash does the work {: .tip}
>
> Ash takes care of all of the data related work for a request (CRUD, Sorting, Filtering, Pagination, Side Loading, and Authorization) while AshJsonApi more or less replaces controllers and serializers.
>
> The beauty of putting all of that data functionality into a non-web layer (Ash) is that it can be used in many contexts. A JSON:API is one context - but there are others such as GraphQL or just using an Ash Resource from other code within an Application.
