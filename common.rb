module Common

    require 'sqlite3'
    require 'rest-client'
    require 'socket'
    require 'fileutils'
    require 'cgi'

def Common.setup ()

    myData = Hash.new
    begin
        db = SQLite3::Database.open 'master.db'
        stm = db.prepare "SELECT config_name, config_value FROM config"
        rs = stm.execute
        while (row = rs.next) do
            myData[row[0]] = row[1]
        end
    rescue SQLite3::Exception => e
        Common.logEvent("Exception occurred", "STDOUT", "STDOUT")
        Common.logEvent(e, "STDOUT", "STDOUT")
    ensure
        stm.close if stm
        db.close if db
    end

    return myData
end
  
def Common.setConfig(myConfig)
    anythingChanged = false
    myConfig.each do |config_name, config_value|
        print("\nCurrent value of ", config_name, " is '", config_value, "'\n")
        print("Change ? (C), Continue (Enter), Quit (Q)")
        myReply = gets
        myReply.chomp!
        case myReply.upcase
            when "Q"
                return
            when "C"
                print("\n", "Please enter new value for ", config_name, " :")
                myInput = gets
                myInput.chomp!
                myConfig[config_name] = myInput
                anythingChanged = true
        end
    end

    if anythingChanged
        puts "The following will be updated:"
        myConfig.each { |key, value|
            print(key, " will be set to '", value, "'\n") }
        print("Confirm changes ? (C), Abort (A)")
        myReply = gets
        myReply.chomp!
        case myReply.upcase
        when "A"
            return
        when "C"
            Common.updateConfig(myConfig)
        end
    end
    myConfig = Common.setup
end

def Common.setSystem(myConfig)
    while true
        if OS.mac? or OS.posix?
            system("clear")
        else
            system("cls")
        end
        puts "Settings"
        puts "--------"
        puts
        puts "(I) Initialize Database"
        puts "(P) Set configuration parameters"
        puts "(R) Refresh Configuration Only"
        puts "(X) Return to Main Menu"
        puts

        myOption = gets
        myOption.chomp!.upcase!
        case myOption
        when "X"
            return
        when "I"
            Common.initializeDb("Init")
        when "R"
            Common.initializeDb("Refresh")
        when "C"
            Common.clearAllFiles("STDOUT", "STDOUT", myConfig)
        when "P"
            puts "Set configuration"
            setConfig(myConfig)
            puts "Press enter to continue."
            gets
        else
            puts "Please select a valid option."
            puts "Press enter to continue."
            gets
        end
    end
end

def Common.initializeDb(action)

    if action == "Init"
        if File.exist?("./master.db")
            File.delete("./master.db")
        end
        db=SQLite3::Database.new("master.db")
    else
        db = SQLite3::Database.open 'master.db'
        db.execute "DROP TABLE IF EXISTS config"
    end

    # CONFIG Table
    db.execute "CREATE TABLE IF NOT EXISTS config(config_name TEXT, config_value TEXT)"
    
    # Document location
    db.execute "INSERT INTO config (config_name, config_value) VALUES (?, ?)", 'RootDirectoryMac', '/Users/chris/Data/Documents/'
    db.execute "INSERT INTO config (config_name, config_value) VALUES (?, ?)", 'RootDirectoryPosix', '/home/chris/Data/Documents/'
    db.execute "INSERT INTO config (config_name, config_value) VALUES (?, ?)", 'RootDirectoryPCWhenOnMac', 'C:\\\Users\\\1347409\\\OneDrive - TCS COM PROD\\\Documents\\'
    db.execute "INSERT INTO config (config_name, config_value) VALUES (?, ?)", 'RootDirectoryPCWhenOnPC', 'C:\Users\1347409\OneDrive - TCS COM PROD\Documents\\'
    # Code location
    db.execute "INSERT INTO config (config_name, config_value) VALUES (?, ?)", 'CodeMac', '/Users/chris/Data/Projects/DataSync/'
    db.execute "INSERT INTO config (config_name, config_value) VALUES (?, ?)", 'CodePosix', '/home/chris/Data/Projects/DataSync/'
    db.execute "INSERT INTO config (config_name, config_value) VALUES (?, ?)", 'CodePC', 'C:\\Users\\1347409\\code\\Dev\\'
    # Execution specific
    db.execute "INSERT INTO config (config_name, config_value) VALUES (?, ?)", 'ChangedFiles', 'changedFiles.txt'
    # Exception files
    db.execute "INSERT INTO config (config_name, config_value) VALUES (?, ?)", 'ExceptionFiles', 'exceptionFiles.txt'
    # FILETIMESTAMP Table
    db.execute "CREATE TABLE IF NOT EXISTS fileTimeStamp(folder_name TEXT, last_access INTEGER)"
    # Set the Hub being used: CustomAPI
    db.execute "INSERT INTO config (config_name, config_value) VALUES (?, ?)", 'Technology', 'CustomAPI'
    # Set the Hub IP address
    db.execute "INSERT INTO config (config_name, config_value) VALUES (?, ?)", 'HubIP', '10.0.0.58'
    # Set the Hub listening port
    db.execute "INSERT INTO config (config_name, config_value) VALUES (?, ?)", 'HubPort', '8000'
    # Set API routes
    db.execute "INSERT INTO config (config_name, config_value) VALUES (?,?)", 'APISend', '/send/?pathname='
    db.execute "INSERT INTO config (config_name, config_value) VALUES (?,?)", 'APIList', '/list/?pathname='
    db.execute "INSERT INTO config (config_name, config_value) VALUES (?,?)", 'APIReceive', '/receive/?pathname='
    
    db.close if db
end

def Common.updateConfig(myConfig)
    db = SQLite3::Database.open 'master.db'
    myConfig.each { |key, value|
        db.execute "UPDATE config SET config_value=? WHERE config_name=?", value, key }
    db.close if db
end

def Common.isAPIHubReady(myConfig)
   begin
        socket = TCPSocket.new(myConfig['HubIP'], myConfig['HubPort'])
        status = true
    rescue Errno::ECONNREFUSED, errno::ETIMEDOUT
        status = false
    end
    return status
end

def Common.getFiles(myConfig, folderName)
    if OS.mac? or OS.posix?
        myListName = "MAC"
        myDirSeperator = "/"
    else
        myListName = "PC"
        myDirSeperator = "\\"
    end

    url = "http://" + myConfig['HubIP'] + ":" + myConfig["HubPort"] + myConfig['APIList']
    url = url + '/' + CGI.escape(folderName) +'/'
    results= RestClient.get(url)

    resultContent = results.body
    resultContent = resultContent.gsub('[','')
    resultContent  = resultContent.gsub(']','')

    fileList = resultContent.split(",")

    print("The following files are being received: \n")
    print("--------------------------------------- \n")
    
#myF = File.open('results.txt', "a")


    fileList.each do |myFileItem|
        print(myFileItem, "\n")


        hubFile = myFileItem.rstrip
        myFile = Common.convertToMyPlatform(hubFile, myConfig)
        Common.receiveFile(myConfig, hubFile, myFile)

   
#myF.puts myFileItem.encode("UTF-8")
    
    end
    print(" ---- Done\n")

#myF.close 


end

def Common.convertToMyPlatform(path, myConfig)

    if OS.mac?
        fromSeperator = "/"
        toSeperator = "\\"
        fromRoot = myConfig['RootDirectoryMac']
        toRoot = myConfig['RootDirectoryPCWhenOnMac']
    elsif OS.posix?
        fromSeperator = "/"
        toSeperator = "\\"
        fromRoot = myConfig['RootDirectoryPosix']
        toRoot = myConfig['RootDirectoryPCWhenOnMac']
    elsif OS.windows?
        fromSeperator = "/"
        toSeperator = "\\"
        toRoot = myConfig['RootDirectoryPCWhenOnMac']
        if Common.hubPlatform(myConfig) == "Linux"
            fromRoot = myConfig['RootDirectoryPosix']
        else
            fromRoot = myConfig['RootDirectoryMac']
        end
    end

    myPath = path.gsub(fromRoot,toRoot)
    myPath = myPath.gsub(fromSeperator,toSeperator)
    return myPath
end

def Common.receiveFile(myConfig, hubFile, fileName)
    
    if OS.mac?
        mySeperator = "/"
        myCodePath = myConfig['CodeMac']
    elsif OS.posix?
        mySeperator = "/"
        myCodePath = myConfig['CodePosix']
    elsif OS.windows?
        mySeperator = 92.chr
        myCodePath = myConfig['CodePC']
    end

    url = "http://" + myConfig['HubIP'] + ":" + myConfig["HubPort"] + myConfig['APIReceive']
    myHubFile = hubFile.chomp('"').reverse.chomp('"').reverse
    myStr = CGI.escape(myHubFile)
    url = url + myStr 
    myNewUrl = url.tr('"','')
    myPath = File.dirname(fileName).tr('"','')
    myFile = fileName[File.dirname(fileName).length + 1, fileName.length].tr('"','').gsub(":","-").gsub("?","-").gsub("*","-").gsub("|","-").gsub("<","-").gsub(">","-")
    myPathAndFileName = myPath + '\\' + myFile
    myDir = File.dirname(fileName)
    myNewDir = myDir.tr('"','')
    
    proceedFlag = true
    begin
        FileUtils.mkdir_p myNewDir
    rescue => e
        proceedFlag = false
        Common.logEvent(e, "STDOUT", "STDOUT")
    end

    if proceedFlag
        if not Dir.exist?(myNewDir)
        FileUtils.mkdir_p myNewDir
        end
        begin
            myResponse = RestClient.get(myNewUrl)
        rescue => e
            Common.logEvent(e, "STDOUT", "STDOUT")
        end

        file = File.open(myPathAndFileName, 'wb')
        file.write(myResponse.body)
        file.close()
    else
        exceptionFile = File.open(myCodePath + myConfig['ExceptionFiles'], "a")
        exceptionFile.puts fileName.encode("UTF-8")
        exceptionFile.close 
    end
end

def Common.hubPlatform(myConfig)
    url = "http://" + myConfig['HubIP'] + ":" + myConfig["HubPort"] + "/platform"
    return RestClient.get(url)
end

def Common.scanForChanges(path='.', lastScan, myConfig)

    if OS.mac?
        mySeperator = "/"
        myCodePath = myConfig['CodeMac']
    elsif OS.posix?
        mySeperator = "/"
        myCodePath = myConfig['CodePosix']
    elsif OS.windows?
        mySeperator = 92.chr
        myCodePath = myConfig['CodePC']
    end

    if not Dir.exist?(path)
        Common.logEvent("Directory " + path + " does not exist. Please chech and try again", "STDOUT", "STDOUT")
        Common.logEvent("Press enter to continue.", "STDOUT", "STDOUT")
        gets
        return
    end

    myPath = Dir.entries(path)

    myPath.each do |name|

        next  if name[0] == '.'
        path2 = path + mySeperator + name
        
        proceedFlag = true
        
        begin
            File.ftype(path2)
        rescue => e
            proceedFlag = false
            Common.logEvent(e, "STDOUT", "STDOUT")
        end

        if proceedFlag
            if File.ftype(path2) == "directory"
                scanForChanges(path2, lastScan, myConfig)
            else
                f = path + mySeperator + name
                fileTime = File.atime(f).to_i
                
                if (fileTime >= lastScan) and (name.byteslice(-3,3) != "mp4")

                    myFile = File.open(myCodePath + myConfig['ChangedFiles'], "a")
                    myFile.puts f.encode("UTF-8")
                    myFile.close  
                end
            end
        else
            myFile = File.open(myCodePath + myConfig['ExceptionFiles'], "a")
            myFile.puts path2.encode("UTF-8")
            myFile.close 
        end
    end
end

def Common.sendFiles(myFolder, myConfig)
    if OS.mac?
        myTarget = "PC"
        mySeperator = "/"
        myCodePath = myConfig['CodeMac']
    elsif OS.posix?
        myTarget = "PC"
        mySeperator = "/"
        myCodePath = myConfig['CodePosix']
    elsif OS.windows?
        myTarget = "MAC"
        mySeperator = "\\"
        myCodePath = myConfig['CodePC']
    end

    if not File.exist?(myCodePath + myConfig['ChangedFiles'])
        Common.logEvent("No files have changed since last run.", "STDOUT", "STDOUT")
        return
    end

    x = File.open(myCodePath + myConfig['ChangedFiles'], "r")
    for fileName in x
        url = "http://" + myConfig['HubIP'] + ":" + myConfig["HubPort"] + myConfig['APISend']

        print(fileName)

        fileName.chomp!

        targetPath = Common.convertToTargetPlatform(fileName, myConfig)
       
        encodedTargetPath = CGI.escape(targetPath)
        url = url + encodedTargetPath

        fileName = fileName.chomp('"').reverse.chomp('"').reverse

        myPath = File.dirname(fileName).tr('"','')
        myFile = File.basename(fileName)

        myPathAndFileName = myPath + "\\" + myFile

        begin
            files = {'file': File.open(myPathAndFileName,'rb')}
        rescue => e
            Common.logEvent(e, "STDOUT", "STDOUT")
            gets
        end

        begin
            RestClient.post(url, files=files)
        rescue => e
            Common.logEvent(e, "STDOUT", "STDOUT")
            gets
        end
    end
    x.close
    File.delete(myCodePath + myConfig['ChangedFiles'])
    Common.thisTimeStamp(myFolder)
end

def Common.lastTimeStamp (myFolder)
    begin
        db = SQLite3::Database.open 'master.db'
        myStmt = "SELECT last_access FROM fileTimeStamp WHERE folder_name=" + '"' + myFolder + '"'
        lastTimeStamp = db.get_first_value myStmt
    rescue SQLite3::Exception => e
        Common.logEvent("Exception occurred", "STDOUT", "STDOUT")
        Common.logEvent(e, "STDOUT", "STDOUT")
        gets
    ensure
        db.close if db
    end
    return lastTimeStamp
end

def Common.thisTimeStamp(myFolder)
    begin
        db = SQLite3::Database.open 'master.db'
        timeStamp = db.get_first_row "SELECT last_access FROM fileTimeStamp WHERE folder_name='" + myFolder + "'"
        if timeStamp == nil
            # Insert
            db.execute "INSERT INTO fileTimeStamp (folder_name, last_access) VALUES (?, ?)", myFolder, Time.now.to_i
        else
            # Update
            updateStatement = "UPDATE fileTimeStamp SET last_access=? WHERE folder_name=?"
            db.execute updateStatement, Time.now.to_i, myFolder
        end
    rescue SQLite3::Exception => e
        Common.logEvent("Exception occurred", "STDOUT", "STDOUT")
        Common.logEvent(e, "STDOUT", "STDOUT")
    ensure
        db.close if db
    end
end

def Common.resetTimeStamp(myFolder, resetTo)
    db = SQLite3::Database.open 'master.db'
    if myFolder == "A"
        updateStatement = "UPDATE fileTimeStamp SET last_access=?"
        db.execute updateStatement, resetTo
    else
        updateStatement = "UPDATE fileTimeStamp SET last_access=? WHERE folder_name=?"
        db.execute updateStatement, resetTo, myFolder
    end
    db.close if db
end

def Common.convertToTargetPlatform(path, myConfig)

    if OS.mac?
        fromSeperator = "/"
        toSeperator = "\\"
        fromRoot = myConfig['RootDirectoryMac']
        toRoot = myConfig['RootDirectoryPCWhenOnMac']
    elsif OS.posix?
        fromSeperator = "/"
        toSeperator = "\\"
        fromRoot = myConfig['RootDirectoryPosix']
        toRoot = myConfig['RootDirectoryPCWhenOnMac']
    elsif OS.windows?
        fromSeperator = "\\"
        toSeperator = "/"
        fromRoot = myConfig['RootDirectoryPCWhenOnPC']

        theHubPlatform = Common.hubPlatform(myConfig)
        if theHubPlatform == "Linux"
            toRoot = myConfig['RootDirectoryPosix']
        elsif theHubPlatform == "Darwin"
            toRoot = myConfig['RootDirectoryMac']
        end
    end

    myPath = path.gsub(fromRoot,toRoot)
    myPath = myPath.gsub(fromSeperator,toSeperator)

    return myPath
end

def Common.logEvent(msg, media, logName)
    case media
    when "TK"
        logName.insert 'end', msg
    when "QUEUE"
            logName << msg
    else
       puts msg
    end
end

end