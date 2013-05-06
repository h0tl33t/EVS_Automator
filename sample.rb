require './file_builder'
require './evs_data_loader'

class Sample
	include File_Builder
	include EVS_Data_Loader
	
	attr_accessor :manifest, :records, :sampleFileName, :semFileName, :date, :time
	
	def initialize(manifest)
		@manifest = manifest
		@date = Time.now.strftime('%Y%m%d')
		@time = Time.now.strftime('%H%M%S')
		@records = []
	end
	
	def generate_records()
		@manifest.details.each_with_index do |detail, index|
			record = Object.const_get(self.class.name + "_Record").new(self, detail, index + 1) if self.class == STATS
			record = Object.const_get(self.class.name + "_Record").new(self, detail) if self.class != STATS
			@records << record
		end
	end
	
	def build(sample, delimiter = nil)
		first = true
		file = File.open(sample.sampleFileName, 'w')
		sample.records.each do |record|
			file.write("\n") unless first
			file.write(record.comb_values.join) unless delimiter
			file.write(record.comb_values.join(delimiter))
			first = false
		end
		file.close()
		sem = File.open(sample.semFileName, 'w')
		sem.close()
		puts "Built #{sample.class} sample for #{@manifest.mail_class}!"
	end
end