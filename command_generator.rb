#Unix SSH Copy Command Generator

class Command_Generator
	def initialize()
		puts "Generate the SSH command for EVS, SBP, or all? (Enter 'EVS', 'SBP', or 'ALL')"
		type = gets.chomp.upcase
		while not ['EVS','SBP','ALL'].include?(type)
			puts "#{type} is not a valid entry, please re-enter either 'EVS', 'SBP', or 'ALL'."
			type = gets.chomp.upcase
		end

		case type
		when 'EVS'
			commGen('Generated EVS Files') #Pass the name of the sub-folder containing the files.
		when 'SBP'
			commGen('Generated SBP Files') #Pass the name of the sub-folder containing the files.
		when 'ALL'
			commGen('Generated EVS Files') #Pass the name of the sub-folder containing the files.
			commGen('Generated SBP Files') #Pass the name of the sub-folder containing the files.
		end
		exit()
	end
	#*********************************************************************************************************************************
	def commGen(targetFolder)
		fullPath = "#{$targetPath}/#{targetFolder}"
		puts "Found #{fullPath}!" if File.exists?(fullPath)
		foundSBPManifests = false
		wrote = false
		sbpWrote = false
		count = 0
		
		manifests = Dir.glob("#{fullPath}/*.raw")
		imds = Dir.glob("#{fullPath}/*.evs")
		stats = Dir.glob("#{fullPath}/STATS*.dat")
		pass = Dir.glob("#{fullPath}/*.pass")
		pos = Dir.glob("#{fullPath}/*.pos")
		sbpFiles = Dir.glob("#{fullPath}/PTS-SBP*.dat")
		extracts = Dir.glob("#{fullPath}/PTSExtract*.dat")
		extractSems = Dir.glob("#{fullPath}/PTSArrival*.sem")

		File.delete("#{fullPath}/shellCommand.txt") if File.exists?("#{fullPath}/shellCommand.txt") #Delete any existing shellCommand files.
		File.delete("#{fullPath}/shellCommand(SBPManifests).txt") if File.exists?("#{fullPath}/shellCommand(SBPManifests).txt") #Delete any existing shellCommand files.
		commandFile = File.open("#{fullPath}/shellCommand.txt",'w')
		sbpManCommFile, foundSBPManifests = File.open("#{fullPath}/shellCommand(SBPManifests).txt",'w'), true if targetFolder == 'Generated SBP Files' and manifests.empty? != true
		
		puts "*****************************************************************"
		puts "Core file name(s) for file(s) found:"
		manifests.each do |manifestFile|
			count = count + 1
			file = /\S+\W/.match(File.basename(manifestFile)).to_s.delete('.')
			puts "#{count}) #{file}"
			if targetFolder == 'Generated EVS Files'
				commandFile.write(" && ") if wrote
				commandFile.write("cp -p #{file}.* /pone/qpone/a03shared/CAT/evs/PTSManifest")
				wrote = true
			end
			
			if foundSBPManifests
				sbpManCommFile.write(" && ") if sbpWrote
				sbpManCommFile.write("cp -p #{file}.* /pone/qpone/a03shared/CAT/evs/PTSManifest") if targetFolder == 'Generated SBP Files'
				sbpWrote = true
			end
		end

		imds.each do |imdFile|
			count = count + 1
			file = /\S+\W/.match(File.basename(imdFile)).to_s.delete('.')
			puts "#{count}) #{file}"
			commandFile.write(" && ") if wrote
			commandFile.write("cp -p #{file}.* /pone/qpone/a03shared/CAT/evs/STATS")
			wrote = true
		end
		
		stats.each do |statsFile|
			count = count + 1
			file = /\S+\W/.match(File.basename(statsFile)).to_s.delete('.')
			puts "#{count}) #{file}"
			commandFile.write(" && ") if wrote
			commandFile.write("cp -p #{file}.* /pone/qpone/a03shared/CAT/evs/STATS") if targetFolder == 'Generated EVS Files'
			commandFile.write("cp -p #{file}.* /pone/qpone/a03shared/CAT/sbp/stats") if targetFolder == 'Generated SBP Files'
			wrote = true
		end
		
		pass.each do |passFile|
			count = count + 1
			file = /\S+\W/.match(File.basename(passFile)).to_s.delete('.')
			puts "#{count}) #{file}"
			commandFile.write(" && ") if wrote
			commandFile.write("cp -p #{file}.* /pone/qpone/a03shared/CAT/evs/STATS") if targetFolder == 'Generated EVS Files'
			commandFile.write("cp -p #{file}.* /pone/qpone/a03shared/CAT/sbp/pass") if targetFolder == 'Generated SBP Files'
			wrote = true
		end
		
		pos.each do |posFile|
			count = count + 1
			file = /\S+\W/.match(File.basename(posFile)).to_s.delete('.')
			puts "#{count}) #{file}"
			commandFile.write(" && ") if wrote
			commandFile.write("cp -p #{file}.* /pone/qpone/a03shared/CAT/evs/STATS") if targetFolder == 'Generated EVS Files'
			commandFile.write("cp -p #{file}.* /pone/qpone/a03shared/CAT/sbp/pts") if targetFolder == 'Generated SBP Files'
			wrote = true
		end
		
		sbpFiles.each do |sbpFile|
			count = count + 1
			file = /\S+\W/.match(File.basename(sbpFile)).to_s.delete('.')
			puts "#{count}) #{file}"
			commandFile.write(" && ") if wrote
			commandFile.write("cp -p #{file}.* /pone/qpone/a03shared/CAT/sbp/pts")
			wrote = true
		end
		
		extracts.each do |extract|
			count = count + 1
			file = /\S+\W/.match(File.basename(extract)).to_s.delete('.')
			puts "#{count}) #{file}"
			commandFile.write(" && ") if wrote
			commandFile.write("cp -p #{file}.* /pone/qpone/a03shared/CAT/evs/PTSExtract")
			wrote = true
		end
		
		extractSems.each do |sem|
			count = count + 1
			file = /\S+\W/.match(File.basename(sem)).to_s.delete('.')
			puts "#{count}) #{file}"
			commandFile.write(" && ") if wrote
			commandFile.write("cp -p #{file}.* /pone/qpone/a03shared/CAT/evs/PTSExtract")
			wrote = true
		end
		puts "*****************************************************************"
		commandFile.close()
		sbpManCommFile.close() if foundSBPManifests
		puts "Wrote shell commands to #{fullPath}/shellCommand.txt!" if targetFolder == 'Generated EVS Files' or not foundSBPManifests
		puts "Wrote shell commands to #{fullPath}/shellCommand.txt and shellCommand(SBPManifests).txt!" if foundSBPManifests
	end
	#*********************************************************************************************************************************
end