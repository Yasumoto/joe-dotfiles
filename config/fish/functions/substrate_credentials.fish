function substrate_credentials
   set SUBSTRATE_OUTPUT (substrate credentials)
   set AWS_ACCESS_KEY_ID (echo $SUBSTRATE_OUTPUT | cut -f3 -d" " | cut -f2 -d\" )
   set AWS_SECRET_ACCESS_KEY (echo $SUBSTRATE_OUTPUT | cut -f4 -d" " | cut -f2 -d\" )
   set AWS_SESSION_TOKEN (echo $SUBSTRATE_OUTPUT | cut -f5 -d" " | cut -f2 -d\" )
   echo "[default]
aws_access_key_id     = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
aws_session_token     = $AWS_SESSION_TOKEN"

end
