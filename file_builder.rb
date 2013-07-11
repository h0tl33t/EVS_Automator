
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
	def load_rate_ingredients(klass, fileName, mailClass = nil)
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
			ingredients << tempIngredient unless mailClass
			ingredients << tempIngredient if mailClass and tempIngredient.mail_class == mailClass
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
	def set_valid_selection(collection, selection_messages = nil) #For use with a collection of elements that each have a code and description type variable, takes optional Procs.
		selection_messages.first.call() if selection_messages.first
		code = collection.first.instance_variables.find {|var| /code/.match(var.to_s)}
		description = collection.first.instance_variables.find {|var| /description/.match(var.to_s)}
		collection.each do |element|
			puts "#{element.get(code)} - #{element.get(description)}"
		end
		selection = gets.chomp
		selection = validate(selection) do |s|
			(collection.map {|element| element.get(code)}).include?(s)
		end
		selected_object = collection.find {|element| element.get(code) == selection}
		selection_messages.last.call(selected_object) if selection_messages.last
		return selected_object
	end
	#*********************************************************************************************************************************
	def comb_values(extra_services_only = false)
		values = []
		self.instance_variables.each do |var|
			if extra_services_only
				values << self.get(var) if var.to_s.include?('extra_service')
			else
				values << self.get(var)
			end
		end
		return values
	end
	#*********************************************************************************************************************************
	def generate_EFN(mid)
		return "92750#{mid}#{rand(99999999).to_s.rjust(8, '0')}"
	end
	#*********************************************************************************************************************************
	def generate_file_name()
		case self.class.name
		when 'Manifest'
			@trim == 'r' ? "#{$evs_file_path}/autogenerated_#{@mail_class}_#{@date}_RateTest" : "#{$evs_file_path}/autogenerated_#{@mail_class}_#{@date}#{@time}"
		when 'SBP_Manifest'
			"#{$sbp_file_path}/autogenerated_#{@date}_#{@time}_#{@stc.service_type_code}_SBP"
		when 'SBP_File'
			return "#{$sbp_file_path}/PTS-SBP-Extract-#{Time.now.strftime('%m%d')}_#{@stc.service_type_code}" unless @event.event_code == '03'
			return "#{$sbp_file_path}/PTS-SBP-Extract-#{Time.now.strftime('%m%d')}_#{@stc.service_type_code}_POS" if @event.event_code == '03'
		when 'IMD'
			"#{@manifest.fileName}_IMD_#{@facilityType}"
		when 'STATS'
			return "#{$evs_file_path}/STATS_#{@date}#{@time}#{@manifest.mail_class}" if @manifest.class.name == 'Manifest'
			return "#{$sbp_file_path}/STATS_#{@date}#{@time}#{@manifest.mail_class}" if @manifest.class.name == 'SBP_Manifest'
		when 'PASS'
			return "#{$evs_file_path}/TRP_P1EVS_OUT_#{@date}#{@manifest.mail_class}" if @manifest.class.name == 'Manifest'
			return "#{$sbp_file_path}/TRP_P1SBP_OUT_#{@date}#{@manifest.mail_class}" if @manifest.class.name  == 'SBP_Manifest'
		when 'POS'
			return "#{$evs_file_path}/TRP_P1PRS_OUT_#{@date}#{@manifest.mail_class}" if @manifest.class.name == 'Manifest'
			return "#{$sbp_file_path}/TRP_P1SBP_OUT_#{@date}#{@manifest.mail_class}" if @manifest.class.name  == 'SBP_Manifest'
		when 'Duplicate_Package_Extract'
			"#{$evs_file_path}/PTSExtractManDup#{@date}_#{@manifest.mail_class}"
		when 'Misshipped_Extract'
			return "#{$evs_file_path}/PTSExtract_Misship#{@date}_#{@manifest.mail_class}", "#{$evs_file_path}/PTSArrival_Misship#{@date}_#{@manifest.mail_class}"
		when 'Unmanifested_Extract'
			return "#{$evs_file_path}/PTSExtractWkly-Unman#{@date}_#{@manifest.mail_class}", "#{$evs_file_path}/PTSArrivalWkly-Unman#{@date}_#{@manifest.mail_class}"
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
	
	module ClassMethods
		def build_simple_class(name, reference_file_name)
			klass = Object.const_set(name,Class.new)
			klass.class_eval do
				include File_Builder
				create_fields_using(reference_file_name)
			end
		end

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

		def format_instance_variable_name(name)
			name.downcase.gsub(' ', '_').gsub('-', '_').gsub('+', 'plus').delete('()')
		end
	end
end

#*************************************************************************************************************************************

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

#*************************************************************************************************************************************

class String
	def domestic? #If the 2-character mail class code is not in the below list of International mail classes, then it is domestic (return true) -- otherwise, false.
		!['LC', 'CP', 'PG', 'IE'].include?(self.chomp.upcase)
	end
end