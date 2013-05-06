require './sample'
require './sample_record'
require './file_builder'

#Set necessary variables to allow for OCRA Executable to function on ACE Machines ************************************************
	$targetPath = File.dirname(ENV['OCRA_EXECUTABLE'].to_s)
	$targetPath.gsub!(/\\/,'/')
	$targetPath = File.expand_path($targetPath) if $targetPath == '.'
	Dir.chdir($targetPath)
	if $targetPath != '.'
		Dir.mkdir("#{$targetPath}/Generated EVS Files/") if File.directory?("#{$targetPath}/Generated EVS Files/") != true
	end
#*********************************************************************************************************************************

class IMD < Sample
	attr_accessor :facilityType, :shapes, :sortations 
	
	def initialize(manifest, facilityType)
		super(manifest)
		@facilityType = facilityType
		@shapes = load_data("#{$targetPath}/Reference Files/shapeIndicators.csv")
		@sortations = load_data("#{$targetPath}/Reference Files/sortationLevels.csv")
		@manifest.details.delete_if {|detail| detail.destination_rate_indicator != @facilityType}
		generate_records()
		#@manifest.details.each do |detail|
		#	imd_detail = IMD_Detail.new(self, detail)
		#	@details << imd_detail
		#end
		@records.insert(0, IMD_Header.new(@manifest, @facilityType))
		@sampleFileName = "#{@manifest.fileName}_IMD_#{@facilityType}.evs"
		@semFileName = "#{@manifest.fileName}_IMD_#{@facilityType}.sem"
		build(self)
	end
end

#*********************************************************************************************************************************

class IMD_Header < Sample_Record
	create_fields_using("#{$targetPath}/Reference Files/imd_header.txt")
	
	def initialize(manifest, facilityType)
		populate_values_from_baseline("#{$targetPath}/Reference Files/baseline.evs")
		@zip_code = manifest.header.entry_facility_zip_code
		@facility_type = convert_facility_type(facilityType)
		@system_date = "#{Time.now.strftime('%m%d%Y')}"
		@record_count = manifest.details.size.to_s.rjust(3, '0')
		@mailer_id = manifest.mailer.mid
	end
	
	def convert_facility_type(type)
		facilityTypes = {'D' => '1', 'S' => '2', 'B' => '3', 'F' => '4', 'N' => '5'} #DDU = D, SCF = S, NDC = B, ASF = F, None = N
		return facilityTypes[type]
	end
end

#*********************************************************************************************************************************

class IMD_Detail < Sample_Record
	create_fields_using("#{$targetPath}/Reference Files/imd_detail.txt")
	
	def initialize(imd, detail)
		populate_values_from_baseline("#{$targetPath}/Reference Files/baseline.evs")
		@weight = convert_weight(detail.weight)
		@length = convert_dimension(detail.length)
		@height = convert_dimension(detail.height)
		@width = convert_dimension(detail.width)
		@girth = convert_dimension(detail.dimensional_weight)
		@delivery_zip_code = detail.destination_zip_code
		@shape_based_rate_indicator = imd.shapes.find {|shape| shape == detail.rate_indicator} || 'NA'
		@sortation_level = imd.sortations.find {|sort| sort == detail.rate_indicator} || 'NA'
		@shape_based_rate_indicator, @sortation_level = check_for_special_cases(detail) if detail.mail_class == 'IE'
		@processing_category = detail.processing_category
		@package_size_and_other_criteria_indicator ||= 'N'
		detail.comb_values.include?('920') ? @delivery_confirmation = 'Y' : @delivery_confirmation = 'N' #Extra Service Code 920 is Delivery Confirmation
		detail.comb_values.include?('921') ? @signature_confirmation = 'Y' : @signature_confirmation = 'N' #Extra Service Code 921 is Signature Confirmation
		detail.comb_values.include?('910') ? @certified_mail = 'Y' : @certified_mail = 'N' #Extra Service Code 910 is Certified Mail
		detail.comb_values.include?('955') ? @return_receipts = 'Y' : @return_receipts = 'N' #Extra Service Code 955 is Return Receipt
		detail.comb_values.include?('960') ? @return_receipt_for_merchandise = 'Y' : @return_receipt_for_merchandise = 'N' #Extra Service Code 960 is Return Receipt for Merchandise
		detail.comb_values.include?('915') ? @cod = 'Y' : @cod = 'N' #Extra Service Code 915 is Cash on Delivery (COD)
		@value_of_cod = convert_dollars(detail.cod_amount_due_sender) if @cod == 'Y'
		detail.comb_values.include?('950') ? @restricted_delivery = 'Y' : @restricted_delivery = 'N' #Extra Service Code 910 is Restricted Delivery
		detail.comb_values.include?('970') ? @special_handling_less_than_10 = 'Y' : @special_handling_less_than_10 = 'N' #Extra Service Code 970 is Special Handling
		detail.comb_values.include?('970') ? @special_handling_more_than_10 = 'Y' : @special_handling_more_than_10 = 'N' #Extra Service Code 970 is Special Handling
		detail.comb_values.include?('930') ? (@insured, @insurance_less_than_200 = '2', 'Y') : (@insured, @insurance_less_than_200 = '0', 'N') ##Extra Service Codes 930 is Insurance Less Than 200
		detail.comb_values.include?('931') ? (@insured, @insurance_more_than_200 = '2', 'Y') : (@insured, @insurance_more_than_200 = '0', 'N') ##Extra Service Codes 930 is Insurance Less Than 200
		@mail_class = detail.mail_class
		@comments = ''.rjust(240, ' ')
		@destination_country_code = detail.destination_country_code.rjust(2,' ')
		@scan_date_time = "#{Time.now.strftime('%m%d%Y')}#{imd.manifest.time}"
		detail.comb_values.include?('957') ? @return_receipt_electronic = 'Y' : @return_receipt_electronic = 'N' #Extra Service Code 957 is Return Receipt Electronic (RRE)
		check_if_merchandise_return(detail.service_type_code) ? @merchandise_return = 'Y' : @merchandise_return = 'N'
		detail.comb_values.include?('922') ? @adult_signature = 'Y' : @adult_signature = 'N' #Extra Service Code 921 is Adult Signature
		detail.comb_values.include?('985') ? @hold_for_pick_up = 'Y' : @hold_for_pick_up = 'N' #Extra Service Code 921 is Hold for Pick Up
		detail.comb_values.include?('990') ? @day_certain_delivery = 'Y' : @day_certain_delivery = 'N' #Extra Service Code 921 is Day Certain Delivery
	end
	
	def convert_weight(weight)
		wholeNum = weight[3, 2] #Pulls the 4th (X) and 5th (Y) digit from the format 000XYdddd where 'd' is the decimal portion of the eVS weight convention
		decimal = weight[5, 4]  #Pulls the decimal portion
		return "#{wholeNum}.#{decimal}"
	end
	
	def convert_dimension(size)
		wholeNum = size[0,3] #Pulls the whole number portion of the eVS dimension/size convention
		decimal = size[3, 2] #Pulls the decimal portion
		return "#{wholeNum}.#{decimal}".ljust(7, '0')
	end
	
	def convert_dollars(value)
		wholeNum = value[0,3] #Pulls the whole number portion of the eVS dimension/size convention
		decimal = value[3, 3] #Pulls the decimal portion
		return "#{wholeNum}.#{decimal}".rjust(8, '0')
	end
	
	def check_if_merchandise_return(stc) #List of all return type STCs.
		['056','117','162','396','402','467','473','528','534','589','595','667','668','669','670','671','672','673','674','675','676','677','678'].include?(stc)
	end
	
	def check_for_special_cases(detail) #Returns Shape, Sortation
		return 'F4', 'NA' if detail.rate_indicator == 'E4'
		return 'F6', 'NA' if detail.rate_indicator == 'E6'
		return 'F8', 'NA' if detail.rate_indicator == 'E8'
		return 'NA', 'PA' if detail.rate_indicator == 'PA'
	end
end