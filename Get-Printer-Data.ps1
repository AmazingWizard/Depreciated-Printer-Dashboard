
# Built with Angular and Firebase. You will need to make a firebase account. I never figured out how
# The firebase authentication stuff worked. So if you figure that out let me know! 

$SNMP = new-object -ComObject olePrn.OleSNMP
$PrintServer = "Your Print Server" # you could likely modify this to work with a list of servers. 
$fb_url = "https://your-firebase-app.firebaseio.com"

# Get all your printers from your print server. If you have a good name convention
# you can use it as your filter. For example GN-Printer-*

$All_Printers = get-printer -ComputerName $PrintServer | 
    Where-Object {
        $_.Name -like "Add Your Filter Here"} |
    Where-Object {  $_.DeviceType -EQ "Print" } # I forget why I did this. Some printers showed up with a different Device Type, and I think they were not "real" printers.

foreach ($Printer in $All_Printers){
    # Port Name is used to find the address for SNMP. Make sure you get rid of dupes
    # You might have to fix the port names if you have weird ones.
    $Address = $Printer.PortName  
    $Name = $Printer.Name
    $Online = ""

    # Set the online status. This is useful, but is really depenedent on how much you refresh your data. 
    if(!(Test-Connection $address -Quiet -Count 1)){$onlineState = "Offline";$onlineColor = "danger"}
    
    #If the printer is online, get more information.
    if(Test-Connection $address -Quiet -Count 1)
    {
        $onlineState = "Online"
        $onlineColor = "success" # These Colors are part of the Angular App. They are incerted in to Bootstrap Styles applied to the HTML.
    
        $SNMP.Open($Address,"public",2,3000)

        $printertype = $snmp.Get(".1.3.6.1.2.1.25.3.2.1.3.1") # Get the Printer Type 

        $black_tonervolume = $snmp.get("43.11.1.1.8.1.1") # Get the max toner volume
        $black_currentvolume = $snmp.get("43.11.1.1.9.1.1") # Get the current toner volume
        [int]$black_percentremaining = ($black_currentvolume / $black_tonervolume) * 100 # Do some math to get percentage left

        $cyan_tonervolume = $snmp.get("43.11.1.1.8.1.2")
        $cyan_currentvolume = $snmp.get("43.11.1.1.9.1.2")
        [int]$cyan_percentremaining = ($cyan_currentvolume / $cyan_tonervolume) * 100

        $magenta_tonervolume = $snmp.get("43.11.1.1.8.1.3")
        $magenta_currentvolume = $snmp.get("43.11.1.1.9.1.3")
        [int]$magenta_percentremaining = ($magenta_currentvolume / $magenta_tonervolume) * 100

        $yellow_tonervolume = $snmp.get("43.11.1.1.8.1.4")
        $yellow_currentvolume = $snmp.get("43.11.1.1.9.1.4")
        [int]$yellow_percentremaining = ($yellow_currentvolume / $yellow_tonervolume) * 100

        # Here I do some math to get the Average Toner level. This was built with color in mind, and I weight Black toner more
        # This way when the Black toner is getting low, the "Average Toner" appears much lower and it will sort higher in the list
        # With out this weight you will have printers out of black toner saying there is about 66% toner left on average. 

        $average_toner_level = [int]((($black_percentremaining * 6) + $cyan_percentremaining + $magenta_percentremaining + $yellow_percentremaining)/9)
        If($average_toner_level -ge 60){
            $AlertColor = "success"    
        } elseif($average_toner_level -ge 31 -AND $average_toner_level -le 59 ) {
            $AlertColor = "warning"
        } elseif($average_toner_level -le 30){
            $AlertColor = "danger"
        }
    }
    
    # Build the JSON object to be pushed to firebase as an entry. 

    $JSON = @"
{
	`"Online`": {
        `"Color`":  `"$onlineColor`",
        `"Status`": `"$onlineState`"
        },
	`"Type`": `"$printertype`",
	`"Name`": `"$Name`",
    `"`Address":  `"$Address`",
	`"Color`": `"$AlertColor`",
	`"Toner`": {
        `"TonerAverage`":{
            `"Name`":`"TonerAverage`",
            `"Percentage`": `"$average_toner_level"`,
            `"Color`": `"TonerAverage`"
        },
		`"Black`": {
            `"Name`":`"Black`",
			`"Percentage`": `"$black_percentremaining`",
			`"Color`": `"Black`"
		},
		`"Cyan`": {
            `"Name`":`"Cyan`",
			`"Percentage`": `"$cyan_percentremaining`",
			`"Color`": `"Cyan`"
		},
		`"Magenta`": {
            `"Name`":`"Magenta`",
			`"Percentage`": `"$magenta_percentremaining`",
			`"Color`": `"Magenta`"
		},
		`"Yellow`": {
            `"Name`":`"Yellow`",
			`"Percentage`": `"$yellow_percentremaining`",
			`"Color`": `"Yellow`"
		}
	}
}
"@

    # Invoke the RestMethod 'PUT' against your FB url for your new entry. Each printer is stored under Printers by its name. 
    # If you don't have unique printer names it might be an issue. 
    Invoke-RestMethod -Method Put -Uri $fb_url/Printers/$Name.json -Body $JSON
    
    $SNMP.Close()
}
