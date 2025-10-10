<!--
SPDX-FileCopyrightText: 2020 Zach Daniel

SPDX-License-Identifier: MIT
-->

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

The `field_inputs` parameter allows you to pass values to calculations that require user input.
This is particularly useful when you need to provide context-specific values for dynamic calculations.

The syntax follows this pattern:
`field_inputs[resource_type][calculation_name][parameter_name]=value`

You can use this in combination with sparse fieldsets to request specific calculations:

Example:

`blogs?fields[blog]=title,views,monthly_engagement&field_inputs[blog][monthly_engagement][yyyy_mm]=2024.06`

This would request the `title`, `views`, and `monthly_engagement` attributes for blogs, while providing 
the input parameter `yyyy_mm` with value `2024.06` to the `monthly_engagement` calculation.

When you need to provide input for multiple calculations or multiple parameters, specify each `field_inputs` parameter in its full form:

`blogs?fields[blog]=title,views,monthly_engagement,quarterly_stats&field_inputs[blog][monthly_engagement][yyyy_mm]=2024.06&field_inputs[blog][quarterly_stats][quarter]=Q2&field_inputs[blog][quarterly_stats][year]=2024`
