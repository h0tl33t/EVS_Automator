require_relative 'file_builder'

#Set necessary variables to allow for OCRA Executable to function on ACE Machines ************************************************
	$targetPath = File.dirname(ENV['OCRA_EXECUTABLE'].to_s)
	$targetPath.gsub!(/\\/,'/')
	$targetPath = File.expand_path($targetPath) if $targetPath == '.'
	Dir.chdir($targetPath)
#*********************************************************************************************************************************

class HeaderRecord
	include File_Builder
	create_fields_using("#{$targetPath}/Reference Files/header.csv")
	
	def initialize(manifest)
		populate_values_from_baseline("#{$targetPath}/Reference Files/baseline.raw")
		@electronic_file_number = generate_EFN(manifest.mailer.mid)
		@electronic_file_type = manifest.type
		@date_of_mailing = manifest.date
		@time_of_mailing = manifest.time
		@entry_facility_zip_code = manifest.originZIP
		@transaction_id = "#{manifest.date}0000"
		@file_record_count = manifest.size.to_s.rjust(9, '0')
		@mailer_id = manifest.mailer.mid
	end
	def generate_EFN(mid)
		return "92750#{mid}#{rand(99999999).to_s.rjust(8, '0')}"
	end
end