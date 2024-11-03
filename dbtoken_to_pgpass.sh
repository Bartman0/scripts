#!/bin/bash

###############################################################
# Retrieve Azure Database token and store in 
# ~/.pgpass file for use by psql or other postgres clients
# 
# Arguments:
# $1 Connection
#    A Connection string like pgpass expects it.
#    "<host>:<port>:<database>:<user>:"
# 
# $2 refresh_interval
#    If refresh_interval is set, the process will
#    keep running and keep updating the token every
#    refresh_interval seconds.
#    If refresh_interval is empty, the token will be set once.
###############################################################

set +e   # required, we do our own error handling

connection="$1"
refresh_interval=$2

echo "Setting up PostgreSQL connection ${connection}"

# Log in to Azure CLI if required
if az account show -o jsonc >> /dev/null;
then
  echo "Already logged in to Azure";
else
  echo "Check browser to login";
  az login
  echo "Logged in to Azure";
fi

# Remove existing password for connection from pgpass file
sed -i .bak "/^${connection}/d" "${HOME}/.pgpass";

# Get token
token=$(az account get-access-token --resource-type oss-rdbms | jq -r .accessToken);
echo "token: ${token}"

# Write new token to pgpass file
echo "${connection}${token}" >> "${HOME}/.pgpass";

# Run again after refresh interval
if [ ! -z "${refresh_interval}" ];
then
  sleep ${refresh_interval};
  exec "$0" "${connection}" ${refresh_interval};
fi

