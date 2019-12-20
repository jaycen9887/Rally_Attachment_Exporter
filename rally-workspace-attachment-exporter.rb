# ------------------------------------------------------------------------------
# Change the below variables
#
$my_username	       = "youremail@domain.com"
$my_password	       = "super_secret_password"
$my_project_name       = "project name here"
$my_workspace_oid      = "0123456789" 
$my_workspace_name 	   = "workspace name here" 
$vendor                = "Vendor Name for custom headers"
$my_base_url	       = "https://rally1.rallydev.com/slm"


# ------------------------------------------------------------------------------

#DO NOT CHANGE ANYTHING BELOW THIS LINE

# ------------------------------------------------------------------------------

require "rally_api"
require "base64"
require "pp"

# ------------------------------------------------------------------------------
# Connect to Rally.
#
def connect_to_rally ()
	custom_headers		= RallyAPI::CustomHttpHeader.new()
	custom_headers.name	= "export-workspace-attachments"
	custom_headers.vendor   = "#{$vendor}"
	custom_headers.version  = "1.0"

	config	= {	:base_url	=> "#{$my_base_url}"}
	config[:username]	= $my_username
	config[:password]	= $my_password
	config[:workspace]	= $my_workspace_name
	config[:project]	= $my_project_name
	config[:version]    = "v2.0"
	config[:headers]	= custom_headers

	print "Attempting connection to Rally as username: #{config[:username]} at URL: #{$my_base_url}...\n"
	@rally = RallyAPI::RallyRestJson.new(config)
	puts "Connection to Rally succeeded."
	puts "Putting RALLY"
	puts @rally
	
	get_workspace(@rally)
end


# ------------------------------------------------------------------------------
# Query for Workspace information.
#
def get_workspace(rally)

	query = RallyAPI::RallyQuery.new()
	query.type = :workspace
	query.fetch = "Name"

	query.workspace = {"_ref" => "#{$my_base_url}/webservice/#{$my_api_version}/workspace/#{$my_workspace_oid}.js" } 
	@my_workspace = @rally.find(query)

	print "Query returned the Workspace: #{@my_workspace.first}\n"
end

DIR_NEW = 0	# Directory must be new (exit if it exists)
DIR_CAN_BE_OLD = 1	# Use existing directory if it already exists

def create_export_dir (dir_name, state)

	if Dir.exists?(dir_name) && state == DIR_CAN_BE_OLD
		puts "ERROR-01: Directory already exists: #{dir_name}\n"
		exit
	end

	if Dir.exists?(dir_name)
		return
	else
		Dir.mkdir (dir_name)
		if ! Dir.exists?(dir_name)
			puts "ERROR-02: Could not create directory: #{dir_name}\n"
			exit
		end
	end
end


# ------------------------------------------------------------------------------
# Get a count of the number of OPEN Projects in this Workspace.
#
def get_open_project_count (this_workspace)
	query			= RallyAPI::RallyQuery.new()
        query.workspace         = this_workspace
	query.project		= nil
	query.project_scope_up	= true
	query.project_scope_down= true
	query.type		= :project
	query.fetch		= "Name"
	query.query_string	= "(State = \"Open\")"

	begin #{
        all_open_projects	= @rally.find(query)
		open_project_count	= all_open_projects.total_result_count
	rescue Exception => e  
		open_project_count	= 0
	end #}
	
	puts "Open Project count: #{open_project_count}"

	return (open_project_count)
end


# ------------------------------------------------------------------------------
# Get all the attachments in a Workspace.
#
def get_all_workspace_attachments (this_workspace)
        query		= RallyAPI::RallyQuery.new()
	query.workspace	= this_workspace
        query.type	= :attachment

        query.fetch	=		"Artifact"
        query.fetch	= query.fetch + ",Build"
        query.fetch	= query.fetch + ",Content"
        query.fetch	= query.fetch + ",ContentType"
        query.fetch	= query.fetch + ",CreationDate"
        query.fetch	= query.fetch + ",Date"
        query.fetch	= query.fetch + ",Description"
        query.fetch	= query.fetch + ",DisplayName"
        query.fetch	= query.fetch + ",EmailAddress"
        query.fetch	= query.fetch + ",FormattedID"
        query.fetch	= query.fetch + ",LastUpdateDate"
        query.fetch	= query.fetch + ",Name"
        query.fetch	= query.fetch + ",ObjectID"
        query.fetch	= query.fetch + ",Size"
        query.fetch	= query.fetch + ",TestCase"
        query.fetch	= query.fetch + ",TestCaseResult"
        query.fetch	= query.fetch + ",TestSet"
        query.fetch	= query.fetch + ",User"

        all_workspace_attachments	= @rally.find(query)

	return (all_workspace_attachments)
end


# ------------------------------------------------------------------------------
# Main code starts here.
#
puts "STARTING..."
connect_to_rally()

#get_all_workspaces()
total_all_workspaces = @my_workspace.count


# ------------------------------------------------------------------------------
# Create a new directory to hold all attachments.
#
root_dir = "./Saved_Attachments"
print "Creating the root directory for saving attachments: #{root_dir}\n"
create_export_dir(root_dir, DIR_NEW)



# ------------------------------------------------------------------------------
# Loop through, processing each Workspace we found.
#
count_all_attachments = 0
total_bytes = 0
type_hash = Hash.new (0)

@my_workspace.each_with_index do | this_workspace, count_workspace | #{

	# Debugging code ... don't do them all
	#if count_workspace != 10531 then
	#	next
	#end

	print "Workspace [%03d of %03d] Name=#{this_workspace.Name}  State=#{this_workspace.State}"%[count_workspace+1,total_all_workspaces]
	if this_workspace.State == "Closed"
		print "...  being skipped.\n"
		next
	end


	# ----------------------------------------------------------------------
	# Only process Workspaces which have at least one OPEN Project.
	#
	open_project_count = get_open_project_count(this_workspace)
	print "  OPEN projects=#{open_project_count}"
	if open_project_count < 1 #{
		print "...  being skipped.\n"
		next
	end #} of "if open_project_count < 1"


	# ----------------------------------------------------------------------
	# Get all attachments in the Workspace.
	#
	all_workspace_attachments = get_all_workspace_attachments(this_workspace)
	print "  Attachments=#{all_workspace_attachments.total_result_count}"
	if all_workspace_attachments.total_result_count < 1 #{
		print "...  being skipped.\n"
		next
	end
	print ".\n"


	# ----------------------------------------------------------------------
	# Loop through and process each Attachment.
	#
	all_workspace_attachments.each_with_index do |this_workspace_attachment, count_workspace_attachments| #{
		count_all_attachments += 1

		print "     %05d - Attachment[%03d] Size=#{this_workspace_attachment.Size}\n"%[count_all_attachments, count_workspace_attachments + 1 ]
		# Debugging code ... don't do them all
		#if count_all_attachments != 35 then
		#	next
		#end


		# --------------------------------------------------------------
		# Create a new directory within our root_dir for each project
		# name.
		#
		dir_name_workspace = root_dir + "/#{$my_project_name}/"
		if count_workspace_attachments == 0
			print "Create a workspace directory within the root_dir for saving attachments: #{dir_name_workspace}\n"
			create_export_dir(dir_name_workspace, DIR_NEW)
		end
		dir_name_artifact = dir_name_workspace


		# --------------------------------------------------------------
		# Save Artifact information (if any) from this attachment.
		#
		total_bytes = total_bytes + this_workspace_attachment.Size
		if this_workspace_attachment.Artifact != nil #{
			artifact_formatted_id = this_workspace_attachment.Artifact.FormattedID
			artifact_creation_date = this_workspace_attachment.Artifact.CreationDate
			artifact_last_update_date = this_workspace_attachment.Artifact.LastUpdateDate
			dir_name_artifact = dir_name_artifact + artifact_formatted_id
		else
			artifact_formatted_id = "(n/a)"
			artifact_creation_date = "(n/a)"
			artifact_last_update_date = "(n/a)"
		end #} of "if this_workspace_attachment.Artifact != nil"


		# --------------------------------------------------------------
		# Save TestCaseResult information (if any) from this attachment.
		#
		test_set_formatted_id = "(n/a)"
		if this_workspace_attachment.TestCaseResult != nil #{
			test_case_result_date = this_workspace_attachment.TestCaseResult.Date
			test_case_result_build = this_workspace_attachment.TestCaseResult.Build
			test_case_formatted_id = "#{this_workspace_attachment.TestCaseResult.TestCase.FormattedID}"
			dir_name_artifact = dir_name_artifact + test_case_formatted_id

			# ------------------------------------------------------
			# Does this Attachment.TestCaseResult also have a TestSet?
			if this_workspace_attachment.TestCaseResult.TestSet != nil
				test_set_formatted_id = "#{this_workspace_attachment.TestCaseResult.TestSet.FormattedID}"
				dir_name_artifact = dir_name_artifact + "-" + test_set_formatted_id
			end
		else
			test_case_result_date = test_case_result_build = test_case_formatted_id = "(n/a)"
			# ------------------------------------------------------
			# Does Attachment have neither an Artifact or a TestCaseResult?
			if artifact_formatted_id == "(n/a)"
				print "WARNING: Orphaned attachment found (has no Artifact or TestCaseResult).\n"
				dir_name_artifact = dir_name_artifact + "-Orphaned"
			end
		end #} of "if this_workspace_attachment.TestCaseResult != nil"


		# --------------------------------------------------------------
		# Create a new directory within our Workspace directory for each
		# artifact or testcase or testset.
		#
		print "Create an artifact directory within the workspace directory for saving attachments: #{dir_name_artifact}\n"
		create_export_dir(dir_name_artifact, DIR_NEW)


		# --------------------------------------------------------------
		# Create a META-data file.
		#
		file_name_meta = dir_name_artifact + "/attachment-%03d.META.txt"%[count_workspace_attachments+1]
		print         "           Creating METADATA: filename=#{file_name_meta}\n"
		file_meta = File.new(file_name_meta,"wb")

		file_meta.syswrite "Attachment.Artifact.FormattedID                : #{artifact_formatted_id}\n"
		file_meta.syswrite "Attachment.Artifact.CreationDate               : #{artifact_creation_date}\n"
		file_meta.syswrite "Attachment.Artifact.LastUpdateDate             : #{artifact_last_update_date}\n"
		file_meta.syswrite "Attachment.TestCaseResult.Date                 : #{test_case_result_date}\n"
		file_meta.syswrite "Attachment.TestCaseResult.Build                : #{test_case_result_build}\n"
		file_meta.syswrite "Attachment.TestCaseResult.TestCase.FormattedID : #{test_case_formatted_id}\n"
		file_meta.syswrite "Attachment.TestCaseResult.TestSet.FormattedID  : #{test_set_formatted_id}\n"
		file_meta.syswrite "Attachment.ContentType                         : #{this_workspace_attachment.ContentType}\n"
		file_meta.syswrite "Attachment.Description                         : #{this_workspace_attachment.Description}\n"
		file_meta.syswrite "Attachment.Name                                : #{this_workspace_attachment.Name}\n"
		file_meta.syswrite "Attachment.Size                                : #{this_workspace_attachment.Size}\n"
		file_meta.syswrite "Attachment.User.EmailAddress                   : #{this_workspace_attachment.User.EmailAddress}\n"
		file_meta.syswrite "Attachment.User.DisplayName                    : #{this_workspace_attachment.User.DisplayName}\n"

		file_meta.close


		# --------------------------------------------------------------
		# Create a real data file which contains the decoded (from Base64)
		# Attachment content.
		#
		file_name_data = dir_name_artifact + "/attachment-%03d.DATA"%[count_workspace_attachments+1]

		if this_workspace_attachment.Content == nil
			# Yes it is possible to have an attachment with no content
			extension = ".empty"
			file_data = File.new(file_name_data + extension,"wb")
		else
			extension = "." + this_workspace_attachment.Name.split(".")[-1]
			file_data = File.new(file_name_data + extension,"wb")
			this_content = this_workspace_attachment.Content.read 
			file_data.syswrite(Base64.decode64(this_content.Content))
		end
		type_hash[extension.downcase] += 1
		print         "           Wrote DATA filename=#{file_name_data}  Size=#{this_workspace_attachment.Size}\n"

		file_data.close

	end #} of "all_workspace_attachments.each_with_index do |this_workspace_attachment,count_workspace_attachments|}

end #} of "all_workspaces.each_with_index do |this_workspace, count_workspace|"

byte_string = total_bytes.to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1,")
print "Found a total of #{count_all_attachments} attachments in ALL WORKSPACES; total bytes = %s.\n"%[byte_string]
pp type_hash.sort
