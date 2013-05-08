#EVS Automator
#Initial Setup..
	#Require certain gems on initial OCRA build.
	unless ENV['OCRA_EXECUTABLE']
		require 'bundler/setup'
		gem 'rake', '>=9.0.0'
		require 'rake'
		require 'builder'
	end

	#Initialize necessary paths and reference data.
	require_relative 'path_configuration'
	Path_Configuration.set_paths()
	Path_Configuration.initialize_reference_directories()
	Path_Configuration.create_local_reference_files()
	
	require_relative 'mailer'
	require_relative 'mail_class'
	require_relative 'manifest'
	require_relative 'sample_generator'
	require_relative 'extract_generator'
	require_relative 'file_builder'
	require_relative 'check_rates'
	require_relative 'rate_validator'
	require_relative 'variance_grabber'
	require_relative 'command_generator'

#**************************************************

class EVS_Automator
	include File_Builder
	include Check_Rates
	
	attr_accessor :mailer, :manifest
	
	def initialize()
		puts "Welcome to the EVS/SBP Automator!"
		continue = true
		while continue
			pick_operation()
			continue = continue?
		end
		puts "Exiting the EVS/SBP Automator.."
	end

	def pick_operation()
		operations = { '1' => 'Generate EVS Files', '2' => 'Generate SBP Files', '3' => 'Validate EVS Rates', '4' => 'Generate Shell Command' }
		puts "Enter the corresponding number for the operation you want to execute:"
		operations.each do |key, value|
			puts "#{key}) #{value}"
		end
		operation = gets.chomp
		operation = validate(operation) do |o|
			(1..operations.size).include?(o.to_i)
		end
		execute_operation(operation)
	end
	
	def continue?()
		puts "Would you like to perform another operation? (y/n)"
		gets.chomp.downcase == 'y'
	end
	
	def execute_check_rates?(mail_class)
		puts "Would you like to generate a rate checking reference file for the #{mail_class} manifest just created? (y/n)"
		gets.chomp.downcase == 'y'
	end
	
	def sample?(mail_class)
		puts "Would you like to generate a sample file for the #{mail_class} manifest just created? (y/n)"
		gets.chomp.downcase == 'y'
	end
	
	def extract?(mail_class)
		puts "Would you like to generate an extract file for the #{mail_class} manifest just created? (y/n)"
		gets.chomp.downcase == 'y'
	end

	def execute_operation(operation)
		@mailer = Mailer.new() if !@mailer and ['1','2'].include?(operation) #Generate a new mailer if one does not already exist and user wants to build an EVS or SBP file.
		case operation
		when '1' #Generate EVS Files
			@mail_class = Mail_Class.new.code
			@manifest = Manifest.new(@mailer, @mail_class)
			check_rates(@manifest) if execute_check_rates?(@manifest.mail_class)
			Sample_Generator.new(@manifest) if sample?(@manifest.mail_class)
			Extract_Generator.new(@manifest) if extract?(@manifest.mail_class)
		when '2' #Generate SBP Files
			puts "Generating SBP File.."
		when '3' #Validate EVS Rates
			Variance_Grabber.new()
			Rate_Validator.new()
		when '4' #Generate Shell Command
			Command_Generator.new()
		end
	end
end

start = EVS_Automator.new()