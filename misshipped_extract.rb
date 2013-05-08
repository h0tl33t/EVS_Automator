require_relative 'sample'
require_relative 'sample_record'

#Set necessary variables to allow for OCRA Executable to function on ACE Machines ************************************************
	$targetPath = File.dirname(ENV['OCRA_EXECUTABLE'].to_s)
	$targetPath.gsub!(/\\/,'/')
	$targetPath = File.expand_path($targetPath) if $targetPath == '.'
	Dir.chdir($targetPath)
	if $targetPath != '.'
		Dir.mkdir("#{$targetPath}/Generated EVS Files/") if File.directory?("#{$targetPath}/Generated EVS Files/") != true
	end
#*********************************************************************************************************************************

class Misshipped_Extract < Sample
	def initialize(manifest)
		super(manifest)
		@fileName = "#{$targetPath}/Generated EVS Files/PTSExtract_Misship#{@date}_#{@manifest.mail_class}.dat"
		@semFileName = "#{$targetPath}/Generated EVS Files/PTSArrival_Misship#{@date}_#{@manifest.mail_class}.sem"
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