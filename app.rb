require 'rubygems'
require 'sinatra'
require 'net/https'
require 'uri'
require 'json'

require 'helpers/user_manager.rb'

class AppServer < Sinatra::Base 
    enable :sessions
    get '/' do
        "GivingStream API"
    end
	
	post '/offers' do
		"Not yet implemented."
	end
	
	get '/watchtags/:id' do
		result = { :success => false }
		begin
			result[:watchtags] = UserManager.instance.get_watchtags(params[:id])
			result[:success] = true
		rescue Exception => e
			result[:success] = false
			result[:message] = e.message
		end
		result.to_json
	end
	
	post '/watchtags/:id' do
		result = {:success => false}
		unless params[:watchtags].nil?
			begin
				watchtags = JSON.parse(params[:watchtags])
				if watchtags.respond_to? :each
					watchtags.each do |watchtag|
						UserManager.instance.add_watchtag(params[:id],watchtag)
					end
					result[:success] = true
				else
					UserManager.instance.add_watchtag(params[:id],watchtags)
					result[:success] = true
				end
			rescue JSON::ParserError => e
				if params[:watchtags].split.length > 1
					result[:success] = false
					result[:message] = "Invalid JSON. To provide multiple watchtags you must provide a JSON encoded array of tags."
				else
					UserManager.instance.add_watchtag(params[:id],params[:watchtags])
					result[:success] = true
				end
			rescue Exception => e
				result[:success] = false
				result[:message] = e.message
			end
		end
		result.to_json
	end
	
	delete '/watchtags/:id' do
		result = { :success => false }
		begin
			if params[:watchtags].nil?
				UserManager.instance.remove_all_watchtags(params[:id])
				result[:success] = true
				result[:message] = "Deleted all watchtags for user #{params[:id]}."
			else
				watchtags = JSON.parse(params[:watchtags])
				if watchtags.respond_to? :each
					rejects = ""
					params[:watchtags].each do |watchtag|
						success = UserManager.instance.remove_watchtag(params[:id], watchtag)
						rejects += " #{watchtag}"
					end
					result[:success] = rejects.empty? == false
					result[:message] = rejects if not rejects.empty?
					result[:message] = "The given watchtags weren't being watched by this user: #{watchtags}" if rejects.empty?
				else
					result[:success] = UserManager.instance.remove_watchtag(params[:id], params[:watchtags])
					result[:message] = "Delete successful." if result[:success] == true
					result[:message] = "The given watchtag wasn't being watched by this user: #{params[:watchtags]}" if result[:success] == false
				end
			end
		rescue JSON::ParserError => e
			# user only provided one watchtag, or bad json
			result[:success] = UserManager.instance.remove_watchtag(params[:id], params[:watchtags])
			result[:message] = "Delete successful." if result[:success] == true
			result[:message] = "The given watchtag wasn't being watched by this user: #{params[:watchtags]}" if result[:success] == false
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