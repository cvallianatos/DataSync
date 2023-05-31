# get-email.rb 
# Retrieves all emails from Inbox, saves them in a specific folder and saves all the attachments.
# Relies on config.txt to derive localization information.
# Created by Chris Vallianatos on 9/5/18.
# Copyright © 2018 xbinvestments. All rights reserved.

require 'win32ole'
require 'parseconfig'

def sanitize(inputName)
  # Remove any character that aren't 0-9, A-Z, or a-z
  x = inputName.gsub(/[^0-9A-Z]/i, '_')
  inputName = x[0..30]
end

def get_emails(myFolder, mapi)

  # Setup section to be changed fby modifying the config.txt file
  config = ParseConfig.new('C:\\Users\\1347409\\code\\config.txt')
  
  # Parameters
  targetStr = config['targetStr']
  myPath = config['myPath']
  excluded = config['excluded'].split(",")

  # emails
  emailSubFolder = config['emailSubFolder']
  emailAttachmentSubFolder = config['emailAttachmentSubFolder']
  emailSaveExtension = config['emailSaveExtension']

  myEmails = myPath + emailSubFolder
  myEmailAttachments = myEmails + emailAttachmentSubFolder

  # Get all emails 

  sourceFolder =    mapi.Folders.Item("chris.vallianatos@tcs.com").Folders.Item(myFolder)

  # Target folder "3-Completed"

  targetFolder = mapi.Folders.Item("chris.vallianatos@tcs.com").Folders.Item("CNV").Folders.Item(targetStr)

  numberOfEmails = sourceFolder.Items.Count

  print "There are ", numberOfEmails, " messages in your ", myFolder, "\n"
  print "=====================================================\n"

  numberOfEmails.downto(1) do |i|
    message = sourceFolder.Items.Item(i) 
    print i, " - \tFrom: ", sanitize(message.SenderName), " - \t", sanitize(message.Subject), "\n\n"

  	tempName = message.Subject

  	fileName = myEmails + message.ReceivedTime.strftime("%Y-%m-%d %H-%M-%S") + " - " + sanitize(message.SenderName) + " - " + sanitize(tempName) + emailSaveExtension

  	message.SaveAs(fileName,4)

  	# Save all the attacments of each message

    	message.Attachments.each do |attachment|
    	  attachmentFile = attachment.FileName
  		
  	  # Ignore "ATT00...gif" & "ATT00..img" or any files ending in .png, imgfiles

    	  if !excluded.include?(attachmentFile[0..4]) and !excluded.include?(attachmentFile.chars.last(3).join)
  	      attachmentName = myEmailAttachments + "\\#{attachmentFile}"
  	      attachment.SaveAsFile(attachmentName)  
  	    end         
      end

      # Move messages from inbox to "3-Completed" if read
      if !message.UnRead
        message.Move(targetFolder)
      end
      
  end
end

def clean_email(targetFolder, mapi)
  cleanFolder = mapi.Folders.Item("chris.vallianatos@tcs.com").Folders.Item(targetFolder)
  numberOfEmails = cleanFolder.Items.Count
  numberOfEmails.downto(1) do |i|
        message = cleanFolder.Items.Item(i) 
        message.delete
  end
end

def create_outlook_object()
  # Basic common setup for Outlook objects

  outlook = WIN32OLE.new('Outlook.Application')
  mapi = outlook.GetNameSpace('MAPI')
  return mapi
end

def process_emails()
    myMapi = create_outlook_object()
    get_emails("Inbox", myMapi)
    get_emails("Sent Items", myMapi)
    clean_email("Junk Email", myMapi)
    clean_email("Deleted Items", myMapi)
end