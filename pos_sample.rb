
class POS < Sample
	def initialize(manifest)
		super(manifest)
		set_file_names('.pos')
		generate_records()
		#build(self, ',') #Old POS version is comma separated
		build(self) #New POS is position-structured (no delimiter)
	end
end

#*********************************************************************************************************************************

class POS_Record < Sample_Record
	create_fields_using("#{$reference_file_path}/pos_fields.txt")
	
	def initialize(pos, detail)
		populate_values_from_baseline("#{$reference_file_path}/pos_baseline.pos")
		#Old version of POS
		#@pic = detail.tracking_number
		#@sample_date = pos.date
		#@actual_weight = convert_weight(detail.weight)
		#@delivery_zip_code = detail.destination_zip_code
		
		#New version of POS
		@file_number = "6612040002#{pos.date}#{pos.date}#{pos.time}"
		@acceptance_date = pos.date
		@acceptance_time = pos.time
		@service_type_code = '62'.ljust(4,' ') if detail.mail_class == 'PG' #GXG requires STC to be '62  ', spaces (default) for all other products.
		@label_id_1 = detail.tracking_number
		@origin_zip_code = pos.manifest.originZIP
		@destination_zip_code = detail.destination_zip_code
		@destination_country_code = detail.destination_country_code.ljust(2, ' ')
		@pounds, @ounces = convert_weight(detail.weight)
		@mail_class = detail.mail_class
		@rate_indicator = detail.rate_indicator
		@destination_rate_indicator = detail.destination_rate_indicator
		@mail_class.domestic? ? @zone = detail.domestic_zone[1] : @zone = ' '
		@surcharge_type = detail.surcharge_type.ljust(2, ' ')
		@surcharge_amount = detail.surcharge_amount
		@dimensions = "#{detail.length[0,3]}#{detail.height[1,2]}#{detail.width[1,2]}" #LLLWWHH, each detail dimension is formatted WWWDD where W is whole number and D is decimal
		
		extra_services = detail.extra_services #Returns false if no extra services found, otherwise returns array of extra service codes.
		#POS service code/fee fields are as follows (start at 6 for some reason based on formatting guide):
		#special_services_code_6, special_services_code_7, special_services_code_8, special_services_code_9, special_services_code_10
		if extra_services
			extra_services.each_with_index do |extra_service, index|
				self.send("special_services_code_#{index+6}=", extra_service['extra_service_code'].ljust(4, ' '))
			end
		end
		
		if ['FC', 'LC'].include?(@mail_class)
			if ['flat/large envelope'].include?(@rate_indicator) #Add in rate indicators
				@shape = '01'
			elsif ['letter', 'pc 2'].include?(@rate_indicator) #Add in rate indicators
				@shape = '02'
			elsif ['package'].include?(@rate_indicator) #Add in rate indicators
				@shape = '03'
			end
		end
	end
	
	def convert_weight(weight) #Needs to return 2-position pound value and 2-position ounce value
		pounds = weight[3, 2] #Pulls the 4th (X) and 5th (Y) digit from the format 000XYdddd where XY is the pounds and 'd' is the decimal portion of the eVS weight convention
		ounces = ((('0.' + weight[5, 4]).to_f)*16).round().to_s.rjust(2, '0')
		return pounds, ounces
	end
end