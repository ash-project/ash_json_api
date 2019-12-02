# AshJsonApi

## TODO
* Validate no overlapping routes
* Make it so that `mix phx.routes` can print the routes from a `Plug.Router` so that our routes can be printed too.
* Validate all fields exist that are in the fields list
* Validate includes
* Do the whole request in a transaction *all the time*
* validate incoming relationship updates have the right type
* validate that there are only `relationship_routes` for something that is in `relationships`, and that the `relationship` is marked as editable (when we implement marking them as editable or not)
* All kinds of spec compliance, like response codes and error semantics
* Should implement a complete validation step, that first checks for a valid request according to json api, then validates against the resource being requested
* Logging should be routed through ash so it can be configured/customized
* Set logger metadata when we parse the request
* Errors should have about pages
* Create the ability to dynamically create a resource in a test
* The JSON schema for test was edited a bit to remove referenes to `uri-reference`, because either our parser was doing them wrong, or we have to do them in a really ugly way that I'd rather just not do. https://github.com/hrzndhrn/json_xema/issues/26