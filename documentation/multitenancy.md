## Multitenancy

Multitenancy is supported via setting the `tenant` assign on your conn. The easiest way to do this is to write a `Plug`. This is a well documented process elsewhere. A good example of what you may want to do is derive the tenant from the subdomain.

See the implementation from [triplex](https://github.com/ateliware/triplex/blob/master/lib/triplex/plugs/subdomain_plug.ex#L2) for a good example. Extract your tenant name and use `Plug.Conn.assign/3` to assign that value to `tenant` before the request is forwarded to your Ash API.
