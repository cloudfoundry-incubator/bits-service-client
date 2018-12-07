# frozen_string_literal: true

guard :bundler do
  require 'guard/bundler'
  require 'guard/bundler/verify'
  helper = Guard::Bundler::Verify.new

  files = ['Gemfile']
  files += Dir['*.gemspec'] if files.any? { |f| helper.uses_gemspec?(f) }

  # Assume files are symlinked from somewhere
  files.each { |file| watch(helper.real_path(file)) }
end

guard :rspec, cmd: 'bundle exec rspec' do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/bits_service_client/(.+)\.rb$}) { |m| "spec/unit/bits_service_client/#{m[1]}_spec.rb" }
  watch(%r{^lib/bits_service_client/client.rb$}) { |m| 'spec/unit/bits_service_client/bits_service_client_spec.rb' }
  watch('spec/spec_helper.rb') { 'spec' }
end

guard :rubocop do
  watch(/.+\.rb$/)
  watch(%r{(?:.+/)?\.rubocop\.yml$}) { |m| File.dirname(m[0]) }
end
