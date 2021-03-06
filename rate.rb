require_relative 'file_builder'

class Rate
	include File_Builder
	create_fields_using("#{$reference_file_path}/rates.csv")
	#create_fields_using essentially provides the following functionality..
	#attr_accessor :mail_class, :processing_category, :destination_rate_indicator, :rate_indicator, :min_zone, :max_zone, :barcode, :discount_and_surcharge, :min_weight, :max_weight
	
	def non_profit?()
		@rate_indicator[0] == 'N' and ['S2', 'SA'].include?(@mail_class)
	end
	
	def is_returns?()
		@mail_class == 'RP'
	end
	
	def is_open_and_distribute?()
		@processing_category == 'O'
	end
	
	def discount?()
		['*', 'N1', 'E1', 'G1'].include?(@discount_and_surcharge) ? false : @discount_and_surcharge #Any discount and surcharge value that is not '*', 'N1', 'E1', 'G1' is a discount type.
	end
	
	def surcharge?()
		['N1', 'E1', 'G1'].include?(@discount_and_surcharge) ? @discount_and_surcharge : false #N1, E1, and G1 are the only valid surcharge types in EVS.
	end
	
	def is_military_box?()
		@mail_class == 'PM' and @rate_indicator == 'PM'  #Catch Priority Mail 'PM' (Military Box) which requires ZIP starting in 963 = Zone 8.
	end
	
	def is_dim_weight?()
		@mail_class == 'PM' and ['DR', 'DN'].include?(@rate_indicator)
	end
	
	def is_cubic?()
		@mail_class == 'PM' and ['CP', 'P5', 'P6', 'P7', 'P8', 'P9'].include?(@rate_indicator)
	end
	
	def is_critical_mail_flat?()
		@rate_indicator == 'AF'
	end
	
	def is_critical_mail_letter?()
		@rate_indicator == 'AL'
	end
end