# frozen_string_literal: true
module BitsService
  class Blob
    attr_reader :guid, :public_download_url, :internal_download_url, :public_upload_url

    def initialize(guid:, public_download_url:, internal_download_url:, public_upload_url:)
      @guid = guid
      @public_download_url = public_download_url
      @internal_download_url = internal_download_url
      @public_upload_url = public_upload_url
    end

    def attributes(*_)
      []
    end
  end
end
