Class mom
mom instproc greet {} {
	$self instvar age
	puts "mom is $age year old"
}

Class kid -superclass mom
kid instproc greet {} {
	$self instvar age
	puts "kid is $age year old"
}

set a [new mom]
set b [new kid]

$a set age 45
$b set age 15

$a greet
$b greet

