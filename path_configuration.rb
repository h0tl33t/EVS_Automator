
require 'fileutils'

module Path_Configuration
	include FileUtils

	def self.set_paths() #Set necessary variables to allow for OCRA Executable to function on ACE Machines
		$targetPath = File.dirname(ENV['OCRA_EXECUTABLE'].to_s)
		$targetPath = File.expand_path($targetPath) if $targetPath == '.'
		$targetPath.gsub!(/\\/,'/')
		$evs_file_path = "#{$targetPath}/Generated EVS Files"
		$sbp_file_path = "#{$targetPath}/Generated SBP Files"
		$reference_file_path = "#{$targetPath}/Reference Files"
		$rate_table_path = "#{$reference_file_path}/Rate Tables"
	end
	
	def self.initialize_reference_directories()
		if $targetPath != '.'
			Dir.mkdir("#{$targetPath}/Generated EVS Files/") if File.directory?("#{$targetPath}/Generated EVS Files/") != true
			Dir.mkdir("#{$targetPath}/Generated SBP Files/") if File.directory?("#{$targetPath}/Generated SBP Files/") != true
			Dir.mkdir("#{$targetPath}/Rate Validations/") if File.directory?("#{$targetPath}/Rate Validations/") != true
			Dir.mkdir("#{$targetPath}/Reference Files/") if File.directory?("#{$targetPath}/Reference Files/") != true
			Dir.mkdir("#{$targetPath}/Reference Files/rateTables/") if File.directory?("#{$targetPath}/Reference Files/rateTables/") != true
		end
	end
	
	def self.create_local_reference_files() #If the Reference Files folder has not yet been populated on current machine, copy all files from OCRA executable.
		ocra_temp_directory = File.dirname(__FILE__)
		ocra_reference_files = Dir.glob("#{ocra_temp_directory}/Reference Files/**/*")
		ocra_trimmed_file_paths = ocra_reference_files.map {|file| file = /Reference Files.*/.match(file).to_s}
		ocra_trimmed_file_paths.each_with_index do |file, index|
			target_file_path = "#{$targetPath}/#{file}"
			FileUtils.copy(ocra_reference_files[index],target_file_path) unless File.exists?(target_file_path)
		end
	end
end