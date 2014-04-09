require 'rubygems'

class Location
	attr_accessor :zip_code
	def initialize zip_code
		# only support zip codes right now
		@zip_code = zip_code
	end
	
	def distance other_loc
		if @zip_code == other_loc.zip_code
			return 0
		end
		
		return 100
	end
	
end