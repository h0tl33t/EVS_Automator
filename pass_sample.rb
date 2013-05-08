require_relative 'sample'
require_relative 'sample_record'

class PASS < Sample
	def initialize(manifest)
		super(manifest)
		@fileName = "#{$targetPath}/Generated EVS Files/TRP_P1EVS_OUT_#{@date}#{@manifest.mail_class}.pass"
		@semFileName = "#{$targetPath}/Generated EVS Files/TRP_P1EVS_OUT_#{@date}#{@manifest.mail_class}.sem"
		generate_records()
		build(self, ',')
	end
end

#*********************************************************************************************************************************

class PASS_Record < Sample_Record
	create_fields_using("#{$targetPath}/Reference Files/pass_fields.txt")
	
	def initialize(pass, detail)
		populate_values_from_baseline("#{$targetPath}/Reference Files/PASS_baseline.pass")
		@destination_facility_type = detail.destination_rate_indicator
		@facility_zip = pass.manifest.originZIP
		@date_of_assessment = pass.date
		@time_of_assessment = pass.time
		@pic = detail.tracking_number
		@destination_zip_code = detail.destination_zip_code
		@mail_class = detail.mail_class
		@usps_product = detail.rate_indicator
		@actual_weight = convert_weight(detail.weight)
		@length = convert_dimension(detail.length)
		@height = convert_dimension(detail.height)
		@width = convert_dimension(detail.width)
		@cubic_rate = 'Y' if @length.to_f > 0 #Any piece that has a dimension greater than 0 is a cubic piece.
	end
	
	def convert_dimension(value)
		wholeNum = value[1,2] #Pulls the whole number portion from 00 to 99 of the eVS dimension/size convention
		decimal = value[3, 2] #Pulls the decimal portion
		return "#{wholeNum}.#{decimal}"
	end
end