require_relative 'file_builder'

#Set necessary variables to allow for OCRA Executable to function on ACE Machines ************************************************
	$targetPath = File.dirname(ENV['OCRA_EXECUTABLE'].to_s)
	$targetPath.gsub!(/\\/,'/')
	$targetPath = File.expand_path($targetPath) if $targetPath == '.'
	Dir.chdir($targetPath)
#*********************************************************************************************************************************

class Mail_Class
	include File_Builder
	
	attr_reader :values, :code
	
	def initialize()
		@values = load_data("#{$targetPath}/Reference Files/mailclasses.txt")
		@code = set_mail_class()
	end
	
	def set_mail_class()
		puts "What mail class would you like to generate a file for?"
		puts "#{@values}"
		mail_class = gets.chomp.upcase
		puts "You selected: #{mail_class}"
		mail_class = validate(mail_class) do |mailClass|
			@values.include?(mailClass)
		end
		return mail_class
	end
end