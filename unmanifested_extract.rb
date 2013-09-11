
class Unmanifested_Extract < Sample
	def initialize(manifest)
		super(manifest)
		set_file_names('.dat')
		modify_pics_for(@manifest)
		generate_records()
		build(self)
	end
	
	def modify_pics_for(manifest) #Change manifested PICs to random PICs for unmanifested processing.
		manifest.details.each do |detail|
      detail.mail_class.domestic? ? detail.tracking_number[26,8] = rand(1..99999999).to_s.ljust(8, '0') : detail.tracking_number[5,6] = rand(999999).to_s.rjust(6, '0')
		end
	end	
end

#*********************************************************************************************************************************

class Unmanifested_Extract_Record < Sample_Record
	create_fields_using("#{$targetPath}/Reference Files/unmanifested_fields.txt")
	
	def initialize(extract, detail)
		populate_values_from_baseline("#{$targetPath}/Reference Files/unmanifested_baseline.dat")
    @pic = detail.tracking_number.ljust(34, ' ')
		@filler_60 = ''.ljust(48, ' ')
		@destination_zip_code = rand(10000..99999).to_s
		@filler_33 = ''.ljust(33, ' ')
		@filler_13 = ''.ljust(13, ' ')
		@date = extract.date
		@time = Time.now.strftime('%H%M')
		@filler_28 = ''.ljust(28, ' ')
    @mailer_id = detail.mail_owner_mailer_id unless detail.mail_class.domestic?
	end
end