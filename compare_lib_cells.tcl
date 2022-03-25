#!/usr/bin/tclsh

set title [ list "Cell"  "Modified" "Celldefine" "Specify" "File existance" "Onespin"]
set data  [ list "--"  "--" "--" "--"  "--"  "Onespin"]

proc seperate_file {dir onespin questa d device} {
	set fp [ open $onespin "r"]
	set flag 0
	set name ""
	set out_files ""
	set f_cell 0
	while { [gets $fp line] >= 0 } {
		if { [ regexp "`celldefine" $line ] } {
			set f_cell 1
		}

		if { [ regexp "^module" $line ]  ||  [ regexp "^primitive" $line ]} {
			set flag 1
			set name1 [ lindex [ split [ join $line " "] " ("] 1 ]
			set name  [ concat $name1.v]
			set out_files [open $dir/$name a]
			puts $name
			if { $f_cell } { 
				puts $out_files "`celldefine"
			}
		}
		if { $flag } {
			puts $out_files $line
		}
		if { [ regexp "^`endcelldefine" $line ] } {
            		set flag 0
			set f_cell 0
			catch {
				close $out_files
			}
			puts "---------------"
        	}	
	}
	diff_log $dir $onespin $questa $d $device
}

proc diff_log {dir onespin questa d device} {
	set fp [open $d/file_$device.diff a]
	set file [ exec find $dir -name "*.v" ]
	foreach file1 $file  {
		set name [ lindex [split $file1 "/"] 2]
		set code [catch {
			exec egrep "(MG)|QA" $questa/$name
		} result]

		if {$code == 0} {
    			puts "Result was $result"
			catch { exec diff -wi $file1 $questa/$name } result
			catch { 
				puts $fp "NAME: $name"
				puts $fp $result
				puts $fp "----"
			}	   	
		} elseif {$code == 1} {
			 catch {
                               puts $fp "NAME: $name"
                               puts $fp "No changes"
                               puts $fp "----"
                       }

    			puts "Error happened with message: $result"
		} else {
    			# Consult the manual for the other cases if you care
    			puts "Code: $code\nResult:$result"
		}

	}
	close $fp
}

proc diff_in_csv { d device} {
	global title
	global data

	set result_file   [ open "$d/res_$device.csv" a+ ]
	puts $result_file [ join $title "," ]	
	set f [open $d/file_$device.diff "r"]
	set cell_d 0
	set spec_d 0
	set diff 1
	set onespin 0
	set ex 0
	set param 0
	while { [gets $f line] >= 0 } {
		set t_l [ string trim $line]
		set l [ split $line " " ]
		if { [ regexp "NAME:" $line] } {
			set cell_d 0
			set spec_d 0
			set diff 0
			set param 0
			set name [ lindex [ split $line " ." ] 1]
			lset data 0 $name
			puts $name
			set ex 0
		}
		if { [ regexp "NO changes" $line] } {
			set cell_d 0
                        set spec_d 0
                        set diff 0
                        set param 0
			lset data 1 $diff
                        lset data 2 $cell_d
                        lset data 3 $spec_d
                        lset data 4 "--"
                        lset data 5 $param
                        puts $result_file [ join $data  "," ]

		}
		if { [regexp "diff:" $line ] } {
			set ex 1
			lset data 1 "--"
			lset data 2 "--"
			lset data 3 "--"
			lset data 4 $line
			lset data 5 "--"
			puts $result_file [ join $data  "," ]
		} else { 
			if { [regexp "^<" $line] || [regexp "^>" $line] } {
				set diff 1 
				if { [ regexp "`ifndef ONESPIN" $line] || [ regexp "`ifdef ONESPIN" $line] || [ regexp "endif" $line ] } {
					puts "onespin"
					set onespin 1		
				} elseif { [ regexp "specify" $line ] && $onespin } {
					#specify block logic works partly
					set spec_d 1
					puts "spec"
				} elseif { [ regexp "endspecify" $line ] && $onespin } {
					set spec_d 0
				} elseif {  [ regexp "`celldefine" $line] } { 
					set cell_d 1
					puts "celldefine"
				} elseif {  [ regexp "`endcelldefine" $line] } { 
                                       # set cell_d 0
                                        puts "endcelldefine"
				} elseif { [regexp "//" [lindex $l 1 ]] } {
					puts "comment"
				} elseif {  $t_l == "<" || $t_l == ">"} {
					puts "empty"
				} elseif { [regexp "endmodule" $line ] } { 
					puts "endmodule"
				} else {
					puts "else $line"
					set cell_d 0
					set onespin 0
				}
			}
			if { [string match "----" $line ] && $ex==0 } {
				puts "cell_d is matching $cell_d"	
				lset data 1 $diff
				lset data 2 $cell_d
				lset data 3 $spec_d
				lset data 4 "--"
				lset data 5 $onespin	
				puts $result_file [ join $data  "," ]
				puts $data 
			}
		}
	}
}

if { $argc > 0 } {
	set device $argv 
}


exec mkdir "diff1_$device"
exec mkdir "merged1_$device"
seperate_file "./merged1_$device" "microsemi_vendor_cells/verilog/$device.v" "microsemi_questa_cells/$device" "diff1_$device" "$device" 
diff_in_csv "diff1_$device" "$device"

