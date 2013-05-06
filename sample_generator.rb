require './file_builder'
require './evs_data_loader'
require './sample'
require './imd_sample'
require './stats_sample'
require './pass_sample'
require './pos_sample'

#Set necessary variables to allow for OCRA Executable to function on ACE Machines ************************************************
	$targetPath = File.dirname(ENV['OCRA_EXECUTABLE'].to_s)
	$targetPath.gsub!(/\\/,'/')
	$targetPath = File.expand_path($targetPath) if $targetPath == '.'
	Dir.chdir($targetPath)
	if $targetPath != '.'
		Dir.mkdir("#{$targetPath}/Generated EVS Files/") if File.directory?("#{$targetPath}/Generated EVS Files/") != true
	end
#*********************************************************************************************************************************

class Sample_Generator
	include File_Builder
	
	attr_accessor :manifest, :samples, :sampleTypes, :type
	
	def initialize(manifest)
		@samples = []
		@manifest = manifest
		@manifest.details.delete_if {|detail| detail.barcode != '1'} #Only keep details that have a barcode value of 1 => eligible for sampling
		@sampleTypes = {'I' => 'IMD', 'S' => 'STATS', 'P' => 'PASS', 'O' => 'POS'}
		determine_sample_type()
		self.send("build_#{@type}")
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
end