# frozen_string_literal: true

require 'json'
require 'net/http/post/multipart'
require 'openssl'

require 'util/signature_util'
require 'bits_service_client/version'
require 'bits_service_client/blob'
require 'bits_service_client/errors'
require 'bits_service_client/client'
require 'bits_service_client/resource_pool'

module BitsService
  BlobstoreError = Class.new(StandardError)
  FileNotFound = Class.new(StandardError)
end
