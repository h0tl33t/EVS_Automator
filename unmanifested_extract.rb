require_relative 'sample'
require_relative 'sample_record'

class Unmanifested_Extract < Sample
	def initialize(manifest)
		super(manifest)
		@fileName = "#{$targetPath}/Generated EVS Files/PTSExtractWkly-Unman#{@date}_#{@manifest.mail_class}.dat"
		@semFileName = "#{$targetPath}/Generated EVS Files/PTSArrivalWkly-Unman#{@date}_#{@manifest.mail_class}.sem"
		modify_pics_for(@manifest)
		generate_records()
		build(self)
	end
	
	def modify_pics_for(manifest) #Change manifested PICs to random PICs for unmanifested processing.
		manifest.details.each do |detail|
			detail.tracking_number[26,8] = rand(1..99999999).to_s.ljust(8, '0')
		end
	end	
end

#*********************************************************************************************************************************

class Unmanifested_Extract_Record < Sample_Record
	create_fields_using("#{$targetPath}/Reference Files/unmanifested_fields.txt")
	
	def initialize(extract, detail)
		populate_values_from_baseline("#{$targetPath}/Reference Files/unmanifested_baseline.dat")
		@pic = detail.tracking_number[12,22]
		@filler_60 = ''.ljust(60, ' ')
		@destination_zip_code = rand(10000..99999).to_s
		@filler_33 = ''.ljust(33, ' ')
		@filler_13 = ''.ljust(13, ' ')
		@date = extract.date
		@time = Time.now.strftime('%H%M')
		@filler_28 = ''.ljust(28, ' ')
	end
end