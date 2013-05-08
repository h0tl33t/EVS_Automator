require_relative 'sample'
require_relative 'sample_record'

class POS < Sample
	def initialize(manifest)
		super(manifest)
		@fileName = "#{$targetPath}/Generated EVS Files/TRP_P1PRS_OUT_#{@date}#{@manifest.mail_class}.pos"
		@semFileName = "#{$targetPath}/Generated EVS Files/TRP_P1PRS_OUT_#{@date}#{@manifest.mail_class }.sem"
		generate_records()
		build(self, ',')
	end
end

#*********************************************************************************************************************************

class POS_Record < Sample_Record
	create_fields_using("#{$targetPath}/Reference Files/pos_fields.txt")
	
	def initialize(pos, detail)
		populate_values_from_baseline("#{$targetPath}/Reference Files/pos_baseline.pos")
		@pic = detail.tracking_number
		@sample_date = pos.date
		@actual_weight = convert_weight(detail.weight)
		@delivery_zip_code = detail.destination_zip_code
	end
end