
class Sample
	include File_Builder
	
	attr_accessor :manifest, :records, :fileName, :semFileName, :date, :time
	
	def initialize(manifest)
		@manifest = manifest
		@date = Time.now.strftime('%Y%m%d')
		@time = Time.now.strftime('%H%M%S')
		@records = []
	end
	
	def set_file_names(ext)
		base_name, sem_name = generate_file_name()
		@fileName =  "#{base_name}#{ext}"
		@semFileName = "#{base_name}.sem" unless sem_name
		@semFileName = "#{sem_name}.sem" if sem_name
	end
	
	def generate_records()
		@manifest.details.each_with_index do |detail, index|
			if detail.barcode == '1'
				record = Object.const_get(self.class.name + "_Record").new(self, detail) unless ['STATS', 'IMD', 'Misshipped_Extract'].include?(self.class.name)
				record = Object.const_get(self.class.name + "_Record").new(self, detail, index + 1) if self.class.name == 'STATS'
				record = Object.const_get(self.class.name + "_Record").new(self, detail) if self.class.name == 'IMD' and detail.destination_rate_indicator == self.facilityType
				record = Object.const_get(self.class.name + "_Record").new(self, detail) if self.class.name == 'Misshipped_Extract' and detail.destination_rate_indicator == 'D' #Only keep DRI 'D" (DDU) detail records for Mis-shipped Extracts
				@records << record if record
			end
		end
	end
	
	def build(sample, delimiter = nil)
		first = true
		file = File.open(sample.fileName, 'w')
		sample.records.each do |record|
			file.write("\n") unless first
			file.write(record.comb_values.join(delimiter))
			first = false
		end
		file.close()
		sem = File.open(sample.semFileName, 'w')
		sem.close()
		puts "Built #{sample.class} file for #{@manifest.mail_class}!"
	end
end