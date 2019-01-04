require 'google/apis/sheets_v4'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'

OOB_URI          = 'urn:ietf:wg:oauth:2.0:oob'.freeze
APPLICATION_NAME = 'sarradar-rpg'.freeze
CREDENTIALS_PATH = '.build/credentials.json'.freeze
TOKEN_PATH       = '.build/token.yml'.freeze
SCOPE            = Google::Apis::SheetsV4::AUTH_SPREADSHEETS_READONLY

##
# Ensure valid credentials, either by restoring from the saved credentials
# files or intitiating an OAuth2 authorization. If authorization is required,
# the user's default browser will be launched to approve the request.
#
# @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
def authorize
	client_id   = Google::Auth::ClientId.from_file(CREDENTIALS_PATH)
	token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_PATH)
	authorizer  = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
	user_id     = 'default'

	credentials = authorizer.get_credentials(user_id)
	return credentials unless credentials.nil?

	url = authorizer.get_authorization_url(base_url: OOB_URI)
	puts 'Open the following URL in the browser and enter the ' \
		 "resulting code after authorization:\n#{url}"
	code = gets

	return authorizer.get_and_store_credentials_from_code(
		base_url: OOB_URI,
		user_id:  user_id,
		code:     code,
	)

end

task :sheets_client => '.build/credentials.json' do

	# Initialize the API
	$sheets_client = Google::Apis::SheetsV4::SheetsService.new
	$sheets_client.client_options.application_name = APPLICATION_NAME
	$sheets_client.authorization = authorize

end

file '.build/data/spells.csv' => [
	:sheets_client,
	dir_data,
] do |task|
	
	spreadsheet_id = ''
	range          = ''

	response = $sheets_client.get_spreadsheet_values(spreadsheet_id, range)

	puts 'No data found.' if response.values.empty?

	File.open task.name, 'wb' do |file|
		file << 'Name,Circle,Description,Reagents'
		response.values.each do |row|
			file << "#{row[0]},#{row[1]},#{row[2]},#{row[3]}"
		end
	end

end

