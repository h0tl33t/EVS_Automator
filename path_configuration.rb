
require 'fileutils'

module Path_Configuration
	include FileUtils
	class << self
		def set_paths() #Set necessary variables to allow for OCRA Executable to function on ACE Machines
			$targetPath = File.dirname(ENV['OCRA_EXECUTABLE'].to_s)
			$targetPath = File.expand_path($targetPath) if $targetPath == '.'
			$targetPath.gsub!(/\\/,'/')
			$evs_file_path = "#{$targetPath}/Generated EVS Files"
			$sbp_file_path = "#{$targetPath}/Generated SBP Files"
			$rate_validation_path = "#{$targetPath}/Rate Validations"
			$reference_file_path = "#{$targetPath}/Reference Files"
			$rate_table_path = "#{$reference_file_path}/Rate Tables"
		end
	
		def initialize_reference_directories()
			[$evs_file_path, $sbp_file_path, $rate_validation_path, $reference_file_path, $rate_table_path].each do |path|
				Dir.mkdir(path) unless File.directory?(path)
			end
		end
	
		def create_local_reference_files() #If the Reference Files folder has not yet been populated on current machine, copy all files from OCRA executable.
			ocra_temp_directory = File.dirname(__FILE__)
			ocra_reference_files = Dir.glob("#{ocra_temp_directory}/Reference Files/**/*")
			ocra_trimmed_file_paths = ocra_reference_files.map {|file| file = /Reference Files.*/.match(file).to_s}
			ocra_trimmed_file_paths.each_with_index do |file, index|
				target_file_path = "#{$targetPath}/#{file}"
				FileUtils.copy(ocra_reference_files[index],target_file_path) unless File.exists?(target_file_path)
			end
		end
	end
end