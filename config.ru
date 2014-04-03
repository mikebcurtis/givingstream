require 'rubygems'
require 'sinatra'

set :environment, ENV['RACK_ENV'].to_sym
disable :run, :reload

require 'app.rb'

run Rack::URLMap.new "/" => AppServer.new