require 'sinatra/base'

class FakeBitsService < Sinatra::Base
  delete %r{/.*/.*} do
    sleep 10
    status 200
  end

  delete '/timeout' do
    sleep 10
    status 200
  end
end
