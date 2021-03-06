#Check_Rates takes a manifest and calculates expected postage detail-by-detail based on local rate tables stored in ./Reference Files/Rate Tables/.

module Check_Rates
	class << self
		def check_rates_for(manifest)
			rate_data = []
			manifest.details.each do |detail|
				start_weight = detail.weight #Baseline the original weight, rate check processes re-format the weights as necessary for rate calculation.
				baseRate, plusRate = find_rate_for(detail)
				detail.weight = start_weight #Revert weight formatting to original weight value/formatting so the manifest object's state is uniform when passed to any file generator.
				discount_surcharge = evaluate_discount_surcharge_type(detail) || ''
				rate_data << ["'#{detail.tracking_number}'", detail.mail_class, detail.processing_category, detail.rate_indicator, detail.destination_rate_indicator, discount_surcharge, detail.barcode, detail.length, detail.height, detail.width, formatPounds(detail.weight), detail.domestic_zone, baseRate, plusRate] if detail.mail_class.domestic?
				rate_data << ["'#{detail.tracking_number}'", detail.mail_class, detail.processing_category, detail.rate_indicator, detail.destination_rate_indicator, discount_surcharge, detail.barcode, detail.length, detail.height, detail.width, formatPounds(detail.weight), "#{detail.customer_reference_number_1} (#{detail.destination_country_code})", baseRate, plusRate] unless detail.mail_class.domestic?
			end
			create_rate_check_file(manifest.header.electronic_file_number, manifest.mail_class, rate_data)
		end
		
		def find_rate_for(detail)
			unless nsa_only?(detail) #Catch detail records that have mail classes or rate indicators that are NSA-only.
				['S2','SA'].include?(detail.mail_class) ? mail_class = 'SM' : mail_class = detail.mail_class
				baseRate = self.send("findRate#{mail_class}", detail, 'base')
				['CP','EX','FC','IE','LC','PG','PM'].include?(detail.mail_class) ? plusRate = self.send("findRate#{detail.mail_class}", detail, 'plus') : plusRate = ''
				return baseRate, plusRate
			else
				return 'NSA Only', ''
			end
		end
		#*********************************************************************************************************************************
		def findRateBB(detail, rateTier)
			detail.domestic_zone = '01' if detail.domestic_zone == '02'
			detail.weight = formatPounds(detail.weight)
      detail.weight = detail.weight.to_f < 1.0 ? '1.00' : detail.weight
			
			if detail.rate_indicator == "NP"
				rateTable = loadTable("BBNP.csv")
				rateTable.each do |rate|
					return rate[detail.domestic_zone] if detail.weight.to_f <= rate['Weight'].to_f
				end
			elsif detail.rate_indicator == "PR"
				if detail.destination_rate_indicator == 'B'
					rateTable = loadTable("BBPRB.csv")
					rateTable.each do |rate|
						if detail.domestic_zone == rate['Zone']
							rateTotal = rate['Per Piece'].to_f. + (detail.weight.to_f * rate['Per Pound'].to_f)
							return rateTotal.round(3).to_s
						end
					end
				elsif detail.destination_rate_indicator == 'N'
					rateTable = loadTable("BBPRN.csv")
					rateTable.each do |rate|
						if detail.domestic_zone == rate['Zone']
							rateTotal = rate['Per Piece'].to_f + (detail.weight.to_f * rate['Per Pound'].to_f)
							return rateTotal.round(3).to_s
						end
					end
				elsif detail.destination_rate_indicator == 'S' or detail.destination_rate_indicator == 'D'
					rateTable = loadTable("BBPRSorD.csv")
					rateTable.each do |rate|
						if detail.destination_rate_indicator == rate['Destination Rate Indicator']
							rateTotal = rate['Per Piece'].to_f + (detail.weight.to_f * rate['Per Pound'].to_f)
							return rateTotal.round(3).to_s
						end
					end	
				end
			end
		end
		#*********************************************************************************************************************************
		def findRateBL(detail, rateTier)
			detail.weight = formatPounds(detail.weight)
			rateTable = loadTable("BL.csv")
			rateTable.each do |rate|
				return rate[detail.rate_indicator] if detail.weight.to_f <= rate['Weight'].to_f
			end
		end
		#*********************************************************************************************************************************
		def findRateBS(detail, rateTier)
			detail.weight = formatPounds(detail.weight)
			rateTable = loadTable("BS.csv")
			rateTable.each do |rate|
				return rate[detail.rate_indicator] if detail.weight.to_f <= rate['Weight'].to_f
			end
		end
		#*********************************************************************************************************************************
		def findRateCM(detail, rateTier)
			rateTable = loadTable("CM.csv")
			rateTable.each do |rate|
				return rate['Rate'] if detail.rate_indicator == rate['Rate Indicator']
			end
		end
		#*********************************************************************************************************************************
		def findRateCP(detail, rateTier)
			detail.customer_reference_number_1 = formatGroup(detail.customer_reference_number_1)
			detail.weight = formatPounds(detail.weight) if rateTier == 'base'
			
			flatRateTable = loadTable("baseCPFlat.csv") if rateTier == 'base'
			flatRateTable = loadTable("plusCPFlat.csv") if rateTier == 'plus'
			flatRateTable.each do |flatRate|
				if detail.rate_indicator == flatRate['Rate Indicator']
					return flatRate['CA'] if detail.destination_country_code == 'CA'
					return flatRate['Other'] if detail.destination_country_code != 'CA'
				end
			end
			rateTable = loadTable("baseCP.csv") if rateTier == 'base'
			rateTable = loadTable("plusCP.csv") if rateTier == 'plus'
			rateTable.each do |rate|
				return rate[detail.customer_reference_number_1] if detail.weight.to_f <= rate['Weight'].to_f
			end
		end
		#*********************************************************************************************************************************
		def findRateEX(detail, rateTier)
			detail.domestic_zone = '00' if ['01','02'].include?(detail.domestic_zone)
			detail.weight = formatPounds(detail.weight) if rateTier == 'base'
			
			flatRateTable = loadTable("baseEXFlat.csv") if rateTier == 'base'
			flatRateTable = loadTable("plusEXFlat.csv") if rateTier == 'plus'
			flatRateTable.each do |flatRate|
				return flatRate['Rate'] if detail.rate_indicator == flatRate['Rate Indicator']
			end
			
			rateTable = loadTable("baseEX.csv") if rateTier == 'base'
			rateTable = loadTable("plusEX.csv") if rateTier == 'plus'
			rateTable.each do |rate|
				return rate[detail.domestic_zone] if detail.weight.to_f <= rate['Weight'].to_f
			end
		end
		#*********************************************************************************************************************************
		def findRateFC(detail, rateTier)
			detail.weight = formatOunces(detail.weight) if rateTier == 'base'
			detail.rate_indicator = 'MA' if detail.rate_indicator == 'SP'
			
			surcharge = evaluate_fc_surcharge(detail)

			retailRateTable = loadTable("retailFC.csv") #Catch Rate Indicator 'S2' which uses FC Retail Rate Tables
			if retailRateTable[0].keys.include?(detail.rate_indicator)
				retailRateTable.each do |rate|
					return rate[detail.rate_indicator] if detail.weight.to_f <= rate['Weight'].to_f
				end
			end
			
			baseRateTable = loadTable("baseFC.csv")
			baseRateTable.each do |rate|
				if detail.weight.to_f <= rate['Weight'].to_f
					return (rate[detail.rate_indicator].to_f + surcharge).round(2).to_s if rate.keys.include?(detail.rate_indicator)
				end
			end
			plusRateTable = loadTable("plusFC.csv")
			plusRateTable.each do |rate|
				if detail.weight.to_f <= rate['Weight'].to_f
					return (rate[detail.rate_indicator].to_f + surcharge).round(2).to_s if rate.keys.include?(detail.rate_indicator) and rateTier == 'plus'
					return '' if rate.keys.include?(detail.rate_indicator) and rateTier == 'base' #Comm Plus FC Rate Indicators filter if price tier is set to 'base'.
				end
			end
		end
		#*********************************************************************************************************************************
		def findRateIE(detail, rateTier)
			detail.customer_reference_number_1 = formatGroup(detail.customer_reference_number_1)
			detail.weight = formatPounds(detail.weight) if rateTier == 'base'
			
			flatRateTable = loadTable("baseIEFlat.csv") if rateTier == 'base'
			flatRateTable = loadTable("plusIEFlat.csv") if rateTier == 'plus'
			flatRateTable.each do |flatRate|
				if detail.rate_indicator == flatRate['Rate Indicator']
					return flatRate['CA'] if detail.destination_country_code == 'CA'
					return flatRate['Other'] if detail.destination_country_code != 'CA'
				end
			end
			rateTable = loadTable("baseIE.csv") if rateTier == 'base'
			rateTable = loadTable("plusIE.csv") if rateTier == 'plus'
			rateTable.each do |rate|
				return rate[detail.customer_reference_number_1] if detail.weight.to_f <= rate['Weight'].to_f
			end
		end
		#*********************************************************************************************************************************
		def findRateLC(detail, rateTier)
			detail.customer_reference_number_1 = formatGroup(detail.customer_reference_number_1)
			detail.customer_reference_number_1 = '3-5' if ['3','4','5'].include?(detail.customer_reference_number_1)
			detail.customer_reference_number_1 = '6-9' if ['6','7','8','9'].include?(detail.customer_reference_number_1)
			detail.weight = formatOunces(detail.weight) if rateTier == 'base'
			
			rateTable = loadTable("baseLC.csv") if rateTier == 'base'
			rateTable = loadTable("plusLC.csv") if rateTier == 'plus'
			rateTable.each do |rate|
				return rate[detail.customer_reference_number_1] if detail.weight.to_f <= rate['Weight'].to_f
			end
		end
		#*********************************************************************************************************************************
		def findRateLW(detail, rateTier)
			detail.weight = formatOunces(detail.weight)
			
			case detail.rate_indicator
			when 'BB'
				rateTable = loadTable("regularBBLW.csv") if detail.processing_category == '3'
				rateTable = loadTable("irregularBBLW.csv") if detail.processing_category == '4'
				rateTable.each do |rate|
					return rate[detail.destination_rate_indicator] if detail.weight.to_f <= rate['Weight'].to_f
				end
			when 'DC'
				rateTable = loadTable("regularDCLW.csv") if detail.processing_category == '3'
				rateTable = loadTable("irregularDCLW.csv") if detail.processing_category == '4'
				rateTable.each do |rate|
					return rate[detail.destination_rate_indicator] if detail.weight.to_f <= rate['Weight'].to_f
				end
			when 'DE'
				rateTable = loadTable("irregularDELW.csv") #DE only has PC 4 (irregular)
				rateTable.each do |rate|
					return rate[detail.destination_rate_indicator] if detail.weight.to_f <= rate['Weight'].to_f
				end
			when 'DF'
				rateTable = loadTable("regularDFLW.csv") if detail.processing_category == '3'
				rateTable = loadTable("irregularDFLW.csv") if detail.processing_category == '4'
				rateTable.each do |rate|
					return rate[detail.destination_rate_indicator] if detail.weight.to_f <= rate['Weight'].to_f
				end
			end
		end
		#*********************************************************************************************************************************
		def findRatePG(detail, rateTier)
			detail.customer_reference_number_1 = formatGroup(detail.customer_reference_number_1)
			detail.customer_reference_number_1 = '2' if detail.customer_reference_number_1 != '1' and detail.rate_indicator == 'LE' #Legal Flat Rate Envelopes are Price Group 1 or 2 only. 
			detail.weight = formatPounds(detail.weight) if rateTier == 'base'
			
			rateTable = loadTable("basePG.csv") if rateTier == 'base'
			rateTable = loadTable("plusPG.csv") if rateTier == 'plus'
			rateTable.each do |rate|
				return rate[detail.customer_reference_number_1] if detail.weight.to_f <= rate['Weight'].to_f
			end
		end
		#*********************************************************************************************************************************
		def findRatePM(detail, rateTier)
			nonCommPlusCubicRate = 'SP'
			detail.domestic_zone = '00' if ['01','02'].include?(detail.domestic_zone)
			detail.weight = formatPounds(detail.weight) if rateTier == 'base'
			detail.weight = calcDimWeight(detail.rate_indicator, detail.weight, detail.length, detail.height, detail.width) if rateTier == 'plus'
			
			cubicRates = ['CP','P5','P6','P7','P8','P9']
			if cubicRates.include?(detail.rate_indicator)
				detail.length = formatCubic(detail.length) if rateTier == 'base'
				detail.height = formatCubic(detail.height) if rateTier == 'base'
				detail.width = formatCubic(detail.width) if rateTier == 'base'
				tier = calcTier(detail.length, detail.height, detail.width)
				detail.rate_indicator = 'SP' if tier > 0.50 #Catch pieces that are greater than 0.50 cubic feet, which are recalculated at Single Piece pricing.
				if detail.rate_indicator != 'SP'
					cubicRateTable = loadTable("cubicPM.csv")
					cubicRateTable.each do |cubicRate|
						if tier <= cubicRate['Tier'].to_f
							return cubicRate[detail.domestic_zone] if rateTier == 'plus'
							break if rateTier == 'base'
						end
					end
				end
			end
			
			rateTableCM = loadTable("CM.csv") #Catch Critical Mail rate indicators in a PM-type detail record.
			rateTableCM.each do |rate|
				return rate['Rate'] if detail.rate_indicator == rate['Rate Indicator']
			end
			
			boxRateTable = loadTable("PMRegionalBox.csv")
			boxRateTable.each do |boxRate|
				return boxRate[detail.domestic_zone] if detail.rate_indicator == boxRate['Rate Indicator']
			end
			
			pmodRateTable = loadTable("pmodDDU.csv") if detail.destination_rate_indicator == 'D'
			pmodRateTable = loadTable("pmodOther.csv") if detail.destination_rate_indicator != 'D'
			pmodRateTable.each do |pmodRate|
				return pmodRate[detail.domestic_zone] if detail.rate_indicator == pmodRate['Rate Indicator'] and rateTier == 'plus'
				#return 'NSA Only' if ['O5','O6','O7','O8'].include?(detail.rate_indicator) #O5 through O8 are CSSC only PMOD Container rates.  There are no published rates for them.
				return '' if detail.rate_indicator == pmodRate['Rate Indicator'] and rateTier == 'base'
			end
			
			flatRateTable = loadTable("basePMFlat.csv") if rateTier == 'base'
			flatRateTable = loadTable("plusPMFlat.csv") if rateTier == 'plus'
			flatRateTable.each do |flatRate|
				return flatRate['Rate'] if detail.rate_indicator == flatRate['Rate Indicator']
			end
			
			rateTable = loadTable("basePM.csv") if rateTier == 'base'
			rateTable = loadTable("plusPM.csv") if rateTier == 'plus'
			rateTable.each do |rate|
				if detail.rate_indicator == 'BN'
					return rate[detail.domestic_zone] if rate['Weight'] == 'BN' #Catches 'BN' (Balloon) rate cells.
				elsif detail.weight.to_f <= rate['Weight'].to_f
					return rate[detail.domestic_zone]
				end
			end
		end
		#*********************************************************************************************************************************
		def findRatePS(detail, rateTier)
			detail.domestic_zone = '00' if ['01','02'].include?(detail.domestic_zone)
			detail.weight = formatPounds(detail.weight)
			
			dndc_nonmachinable_surcharge_discount, dscf_nonmachinable_surcharge_discount = evaluate_ps_with_special_handling(detail)
			
			if detail.destination_rate_indicator == 'B'
				rateTable = loadTable("PSDestEntry3B.csv") if detail.processing_category == '3'
				rateTable = loadTable("PSDestEntry5B.csv") if detail.processing_category == '5'
				rateTable.each do |rate|
					if detail.rate_indicator == 'BN'
						return (rate[detail.domestic_zone].to_f - dndc_nonmachinable_surcharge_discount).to_s if rate['Weight'] == 'BN' #Catches 'BN' (Balloon) rate cells.
					elsif detail.rate_indicator == 'OS'
						return rate[detail.domestic_zone] if rate['Weight'] == 'OS' #Catches 'OS' (Balloon) rate cells.
					else
						return (rate[detail.domestic_zone].to_f - dndc_nonmachinable_surcharge_discount).to_s if detail.weight.to_f <= rate['Weight'].to_f
					end
				end
			elsif detail.destination_rate_indicator == 'D'
				rateTable = loadTable("PSDestEntryDDU.csv")
				rateTable.each do |rate|
					if detail.rate_indicator == 'BN'
						return rate[detail.processing_category] if rate['Weight'] == 'BN'
					elsif detail.rate_indicator == 'OS'
						return rate[detail.processing_category] if rate['Weight'] == 'OS'
					else
						return rate[detail.processing_category] if detail.weight.to_f <= rate['Weight'].to_f
					end
				end
			elsif detail.destination_rate_indicator == 'S' and detail.processing_category == '3'
				rateTable = loadTable("PSDestEntry3S.csv")
				rateTable.each do |rate|
					if detail.rate_indicator == 'BN'
						return rate[detail.destination_rate_indicator] if rate['Weight'] == 'BN' #Catches 'BN' (Balloon) rate cells.
					else
						return rate[detail.destination_rate_indicator] if detail.weight.to_f <= rate['Weight'].to_f
					end
				end
			elsif detail.destination_rate_indicator == 'S' and detail.processing_category == '5'
				rateTable = loadTable("PSDestEntry5S.csv")
				rateTable.each do |rate|
					if detail.rate_indicator == 'BN'
						return (rate['5D'].to_f - dscf_nonmachinable_surcharge_discount).to_s if rate['Weight'] == 'BN' #Catches 'BN' (Balloon) rate cells.  5 BN S uses 5-Digit (5D) rate column.
					elsif detail.rate_indicator == 'OS'
						return rate['5D'] if rate['Weight'] == 'OS' #Catches 'OS' (Balloon) rate cells. 5 OS S uses 5-Digit (5D) rate column.
					elsif detail.rate_indicator == 'B3'
						return (rate['3D'].to_f - dscf_nonmachinable_surcharge_discount).to_s if rate['Weight'] == 'BN' #Catches 'B3' (3-Digit Balloon) rate cells.
					else
						return (rate[detail.rate_indicator].to_f - dscf_nonmachinable_surcharge_discount).to_s if detail.weight.to_f <= rate['Weight'].to_f
					end
				end
			end
			
			rateTable = loadTable("PSNDCPresort.csv") if ['D3','D9'].include?(detail.discount_type)  #Catch NDC Discount Types
			rateTable = loadTable("PSONDCPresort.csv") if ['D2','D8'].include?(detail.discount_type) #Catch ONDC Discount Types
			rateTable = loadTable("PSNonPresort.csv") if detail.discount_type == '' #Catch any remaining PS Non-presort
			rateTable.each do |rate|
				if detail.rate_indicator == 'BN'
					return rate[detail.domestic_zone] if rate['Weight'] == 'BN' #Catches 'BN' (Balloon) rate cells.
				elsif detail.rate_indicator == 'OS'
					return rate[detail.domestic_zone] if rate['Weight'] == 'OS' #Catches 'OS' (Balloon) rate cells.
				else
					return rate[detail.domestic_zone] if detail.weight.to_f <= rate['Weight'].to_f
				end
			end
		end
		#*********************************************************************************************************************************
		def findRateRP(detail, rateTier)
			#PRS does not have a variance report that provides the piece-level information necessary for rate validation.
			#In order to validate PRS rates, EVS IT needs to pull the data from the DB based on the PRS manifest's EFN.
			return ''
		end
		#*********************************************************************************************************************************
		def findRateSM(detail, rateTier)
			nonBarcodedSurcharge = 0.064 #The non-barcoded surcharge is added to any piece with barcode value '0' and is NOT 5-Digit sort (Rate Indicator '5D' for-profit, 'N5' non-profit)
			detail.weight = formatPounds(detail.weight, 4)
			nonProfit = is_non_profit?(detail.rate_indicator)
			
			if nonProfit
				if detail.weight.to_f <= 0.20625
					rateTable = loadTable("SMNPUnder3Presorted.csv") if detail.processing_category == '3' or detail.mail_class == 'S2' #Machinable SA and all S2
					rateTable = loadTable("SMNPUnder3Irregular.csv") if detail.processing_category == '4' and detail.mail_class == 'SA'#Irregular SA
					rateTable.each do |rate|
						return (rate[detail.rate_indicator].to_f + nonBarcodedSurcharge).to_s if detail.destination_rate_indicator == rate['Destination Rate Indicator'] and detail.barcode == '0' and detail.rate_indicator != 'N5'
						return rate[detail.rate_indicator] if detail.destination_rate_indicator == rate['Destination Rate Indicator']
					end
				elsif detail.weight.to_f > 0.20625
					perPiece = 0.0
					perOunce = 0.0
					rateTable = loadTable("SMNPOver3Presorted.csv") if detail.processing_category == '3' or detail.mail_class == 'S2' #Machinable SA and all S2
					rateTable = loadTable("SMNPOver3Irregular.csv") if detail.processing_category == '4' and detail.mail_class == 'SA'#Irregular SA
					rateTable.each do |rate|
						perPiece = rate[detail.rate_indicator].to_f if rate['Destination Rate Indicator'] == 'Per Piece'
						perOunce = rate[detail.rate_indicator].to_f if detail.destination_rate_indicator == rate['Destination Rate Indicator']
					end
					return ((perPiece + detail.weight.to_f * perOunce).round(3) + nonBarcodedSurcharge).to_s if detail.barcode == '0' and detail.rate_indicator != 'N5'
					return (perPiece + detail.weight.to_f * perOunce).round(3).to_s
				end
			else
				if detail.weight.to_f <= 0.20625
					rateTable = loadTable("S2Under3.csv")
					rateTable.each do |rate|
						return (rate[detail.rate_indicator].to_f + nonBarcodedSurcharge).to_s if detail.destination_rate_indicator == rate['Destination Rate Indicator'] and detail.barcode == '0' and detail.rate_indicator != '5D'
						return rate[detail.rate_indicator] if detail.destination_rate_indicator == rate['Destination Rate Indicator']
					end
				elsif detail.weight.to_f > 0.20625
					perPiece = 0.0
					perOunce = 0.0
					rateTable = loadTable("S2Over3.csv")
					rateTable.each do |rate|
						perPiece = rate[detail.rate_indicator].to_f if rate['Destination Rate Indicator'] == 'Per Piece'
						perOunce = rate[detail.rate_indicator].to_f if detail.destination_rate_indicator == rate['Destination Rate Indicator']
					end
					return ((perPiece + detail.weight.to_f * perOunce).round(3) + nonBarcodedSurcharge).to_s if detail.barcode == '0' and detail.rate_indicator != '5D'
					return (perPiece + detail.weight.to_f * perOunce).round(3).to_s
				end
			end
		end
		#*********************************************************************************************************************************
		def is_non_profit?(rateInd)
			rateInd[0] == 'N'  #All Standard Mail Non-Profit Rate Ingredients start with 'N' (N5, NT, NM, etc)
		end
		#*********************************************************************************************************************************
		#Re-format weight from manifest formatting
		def formatPounds(value, decimal_places = 2)
			wholeNum = value[1, 4] #Pulls the 2nd (A), 3rd (B), 4th (C) and 5th (D) digit from the format 0ABCDdddd where 'd' is the decimal portion of the eVS weight convention
			decimal = value[5, 4]  #Pulls the decimal portion
			return "#{wholeNum}.#{decimal}".to_f.round(decimal_places).to_s
		end
		#*********************************************************************************************************************************
		#Re-format weight from manifest formatting
		def formatOunces(value)
			wholeNum = value[1, 4] #Pulls the 2nd (A), 3rd (B), 4th (C) and 5th (D) digit from the format 0ABCDdddd where 'd' is the decimal portion of the eVS weight convention
			decimal = value[5, 4]  #Pulls the decimal portion
			return ("#{wholeNum}.#{decimal}".to_f * 16.0).round(4).to_s
		end
		#*********************************************************************************************************************************
		#Re-format Price Group value -- trim out "Price Group" from "Price Group #" format as found in the Customer Reference Number 1 Field
		def formatGroup(value)
			return value.delete("Price Group").chomp
		end
		#*********************************************************************************************************************************
		#Priority Mail Cubic Price Tier calculations require each dimension be rounded down to the nearest 1/4th inch.  Format the values and round appropriately.
		def formatCubic(value)
			wholeNum = value[1,2].to_f #Pulls the whole number portion from 00 to 99 of the eVS dimension/size convention
			decimal = "0.#{value[3, 2]}".to_f #Pulls the decimal portion

			quarterVals = [0.00, 0.25, 0.50, 0.75]
			quarterVals.each_with_index do |val, index|
				return (wholeNum + decimal).to_s if decimal == val
				return (wholeNum + quarterVals[index - 1]).to_s if decimal < val
				return (wholeNum + quarterVals.last).to_s if decimal > quarterVals.last
			end
		end
		#*********************************************************************************************************************************
		#Determine the Priority Mail Cubic Price Tier
		def calcTier(length, height, width)
			((length.to_f * height.to_f * width.to_f)/1728.0).round(4)
		end
		#*********************************************************************************************************************************
		def calcDimWeight(rateInd, weight, length, height, width) #Calculate dimensional weight for Dimensional Rect. and Non-Rect.
			length = "#{length[1,2]}.#{length[3,2]}".to_f.round #Re-formats and rounds to nearest whole inch.
			height = "#{height[1,2]}.#{height[3,2]}".to_f.round #Re-formats and rounds to nearest whole inch.
			width = "#{width[1,2]}.#{width[3,2]}".to_f.round #Re-formats and rounds to nearest whole inch.

			if rateInd == 'DR'
				dimWeight = ((length * height * width)/194.0)
				splitNum = dimWeight.to_s.split('.')
				dimWeight = splitNum[0].to_f + 1.0 if splitNum[1].to_f > 0.00
				return dimWeight.to_s if dimWeight > weight.to_f
				return weight if dimWeight < weight.to_f
			elsif rateInd == 'DN'
				dimWeight = (((length * height * width)*0.785)/194.0)
				splitNum = dimWeight.to_s.split('.')
				dimWeight = splitNum[0].to_f + 1.0 if splitNum[1].to_f > 0.00
				return dimWeight.to_s if dimWeight > weight.to_f
				return weight if dimWeight < weight.to_f
			else
				return weight
			end
		end
		#*********************************************************************************************************************************
		#Determine whether the detail record is NSA-only.
		def nsa_only?(detail)
			return true if detail.mail_class == 'MT' #Metro Post is NSA only.
			return true if ['B4','B5','B6','B7','B8','B9','O5','O6','O7','O8','IA','IB','IC'].include?(detail.rate_indicator)
      #New PS Rate Indicators:  LW Machinable (A1, A3, A5), LW Irregular (A2, A4, A6), Extended Coverage (1B, 1C, 1D)
      #New FC Rate Indicators:  First Class <= 5lbs (2B, 2C, 2D, 2F)
			#B4-B9 are PS NSA-Only Rates.  O5-O8 are PMOD NSA-Only rates.  IA, IB, and IC are PMI NSA-Only rates.
		end
		#*********************************************************************************************************************************
		#Return Discount Type or Surcharge Type if a given detail record contains a non-empty value for discount/surcharge type fields.
		def evaluate_discount_surcharge_type(detail)
			return detail.discount_type if detail.discount_type != ''
			return detail.surcharge_type if detail.surcharge_type != ''
		end
		#*********************************************************************************************************************************
		def evaluate_fc_surcharge(detail)
			if ['3D','AD'].include?(detail.rate_indicator) and detail.processing_category == '5'
				return 0.08 #Non-machinable pieces not in a 5-Digit Scheme get the 0.08 surcharge.
			elsif ['3D','AD','U3','U5','UA','US'].include?(detail.rate_indicator) and detail.processing_category == '3' and detail.barcode == '0'
				return 0.08 #Machinable pieces without a barcode get the 0.08 surcharge.
			else
				return 0.00 #Otherwise, no surcharge.
			end
		end
		#*********************************************************************************************************************************
		#Calculates Parcel Select non-machinable pricing when Special Handling is used.
		def evaluate_ps_with_special_handling(detail) #Return DNDC and DSCF nonmachinable surcharge discount rates (or FALSE if not-applicable).
			dndc_discount = 0 #Initial value set to 0.
			dscf_discount = 0 #Initial value set to 0.
			
			#For DNDC (B), only applicable for rate indicators SP and BN that have PC 5 (Non-machinable)
			#For DSCF (S), only applicable for rate indicators 3D and B3 (3Digit Balloon) that have PC 5 (Non-machinable)
			
			if detail.comb_values(true).include?('970') #Catch extra-service-code '970' (Special Handling)
				if detail.destination_rate_indicator == 'B' and detail.processing_category == '5' and ['SP','BN'].include?(detail.rate_indicator) #Non-machinable DNDC
					machinable_rate = 0
					nonmachinable_rate = 0
					["PSDestEntry3B.csv", "PSDestEntry5B.csv"].each do |rate_table_file|
						rateTable = loadTable(rate_table_file)
						if rate_table_file.include?('3')
							machinable_rate = rateTable.first[detail.domestic_zone].to_f
						elsif rate_table_file.include?('5')
							nonmachinable_rate = rateTable.first[detail.domestic_zone].to_f
						end
					end
					dndc_discount = nonmachinable_rate - machinable_rate
				elsif detail.destination_rate_indicator == 'S' and detail.processing_category == '5' and ['3D','B3'].include?(detail.rate_indicator) #Non-machinable DSCF
					machinable_rate = 0
					nonmachinable_rate = 0
					["PSDestEntry3S.csv", "PSDestEntry5S.csv"].each do |rate_table_file|
						rateTable = loadTable(rate_table_file)
						if rate_table_file.include?('3')
							machinable_rate = rateTable.first['S'].to_f
						elsif rate_table_file.include?('5')
							nonmachinable_rate = rateTable.first['3D'].to_f
						end
					end
					dscf_discount = nonmachinable_rate - machinable_rate
				end
			end
			return dndc_discount.round(2), dscf_discount.round(2)
		end
		#*********************************************************************************************************************************
		def loadTable(tableName)
			rateTable = []
			rateCells = {}
			file = File.open("#{$rate_table_path}/#{tableName}",'r')
			tableColumns = file.readline.chomp.split(',')
			file.each_line do |line|
				rate = line.chomp.split(',')
				tableColumns.each_with_index do |field, index|
					rateCells.merge!(field.to_s => rate[index].to_s)
				end
				rateTable << rateCells.dup if rateCells.empty? == false
				rateCells.clear
			end
			file.close()
			return rateTable
		end
		#*********************************************************************************************************************************
		def create_rate_check_file(efn, mail_class, rate_data)
			file = File.open("#{$rate_validation_path}/#{efn}_rateCheck#{mail_class}.csv",'w')
			file.write("Tracking Number,Mail Class,PC,RI,DRI,Discount/Surcharge,Barcode,Length,Height,Width,Weight,Zone,Base Rate,Plus Rate") if mail_class.domestic?
			file.write("Tracking Number,Mail Class,PC,RI,DRI,Discount/Surcharge,Barcode,Length,Height,Width,Weight,Price Group,Base Rate,Plus Rate") unless mail_class.domestic?
			rate_data.each do |rate|
				file.write("\n")
				file.write(rate.join(','))
			end
			file.close()
		end
	end
end