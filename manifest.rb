
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
		@fileName = generate_file_name()
		@mail_class.domestic? ? generate_domestic_details() : generate_international_details()
		@header = HeaderRecord.new(self)
		build_raw()
		build_cew()
		build_sem()
		puts "Built manifest (.raw/.cew/.sem) for mail class #{@mail_class}!"
	end
	
	def determine_rate_ingredients()
		@rates = load_rate_ingredients(Rate, "#{$reference_file_path}/rates.csv", @mail_class)
		if @mail_class.domestic?
			puts "Use all Rate and Extra Service Combinations or just Rates? (Enter 'a' for all or 'r' for rates only)"
			@trim = gets.chomp.downcase
			@trim = validate(@trim) do |t|
				['a', 'r'].include?(t)
			end
			@stcs = load_rate_ingredients(ServiceTypeCode, "#{$reference_file_path}/stcs.csv", @mail_class) #Currently, only domestic mail classes have STC codes/extra services.
		end
	end
	
	def generate_domestic_details()
		if @trim == 'r'
			@rates.each do |rate|
				detail = Detail_Record.new(self, rate, @stcs.simplest)
				@details << detail
			end
		else
			@rates.each do |rate|
				if rate.is_open_and_distribute? #For all-type (trim level 'a') manifests, skip the stc-iteration for O&D rates.  They have specific STC/Extra Service Combinations.
					detail = Detail_Record.new(self, rate, @stcs.simplest)
					@details << detail
					next
				end
				@stcs.each do |stc|
					detail = Detail_Record.new(self, rate, stc)
					@details << detail
				end
			end
		end
	end
	
	def generate_international_details()
		@rates.each do |rate|
			detail = International_Detail_Record.new(self, rate)
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
end

