

module EVSDataLoader
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
end