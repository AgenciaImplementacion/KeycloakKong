die() { echo "$@" 1>&2 ; exit 1; }

kcadm=$JBOSS_HOME/bin/kcadm.sh

realm=$KC_REALM_NAME
[ -z "$realm" ] && die "Realm not set. Beware to call this script with Make!"

#########################################
# Login
#########################################
$kcadm config credentials --server http://keycloak:8080/auth --realm master --user $KEYCLOAK_USER --password $KEYCLOAK_PASSWORD
[ $? = 0 ] || die "Unable to login"

#########################################
# Test realm
#########################################
$kcadm get realms/$realm 1> /dev/null
if [ $? = 0 ]
then
  echo "Realm '$realm' already exists. Abort configuration."
  exit 0
fi

#########################################
# Create realm
#########################################
realm_id=$($kcadm create realms \
  -s realm=$realm \
  -s enabled=true -i)
[ $? = 0 ] || die "Unable to create realm"

echo "Realm '$realm_id' created."

$kcadm update realms/$realm \
  -s registrationAllowed=true \
  -s rememberMe=true
[ $? = 0 ] || die "Unable to configure realm"
echo "Realm '$realm_id' configured."

#########################################
# Create client(s)
#########################################
client_id=$($kcadm create clients \
  -r $realm \
  -s clientId=$KC_API_CLIENT_ID \
  -s baseUrl=$KC_API_CLIENT_BASEURL \
  -s "redirectUris=[\"$KC_API_CLIENT_BASEURL/*\"]" \
  -s "webOrigins=[\"+\"]" \
  -s "directAccessGrantsEnabled=true" \
  -i)
[ $? = 0 ] || die "Unable to create client"

echo "Client '$client_id' created."

#########################################
# Create roles
#########################################
$kcadm create roles -r $realm \
  -s name=ROLE_ADMIN \
  -s 'description=Regular admin with full set of permissions'
[ $? = 0 ] || die "Unable to create 'admin' role"

echo "Roles created."

#########################################
# Create users
#########################################
uid=$($kcadm create users -r $realm \
  -s username=$KC_REALM_USERNAME \
  -s enabled=true \
  -i)
[ $? = 0 ] || die "Unable to create '$KC_REALM_USERNAME' user"

$kcadm update users/$uid/reset-password \
  -r $realm \
  -s type=password \
  -s value=$KC_REALM_PASSWORD \
  -s temporary=false \
  -n
[ $? = 0 ] || die "Unable to set '$KC_REALM_USERNAME' password"

echo "User '$KC_REALM_USERNAME' created."

#########################################
# Create groups
#########################################

a_gid=$($kcadm create groups -r $realm -s name=Admin -i)
[ $? = 0 ] || die "Unable to create 'Admin' group"

gid=$($kcadm create groups -r $realm -s name=User -i)
[ $? = 0 ] || die "Unable to create 'User' group"

echo "Groups created."

#########################################
# Role affectation
#########################################
$kcadm add-roles -r $realm \
  --gname Admin --rolename ROLE_ADMIN
[ $? = 0 ] || die "Unable to affect 'admin' role to the 'Admin' group"
echo "Groups configured."

#########################################
# Group affectations
#########################################
$kcadm update users/$uid/groups/$gid \
  -r $realm \
  -s realm=$realm \
  -s userId=$uid \
  -s groupId=$gid \
  -n
[ $? = 0 ] || die "Unable to affect '$uid' user to the '$gid' group"
echo "$KC_REALM_USERNAME user affected to the 'User' group."

echo "Keycloak successfully configured."