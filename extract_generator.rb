
class Extract_Generator
	include File_Builder
	
	def initialize(manifest)
		build_extract(determine_extract_type(manifest.mail_class), manifest)
	end
	
	def determine_extract_type(mail_class)
		puts "Enter the number of the extract you would like to build:"
    puts "1) Un-manifested"
    puts "2) Duplicate Package"
		puts "3) Mis-Shipped" if mail_class.domestic?
   
		type = gets.chomp
		type = validate(type) do |t|
			['1','2','3'].include?(t)
		end
		return type
	end
	
	def build_extract(type, manifest)
		case type
		when '1'
      Unmanifested_Extract.new(manifest)
		when '2'
			Duplicate_Package_Extract.new(manifest)
		when '3'
			Misshipped_Extract.new(manifest) if manifest.mail_class.domestic?
		end
	end
end