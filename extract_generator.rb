
class Extract_Generator
	include File_Builder
	
	def initialize(manifest)
		build_extract(determine_extract_type(), manifest)
	end
	
	def determine_extract_type()
		puts "Enter the number of the extract you would like to build:"
		puts "1) Mis-Shipped"
		puts "2) Duplicate Package"
		puts "3) Un-manifested"
		type = gets.chomp
		type = validate(type) do |t|
			['1','2','3'].include?(t)
		end
		return type
	end
	
	def build_extract(type, manifest)
		case type
		when '1'
			Misshipped_Extract.new(manifest)
		when '2'
			Duplicate_Package_Extract.new(manifest)
		when '3'
			Unmanifested_Extract.new(manifest)
		end
	end
end