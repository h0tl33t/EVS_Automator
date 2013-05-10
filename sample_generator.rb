require_relative 'file_builder'
require_relative 'imd_sample'

class Sample_Generator
	include File_Builder
	
	attr_accessor :manifest, :samples, :sampleTypes, :type
	
	def initialize(manifest)
		@samples = []
		@manifest = manifest
		@sampleTypes = {'I' => 'IMD', 'S' => 'STATS', 'P' => 'PASS', 'O' => 'POS'}
		determine_sample_type()
		self.send("build_#{@type}") if eligible
	end
	
	def determine_sample_type()
		puts "What kind of sample would you like to create?"
		puts "#{@sampleTypes}"
		@type = gets.chomp.upcase
		@type = validate(@type) do |t|
			@sampleTypes.keys.include?(t) or @sampleTypes.values.include?(t)
		end
		@type = @sampleTypes[@type] || @type #If user enters key (I, S, P, or O), set type to correspoding value (IMD, STATS, PASS, or POS).
	end
	
	def method_missing(method)
		self.class.class_eval do
			define_method method do
				@samples << Module.const_get(@type).new(@manifest)
			end
		end
		self.send("build_#{@type}")
	end
	
	def build_IMD()
		#For each destination rate indicator in @manifest, IMD.new()
		facilityTypes = @manifest.pull_facility_types()
		facilityTypes.each do |type|
			@samples << IMD.new(@manifest, type)
		end
	end
	
	def eligible()
		if @manifest.class.name == 'SBP_Manifest' and @type == 'POS'
			puts '***WARNING***'
			puts 'SBP-based POS samples should be created as SBP Files with Scan Event Code 03.'
			puts 'Returning to main menu..'
			return false
		else
			return true
		end
	end
end