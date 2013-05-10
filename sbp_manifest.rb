
class SBP_Manifest < Manifest

	attr_reader :stc
	
	def initialize(mailer, stc)
		@details ||= []
		@date = Time.now.strftime('%Y%m%d') #Set a fixed date to use throughout a manifest object.
		@time = Time.now.strftime('%H%M%S') #Set a fixed time to use throughout a manifest object.
		@originZIP = '20260' #Hard coded origin ZIP for simplicity.
		@mailer = mailer
		@stc = stc
		@mail_class = stc.mail_class
		@mail_class == 'RP' ? @type = '3' : @type = '1' #RP is a returns product, which requires a type '3' manifest.  Otherwise, set to type '1'.
		@rates = load_rate_ingredients(Rate, "#{$reference_file_path}/rates.csv", @mail_class)
		@fileName = generate_file_name()
		generate_details()
		@header = HeaderRecord.new(self)
		build_raw()
		build_cew()
		build_sem()
		puts "Built manifest (.raw/.cew/.sem) for manifest-based SBP file having STC #{stc.service_type_code}!"
	end
	
	def generate_details()
		@rates.each do |rate|
			next if rate.is_open_and_distribute? #There are no SBP Open & Distribute STCs...ignore O&D rates.
			next if rate.is_critical_mail_flat? and !['741','799'].include?(@stc.service_type_code) #Skip if rate is Critical Mail Flats but doesn't have a CM Flats STC
			next if rate.is_critical_mail_letter? and !['740','816'].include?(@stc.service_type_code) #Skip if rate is Critical Mail Letters but doesn't have a CM Letters STC
			detail = SBP_Detail_Record.new(self, rate, @stc)
			@details << detail
		end
	end
end