require_relative 'file_builder'

class Mailer
	include File_Builder
	
	attr_accessor :mid, :permit, :permitZIP, :nonProfitPermit, :nonProfitPermitZIP, :returnsPermit, :returnsPermitZIP
	
	def initialize()
		set_MID()
		set_permit()
		set_permit_ZIP()
		puts "Mailer Profile:  #{@mid} (MID), #{@permit} (Permit), #{@permitZIP} (Permit ZIP)"
	end
	
	def set_MID()
		puts "Enter a 9-digit Mailer ID (MID):"
		@mid = gets.chomp
		@mid = validate(@mid) do |mid|
			/\d{9}/.match(mid).to_s == mid
		end
	end
	
	def set_permit()
		puts "Enter the permit number for #{@mid}:"
		@permit = gets.chomp
		@permit = validate(@permit) do |p|
			/\d+/.match(p).to_s == p
		end
	end
	
	def set_permit_ZIP()
		puts "Enter the 5-digit permit ZIP code for permit #{@permit}:"
		@permitZIP = gets.chomp
		@permitZIP = validate(@permitZIP) do |zip|
			/\d{5}/.match(zip).to_s == zip
		end
	end
	
	def set_non_profit_permit()
		puts "The manifest generator has detected a non-profit rate indicator."
		puts "Enter the non-profit permit number for #{@mid}:"
		@nonProfitPermit = gets.chomp
		@nonProfitPermit = validate(@nonProfitPermit) do |p|
			/\d+/.match(p).to_s == p
		end
	end
	
	def set_non_profit_permit_ZIP()
		puts "Enter the 5-digit permit ZIP code for non-profit permit #{@nonProfitPermit}:"
		@nonProfitPermitZIP = gets.chomp
		@nonProfitPermitZIP = validate(@nonProfitPermitZIP) do |zip|
			/\d{5}/.match(zip).to_s == zip
		end
	end
	
	def set_returns_permit()
		puts "The manifest generator has detected a merchandise returns product."
		puts "Enter the merchandise return permit number for #{@mid}:"
		@returnsPermit = gets.chomp
		@returnsPermit = validate(@returnsPermit) do |p|
			/\d+/.match(p).to_s == p
		end
	end
	
	def set_returns_permit_ZIP()
		puts "Enter the 5-digit permit ZIP code for the merchandise return permit #{@returnsPermit}:"
		@returnsPermitZIP = gets.chomp
		@returnsPermitZIP = validate(@returnsPermitZIP) do |zip|
			/\d{5}/.match(zip).to_s == zip
		end
	end
end