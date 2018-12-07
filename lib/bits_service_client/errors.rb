# frozen_string_literal: true

module BitsService
  module Errors
    class Error < StandardError; end
    class FileDoesNotExist < Error; end
    class UnexpectedResponseCode < Error; end
  end
end
