require 'rubygems'
require 'sinatra'

set :environment, ENV['RACK_ENV'].to_sym
disable :run, :reload

#log = File.new("/sinatra.log", "a")
#STDOUT.reopen(log)
#STDERR.reopen(log) 

require 'app.rb'

run Rack::URLMap.new "/" => AppServer.new