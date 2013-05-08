#File to test classes and set values.

require_relative 'manifest'
require_relative 'sample_generator'
require_relative 'extract_generator'

continue = true
while continue
	puts "Enter the code you want to evaluate:"
	codeToExecute = gets.chomp
	eval(codeToExecute)
	puts "**************************"
	puts "Do you want to continue? (Y/N)"
	choice = gets.chomp.upcase
	continue = false if choice == 'N'
end