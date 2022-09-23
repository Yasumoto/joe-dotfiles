function substrate_credentials
   set SUBSTRATE_OUTPUT (refreshment -p (which substrate) -r ~/src/sw/infrastructure/terraform)
   set AWS_ACCESS_KEY_ID (echo $SUBSTRATE_OUTPUT | cut -f3 -d" " | cut -f2 -d\" )
   set AWS_SECRET_ACCESS_KEY (echo $SUBSTRATE_OUTPUT | cut -f4 -d" " | cut -f2 -d\" )
   set AWS_SESSION_TOKEN (echo $SUBSTRATE_OUTPUT | cut -f5 -d" " | cut -f2 -d\" )
   python -c "from os import path; from configparser import ConfigParser; config = ConfigParser(); config.read(path.expanduser('~/.aws/credentials'))
if '$AWS_ACCESS_KEY_ID' == '':
  print('Existing creds should already be wired in!')
else:
  for profile_name in ['default', 'refreshment_substrate']:
    config.set(profile_name, 'aws_access_key_id', '$AWS_ACCESS_KEY_ID')
    config.set(profile_name, 'aws_secret_access_key', '$AWS_SECRET_ACCESS_KEY')
    config.set(profile_name, 'aws_session_token', '$AWS_SESSION_TOKEN')
  with open(path.expanduser('~/.aws/credentials'), 'w') as credentialsFile:
    config.write(credentialsFile)
"

end
