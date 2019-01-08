module BitsService
  module SignatureUtil
    def sign_signature(resource_path, key_secret, key_id)
      expires = seconds_since_the_unix_epoch_with_offset(3600)
      signature_parts = "#{expires}#{resource_path}#{' '}#{key_secret}"
      digest = OpenSSL::Digest::SHA256.new
      hmac = OpenSSL::HMAC.new(key_secret, digest)
      signature=OpenSSL::HMAC.hexdigest(digest, key_secret, signature_parts)
      signed_path = "#{resource_path}?signature=#{signature}&expires=#{expires}&AccessKeyId=#{key_id}"
      return signed_path
    end

    def seconds_since_the_unix_epoch_with_offset(offset)
      t = Time.now.utc + offset
      t.strftime('%s')
    end
  end
end
