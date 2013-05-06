require './file_builder'

class Sample_Record
	include File_Builder
	
	def convert_weight(weight)
		wholeNum = weight[1, 4] #Pulls the 2nd (A), 3rd (B), 4th (C) and 5th (D) digit from the format 0ABCDdddd where 'd' is the decimal portion of the eVS weight convention
		decimal = weight[5, 4]  #Pulls the decimal portion
		return "#{wholeNum}.#{decimal}"
	end
end