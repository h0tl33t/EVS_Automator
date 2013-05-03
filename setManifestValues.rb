#File to test classes and set values.

require './manifestClasses'
require './sampleClasses'

continue = true
while continue
	puts "Enter the code you want to evaluate:"
	codeToExecute = gets.chomp
	eval(codeToExecute)
	puts "**************************"
	puts "Do you want to continue? (Y/N)"
	continue = false if gets.downcase == 'n'
end