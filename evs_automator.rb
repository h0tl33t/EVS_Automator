#**************************************************
#EVS/SBP Automator
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
	
	#Require all necessary EVS/SBP File Generation ruby files.
	Dir[File.dirname(__FILE__) + '/*.rb'].each {|file| require_relative file unless file.include?('path_configuration') or file.include?('evs_automator')}

#**************************************************

class EVS_Automator
	include File_Builder
	include Check_Rates
	
	attr_accessor :mailer, :manifest, :sbp
	
	def initialize()
		start_banner()
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

	def execute_operation(operation)
		@mailer = Mailer.new() if !@mailer and ['1','2'].include?(operation) #Generate a new mailer if one does not already exist and user wants to build an EVS or SBP file.
		case operation
		when '1' #Generate EVS Files
			@mail_class = Mail_Class.new.code
			@manifest = Manifest.new(@mailer, @mail_class)
			Check_Rates.check_rates_for(@manifest) if execute_check_rates?(@manifest.mail_class)
			Sample_Generator.new(@manifest) if sample?(@manifest.mail_class)
			if @manifest.mail_class.domestic? #Disable extracts for international mail classes.
				Extract_Generator.new(@manifest) if extract?(@manifest.mail_class)
			end
		when '2' #Generate SBP Files
			@sbp = SBP_File.new(@mailer)
			if @sbp.event.event_code != '03' #Event Code '03' generates an SBP POS sample.  Do not generate a second sample for the same SBP file.
				Sample_Generator.new(@sbp.manifest) if @sbp.manifest and sample?
			end
		when '3' #Validate EVS Rates
			Variance_Grabber.new()
			Rate_Validator.new()
		when '4' #Generate Shell Command
			Command_Generator.generate_shell_commands()
		end
	end
		
	def continue?()
		puts "Would you like to perform another operation? (y/n)"
		gets.chomp.downcase == 'y'
	end
	
	def execute_check_rates?(mail_class = nil)
		puts "Would you like to generate a rate checking reference file for the #{mail_class} manifest just created? (y/n)"
		gets.chomp.downcase == 'y'
	end
	
	def sample?(mail_class = nil)
		puts "Would you like to generate a sample file for the #{mail_class} manifest just created? (y/n)"
		gets.chomp.downcase == 'y'
	end
	
	def extract?(mail_class = nil)
		puts "Would you like to generate an extract file for the #{mail_class} manifest just created? (y/n)"
		gets.chomp.downcase == 'y'
	end
	
	def start_banner()
	puts "
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
 _______ ___ ___ _______    __________  _______  _______    
|   _   |   Y   |   _   |  /  /   _   ||   _   \|   _   |   
|.  1___|.  |   |   1___|,' ,'|   1___||.  1   /|.  1   |   
|.  __)_|.  |   |____   /__/  |____   ||.  _   \|.  ____|   
|:  1   |:  1   |:  1   |     |:  1   ||:  1    \:  |       
|::.. . |\:.. ./|::.. . |     |::.. . ||::.. .  /::.|       
`_______' `---' `__-----'     `-------'`----__-'`---'       
|   _   |.--.--.|  |_.-----.--------.---.-.|  |_.-----.----.
|.  1   ||  |  ||   _|  _  |        |  _  ||   _|  _  |   _|
|.  _   ||_____||____|_____|__|__|__|___._||____|_____|__|  
|:  |   |                                                   
|::.|:. |                                                   
`--- ---'
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
	puts "Welcome to the EVS/SBP Automator!"
	end
end

start = EVS_Automator.new()