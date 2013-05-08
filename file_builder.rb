
module File_Builder
	def self.included(base)
		base.extend(ClassMethods)
	end
	#*********************************************************************************************************************************
	def populate_values_from_baseline(fileName)
		baselineFile = File.open(fileName, 'r')
		values = baselineFile.readlines[0].chomp.split('|') unless self.class.name.match(/Detail/) #Read header or single-format baseline records.
		values = baselineFile.readlines[1].chomp.split('|') if self.class.name.match(/Detail/)
		
		setter_methods_to_call = (self.methods - self.class.methods).grep(/=/)
		setter_methods_to_call.each_with_index do |method, i|
			self.send(method, values[i])
		end
		baselineFile.close()
	end
	#*********************************************************************************************************************************
	def load_data(fileName) #Takes a one-line csv reference file and returns the data in an array.
		dataFile = File.open(fileName, 'r')
		data_as_array = dataFile.readline.chomp.split(',')
		dataFile.close()
		return data_as_array
	end
	#*********************************************************************************************************************************
	def load_rate_ingredients(klass, fileName, mailClass)
		ingredients = []
		file = File.open(fileName, 'r')
		bulkLines = file.readlines
		splitLines = []
		bulkLines.each do |line|
			splitLines << line.chomp.split(',')
		end
		splitLines.delete_at(0) #Delete the 1st row which just contains field names
		splitLines.each do |ingredient|
			tempIngredient = klass.new
			ingredient.each_with_index do |value, index|
				tempIngredient.send((tempIngredient.methods - tempIngredient.class.methods).grep(/=/)[index], value)
			end
			ingredients << tempIngredient if tempIngredient.mail_class == mailClass
		end
		return ingredients
	end
	#*********************************************************************************************************************************
	def set(target, value)
		self.send("#{target.to_s.delete('@')}=", value)
	end
	#*********************************************************************************************************************************	
	def get(target)
		self.send("#{target.to_s.delete('@')}")
	end
	#*********************************************************************************************************************************
	def comb_values()
		values = []
		self.instance_variables.each do |var|
			values << self.get(var)
		end
		return values
	end
	#*********************************************************************************************************************************
	def generate_EFN(mid)
		return "92750#{mid}#{rand(99999999).to_s.rjust(8, '0')}"
	end
	#*********************************************************************************************************************************
	#Filename Generator
	def generate_file_name(klass, mail_class, date, time, *trim)
		if klass == Manifest
			if trim[0] == 'r'
				return "#{$targetPath}/Generated EVS Files/autogenerated_#{mail_class}_#{date}_RateTest"
			else
				return "#{$targetPath}/Generated EVS Files/autogenerated_#{mail_class}_#{date}#{time}"
			end
		#Include other file types and their file naming conventions.
		end
	end
	#*********************************************************************************************************************************
	def validate(value, &validation)
		while not validation.call(value)
			upcased = (value == value.upcase)
			downcased = (value == value.downcase)
			puts "#{value} is not a valid entry.  Please re-enter a valid value:"
			value = gets.chomp
			value.upcase if upcased
			value.downcase if downcased
		end
		return value
	end
	#*********************************************************************************************************************************
	def test_output()
		output = ''
		self.instance_variables.each do |var|
			output = output + (self.send(var.to_s.delete('@')) || '') + '|'
		end
		return output
	end
	#*********************************************************************************************************************************
	def build_raw()
		header = self.header.test_output
		details = []
		self.details.each do |detail|
			details << detail.test_output
		end
		manifest = File.open("#{self.fileName}.raw", 'w')
		manifest.write(header)
		details.each do |detail|
			manifest.write("\n")
			manifest.write(detail)
		end
		manifest.close()
	end
	#*********************************************************************************************************************************
	def build_cew()
		cewFields = [self.mailer.mid, self.header.electronic_file_number[14..21], self.date, self.time, self.originZIP, self.date, self.size.to_s, '0', self.size.to_s, self.details.size.to_s, ''] 
		cew = File.open("#{self.fileName}.cew", 'w')
		cewFields.each do |val|
			cew.write(val + ',')
		end
		cew.close()
	end
	#*********************************************************************************************************************************
	def build_sem()
		sem = File.open("#{self.fileName}.sem", 'w')
		sem.close()
	end
	#*********************************************************************************************************************************		
	def exit()
		puts "Press any key to exit the program."
		prompt()
		gets()
	end
	#*********************************************************************************************************************************
	def prompt()
		print "> "
	end
	#*********************************************************************************************************************************
	module ClassMethods
		def create_fields_using(fileName)
			file = File.open(fileName, 'r')
			fields = file.readline.chomp.split(',')
			fields.map! {|field| format_instance_variable_name(field)}
			self.class_eval do
				fields.each do |fieldAsVariable|
					define_method "#{fieldAsVariable}=" do |value|  #Define setter method for each field pulled from reference file (.csv)
						instance_variable_set("@#{fieldAsVariable}", value)
					end
					define_method "#{fieldAsVariable}" do
						instance_variable_get("@#{fieldAsVariable}")
					end
				end
				file.close()
				return fields
			end
		end
	#*********************************************************************************************************************************
		def format_instance_variable_name(name)
			name.downcase.gsub(' ', '_').gsub('-', '_').gsub('+', 'plus').delete('()')
		end
	#*********************************************************************************************************************************
=begin
	#*********************************************************************************************************************************
	#Method to Handle Extracts
	def buildExtracts()
		puts "Would you like to build any extracts (mis-shipped, duplicate package, or un-manifested)? (Y/N)"
		prompt
		choice = gets.chomp.upcase
		if choice == 'Y'
			puts "Enter the number of the extract you would like to build:"
			puts "1) Mis-Shipped"
			puts "2) Duplicate Package"
			puts "3) Un-manifested"
			prompt
			extract = gets.chomp
			while not ['1','2','3'].include?(extract)
				puts "#{extract} is not a valid entry.  Please enter 1, 2, or 3."
				prompt
				extract = gets.chomp
			end
			
			extract = extract.to_i
			case extract
			when 1
				buildMisshipped()
			when 2
				buildDupPackage()
			when 3
				buildUnmanifested()
			end
		end
	end
	#*********************************************************************************************************************************
	#Mis-Shipped Extract Builder
	def buildMisshipped()
		dduDetails = []
		first = true
		details = pullDetails() #sample(5) #Limit extract to 5 records which are sampled at random.  Using all detail records would clutter the extract reports.
		details.each do |d|
			dduDetails << d if d['Destination Rate Indicator'] == 'D'
			puts "#{d['Tracking Number']} has DRI #{d['Destination Rate Indicator']}(should be 'D')." if d['Destination Rate Indicator'] == 'D'
		end
		puts dduDetails.size
		dduDetails = dduDetails.sample(5) if dduDetails.size > 5
		extractFile = File.open("#{$targetPath}\\Generated EVS Files\\PTSExtract_Misship#{@date}_#{@mailClass}.dat", 'w')
		dduDetails.each do |d|
			extractFile.write("\n") if not first
			extractFile.write("#{d['Tracking Number'][12,22]}#{' '.ljust(60, ' ')}#{rand(10000..99999)}#{' '.ljust(31, ' ')}15TEST-MISSHIPD PARCEL#{' '.ljust(20, ' ')}#{@date}#{Time.now.strftime('%H%M')}#{' '.ljust(28,' ')}")
			first = false
		end
		extractFile.close()
		extractSem = File.open("#{$targetPath}\\Generated EVS Files\\PTSArrival_Misship#{@date}_#{@mailClass}.sem", 'w')
		extractSem.close()
		puts "Built mis-shipped extract (.dat/.sem) for #{@mailClass}!"
	end
	#*********************************************************************************************************************************
	#Duplicate Package Extract Builder
	def buildDupPackage()
		details = pullDetails().sample(5) #Limit extract to 5 records which are sampled at random.  Using all detail records would clutter the extract reports.
		first = true
		extractFile = File.open("#{$targetPath}\\Generated EVS Files\\PTSExtractManDup#{@date}_#{@mailClass}.dat", 'w')
		details.each do |d|
			extractFile.write("\n") if not first
			extractFile.write("#{['01','16'].sample}#{@date}#{Time.now.strftime('%H%M')}#{d['Tracking Number']}#{@efn.ljust(34, ' ')}#{rand(10000..99999)}    #{@mid}")
			first = false
		end
		extractFile.close()
		extractSem = File.open("#{$targetPath}\\Generated EVS Files\\PTSExtractManDup#{@date}_#{@mailClass}.sem", 'w')
		extractSem.close()
		puts "Built duplicate package extract (.dat/.sem) for #{@mailClass}!"
	end
	#*********************************************************************************************************************************
	#Un-manifested Extract Builder
	def buildUnmanifested()
		stc = getBaseSTC(@mailClass)
		pic = picGen(stc)
		first = true
		extractFile = File.open("#{$targetPath}\\Generated EVS Files\\PTSExtractWkly-Unman#{@date}_#{@mailClass}.dat", 'w')
		5.times do
			extractFile.write("\n") if not first
			extractFile.write("#{pic[12,22]}#{' '.ljust(60, ' ')}#{rand(10000..99999)}#{' '.ljust(33, ' ')}UN-MANIFESTED PARCEL RECORD#{' '.ljust(13, ' ')}#{@date}#{Time.now.strftime('%H%M')}#{' '.ljust(28, ' ')}")
			first = false
		end
		extractFile.close()
		extractSem = File.open("#{$targetPath}\\Generated EVS Files\\PTSArrivalWkly-Unman#{@date}_#{@mailClass}.sem", 'w')
		extractSem.close()
		puts "Built un-manifested extract (.dat/.sem) for #{@mailClass}!"
	end
	#*********************************************************************************************************************************
=end
	end
end

class Array
	def simplest()
		simplestObject = self.first #Set a starting point.
		self.each do |object|
			simplestObject = object if object.instance_variables.size < simplestObject.instance_variables.size
		end
		return simplestObject
	end
	
	def list() #Prints a formatted, easily readable list of collections containing either detail records, STCs, and rates.
		self.each_with_index do |object, index|
			objSummary = "#{object.class}"
			object.instance_variables.each do |var|
				objSummary = objSummary + " || " + object.send(var.to_s.delete('@'))
			end
			puts objSummary
		end
	end
end

#*********************************************************************************************************************************

class String
	def domestic? #If the 2-character mail class code is not in the below list of International mail classes, then it is domestic (return true) -- otherwise, false.
		!['LC', 'CP', 'PG', 'IE'].include?(self.chomp.upcase)
	end
end