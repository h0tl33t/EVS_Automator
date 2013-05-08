require_relative 'sample'
require_relative 'sample_record'

class Duplicate_Package_Extract < Sample
	def initialize(manifest)
		super(manifest)
		@fileName = "#{$targetPath}/Generated EVS Files/PTSExtractManDup#{@date}_#{@manifest.mail_class}.dat"
		@semFileName = "#{$targetPath}/Generated EVS Files/PTSExtractManDup#{@date}_#{@manifest.mail_class}.sem"
		generate_records()
		build(self)
	end
end

#*********************************************************************************************************************************

class Duplicate_Package_Extract_Record < Sample_Record
	create_fields_using("#{$targetPath}/Reference Files/duplicate_package_fields.txt")
	
	def initialize(extract, detail)
		populate_values_from_baseline("#{$targetPath}/Reference Files/duplicate_package_baseline.dat")
		@event_type = ['01','16'].sample #Event types for duplicate package are either '01' or '16' -- set at random w/ sample().
		@event_date = extract.date
		@event_time = Time.now.strftime('%H%M')
		@pic = detail.tracking_number
		@electronic_file_number = extract.manifest.header.electronic_file_number.ljust(34, ' ')
		@event_zip = rand(10000..99999).to_s
		@mailer_id = detail.mail_owner_mailer_id
	end
end