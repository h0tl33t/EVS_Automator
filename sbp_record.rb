
class SBP_Record
	include File_Builder
	
	create_fields_using("#{$reference_file_path}/sbp_fields.txt")
	
	def initialize(sbp_file, detail = nil)
		populate_values_from_baseline("#{$reference_file_path}/sbp_baseline.dat")
		@date = Time.now.strftime('%m/%d/%Y')
		@time = Time.now.strftime('%H.%M.%S')
		detail ? @tracking_number = detail.tracking_number : @tracking_number = generate_PIC(sbp_file)
		@event_code = sbp_file.event.event_code
		@entry_facility_zip = sbp_file.originZIP
		detail ? @destination_zip_code = detail.destination_zip_code : @destination_zip_code = rand(10000..99999).to_s
		if is_sample?(sbp_file.event.event_code)
			@weight = detail.weight
			@length = detail.length
			@height = detail.height
			@width = detail.width
			@dim_weight = detail.dimensional_weight
		end
		if ['MA','MR'].include?(sbp_file.event.event_code) and sbp_file.manifest
			@overlabel = sbp_file.manifest.header.electronic_file_number.rjust(34, ' ')
		end
	end
	
	def generate_PIC(sbp_file)
		@tracking_number = "420#{sbp_file.originZIP}000092#{sbp_file.stc.service_type_code}#{sbp_file.mailer.mid}#{rand(99999999).to_s.rjust(8, '0')}"
	end
	
	def is_sample?(event_code)
		event_code == '03'
	end
	
	def format_fields() #Ensure each SBP field is surrounded in quotes.
		self.instance_variables.each do |var|
			self.instance_variable_set(var, "\"#{self.instance_variable_get(var)}\"") unless self.instance_variable_get(var).include?("\"")
		end
	end
end

