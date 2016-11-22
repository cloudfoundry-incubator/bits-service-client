# Bits-Service Client

Ruby client for [bits-service](https://github.com/cloudfoundry-incubator/bits-service).

# Changelog

* 0.2.1:
  - Update list of authors

* 0.2.0:
  - Add `vcap_request_id` to `BitsService::Client` and `BitsService::ResourcePool`
  - Add `request_timeout_in_seconds` to `BitsService::ResourcePool`
  - Move unit tests from CloudController to this gem

* 0.1.0: Initial version

# Bump

The gem is automatically built and published to [rubygems.org](https://rubygems.org/gems/bits_service_client) in the [flintstone](https://flintstone.ci.cf-app.com) CI pipeline.

In order to release a new version of the gem, the following steps should be taken:

1. Update the change log above
1. Update [`version.rb`](lib/bits_service_client/version.rb) with the new version
1. Check in the changes and push them to `origin`.

The pipeline will pick up the changes and will, if `version.rb` has changed, tag the release in git and publish the new version of the gem.
