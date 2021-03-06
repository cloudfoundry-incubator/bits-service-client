# frozen_string_literal: true

module BitsService
  module SignatureUtil
    def sign_signature(method, resource_path, key_secret, key_id)
      expires = seconds_since_the_unix_epoch_with_offset(3600)
      "#{resource_path}?" \
        "signature=#{OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, key_secret, "#{method.upcase} #{resource_path} #{key_secret} #{expires}")}&" \
        "expires=#{expires}&" \
        "AccessKeyId=#{key_id}"
    end

    def seconds_since_the_unix_epoch_with_offset(offset)
      t = Time.now.utc + offset
      t.strftime('%s')
    end
  end
end
