require './file_builder'
require './evs_data_loader'

#Set necessary variables to allow for OCRA Executable to function on ACE Machines ************************************************
	$targetPath = File.dirname(ENV['OCRA_EXECUTABLE'].to_s)
	$targetPath.gsub!(/\\/,'/')
	$targetPath = File.expand_path($targetPath) if $targetPath == '.'
	Dir.chdir($targetPath)
	if $targetPath != '.'
		Dir.mkdir("#{$targetPath}/Generated EVS Files/") if File.directory?("#{$targetPath}/Generated EVS Files/") != true
		Dir.mkdir("#{$targetPath}/Reference Files/") if File.directory?("#{$targetPath}/Reference Files/") != true
		Dir.mkdir("#{$targetPath}/Rate Validations/") if File.directory?("#{$targetPath}/Rate Validations/") != true
	end
#*********************************************************************************************************************************

#Build in a 'Reference Data' folder that contains all reference files.  Initialize reference files from the OCRA .exe if they do not exist.
#Otherwise, read all reference files from $targetPath/Reference Files/*

class Manifest
	include File_Builder
	include EVS_Data_Loader

	attr_reader :date, :time, :originZIP
	attr_accessor :mailer, :mail_class, :rates, :stcs, :header, :details, :trim, :type, :fileName
	
	def initialize(mailer = nil, mail_class = nil)
		@details ||= []
		@date = Time.now.strftime('%Y%m%d') #Set a fixed date to use throughout a manifest object.
		@time = Time.now.strftime('%H%M%S') #Set a fixed time to use throughout a manifest object.
		@originZIP = '20260' #Hard coded origin ZIP for simplicity.
		@mailer = mailer || Mailer.new()
		@mail_class = mail_class || set_mail_class()
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
	
	def set_mail_class()
		mail_classes = load_data("#{$targetPath}/Reference Files/mailclasses.txt")
		puts "What mail class would you like to generate a file for?"
		puts "#{mail_classes}"
		@mail_class = gets.chomp.upcase
		puts "You selected: #{@mail_class}"
		@mail_class = validate(@mail_class) do |mailClass|
			mail_classes.include?(mailClass)
		end
		return @mail_class
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

#*********************************************************************************************************************************

class HeaderRecord
	include File_Builder
	create_fields_using("#{$targetPath}/Reference Files/header.csv")
	
	def initialize(manifest)
		populate_values_from_baseline("#{$targetPath}/Reference Files/baseline.raw")
		@electronic_file_number = generate_EFN(manifest.mailer.mid)
		@electronic_file_type = manifest.type
		@date_of_mailing = manifest.date
		@time_of_mailing = manifest.time
		@entry_facility_zip_code = manifest.originZIP
		@transaction_id = "#{manifest.date}0000"
		@file_record_count = manifest.size.to_s.rjust(9, '0')
		@mailer_id = manifest.mailer.mid
	end
	def generate_EFN(mid)
		return "92750#{mid}#{rand(99999999).to_s.rjust(8, '0')}"
	end
end

#*********************************************************************************************************************************

class DetailRecord
	include File_Builder
	create_fields_using("#{$targetPath}/Reference Files/detail.csv")
	
	def initialize(manifest, rate, *stc)
		populate_values_from_baseline("#{$targetPath}/Reference Files/baseline.raw")
		self.instance_variables.each do |var|
			self.set(var, rate.get(var)) if rate.instance_variables.include?(var) #Update the detail record with rate information for each shared field
			self.set(var, stc[0].get(var)) if stc[0] and stc[0].instance_variables.include?(var)   #Update the detail record with STC information for each shared field
		end
		generate_PIC(manifest, stc[0])
		generate_weight(rate)
		set_mailer_info(manifest.mailer, rate)
		evaluate_extra_services(stc[0]) if stc[0] #Evaluate extra services if any STC object was passed for detail generation.
		continue_build_options(rate)
	end
	
	def continue_build_options(rate)
		generate_zone(rate)
		generate_ZIP()
		evaluate_discounts_and_surcharges(rate)
		evaluate_open_and_distribute() if rate.is_open_and_distribute?
		evaluate_military_box() if rate.is_military_box?
		evaluate_dim_weight(rate)
		evaluate_cubic(rate)
	end
	
	def generate_PIC(manifest, stc)
		@tracking_number = "420#{manifest.originZIP}000092#{stc.service_type_code}#{manifest.mailer.mid}#{rand(99999999).to_s.rjust(8, '0')}"
	end
	
	def update_PIC(stc)
		@tracking_number[14,3] = stc #Update position (index) 14 through 16 to the new STC
	end
	
	def generate_weight(rate)
		min = rate.min_weight.to_f
		max = rate.max_weight.to_f
		part = rand(min..max).round(4).to_s.split('.')
		wholeNum = part[0].rjust(5,'0')
		decimal = part[1].ljust(4,'0')
		@weight = wholeNum + decimal
	end
	
	def generate_zone(rate)
		rate.min_zone = '01' if rate.min_zone == 'LC'
		if rate.min_zone != '00' and rate.max_zone != '00'
			@domestic_zone = rand(rate.min_zone.to_i..rate.max_zone.to_i).to_s.rjust(2, '0')
		else
			@domestic_zone = '00'
		end
	end
	
	def generate_ZIP()
		zips = {'00' => '20260', '01' => '20260', '02' => '24001', '03' => '25505', '04' => '61001', '05' => '35601', '06' => '74333', '07' => '87501', '08' => '90210'}
		@destination_zip_code = zips[@domestic_zone]
	end
	
	def set_mailer_info(mailer, rate)
		@mail_owner_mailer_id = mailer.mid
		if rate.non_profit?
			mailer.set_non_profit_permit unless mailer.nonProfitPermit
			mailer.set_non_profit_permit_ZIP unless mailer.nonProfitPermitZIP
			@payment_account_number = mailer.nonProfitPermit
			@post_office_of_account_zip_code = mailer.nonProfitPermitZIP
		elsif rate.is_returns?
			mailer.set_returns_permit unless mailer.returnsPermit
			mailer.set_returns_permit_ZIP unless mailer.returnsPermitZIP
			@payment_account_number = mailer.returnsPermit
			@post_office_of_account_zip_code = mailer.returnsPermitZIP
		else
			@payment_account_number = mailer.permit
			@post_office_of_account_zip_code = mailer.permitZIP
		end
	end
	
	def evaluate_extra_services(stc)
		@value_of_article = stc.assess_insurance() || @value_of_article #If insurance is assessed, it returns a value.  Otherwise, it returns false and just uses default value.
		@cod_amount_due_sender = stc.assess_COD() || @cod_amount_due_sender
	end
	
	def evaluate_open_and_distribute()
		@open_and_distribute_contents_indicator = 'EP' #Required field for O&D, EP = Parcels/Electronic Payment
		if @mail_class == 'PM'
			@service_type_code = '123' #Priority Mail Open & Distribute STC Value
			@extra_service_code_1st_service = '430' #Priority Mail Open & Distribute 1st Service Code
			update_PIC(@service_type_code)
		elsif @mail_class == 'EX'
			@service_type_code = '723' #Express Mail Open & Distribute STC Value
			@delivery_option_indicator = 'E' #Required for EXOD
			update_PIC(@service_type_code)
		end
	end
	
	def evaluate_military_box() #Military Box requires ZIP starting in 963 (Zone 8).
		@domestic_zone = '08'
		@destination_zip_code = '96303'
	end
	
	def evaluate_discounts_and_surcharges(rate)
		@discount_type = rate.discount? || @discount_type #If rate contains a discount type, it returns a value.  Otherwise, it returns false and just uses default value.
		@surcharge_type = rate.surcharge? || @surcharge_type #If rate contains a surcharge type, it returns a value.  Otherwise, it returns false and just uses default value.
	end
		
	def evaluate_dim_weight(rate)
		@length, @width, @height = '01400','01400','01400' if rate.is_dim_weight? #14 inches (1728 cubic inches is minimum for DR/DN...DN volume is multiplied by 0.785)
	end
	
	def evaluate_cubic(rate)
		if rate.is_cubic?
			minVol = 0.00
			maxVol = 10.00 #9.50 will go to 0.49 (Tier 5).  Anything above will test recalculation to SP from CP.
			part = rand(minVol..maxVol).round(2).to_s.split('.')
			wholeNum = part[0].rjust(3, '0')
			decimal = part[1].ljust(2, '0')
			dimension = wholeNum + decimal
			@length, @width, @height = dimension, dimension, dimension
		end
	end
end

#*********************************************************************************************************************************

class InternationalDetailRecord < DetailRecord #Need to inherit PIC and be able to modify it in accordance with International Mail Classes.
	def initialize(manifest, rate)
		super(manifest, rate)
	end
	
	def continue_build_options(rate)
		set_code_and_price_group()
	end
	
	#International PIC Generator - generates PIC and also sets barcode construct based on mail class.
	def generate_PIC(manifest, stc = nil)
		case manifest.mail_class
		when 'LC'
			@tracking_number = "LX600#{rand(999999).to_s.rjust(6, '0')}US"
			@barcode_construct_code = 'I01'
		when 'PG'
			@tracking_number = "83500#{rand(99999).to_s.rjust(5, '0')}"
			@barcode_construct_code = 'G01'
		when 'IE'
			@tracking_number = "AA100#{rand(999999).to_s.rjust(6, '0')}US"
			@barcode_construct_code = 'I01'
		when 'CP'
			@tracking_number = "CB600#{rand(999999).to_s.rjust(6, '0')}US"
			@barcode_construct_code = 'I01'
		end
	end
	
	#International Country Code and Price Group Calculation
	def set_code_and_price_group()
		@foreign_postal_code = '123456789' #Default value for now as it is not validated and has no postage impact.
		if @mail_class == 'PG'
			info = {'CA' => 'Price Group 1', 'MX' => 'Price Group 2', 'HK' => 'Price Group 3', 'AL' => 'Price Group 4', 'FI' => 'Price Group 5', 'IN' => 'Price Group 6', 'DO' => 'Price Group 7', 'PE' => 'Price Group 8'}
			temp = info.keys
			@destination_country_code = temp[rand(temp.size)]
			@customer_reference_number_1 = info[@destination_country_code]
		else
			info = {'CA' => 'Price Group 1', 'MX' => 'Price Group 2', 'HK' => 'Price Group 3', 'AL' => 'Price Group 4', 'FI' => 'Price Group 5', 'IN' => 'Price Group 6', 'CM' => 'Price Group 7', 'EG' => 'Price Group 8', 'JM' => 'Price Group 9'}
			temp = info.keys
			@destination_country_code = temp[rand(temp.size)]
			@customer_reference_number_1 = info[@destination_country_code]
		end
	end
end

#*********************************************************************************************************************************

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

#*********************************************************************************************************************************

class Rate
	include File_Builder
	create_fields_using("#{$targetPath}/Reference Files/rates.csv")
	#create_fields_using essentially provides the following functionality..
	#attr_accessor :mail_class, :processing_category, :destination_rate_indicator, :rate_indicator, :min_zone, :max_zone, :barcode, :discount_and_surcharge, :min_weight, :max_weight
	
	def initialize()
	end
	
	def non_profit?()
		@rate_indicator[0] == 'N' and ['S2', 'SA'].include?(@mail_class)
	end
	
	def is_returns?()
		@mail_class == 'RP'
	end
	
	def is_open_and_distribute?()
		@processing_category == 'O'
	end
	
	def discount?()
		['*', 'N1'].include?(@discount_and_surcharge) ? false : @discount_and_surcharge #Any discount and surcharge value that is not '*' or 'N1' is a discount type.
	end
	
	def surcharge?()
		@discount_and_surcharge == 'N1' ? @discount_and_surcharge : false #N1 is the only valid surcharge type in EVS.
	end
	
	def is_military_box?()
		@mail_class == 'PM' and @rate_indicator == 'PM'  #Catch Priority Mail 'PM' (Military Box) which requires ZIP starting in 963 = Zone 8.
	end
	
	def is_dim_weight?()
		@mail_class == 'PM' and ['DR', 'DN'].include?(@rate_indicator)
	end
	
	def is_cubic?()
		@mail_class == 'PM' and ['CP', 'P5', 'P6', 'P7', 'P8', 'P9'].include?(@rate_indicator)
	end
end

#*********************************************************************************************************************************

class ServiceTypeCode #STC
	include File_Builder
	
	create_fields_using("#{$targetPath}/Reference Files/stcs.csv")
	#create_fields_using essentially provides the following functionality..
	#attr_accessor :service_type_code, :mail_class, :extra_service_code_1st_service, :extra_service_code_2nd_service, :extra_service_code_3rd_service, :extra_service_code_4th_service
	
	def initialize()
	end
	
	def assess_insurance()
		values = self.comb_values()
		return '0010000' if values.include?('930') #If extra service code 930 (insurance <= $200) is found, return manifest value for $100 ('0010000')
		return '0050000' if values.include?('931') #If extra service code 931 (insurance > $200) is found, return manifest value for $500 ('0050000')
		return false #If insurance values are not found, return false.
	end
	
	def assess_COD()
		return '0005000' if self.comb_values().include?('915') #If COD STC '915' is found, send COD Amount Due Sender to $50
		return false #If insurance values are not found, return false.
	end
end

#*********************************************************************************************************************************