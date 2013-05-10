
class SBP_File
	include File_Builder
	
	build_simple_class('SBP_STC', "#{$reference_file_path}/sbp_stcs.csv")
	build_simple_class('SBP_Event', "#{$reference_file_path}/sbp_event_codes.csv")
	
	attr_accessor :mailer, :stcs, :stc, :events, :event, :manifest, :records, :originZIP, :fileName
	
	def initialize(mailer = nil)
		@records = []
		@mailer = mailer || Mailer.new()
		@stcs = load_rate_ingredients(SBP_STC, "#{$reference_file_path}/sbp_stcs.csv")
		@events = load_rate_ingredients(SBP_Event, "#{$reference_file_path}/sbp_event_codes.csv")
		@originZIP = '20260' #Hard coded origin ZIP for simplicity.
		@stc = set_valid_selection(@stcs, stc_selection_messages)
		@event = set_valid_selection(@events, event_selection_messages)
		@manifest = SBP_Manifest.new(@mailer, @stc) if eligible? and create_manifest?
		@manifest ? generate_manifest_based_records() : generate_stand_alone_records()
		@fileName = generate_file_name()
		build_sbp()
		build_sem()
		puts "Built SBP file (.dat/.sem) for STC #{@stc.service_type_code} and Event Code #{@event.event_code}!"
	end
	
	def stc_selection_messages()
		ask = lambda {puts "Enter the 3-digit STC to create the SBP file with:"}
		reply = lambda {|stc| puts "You selected STC #{stc.service_type_code} - #{stc.description}"}
		return ask, reply
	end
	
	def event_selection_messages()
		ask = lambda {puts "Enter the 2-digit SBP Scan Event Code to use (select '03' for an SBP POS sample):"}
		reply = lambda {|event| puts "You selected Event Code #{event.event_code} - #{event.description}"}
		return ask, reply
	end
	
	def eligible?
		/Parcel Return Service/.match(@stc.description) == nil #Eligible returns true if the STC is not a Parcel Return Service-type STC.
	end
	
	def create_manifest?()
		return true if @event.event_code == '03' #User already selected the sampling event code.
		puts "Is this SBP file manifest-based? (y/n)"
		gets.chomp.downcase == 'y'
	end
	
	def number_of_records()
		puts "How many records do you want to generate?"
		number = gets.chomp.to_i
		number = validate(number) do |n|
			n > 0
		end
		return number
	end
	
	def generate_manifest_based_records()
		@manifest.details.each do |detail|
			@records << SBP_Record.new(self, detail)
		end
	end
	
	def generate_stand_alone_records()
		number_of_records.times do
			@records << SBP_Record.new(self)
		end
	end

	def build_sbp()
		first = true
		file = File.open("#{@fileName}.dat", 'w')
		@records.each do |record|
			file.write("\n") unless first
			record.format_fields()
			file.write(record.comb_values.join(','))
			first = false
		end
		file.close()
	end
end