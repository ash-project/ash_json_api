# AshJsonApi

## TODO
* Validate no overlapping routes
* Validate all fields exist that are in the fields list
* Validate includes
* Do the whole request in a transaction *all the time*
* validate incoming relationship updates have the right type
* validate that there are only `relationship_routes` for something that is in `relationships`, and that the `relationship` is marked as editable (when we implement marking them as editable or not)
* All kinds of spec compliance, like response codes and error semantics