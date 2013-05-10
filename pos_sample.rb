
class POS < Sample
	def initialize(manifest)
		super(manifest)
		set_file_names('.pos')
		generate_records()
		build(self, ',')
	end
end

#*********************************************************************************************************************************

class POS_Record < Sample_Record
	create_fields_using("#{$reference_file_path}/pos_fields.txt")
	
	def initialize(pos, detail)
		populate_values_from_baseline("#{$reference_file_path}/pos_baseline.pos")
		@pic = detail.tracking_number
		@sample_date = pos.date
		@actual_weight = convert_weight(detail.weight)
		@delivery_zip_code = detail.destination_zip_code
	end
end