require_relative 'sample'
require_relative 'sample_record'

class Duplicate_Package_Extract < Sample
	def initialize(manifest)
		super(manifest)
		set_file_names('.dat')
		generate_records()
    update_record_counts
		build(self)
	end
  
  def update_record_counts
    count = @records.size > 999 ? '999' : @records.size.to_s.rjust(3, ' ')
    @records.each {|record| record.record_count = count }
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
		@pic = detail.tracking_number.ljust(34, ' ')
		@electronic_file_number = extract.manifest.header.electronic_file_number.ljust(34, ' ')
		@event_zip = rand(10000..99999).to_s
		@mailer_id = detail.mail_owner_mailer_id
	end
end