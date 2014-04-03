require 'rubygems'
require 'json'
require 'singleton'

class UserManager
  include Singleton
  attr_accessor :users, :filename
  
  def initialize
    @users = []
    @filename = "./cache/user_cache"
    load_users
  end
  
  def load_users
    begin
        File.open(@filename) do |f|
            @users = Marshal.load(f)
        end
        @load_time = Time.now
        puts "Loaded user data from #{@filename}"
    rescue
        puts "Failure to load from #{@filename}"
        @users = []
    end
  end

  def add_user id
	if @users.select { |user| user[:id] == id }.length > 0
		return false
	end
	
    @users << {:id => id, :watchtags => []}
    cache_user_data
    return true
  end
  
  def add_attr id, attr, val
    matches = @users.select { |user| user[:id] == id }
	matches.each do |user|
		if user[attr].respond_to? :each
			matches.each { |user| user[attr] << val }
		else
			matches.each { |user| user[attr] = val}
		end
	end
	
    cache_user_data
  end
  
  def add_watchtag id, watchtag
	matches = @users.select { |user| user[:id] == id }
	if matches.length <= 0
		return false
	end
	matches.each do |user|
		user[:watchtags] << watchtag
	end
	
	cache_user_data
	return true
  end
  
  def remove_watchtag id, tag
	matches = @users.select { |user| user[:id] == id}
	matches.each do |user| 
		rejects = user[:watchtags].reject! { |watchtag| watchtag == tag} 
		if rejects.nil?
			return false
		end
	end
	
	cache_user_data
	return true
  end
  
  def remove_all_watchtags id
	matches = @users.select { |user| user[:id] == id }
	matches.each do |user|
		user[:watchtags] = []
	end
  end
  
  def cache_user_data
    puts "caching user data" # DEBUG
    File.open('./cache/user_cache', 'w') do |f|
        f.write(Marshal.dump(@users))
    end
  end
  
  def get_watchtags id
    user = @users.select { |user| user[:id] == id }[0]
	return user[:watchtags]
  end
end
