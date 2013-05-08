require_relative 'file_builder'
require_relative 'mailer'
require_relative 'mail_class'
require_relative 'rate'
require_relative 'service_type_code'
require_relative 'header_record'
require_relative 'detail_record'

class Manifest
	include File_Builder

	attr_reader :date, :time, :originZIP
	attr_accessor :mailer, :mail_class, :rates, :stcs, :header, :details, :trim, :type, :fileName
	
	def initialize(mailer = nil, mail_class = nil)
		@details ||= []
		@date = Time.now.strftime('%Y%m%d') #Set a fixed date to use throughout a manifest object.
		@time = Time.now.strftime('%H%M%S') #Set a fixed time to use throughout a manifest object.
		@originZIP = '20260' #Hard coded origin ZIP for simplicity.
		@mailer = mailer || Mailer.new()
		@mail_class = mail_class || Mail_Class.new.code
		@mail_class == 'RP' ? @type = '3' : @type = '1' #RP is a returns product, which requires a type '3' manifest.  Otherwise, set to type '1'.
		determine_rate_ingredients()
		@fileName = generate_file_name(self.class, @mail_class, @date, @time, @trim)
		@mail_class.domestic? ? generate_domestic_details() : generate_international_details()
		@header = HeaderRecord.new(self)
		build_raw()
		build_cew()
		build_sem()
		puts "Built manifest (.raw/.cew/.sem) for mail class #{@mail_class}!"
	end
	
	def determine_rate_ingredients()
		@rates = load_rate_ingredients(Rate, "#{$targetPath}/Reference Files/rates.csv", @mail_class)
		if @mail_class.domestic?
			puts "Use all Rate and Extra Service Combinations or just Rates? (Enter 'a' for all or 'r' for rates only)"
			@trim = gets.chomp.downcase
			@trim = validate(@trim) do |t|
				['a', 'r'].include?(t)
			end
			@stcs = load_rate_ingredients(ServiceTypeCode, "#{$targetPath}/Reference Files/stcs.csv", @mail_class) #Currently, only domestic mail classes have STC codes/extra services.
		end
	end
	
	def generate_domestic_details()
		if @trim == 'r'
			@rates.each do |rate|
				detail = DetailRecord.new(self, rate, @stcs.simplest)
				@details << detail
			end
		else
			@rates.each do |rate|
				if rate.is_open_and_distribute? #For all-type (trim level 'a') manifests, skip the stc-iteration for O&D rates.  They have specific STC/Extra Service Combinations.
					detail = DetailRecord.new(self, rate, @stcs.simplest)
					@details << detail
					next
				end
				@stcs.each do |stc|
					detail = DetailRecord.new(self, rate, stc)
					@details << detail
				end
			end
		end
	end
	
	def generate_international_details()
		@rates.each do |rate|
			detail = InternationalDetailRecord.new(self, rate)
			@details << detail
		end
	end

	def size()
		@details.size + 1
	end
	
	def pull_facility_types()
		types = []
		@details.each {|detail| types << detail.destination_rate_indicator}
		return types.uniq
	end
	
	def delete_detail(&criteria)
		@details.each_with_index do |detail, index|
			@details.delete_at(index) if criteria.call(detail)
		end
		criteria = lambda {@details.find_index {|d| d == detail}}
		self.details.delete_at(criteria.call)
	end
end

