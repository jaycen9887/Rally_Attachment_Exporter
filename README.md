# Rally_Attachment_Exporter
A Ruby script to export all attachments for a project.

Instructions 

	1.	Make sure that Ruby 2.6.5 is installed (this is the version it was ran and tested with).
	2.	Make sure that the following gems are installed.
		a.	rally_api-0.9.20 
		b.	httpclient-2.8.3
	3.	Right click on the export-workspace-attachments.rb script and select “edit”
	4.	Update the below variables (located at the very top of the script):
		a.	$my_username
		b.	$my_password
		c.	$my_project_name
		d.  $my_workspace_oid 
		e.  $my_workspace_name
		f.  $vendor
		g.  $my_base_url
	5.	Open a terminal and cd into the directory containing the export-workspace-attachments.rb script and run it.
			ruby export-workspace-attachments.rb 
			Notes: The attachments will be inside a “Saved_Attachments” directory (created when the script is
			Initially ran). 
			There will be a directory for with the project name you specified to download the attachments for.  
			The “Saved_Attachments” directory will be in same directory as the export-workspace-attachments.rb 
			script. 
			There is a meta data file created for each attachment that contains information about the attachment 
			(creation date, last update date, user email address, etc).  
	6.	Do this for each project in question.
