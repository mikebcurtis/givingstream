require 'rubygems'
require 'sinatra'
require 'net/https'
require 'uri'
require 'json'
require 'net/http'
require 'uri'

require 'helpers/user_manager.rb'
require 'helpers/location.rb'

class AppServer < Sinatra::Base 
    enable :sessions
	attr_accessor :debug_offer
	
	def initialize
		@debug_offer = ""
	end
	
    get '/' do
        "GivingStream API"
    end
	
	post '/' do
	end
	
	get '/offers/debug' do
		res = @debug_offer
		@debug_offer = ""
		return res
	end
	
	post '/offers' do
		result = { :success => false }
		begin 
			body = JSON.parse(request.body.read)
			tags = get_synonyms(body["tag"])
			push_offer (body["location"], tags, body["description"], imgURL=body["imgURL"])
			result[:success] = true
			result[:message] = "Sent offers for the following key words: " + tags.inspect
			result[:tags] = tags
		rescue Exception => e
			result[:success] = false
			result[:message] = e.message
		end
		result.to_json
	end
	
	def push_offer location, tags, description, imgURL = nil
		if imgURL.nil?
			imgURL = ""
		end
		data = { :location => location, :tags => tags, :description => description, :imgURL => imgURL }
		
		UserManager.instance.users.each do |user|
			unless user[:watchtags].empty? or not user[:watchtags].respond_to? :each or (tags & user[:watchtags].collect{|watchtag| watchtag.tag}).empty?
				matches = user[:watchtags].reject { |watchtag| not tags.include? watchtag.tag }
				matches.each do |watchtag|
					if watchtag.webhook == "http://ec2-54-80-167-106.compute-1.amazonaws.com/"
						@debug_offer = "offer=" + data.to_json
					end
					begin
						uri = URI.parse(watchtag.webhook)
						http = Net::HTTP.new(uri.host, uri.port)
						request = Net::HTTP::Post.new(uri.request_uri)
						request.set_form_data("offer=" + data.to_json)
						request["Content-Type"] = "application/x-www-form-urlencoded"
						response = http.request(request)
						
						#response = Net::HTTP.post_form(uri, {"offer" => data.to_json})
					rescue
						# skip if uri doesn't parse, or response is bad
					end
				end
			end
		end
	end	
	
	def get_synonyms tag
		begin
			url = "http://words.bighugelabs.com/api/2/0b177985e3e819c093e1ba66c3405c58/" + tag + "/json"
			uri = URI.parse(url)
			res = Net::HTTP.get(uri)
			parsed_res = JSON.parse(res)
			return parsed_res["noun"]["syn"] << tag
		rescue
			return [] << tag
		end
	end
	
	get '/users/:id/watchtags' do
		result = { :success => false }
		begin
			watchtags = UserManager.instance.get_watchtags(params[:id])
			converted = []
			watchtags.each do |watchtag|
				converted << {:tag => watchtag.tag, :webhook => watchtag.webhook}
			end
			result[:watchtags] = converted
			result[:success] = true
		rescue Exception => e
			result[:success] = false
			result[:message] = e.message
		end
		result.to_json
	end
	
	post '/users/:id/watchtags' do
		result = {:success => false}
		body = JSON.parse request.body.read
		if body["webhook"].nil?
			result[:success] = false
			result[:message] = "A webhook is required."
		end
		unless body["watchtags"].nil?
			begin
				watchtags = body["watchtags"]
				if watchtags.respond_to? :each
					watchtags.each do |watchtag|
						UserManager.instance.add_watchtag(params[:id],watchtag,body["webhook"])
					end
					result[:success] = true
				else
					UserManager.instance.add_watchtag(params[:id],watchtags,body["webhook"])
					result[:success] = true
				end
			rescue JSON::ParserError => e
				if body["watchtags"].split.length > 1
					result[:success] = false
					result[:message] = "Invalid JSON. To provide multiple watchtags you must provide a JSON encoded array of tags."
				else
					UserManager.instance.add_watchtag(params[:id],body["watchtags"],body["webhook"])
					result[:success] = true
				end
			rescue Exception => e
				result[:success] = false
				result[:message] = e.message
			end
		end
		result.to_json
	end
	
	delete '/users/:id/watchtags' do
		result = { :success => false }
		body = JSON.parse request.body.read
		begin
			if body["watchtags"].nil?
				UserManager.instance.remove_all_watchtags(params[:id])
				result[:success] = true
				result[:message] = "Deleted all watchtags for user #{params[:id]}."
			else
				watchtags = body["watchtags"]
				if watchtags.respond_to? :each
					rejects = ""
					body["watchtags"].each do |watchtag|
						success = UserManager.instance.remove_watchtag(params[:id], watchtag)
						rejects += " #{watchtag}"
					end
					result[:success] = rejects.empty? == false
					result[:message] = rejects if not rejects.empty?
					result[:message] = "The given watchtags weren't being watched by this user: #{watchtags}" if rejects.empty?
				else
					result[:success] = UserManager.instance.remove_watchtag(params[:id], body["watchtags"])
					result[:message] = "Delete successful." if result[:success] == true
					result[:message] = "The given watchtag wasn't being watched by this user: #{body["watchtags"]}" if result[:success] == false
				end
			end
		rescue JSON::ParserError => e
			# user only provided one watchtag, or bad json
			result[:success] = UserManager.instance.remove_watchtag(params[:id], body["watchtags"])
			result[:message] = "Delete successful." if result[:success] == true
			result[:message] = "The given watchtag wasn't being watched by this user: #{body["watchtags"]}" if result[:success] == false
		rescue Exception => e
			result[:success] = false
			result[:message] = e.message
		end
		result.to_json
	end
	
	post '/users' do
		mgr = UserManager.instance
		result = {:success => false}
		begin
			#if the user didn't provide an id, generate one
			if not params[:id].nil?
				success = mgr.add_user params[:id]
				if not success
					result[:success] = false
					result[:message] = "ID already taken."
				else
					result[:success] = true
					result[:message] = "New ID added."
					result[:id] = params[:id]
				end
			else
				id = rand(36**8).to_s(36)
				success = mgr.add_user id
				while not success
					id = rand(36**8).to_s(36)
					success = mgr.add_user id
				end
				result[:success] = true
				result[:message] = "New ID added"
				result[:id] = id
			end
		rescue Exception => e
			result[:success] = false
			result[:message] = e.message
		end
		result.to_json
	end
end