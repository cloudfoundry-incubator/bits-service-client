# frozen_string_literal: true

require 'spec_helper'

module BitsService
    class ClassForTest
        include BitsService::SignatureUtil
    end
    RSpec.describe SignatureUtil do
        before(:each) do
            @util = ClassForTest.new
        end
        describe 'Signing generate' do
            it 'creates a HMAC based signature for client signed urls' do

                resource_path = '/packages/stuff'
                secret = 's3cr3t'
                key_id = 'key1'
                encoded_signed_url = @util.sign_signature(resource_path, secret, key_id)
                url_query_params = encoded_signed_url.split("?")[1]
                params = url_query_params.split("&")

                params_hash = {}
                params.each do | param |
                    key_value = param.split("=")
                    params_hash[key_value[0]] = key_value[1]
                end

                expect(encoded_signed_url).not_to be_empty
                expect(params_hash['signature']).not_to include "-"
                expect(params_hash['signature'].length).to equal 64
                expect(params_hash['expires'].to_i - Time.now.to_i).to be 3600
                expect(params_hash['AccessKeyId']).to eq key_id
            end
        end
    end
end
