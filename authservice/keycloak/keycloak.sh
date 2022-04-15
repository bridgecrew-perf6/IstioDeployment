# Talk to keycloak

options="a:r:c:u:t:vh"

function usage() {
printf "usage: $(basename $0) [options]
options:
  -a <action> : get-token | create-user | get-secret | get-jwks
  -t <token>  : Token to use
  -r <realm>  : Realm to use
  -c <client> : Client to use
  -u <user>   : User to use
  -v          : Verbose HTTP
env:
  SCHEME - http or https to use for keycloak communication
  HOST   - Hostname or IP address of the keycloak
  PORT   - Port of the keycloak

examples:
  TOKEN=\$(./keycloak.sh -a get-token -r master)
  ./keycloak.sh -a create-user -r master -t \$TOKEN
  ./keycloak.sh -a get-secret -r master -c test -t \$TOKEN
  ./keycloak.sh -a get-jwks -r master -t \$TOKEN\n"
  exit 1
}

SCHEME=${SCHEME:-https}
HOST=${HOST:-localhost}
PORT=${PORT:-443}

action=""
realm=""
client=""
user=""
token=""
verbose=""

while getopts $options opt; do
  case ${opt} in
    a )
      action=$OPTARG
      ;;
    r )
      realm=$OPTARG
      ;;
    c )
      client=$OPTARG
      ;;
    u )
      user=$OPTARG
      ;;
    t )
      token=$OPTARG
      ;;
    v )
      verbose="-v"
      ;;
    h )
      usage
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      usage
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      usage      
      ;;
  esac
done
shift $((OPTIND -1))

function get_token() {
  curl $verbose -k -s -L -X POST "${SCHEME}://$HOST:$PORT/auth/realms/$realm/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin" \
  -d 'password=admin' \
  -d 'grant_type=password' \
  -d 'client_id=admin-cli' | jq -r '.access_token'
}

function create_user() {
  curl $verbose -k -X POST "${SCHEME}://$HOST:$PORT/auth/admin/realms/$realm/clients" \
   -H "authorization: Bearer ${token}" \
   -H "Content-Type: application/json" \
   --data \
   '{
      "id": "test",
      "name": "test",
      "redirectUris": ["*"]
   }' 
}

function get_secret() {
  curl $verbose -k -s "${SCHEME}://$HOST:$PORT/auth/admin/realms/$realm/clients/$client/client-secret" \
   -H "authorization: Bearer ${token}" \
   -H "Content-Type: application/json" | jq -r '.value'
}

function get_jwks() {
  curl $verbose -k -s "${SCHEME}://$HOST:$PORT/auth/realms/$realm/protocol/openid-connect/certs" \
   -H "authorization: Bearer ${token}" \
   -H "Content-Type: application/json" 
}

if [[ $verbose != "" ]]; then
  echo "Keycloak URL: $SCHEME://$HOST:$PORT"
fi

case ${action} in 
  "get-token")
    if [ -z $realm ]; then
      usage
    fi
    get_token
  ;;
  "create-user")
    if [[ -z $realm || -z $token ]]; then
      usage
    fi
    create_user
  ;;
  "get-secret")
    if [[ -z $realm || -z $token || -z $client ]]; then
      usage
    fi
    get_secret
  ;;
  "get-jwks")
    if [[ -z $realm || -z $token ]]; then
      usage
    fi
    get_jwks
  ;;
esac
