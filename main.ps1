########################################
#Script 1.3d SDB Mail Backup by Krailer#
########################################
# Release note                         #
# 1. config file txt format            #
# 2. remove all backup old vm          #
# 3. clone backup vm form pools        #
# 4. send email action and notification#
# 5. save log to file txt              #
#                                      #
########################################
#======================= LoadPowerCLI ================================
#Add-PSSnapin VMware.VimAutomation.Core
. "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1"
#
#====================== Clone Backup VM ===============================
Function CloneBKVM($srcresourcepool, $desfolderlocation, $desdatastore, $deslc){
	$vmary = Get-ResourcePool -Name $srcresourcepool | Get-VM | foreach {$_.Name};		# Get array string VM list form resource pool
    $msg = '';
	foreach ($customer in $vmary){                  # Start backup VM
        $date = Get-Date -Format "yyyyMMddHHmmss";
		$newvmname = "BK-" + $date + "-" + $customer;		# This defines the VM Prefixed that will be used for the name of the VM
        $msg += Get-Date -Format "dd.MM.yyyy HH:mm:ss";    	# Set Date format for emails
        $msg += " : Clone [$customer] to [$newvmname] Start `r`n";
        Start-Sleep -s 10;
        try{
		    if(New-VM -Name $newvmname -VM $customer -ResourcePool $desfolderlocation -Location $deslc -Datastore $desdatastore -DiskStorageFormat Thin){
                $msg += Get-Date -Format "dd.MM.yyyy HH:mm:ss";
                $msg += " : Clone [$customer] to [$newvmname] Completed `r`n";
            }
            else{
                $msg += Get-Date -Format "dd.MM.yyyy HH:mm:ss";
                $msg += " : Clone [$customer] to [$newvmname] Something wrong with clone `r`n";
            }
        }
        Catch{
            $msg += Get-Date -Format "dd.MM.yyyy HH:mm:ss";
            $msg += " : Error function `r`n";
        }
		remove-variable customer, newvmname;		# Remove variable
	}
    if($msg -eq ''){
        $msg += Get-Date -Format "dd.MM.yyyy HH:mm:ss";
        $msg += " : Not found any vm for Clone `r`n";
    }
    $msg;
	remove-variable srcresourcepool, desdatastore, desfolderlocation, deslc, msg, vmary ,date;	# Remove variable
}
#==================== END Clone Backup VM =============================
#
#====================== Remove Old Backup VM ==========================
Function RMOldBKVM($desrp,$copys){
    $exit = 0;
    $msg = '';
    do{
        Start-Sleep -s 10;
        $name = New-Object System.Collections.Generic.List[System.Object];
        $point = New-Object System.Collections.Generic.List[System.Object];
        $nco = New-Object System.Collections.Generic.List[System.Object];
        $vmary = Get-ResourcePool -Name $desrp | Get-VM | foreach {$_.Name};
        $dnow = Get-Date -Format "yyyyMMddHHmmss"; 
        $maxpoint = 0;
        $maxname = '';
        $maxcopy = 0;
        foreach ($customer in $vmary){ # create data name, point, copy to array
            if($customer.Split('-')[0] -eq "BK"){
                $dvm = $customer.Split('-')[1];
                $dif = $dnow - $dvm;
                $name.add($customer);
                $point.add($dif);
                $countnco = 0;
                foreach ($vn in $vmary){
                    if($customer.Split('-')[2] -eq $vn.Split('-')[2]){
                        $countnco++;
                    }
                }
                $nco.add($countnco);
            }
        }
        $i=0;
        foreach ($customer in $name){ # find name old vm by max point in real time
            if($copys -lt $nco[$i]){
                if($maxpoint -lt $point[$i]){
                    $maxname = $name[$i];
                    $maxpoint = $point[$i];
                    $maxcopy = $nco[$i];
                }
            }
            $i++;
        }
        #echo "loop";
        if($maxname -ne ''){ # Remove old vm by name max point in real time
            #echo "maxloop";
            if($copys -lt $maxcopy){
                #echo "removeloop";
                $msg += Get-Date -Format "dd.MM.yyyy HH:mm:ss";    	# Set Date format for emails
                $msg += " : Remove [$maxname] Start `r`n";
                try{
                    if(Remove-VM $maxname -DeletePermanently -Confirm:$false -RunAsync){
                        $msg += Get-Date -Format "dd.MM.yyyy HH:mm:ss";
                        $msg += " : Remove [$maxname] Completed `r`n";
                    }
                    else{
                        $msg += Get-Date -Format "dd.MM.yyyy HH:mm:ss";
                        $msg += " : Remove [$maxname] Something wrong with delete `r`n";
                    }
                }
                Catch{
                    $msg += Get-Date -Format "dd.MM.yyyy HH:mm:ss";
                    $msg += " : Error function `r`n";
                }
            }
            else{
                $exit = 1; # exit loop if not vm found for remove
                #echo "end loop";
            }
        }
        else{
            $exit = 1; # exit loop if not vm found for remove
            #echo "end loop";
        }
    }while($exit –ne 1);
    if($msg -eq ''){
        $msg += Get-Date -Format "dd.MM.yyyy HH:mm:ss";
        $msg += " : Not found any vm for remove `r`n";
    }
    $msg;
    remove-variable desrp, copys, exit, msg, name, point, nco, vmary, dnow, maxpoint, maxname, maxcopy, customer, dvm, dif, countnco, i;
}
#==================== END Remove Old Backup VM ========================
#
#========================= Send Email =================================
Function SendEmail($smtpServer, $sfrom, $sto, $scc, $ssubject, $sdear, $smessage, $ssignature){   #Sent e-mail
    $msg = '';
    $smsg = new-object Net.Mail.MailMessage;
    $smtp = new-object Net.Mail.SmtpClient($smtpServer);
    $smsg.From = $sfrom;
    $smsg.To.Add($sto);
    $smsg.cc.Add($scc);
    $smsg.Subject = $ssubject;
    $smsg.Body = "$sdear`r`n`r`n$smessage`r`n`r`n$ssignature";
    Try{
        $smtp.Send($smsg);
        $msg += Get-Date -Format "dd.MM.yyyy HH:mm:ss";
        $msg += " : Send E-mail ready.`r`n";
    }
    Catch{
        $msg += Get-Date -Format "dd.MM.yyyy HH:mm:ss";
        $msg += " : Can not Send E-mail.`r`n";
    }
    $msg;
	remove-variable smtpServer, sfrom, sto, scc, ssubject, sdear, smessage, ssignature, msg, smsg, smtp;
}
#======================= END Send Email ===============================
#
#=========================== MAIN =====================================
# Specify the path to the Excel file and the WorkSheet Name
$report = $null;
$fcn = (split-path $SCRIPT:MyInvocation.MyCommand.Path -parent)+'\main.conf';
$a = Get-Content $fcn;
$i = 0;
$line = $a.Split("`r`n").count
$conf = New-Object System.Collections.Generic.List[System.Object];
$confn = New-Object System.Collections.Generic.List[System.Object];
do{
    $txl = $a.Split("`r`n")[$i];
    $i += 1;
    if($txl[0] -ne '#'){
        $conf.add([string]$txl.Split('=')[1]);
        $confn.add([string]$txl.Split('=')[0]);
    }
}while($i -lt $line);
remove-variable fcn, a, i, line, txl;
# Authentication for login vmware vsphere
$vc = "";
$user = ""; # Username
$pass = ""; # Password
# Backup Config Source and Destination for backup
$spools = ""; # Source Pools
$dpools = ""; # Destination Pools
$dlc = ""; # Destination Foder
$ddstore = ""; # Destination Datastore
$bcopy = ""; # Backup copy
# E-mail Notification alert start and done backup
$relay = ""; # Relay Server
$form = ""; # Form
$to = ""; # To
$cc = ""; # CC
$sub = ""; # Subject
$dear = ""; # Dear
$body = ""; # Body
$sig = ""; # Signature
$i = 0;
foreach ($tname in $confn){
    if($tname -eq "vc"){
        $vc = $conf[$i];
        #echo $vc;
    }
    elseif($tname -eq "uname"){
        $user = $conf[$i]; # Username
        #echo $user;
    }
    elseif($tname -eq "pass"){
        $pass = $conf[$i]; # Password
        #echo $pass;
    }
    elseif($tname -eq "sp"){
        $spools = $conf[$i]; # Source Pools
        #echo $spllos;
    }
    elseif($tname -eq "dp"){
        $dpools = $conf[$i]; # Destination Pools
    }
    elseif($tname -eq "lc"){
        $dlc = $conf[$i]; # Destination Foder
    }
    elseif($tname -eq "dd"){
        $ddstore = $conf[$i]; # Destination Datastore
    }
    elseif($tname -eq "bc"){
        $bcopy = $conf[$i]; # Backup copy
    }
    elseif($tname -eq "rs"){
        $relay = $conf[$i]; # Relay Server
    }
    elseif($tname -eq "fo"){
        $form = $conf[$i]; # Form
    }
    elseif($tname -eq "to"){
        $to = $conf[$i]; # To
    }
    elseif($tname -eq "cc"){
        $cc = $conf[$i]; # CC
    }
    elseif($tname -eq "su"){
        $sub = $conf[$i]; # Subject 
    }
    elseif($tname -eq "de"){
        $dear = $conf[$i]; # Dear
    }
    elseif($tname -eq "bo"){
        $body = $conf[$i]; # Body
    }
    elseif($tname -eq "sg"){
        $sig = $conf[$i]; # Signature
    }
    else{
    }
    $i++;
}
remove-variable i;
# Login VMware vCenter Server by username and password
try{
    Connect-VIServer $vc -User $user -Password $pass; # Connect to vCenter
    $report += Get-Date -Format "dd.MM.yyyy HH:mm:ss";
    $report += " : Connect to [$vc] ready.`r`n";
}                                               
Catch{
    $report += Get-Date -Format "dd.MM.yyyy HH:mm:ss";
    $report += " : Connect to [$vc] Something wrong`r`n";
}
$report += CloneBKVM($spools)($dpools)($ddstore)($dlc); # Start function clone vm for bk
$report += RMOldBKVM($dpools)($bcopy); # Start function remove vm form disk
try{
    Disconnect-VIServer -Server $vc -Force -Confirm:$false; # Disconnect from vCentre
    $report += Get-Date -Format "dd.MM.yyyy HH:mm:ss";
    $report += " : Disconnect [$vc] done.`r`n";
}
Catch{
    $report += Get-Date -Format "dd.MM.yyyy HH:mm:ss";
    $report += " : Disconnect [$vc] Something wrong";
}
$message = "$body `r`n`r`n=============== Log Information Below ===============`r`n`r`n$report`r`n====================== Log End ======================";
$report += SendEmail($relay)($form)($to)($cc)($sub)($dear)($message)($sig);
$rootp = split-path $SCRIPT:MyInvocation.MyCommand.Path -parent;
$report | out-file "$rootp\log_sdb_bk.txt";
echo $report;
remove-variable report, conf, confn, user, pass, vc, spools, dpools, dlc, ddstore, relay, form, to, cc, sub, dear, body, sig, message, rootp; # Remove variable
#========================= END MAIN ===================================
