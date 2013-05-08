require_relative 'sample'
require_relative 'sample_record'

class STATS < Sample
	def initialize(manifest)
		super(manifest)
		@fileName = "#{$targetPath}/Generated EVS Files/STATS_#{@date}#{@time}#{@manifest.mail_class}.DAT"
		@semFileName = "#{$targetPath}/Generated EVS Files/STATS_#{@date}#{@time}#{@manifest.mail_class}.sem"
		generate_records()
		build(self)
	end
end

#*********************************************************************************************************************************

class STATS_Record < Sample_Record
	create_fields_using("#{$targetPath}/Reference Files/stats_fields.txt")
	
	def initialize(stats, detail, recordNumber)
		populate_values_from_baseline("#{$targetPath}/Reference Files/STATS_baseline.DAT")
		@test_date = stats.date
		@record_number = recordNumber.to_s.rjust(4, ' ')
		@sample_pounds, @sample_ounces = convert_weight(detail.weight)
		@sample_ounces = @sample_ounces.rjust(4, ' ')
		@mail_class, @mail_subclass = determine_class_data_for(detail.mail_class)
		@shape = determine_shape_for(detail.processing_category, detail.rate_indicator)
		@length = convert_dimension(detail.length).rjust(3, '0')
		@height = convert_dimension(detail.height).rjust(2, '0')
		@thickness = convert_dimension(detail.width).rjust(2, '0')
		@origin_zip_code = stats.manifest.originZIP
		@pic = detail.tracking_number
		@mailer_id = detail.mail_owner_mailer_id
		@destination_zip_code = detail.destination_zip_code
		@laptop_system_date = stats.date
		@marking = determine_marking_for(stats.manifest.mail_class)
	end
	
	#Re-format weight for STATS Files
	def convert_weight(weight)
		pounds = weight[2, 3] #Pulls the 3rd (X), 4th (Y) and 5th (Z) digit from the format 00XYZdddd where 'd' is the decimal portion of the eVS weight convention
		ounces = ((('0.' + weight[5, 4]).to_f)*16).round(1).to_s
		ounces = ounces.to_f.round().to_s.rjust(3, ' ') if ounces.size > 3
		return pounds, ounces
	end

	#Re-format dimensions for STATS Files
	def convert_dimension(value)
		wholeNum = value[0,3] #Pulls the whole number portion of the eVS dimension/size convention
		decimal = value[3, 2] #Pulls the decimal portion
		return "#{wholeNum}.#{decimal}".to_f.round.to_s
	end

	#Calculates STATS Value for Mail Class
	def determine_class_data_for(mailClass)
		if mailClass == 'FC'
			return '10' #Code for First Class Mail
		elsif mailClass == 'PM' or mailClass == 'CM'
			return '20' #Code for Priority Mail
		elsif mailClass == 'S2'
			return '40' #Code for Standard
		elsif mailClass == 'SA'
			return '90' #Code for Standard Non-Profit
		elsif mailClass == 'CP'
			return '7G' #Code for Priority Mail International
		elsif mailClass == 'LC'
			return '7K' #Code for FCPIS
		elsif mailClass == 'PG' or mailClass == 'IE'
			return '70' #Code for GxG or EMI
		elsif mailClass == 'BB'
			return '52' #Code for Bound Printed Matter
		elsif mailClass == 'BL'
			return '54' #Code for Library Mail
		elsif mailClass == 'BS'
			return '53' #Code for Media Mail
		elsif mailClass == 'RP'
			return '5I' #Code for PRS
		elsif mailClass == 'PS' or mailClass == 'LW'
			return '5H' #Code for Parcel Select
		else
			return '50' #Package Services Default
		end
	end

	#Determine Shape Value for STATS Samples, takes (Processing Category, Rate Indicator)
	def determine_shape_for(pc, ri)
		if pc == '1'
			return '3' if ri == 'E3' or ri == 'E4' #Flat Rate Envelope
			return '1'  #Letters
		elsif pc == '2'
			return '3' if ri == 'E3' or ri == 'E4' or ri == 'FE' #Flat Rate Envelope
			return 'I' if ri == 'E5' or ri == 'E6' or ri == 'E7' #Legal Flat Rate Envelope
			return '9' if ri == 'FP' #Flat Rate Padded Envelope
			return '2'  #Flats
		elsif pc == '3'
			return 'J' if ri == 'C6'
			return 'K' if ri == 'C7'
			return 'L' if ri == 'C8'
			return '8' if ri == 'E8' or ri == 'E9' or ri == 'EE' #Regular/Medium Flat Rate Box
			return '5' #Parcels
		elsif pc == '4'
			return '5' #Parcels
		elsif pc == '5'
			return '9' if ri == 'FP' #Flat Rate Padded Envelope
			return 'F' if ri == 'FS' #Small Flat Rate Box
			return '8' if ri == 'FB' #Regular/Medium Flat Rate Box
			return 'D' if ri == 'PL' #Large Flat Rate Box
			return 'E' if ri == 'PM' #Large Flat Rate Military Box
			return '5' #Parcels
		elsif pc == 'O'
			return '7' #PMOD/Pallets
		else
			return '0' #Default/Fill
		end
	end

	#Determine 'Marking' field value for STATS sample files
	def determine_marking_for(mailClass)  #Currently only handles LW, the rest are defaulted to '00'
		if mailClass == 'LW'
			return '36'
		else
			return '00'
		end
	end
end