
class Misshipped_Extract < Sample
	def initialize(manifest)
		super(manifest)
		set_file_names('.dat')
		generate_records()
		build(self)
	end
end

#*********************************************************************************************************************************

class Misshipped_Extract_Record < Sample_Record
	create_fields_using("#{$targetPath}/Reference Files/misshipped_fields.txt")
	
	def initialize(extract, detail)
		populate_values_from_baseline("#{$targetPath}/Reference Files/misshipped_baseline.dat")
		@pic = detail.tracking_number[12,22]
		@filler_60 = ''.ljust(60, ' ')
		@destination_zip_code = rand(10000..99999).to_s
		@filler_31 = ''.ljust(31, ' ')
		@filler_20 = ''.ljust(20, ' ')
		@date = extract.date
		@time = Time.now.strftime('%H%M')
		@filler_28 = ''.ljust(28, ' ')
	end
end