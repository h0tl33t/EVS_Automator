
module Command_Generator
	class << self
		def generate_shell_commands()
			case set_file_type()
			when 'EVS'
				generate_evs_commands()
				puts "Generated shell commands for EVS."
			when 'SBP'
				generate_sbp_commands()
				puts "Generated shell commands for SBP."
			when 'ALL'
				generate_evs_commands()
				generate_sbp_commands()
				puts "Generated shell commands for EVS and SBP."
			end
		end
	
		def set_file_type()
			puts "Generate the SSH command for EVS, SBP, or all? (Enter 'EVS', 'SBP', or 'ALL')"
			type = gets.chomp.upcase
			while not ['EVS','SBP','ALL'].include?(type)
				puts "#{type} is not a valid entry, please re-enter either 'EVS', 'SBP', or 'ALL'."
				type = gets.chomp.upcase
			end
			return type
		end
		
		def generate_evs_commands()
			commands = determine_commands(Dir.glob("#{$evs_file_path}/*"), evs_match_guide)
			write_commands_to_file(commands, $evs_file_path)
		end
		
		def generate_sbp_commands()
			sbp_manifests = Dir.glob("#{$sbp_file_path}/*.raw")
			sbp_manifest_commands = determine_commands(sbp_manifests, sbp_match_guide)
			write_commands_to_file(sbp_manifest_commands, $sbp_file_path, '(SBP Manifests)')
			
			sbp_files = Dir.glob("#{$sbp_file_path}/*").delete_if {|file| /raw/.match(file)}
			sbp_file_commands = determine_commands(sbp_files, sbp_match_guide)
			write_commands_to_file(sbp_file_commands, $sbp_file_path)
		end
	
		def determine_commands(files, matches_with_paths)
			commands = []
			files.each do |file|
				matches_with_paths.each_pair do |match, target_path|
					commands << "cp -p #{/\S+\W/.match(File.basename(file))}* #{target_path}" if match =~ file
				end
			end
			return commands
		end
	
		def evs_match_guide()
			guide = {
				/.raw/ => "/pone/qpone/a03shared/CAT/evs/PTSManifest",
				/.evs/ => "/pone/qpone/a03shared/CAT/evs/STATS",
				/STATS.*dat/ => "/pone/qpone/a03shared/CAT/evs/STATS",
				/.pass/ => "/pone/qpone/a03shared/CAT/evs/STATS",
				/.pos/ => "/pone/qpone/a03shared/CAT/evs/STATS",
				/PTSExtract.*.dat/ => "/pone/qpone/a03shared/CAT/evs/PTSExtract",
				/PTSArrival.*.sem/ => "/pone/qpone/a03shared/CAT/evs/PTSExtract"}
		end
	
		def sbp_match_guide()
			guide = {
				/.raw/ => "/pone/qpone/a03shared/CAT/evs/PTSManifest",
				/PTS-SBP.*.dat/ => "/pone/qpone/a03shared/CAT/sbp/pts",
				/.evs/ => "/pone/qpone/a03shared/CAT/evs/STATS",
				/STATS.*dat/ => "/pone/qpone/a03shared/CAT/sbp/stats",
				/.pass/ => "/pone/qpone/a03shared/CAT/sbp/pass",
				/.pos/ => "/pone/qpone/a03shared/CAT/sbp/pts"}
		end
	
		def write_commands_to_file(commands, path, classifier = nil)
			puts "Writing the following shell commands for the files found at #{path}:"
			puts commands.join("\n")
			file = File.open("#{path}/shell_commands#{classifier}.txt", 'w')
			file.write(commands.join(" && "))
			file.close()
		end
	end
end