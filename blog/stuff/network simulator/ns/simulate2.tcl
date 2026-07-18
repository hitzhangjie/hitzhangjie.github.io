#create a simulator object
set ns [new Simulator]

#define several colors
$ns color 1	Yellow 
$ns color 2 Green

#open nam trace 
set nf [open out.nam w]
$ns namtrace-all $nf

#define a 'finish' procdure
proc finish {} {
	global ns nf
	$ns flush-trace
	#close name trace file
	close $nf
	#execute name on the trace file
	exec nam out.nam &
	exit 0
}

#create 4 nodes
set n0 [$ns node]
set n1 [$ns node]
set n2 [$ns node]
set n3 [$ns node]

#create links between nodes
$ns duplex-link $n0 $n2 2Mb 10ms DropTail
$ns duplex-link $n1 $n2 2Mb 10ms DropTail
$ns duplex-link $n2 $n3 1.7Mb 20ms DropTail

#set queue size of link (n2-n3) to 16
$ns queue-limit $n2 $n3 5 

#give node position (for nam)
$ns duplex-link-op $n0 $n2 orient right-down
$ns duplex-link-op $n1 $n2 orient right-up
$ns duplex-link-op $n2 $n3 orient right

#monitor the queue for (n2-n3) 
$ns duplex-link-op $n2 $n3 queuePos 0.5

#setup a tcp conn
set tcp [new Agent/TCP]
$tcp set class_ 2
$ns attach-agent $n0 $tcp
set sink [new Agent/TCPSink]
$ns attach-agent $n3 $sink
$ns connect $tcp $sink
$tcp set fid_ 1

#setup a ftp over tcp conn
set ftp [new Application/FTP]
$ftp attach-agent $tcp
$ftp set type_ FTP

#setup a udp conn
set udp [new Agent/UDP]
$ns attach-agent $n1 $udp
set null [new Agent/Null]
$ns attach-agent $n3 $null
$ns connect $udp $null
$udp set fid_ 2

#setup a cbr over udp conn
set cbr [new Application/Traffic/CBR]
$cbr attach-agent $udp
$cbr set type_ CBR
$cbr set packet_size_ 1000
$cbr set rate_ 1mb
$cbr set random_ false

#schedule events for cbr and ftp agents
$ns at 0.1 "$cbr start"
$ns at 1.0 "$ftp start"
$ns at 4.0 "$ftp stop"
$ns at 4.5 "$cbr stop"

#detach tcp and sink agents
$ns at 4.5 "$ns detach-agent $n0 $tcp; $ns detach-agent $n3 $sink"

#call finish procedure after 5 seconds of simulation
$ns at 5.0 "finish"

#print
puts "cbr packet size = [$cbr set packet_size_]"
puts "cbr interval = [$cbr set interval_]"

#run the simulation
$ns run
