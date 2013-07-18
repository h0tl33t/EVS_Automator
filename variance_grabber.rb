#Variance Report Grabber

require 'watir'
require 'win32ole'

class Variance_Grabber
	def initialize()
		puts "Welcome to the Variance Grabber!"
		
		url = pick_environment #Returns URL for selected environment (DEV, SIT, CAT, PROD)
		
		@ie = Watir::Browser.new
		@ie.goto(url)
		sleep(1)
		
		if @ie.frame(:name, "portal_main").exists?
			@main = @ie.frame(:name, "portal_main")
			user, pass = getUserPass()
			login(user, pass)
			drive()
		end
		@ie.close
	end
	#*********************************************************************************************************************************
	def pick_environment
		environments = {'DEV' => 'https://dev1a.uspspostalone.com/postal1/index.cfm?com=false',
						'CAT' => 'https://cat1a.uspspostalone.com/postal1/index.cfm?com=false',
						'SIT' => 'https://sit1a.uspspostalone.com/postal1/index.cfm?com=false',
						'PROD' => 'https://uspspostalone.com/postal1/index_enabled.cfm'}
						
		puts "What environment contains the associated variance reports for the rate check files you want to validate?"
		environments.each_key {|e| puts e}
		env = gets.chomp.upcase
		environments.keys.include?(env) ? environments[env] : 'http://www.google.com' #Need a fall-back URL in order to compile OCRA executable.  PO environments require USPS Intranet. 
	end
	#*********************************************************************************************************************************
	def select_mailer
		puts "****USER INPUT REQUIRED!****"
		puts "Click on the mailer for which the varaince reports should be pulled."
		puts "Once done, press any key to continue."
		gets
	end
	#*********************************************************************************************************************************
	def drive()
		links = @main.links
		roleLink = ''
		links.each {|eachLink| @main.link(:href, eachLink.href).click if eachLink.href.include?('e-VS Admin Super User')}

		select_mailer()
		sleep(1)
		if @main.link(:text, 'Total manifest postage').exists?
			@main.link(:text, 'Total manifest postage').click
		else
			@main.link(:href, "#ui-tabs-2").click if @main.link(:href, "#ui-tabs-2").exists?
			sleep(1) until @main.link(:text, 'Total manifest postage').exists?
			@main.link(:text, 'Total manifest postage').click
		end
		
		efns = {}
		rateCheckEFNs = grabRateCheckEFNs()
		pages = getPageNumbers()
		if pages != 0
			(1..pages).each do |page|
				@main.link(:text, page.to_s).click if page != 1
				pageEFNs = getEFNs(page)
				efns.merge!(pageEFNs)
				pageEFNs.clear
			end
			@main.link(:text, '1').click #Go back to page 1.
		else
			efns.merge!(getEFNs(pages))
		end
		matchedEFNs = compareEFNs(efns, rateCheckEFNs)
		if matchedEFNs.size != 0
			pagesWithActableEFNs = matchedEFNs.values.uniq! || [0] #Catch situation where there's only 1 matchedEFN where uniq! on an array of 1 throws nil
			pagesWithActableEFNs.each do |page|
				@main.link(:text, page).click if not (0..1).include?(page) #Don't need to navigate to another page if it's the first time in this loop (you start at page 1).
				matchedEFNs.each_pair do |efn, pageFoundOn|
					pullVariance(efn) if pageFoundOn == page
				end
			end
		else
			puts "No EFNs were found to match the rate check file(s) in '#{$rate_validation_path}'."
		end
	end
	#*********************************************************************************************************************************
	def getUserPass()
		puts "Username: "
		username = gets.chomp
		puts "Password: "
		password = gets.chomp
		return username, password
	end
	#*********************************************************************************************************************************
	def login(username, password)
		@main.text_field(:name, 'txt_username').set(username)
		@main.text_field(:name, 'pwd_password').set(password)
		@main.button(:name, 'but_login').click
	end
	#*********************************************************************************************************************************
	def getPageNumbers()
		pageNumbers = []
		pages = 1
		@main.links.each do |link|
			pageNumbers << link.text if link.text.length == 1 and /\d{1}/.match(link.text) != nil
		end
		if pageNumbers.size > 0
			pageNumbers.each {|page| pages = page.to_i if page.to_i > pages}
			puts "EFNs are spread across #{pages} page(s)."
		else
			pages = 0
		end
		return pages
	end
	#*********************************************************************************************************************************
	def getEFNs(page)  #Pull EFNs from Each Page
		efns = {}
		@main.links.each do |link|
			efn = link.text if /\d{22}/.match(link.text) and /\d{22}/.match(link.text) != nil
			efns.merge!(efn => page)
		end
		return efns
	end
	#*********************************************************************************************************************************
	def grabRateCheckEFNs() #Grab EFNs from Existing Rate Check Files
		rateCheckEFNs = []
		varEFNs = []
		rateCheckFiles = Dir.glob("#{$rate_validation_path}/*_rateCheck??.csv")
		varianceFiles = Dir.glob("#{$rate_validation_path}/*_variance*.csv")
		
		varianceFiles.each do |varFile|
			varEFNs << (/\d{22}/.match(varFile)).to_s #Pulls a 22-digit EFN from the filename then coverts the MatchData object to a string.
		end
		rateCheckFiles.each do |checkFile|
			rateCheckEFNs << (/\d{22}/.match(checkFile)).to_s #Pulls a 22-digit EFN from the filename then coverts the MatchData object to a string.
		end
		rateCheckEFNs.delete_if {|rateEFN| varEFNs.include?(rateEFN)} #Delete rateCheckEFN if a variance with that EFN already exists.  No need to re-DL variance in this case.
		return rateCheckEFNs
	end
	#*********************************************************************************************************************************
	def compareEFNs(efns, rateCheckEFNs) #Compare EFNs that have been generated with rate check files to those which have been processed through EVS and have associated variance reports
		matchedEFNs = {}
		efns.each_pair do |efn, page|
			if rateCheckEFNs.include?(efn) and efn != nil
				puts "Found match EFN! (#{efn})"
				matchedEFNs.merge!(efn => page)
			end
		end
		return matchedEFNs
	end
	#*********************************************************************************************************************************
	def pullVariance(efn) #Pull Variance Report in .csv (takes EFN)
		efnLinks = []
		varianceCount = 1
		@main.links.each {|l| efnLinks << l.href if l.href.include?("viewPSDetail?fileNumber=#{efn}")}
		efnLinks.each do |efnLink|
			@main.link(:href, efnLink).click #Click on EFN link
			varLinks = []
			@main.links.each {|l| varLinks << l.href if l.href.include?("varianceReport.do?fileNumber=#{efn}")} #Grab all hrefs for the variance reports.
			varLinks.uniq! #Delete links with duplicate hrefs
			varLinks.each do |varLink|
				@main.link(:href, varLink).click
				sleep(1)
				handleDownload(efn, varianceCount)
				sleep(1)
				@ie.back
				varianceCount = varianceCount + 1
			end
			@ie.back #Back to the EFN list page
		end
	end
	#*********************************************************************************************************************************
	def handleDownload(efn, varCount) #Handle Variance Report Download(efn, varianceCount)
		begin
			Timeout::timeout(5) do 
				puts "Opening download box.."
				@main.link(:text, 'CSV').click #Brings up download box.
			end
		rescue Timeout::Error => msg
			puts "Timed out 'click' operation on CSV link.  Moving on.."
			sleep(1)
		end
		
		path = "#{$rate_validation_path}/#{efn}_variance#{varCount}.csv".gsub(/\//,"\\")
		box = WIN32OLE.new('Wscript.Shell')
		
		puts "Activating File Download box.."
		if box.AppActivate('File Download')
			puts "File Download box activated? #{box.AppActivate('File Download')}"
			sleep(1)
			box.SendKeys('S')
			puts "Sent 'S' to box."
		else
			puts "Failed to activate File Download box."
		end
		sleep(1)
		puts "Activating Save As box.."
		if box.AppActivate('Save As')
			puts "Save As box activated? #{box.AppActivate('Save As')}"
			sleep(1)
			box.SendKeys("#{path}{ENTER}")
			puts "Sent #{path} to box."
		else
			puts "Failed to activate Save As box."
		end
		sleep(2)
	end
end