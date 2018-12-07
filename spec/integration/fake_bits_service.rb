# frozen_string_literal: true

require 'sinatra/base'

class FakeBitsService < Sinatra::Base
  delete %r{/.*/.*} do
    # binding.pry
    sleep 10
    status 200
  end

  delete '/timeout' do
    sleep 10
    status 200
  end

  head %r{/.*/.*} do
    sleep 10
    status 200
  end

  get '/status' do
    status 200
  end
end
