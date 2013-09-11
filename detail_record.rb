require_relative 'file_builder'

class Detail_Record
	include File_Builder
	create_fields_using("#{$targetPath}/Reference Files/detail.csv")
	
	def initialize(manifest, rate, stc = nil)
		populate_values_from_baseline("#{$targetPath}/Reference Files/baseline.raw")
		self.instance_variables.each do |var|
			self.set(var, rate.get(var)) if rate.instance_variables.include?(var) #Update the detail record with rate information for each shared field
			self.set(var, stc.get(var)) if stc and stc.instance_variables.include?(var)   #Update the detail record with STC information for each shared field
		end
		generate_PIC(manifest, stc)
		generate_weight(rate)
		stc ? set_mailer_info(manifest.mailer, rate, stc) : set_mailer_info(manifest.mailer, rate)
		evaluate_extra_services(stc) if stc #Evaluate extra services if any STC object was passed for detail generation.
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
	
	def set_mailer_info(mailer, rate, stc = nil)
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

	def extra_services()
		extra_services_found = []
		(1..5).each do |number|
			position_text = {1 => '1st', 2 => '2nd', 3 => '3rd', 4 => '4th', 5 => '5th'} 
			code = self.send("extra_service_code_#{position_text[number]}_service")
			fee = self.send("extra_service_fee_#{position_text[number]}_service")
			extra_services_found << {'extra_service_code' => code, 'fee' => fee} unless code.size == 0 #If an extra service code is not blank ('   '), add it to array.
		end
		extra_services_found.empty? ? false : extra_services_found #Return false if no extra services found, otherwise return the extra service codes.
	end
end

#*********************************************************************************************************************************

class International_Detail_Record < Detail_Record #Need to inherit PIC and be able to modify it in accordance with International Mail Classes.
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
			@tracking_number = "83500#{rand(999999).to_s.rjust(6, '0')}"
			@barcode_construct_code = 'G01'
		when 'IE'
			@tracking_number = "EI100#{rand(999999).to_s.rjust(6, '0')}US"
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

class SBP_Detail_Record < Detail_Record
	def initialize(manifest, rate, stc)
		super(manifest, rate, stc)
	end
	
	def continue_build_options(rate)
		generate_zone(rate)
		generate_ZIP()
		evaluate_discounts_and_surcharges(rate)
		evaluate_dim_weight(rate)
		evaluate_cubic(rate)
		evaluate_military_box() if rate.is_military_box?
	end
	
	def set_mailer_info(mailer, rate, stc)
		@mail_owner_mailer_id = mailer.mid
		if /Return/.match(stc.description)
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
		@value_of_article = '0010000' if stc.comb_values.include?('930')
		@value_of_article = '0050000' if stc.comb_values.include?('931')
		@cod_amount_due_sender = '0005000' if stc.comb_values().include?('915')
	end
end