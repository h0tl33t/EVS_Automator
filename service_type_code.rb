require_relative 'file_builder'

class ServiceTypeCode #STC
	include File_Builder
	
	create_fields_using("#{$targetPath}/Reference Files/stcs.csv")
	#create_fields_using essentially provides the following functionality..
	#attr_accessor :service_type_code, :mail_class, :extra_service_code_1st_service, :extra_service_code_2nd_service, :extra_service_code_3rd_service, :extra_service_code_4th_service
	
	def assess_insurance()
		values = self.comb_values()
		return '0010000' if values.include?('930') #If extra service code 930 (insurance <= $200) is found, return manifest value for $100 ('0010000')
		return '0050000' if values.include?('931') #If extra service code 931 (insurance > $200) is found, return manifest value for $500 ('0050000')
		return false #If insurance values are not found, return false.
	end
	
	def assess_COD()
		return '0005000' if self.comb_values().include?('915') #If COD STC '915' is found, send COD Amount Due Sender to $50
		return false #If insurance values are not found, return false.
	end
end