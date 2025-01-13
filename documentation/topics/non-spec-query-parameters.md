# Non-Spec query parameters

AshJsonApi supports a few non-spec query parameters that enhance
the capabilities of your API.

These are currently not exposed in the generated OpenAPI spec. PRs welcome!

## `filter_included`

Includes can be filtered via the `filter_included` query parameter.
To do this, you provide the path to the included resource and the
filter to apply.

Example:

`posts?include=comments&filter_included[comments][author_id]=1`


## `sort_included`

Includes can be sorted via the `sort_included` query parameter.
To do this, you provide the path to the included resource and the
sort to apply.

Example:

`posts?include=comments&sort_included[comments]=author.username,-created_at`

> ### included is unsorted! {: .info}
>
> Keep in mind that the records in the top level `included` key will not be
> reliably sorted. This is because multiple relationships could include the same record.
> When sorting includes, look at the `data.relationships.name` key for the order instead.

## `field_inputs`

You can pass arguments to calculations via the `field_inputs` query parameter.

Example:

Suppose posts have a calculation called `time_to_read` with an argument `words_per_minute`.
We can load that calculation with a specified `words_per_minute` argument like this:

`posts?fields[post]=time_to_read&field_inputs[post][time_to_read][words_per_minute]=50`
