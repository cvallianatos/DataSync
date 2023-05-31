require 'os'

# Main program

myFlag = true
gotLoaded = false
while myFlag
    if OS.mac? or OS.posix?
        system("clear")
    else
        system("cls")
    end

    puts "Main Menu"
    puts "---------"
    puts
    puts "(S) Send files"
    puts "(R) Receive files"
    puts "(C) Set timestamp"
    puts "(M) Process emails & attachments"
    puts "(T) Sync with Teams"
    puts "(G) Settings"
    puts "(X) Exit"
    puts

    myOption = gets
    myOption.chomp!
    myOption.upcase!
   
    if myOption != "M" && myOption != "X" && gotLoaded != true
        gotLoaded = true
        if OS.mac? or OS.posix?
            require './common.rb'
        else
            require 'C:\\Users\\1347409\\code\\common.rb'
        end
        myConfig = Common.setup()

        if OS.mac?
            myCodePath = myConfig['CodeMac']
            myDocumentDirectory = myConfig['RootDirectoryMac']
        elsif OS.posix?
            myCodePath = myConfig['CodePosix']
            myDocumentDirectory = myConfig['RootDirectoryPosix']
        elsif OS.windows?
            myCodePath = myConfig['CodePC']
            myDocumentDirectory = myConfig['RootDirectoryPCWhenOnPC']
        end
    end

    myIsAPIHubReady = false

    if myOption == "S" or myOption == "R"
        myIsAPIHubReady = Common.isAPIHubReady(myConfig)
    end

    case myOption
        when "X"
            myFlag = false
        when "S"
            if myIsAPIHubReady
                puts "Please enter file folder name (under \\Documents)"
                myFolder = gets
                lastScan = Common.lastTimeStamp(myFolder.chomp!)
                if lastScan == nil
                    lastScan = Time.new(2000,1,1).to_i
                end
                Common.scanForChanges(myDocumentDirectory + myFolder, lastScan, myConfig)
                Common.sendFiles(myFolder, myConfig)
            else
                puts "API Hub is not ready."
                puts "Press enter to continue."
                gets
            end
        when "R"
            if myIsAPIHubReady
                puts "Please enter file folder name (under /Data/Documents)"
                myFolder = gets
                Common.getFiles(myConfig, myFolder.chomp!)
                puts "\nPress enter to continue."
                gets
            else
                puts "API Hub is not ready."
                puts "Press enter to continue."
                gets
            end
        when "C"
            puts "Please enter (file folder name), All Folders (A), Quit (Q)"
            myFolder = gets
            myFolder.chomp!
            if myFolder.upcase == "A"
                myFolder.upcase!
            end
            if myFolder.upcase != "Q"
                puts "Enter year"
                myYear = gets
                myYear.chomp!
                puts "Enter month"
                myMonth = gets
                myMonth.chomp!
                puts "Enter day"
                myDay = gets
                myDay.chomp!
                Common.resetTimeStamp(myFolder, Time.new(myYear.to_i, myMonth.to_i, myDay.to_i).to_i)
            end
        when "M"
            if OS.windows?
                require 'C:\\Users\\1347409\\code\\get-email.rb'
                process_emails()
            else
                puts "Feature Not implemented yet."
                puts "Press enter to continue."
                gets
            end
        when "T"
			 if OS.mac? or OS.posix?
				puts "Feature Not implemented yet."
			else
				system("msteams.bat")
			end
			 puts "Press enter to continue."
             gets
        when "G"
            Common.setSystem(myConfig)
        else
            puts "Please select a valid option."
            puts "Press enter to continue."
            gets
    end
end
